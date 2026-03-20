import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';

class AddonRegistryService {
  static const String _fileName = '.wow_qaddons_registry.json';

  Future<List<InstalledAddonGroup>> loadAddonGroups(
    GameClient client,
    List<InstalledAddonFolder> scannedFolders,
  ) async {
    final registryEntries = await _readRegistry(client);
    final scannedMap = {
      for (final folder in scannedFolders) folder.folderName: folder,
    };

    final syncedManagedGroups = registryEntries
        .map((group) {
          final existingFolders =
              group.installedFolders.where(scannedMap.containsKey).toList()
                ..sort();
          if (existingFolders.isEmpty) {
            return null;
          }

          final folderDetails = existingFolders
              .map((folderName) => scannedMap[folderName])
              .whereType<InstalledAddonFolder>()
              .toList(growable: false);

          return group.copyWith(
            displayName: group.displayName,
            installedFolders: existingFolders,
            isManaged: true,
            folderDetails: folderDetails,
          );
        })
        .whereType<InstalledAddonGroup>()
        .toList();

    await _writeRegistry(client, syncedManagedGroups);

    final managedFolders = syncedManagedGroups
        .expand((group) => group.installedFolders)
        .toSet();
    final manualFolders = scannedFolders
        .where((folder) => !managedFolders.contains(folder.folderName))
        .toList();
    final manualGroups = _buildManualGroups(manualFolders);

    final groups = [...syncedManagedGroups, ...manualGroups];
    groups.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return groups;
  }

  Future<void> registerInstallation(
    GameClient client, {
    required AddonItem addon,
    required List<String> installedFolders,
  }) async {
    final folders = installedFolders.toSet().toList()..sort();
    if (folders.isEmpty) {
      return;
    }

    final registryEntries = await _readRegistry(client);
    registryEntries.removeWhere(
      (group) =>
          group.id == _buildManagedId(addon) ||
          group.installedFolders.any(folders.contains),
    );

    registryEntries.add(
      InstalledAddonGroup(
        id: _buildManagedId(addon),
        displayName: addon.name,
        providerName: addon.providerName,
        originalId: addon.originalId.toString(),
        version: addon.version,
        thumbnailUrl: addon.thumbnailUrl,
        installedFolders: folders,
        isManaged: true,
      ),
    );

    await _writeRegistry(client, registryEntries);
  }

  Future<void> removeGroup(GameClient client, InstalledAddonGroup group) async {
    final registryEntries = await _readRegistry(client);
    registryEntries.removeWhere(
      (entry) =>
          entry.id == group.id ||
          entry.installedFolders.any(group.installedFolders.contains),
    );
    await _writeRegistry(client, registryEntries);
  }

  List<InstalledAddonGroup> _buildManualGroups(
    List<InstalledAddonFolder> folders,
  ) {
    final groups = <InstalledAddonGroup>[];

    if (folders.isEmpty) {
      return groups;
    }

    final byFolderName = {
      for (final folder in folders) folder.folderName: folder,
    };
    final aliasIndex = _buildAliasIndex(folders);
    final parentByChild = <String, String>{};

    for (final folder in folders) {
      final parent = _resolveExplicitParent(
        folder,
        byFolderName,
        aliasIndex,
        parentByChild,
      );
      if (parent != null) {
        parentByChild[folder.folderName] = parent.folderName;
      }
    }

    final groupedFolderNames = parentByChild.keys.toSet()
      ..addAll(parentByChild.values);
    final orphanFolders = folders
        .where((folder) => !groupedFolderNames.contains(folder.folderName))
        .toList();
    final syntheticGroups = _buildFallbackSyntheticGroups(
      orphanFolders,
      byFolderName,
      parentByChild,
    );

    final groupedByRoot = <String, List<InstalledAddonFolder>>{};
    for (final folder in folders) {
      if (_belongsToSyntheticGroup(folder.folderName, syntheticGroups)) {
        continue;
      }

      final rootName = _findRootFolderName(folder.folderName, parentByChild);
      groupedByRoot.putIfAbsent(rootName, () => []).add(folder);
    }

    for (final entry in groupedByRoot.entries) {
      final root = byFolderName[entry.key];
      if (root == null) {
        continue;
      }

      final foldersInGroup = entry.value.toList()
        ..sort(
          (a, b) =>
              a.folderName.toLowerCase().compareTo(b.folderName.toLowerCase()),
        );
      groups.add(
        InstalledAddonGroup(
          id: 'manual:${root.folderName.toLowerCase()}',
          displayName: root.title,
          installedFolders: foldersInGroup
              .map((folder) => folder.folderName)
              .toList(),
          isManaged: false,
          folderDetails: foldersInGroup,
        ),
      );
    }

    for (final syntheticGroup in syntheticGroups) {
      final sortedFolders = syntheticGroup.folders.toList()
        ..sort(
          (a, b) =>
              a.folderName.toLowerCase().compareTo(b.folderName.toLowerCase()),
        );
      groups.add(
        InstalledAddonGroup(
          id: 'manual:${syntheticGroup.id}',
          displayName: syntheticGroup.displayName,
          installedFolders: sortedFolders
              .map((folder) => folder.folderName)
              .toList(),
          isManaged: false,
          folderDetails: sortedFolders,
        ),
      );
    }

    return groups;
  }

  Map<String, InstalledAddonFolder> _buildAliasIndex(
    List<InstalledAddonFolder> folders,
  ) {
    final aliases = <String, InstalledAddonFolder>{};

    for (final folder in folders) {
      aliases[_normalizeKey(folder.folderName)] = folder;
      aliases[_normalizeKey(folder.title)] = folder;
      aliases[_normalizeKey(folder.displayName)] = folder;

      final titleBase = _extractTitleGroupBase(folder.title);
      final normalizedTitleBase = _normalizeKey(titleBase);
      if (normalizedTitleBase.isNotEmpty) {
        aliases.putIfAbsent(normalizedTitleBase, () => folder);
      }
    }

    return aliases;
  }

  InstalledAddonFolder? _resolveExplicitParent(
    InstalledAddonFolder folder,
    Map<String, InstalledAddonFolder> byFolderName,
    Map<String, InstalledAddonFolder> aliasIndex,
    Map<String, String> parentByChild,
  ) {
    final xPartTarget = folder.xPartOf?.trim();
    if (xPartTarget != null && xPartTarget.isNotEmpty) {
      final parent = _findFolderReference(
        xPartTarget,
        byFolderName,
        aliasIndex,
      );
      if (_isValidParent(folder, parent, parentByChild)) {
        return parent;
      }
    }

    for (final dependency in folder.dependencies) {
      final parent = _findFolderReference(dependency, byFolderName, aliasIndex);
      if (_isValidParent(folder, parent, parentByChild)) {
        return parent;
      }
    }

    return null;
  }

  InstalledAddonFolder? _findFolderReference(
    String rawReference,
    Map<String, InstalledAddonFolder> byFolderName,
    Map<String, InstalledAddonFolder> aliasIndex,
  ) {
    final reference = rawReference.trim();
    if (reference.isEmpty) {
      return null;
    }

    final exactFolder = byFolderName[reference];
    if (exactFolder != null) {
      return exactFolder;
    }

    return aliasIndex[_normalizeKey(reference)];
  }

  bool _isValidParent(
    InstalledAddonFolder child,
    InstalledAddonFolder? parent,
    Map<String, String> parentByChild,
  ) {
    if (parent == null || parent.folderName == child.folderName) {
      return false;
    }

    return !_createsCycle(child.folderName, parent.folderName, parentByChild);
  }

  bool _createsCycle(
    String childFolder,
    String parentFolder,
    Map<String, String> parentByChild,
  ) {
    var cursor = parentFolder;
    while (parentByChild.containsKey(cursor)) {
      cursor = parentByChild[cursor]!;
      if (cursor == childFolder) {
        return true;
      }
    }

    return false;
  }

  List<_SyntheticManualGroup> _buildFallbackSyntheticGroups(
    List<InstalledAddonFolder> orphanFolders,
    Map<String, InstalledAddonFolder> byFolderName,
    Map<String, String> parentByChild,
  ) {
    final groups = <_SyntheticManualGroup>[];
    final assignedFolders = <String>{};

    final prefixBuckets = <String, List<InstalledAddonFolder>>{};
    for (final folder in orphanFolders) {
      final prefix = _extractFolderPrefix(folder.folderName);
      if (prefix == null) {
        continue;
      }
      prefixBuckets.putIfAbsent(prefix, () => []).add(folder);
    }

    for (final entry in prefixBuckets.entries) {
      final members = entry.value;
      if (members.length < 2) {
        continue;
      }

      final root = byFolderName[entry.key];
      if (root != null) {
        for (final member in members) {
          if (member.folderName == root.folderName ||
              assignedFolders.contains(member.folderName)) {
            continue;
          }
          parentByChild[member.folderName] = root.folderName;
          assignedFolders.add(member.folderName);
        }
        assignedFolders.add(root.folderName);
        continue;
      }

      final unassignedMembers = members
          .where((member) => !assignedFolders.contains(member.folderName))
          .toList();
      if (unassignedMembers.length >= 2) {
        groups.add(
          _SyntheticManualGroup(
            id: 'prefix:${entry.key.toLowerCase()}',
            displayName: _prettifyManualDisplayName(
              entry.key,
              unassignedMembers.first.title,
            ),
            folders: unassignedMembers,
          ),
        );
        assignedFolders.addAll(
          unassignedMembers.map((member) => member.folderName),
        );
      }
    }

    final titleBuckets = <String, List<InstalledAddonFolder>>{};
    for (final folder in orphanFolders) {
      if (assignedFolders.contains(folder.folderName)) {
        continue;
      }

      final titleKey = _extractTitleGroupBase(folder.title);
      final normalized = _normalizeKey(titleKey);
      if (normalized.length < 4) {
        continue;
      }

      titleBuckets.putIfAbsent(normalized, () => []).add(folder);
    }

    for (final entry in titleBuckets.entries) {
      final members = entry.value
          .where((folder) => !assignedFolders.contains(folder.folderName))
          .toList();
      if (members.length < 2) {
        continue;
      }

      final root = members.firstWhere(
        (folder) =>
            _normalizeKey(folder.title) == entry.key ||
            _normalizeKey(folder.folderName) == entry.key,
        orElse: () => members.first,
      );

      final normalizedRootFolder = _normalizeKey(root.folderName);
      final normalizedRootTitle = _normalizeKey(root.title);

      final hasDedicatedRoot =
          normalizedRootFolder == entry.key || normalizedRootTitle == entry.key;
      if (hasDedicatedRoot) {
        for (final member in members) {
          if (member.folderName == root.folderName) {
            continue;
          }
          parentByChild[member.folderName] = root.folderName;
        }
        assignedFolders.addAll(members.map((member) => member.folderName));
        continue;
      }

      groups.add(
        _SyntheticManualGroup(
          id: 'title:${entry.key}',
          displayName: _humanizeTitleGroup(entry.key, members.first.title),
          folders: members,
        ),
      );
      assignedFolders.addAll(members.map((member) => member.folderName));
    }

    return groups;
  }

  bool _belongsToSyntheticGroup(
    String folderName,
    List<_SyntheticManualGroup> groups,
  ) {
    for (final group in groups) {
      if (group.folders.any((folder) => folder.folderName == folderName)) {
        return true;
      }
    }
    return false;
  }

  String _findRootFolderName(
    String folderName,
    Map<String, String> parentByChild,
  ) {
    var cursor = folderName;
    while (parentByChild.containsKey(cursor)) {
      cursor = parentByChild[cursor]!;
    }
    return cursor;
  }

  String? _extractFolderPrefix(String folderName) {
    final parts = folderName.split(RegExp(r'[_-]'));
    if (parts.length < 2) {
      return null;
    }

    final prefix = parts.first.trim();
    return prefix.isEmpty ? null : prefix;
  }

  String _extractTitleGroupBase(String title) {
    final withoutBrackets = title.replaceAll(RegExp(r'\[[^\]]+\]'), '').trim();
    final withoutParentheses = withoutBrackets
        .replaceAll(RegExp(r'\([^\)]+\)'), '')
        .trim();
    final splitByDash = withoutParentheses
        .split(RegExp(r'\s*[-:]\s*'))
        .first
        .trim();
    return splitByDash.isEmpty ? title.trim() : splitByDash;
  }

  String _prettifyManualDisplayName(String key, String fallbackDisplayName) {
    final cleanedFallback = fallbackDisplayName
        .split(RegExp(r'\s*[-:]\s*'))
        .first
        .trim();
    if (cleanedFallback.isNotEmpty) {
      return cleanedFallback;
    }
    return key;
  }

  String _humanizeTitleGroup(String normalizedKey, String fallbackTitle) {
    final titleBase = _extractTitleGroupBase(fallbackTitle);
    if (titleBase.isNotEmpty) {
      return titleBase;
    }

    return normalizedKey;
  }

  String _normalizeKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9!]'), '');
  }

  String _buildManagedId(AddonItem addon) {
    final provider = addon.providerName.toLowerCase();
    final originalId = addon.originalId.toString().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9._/-]+'),
      '-',
    );
    if (originalId.isNotEmpty) {
      return '$provider:$originalId';
    }

    final normalizedName = addon.name.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    return '$provider:$normalizedName';
  }

  Future<List<InstalledAddonGroup>> _readRegistry(GameClient client) async {
    final file = _registryFile(client);
    if (!await file.exists()) {
      return [];
    }

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .map(InstalledAddonGroup.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeRegistry(
    GameClient client,
    List<InstalledAddonGroup> groups,
  ) async {
    final file = _registryFile(client);
    await file.parent.create(recursive: true);
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(groups.map((group) => group.toJson()).toList());
    await file.writeAsString(json);
  }

  File _registryFile(GameClient client) {
    return File(p.join(client.path, 'Interface', 'AddOns', _fileName));
  }
}

class _SyntheticManualGroup {
  final String id;
  final String displayName;
  final List<InstalledAddonFolder> folders;

  const _SyntheticManualGroup({
    required this.id,
    required this.displayName,
    required this.folders,
  });
}
