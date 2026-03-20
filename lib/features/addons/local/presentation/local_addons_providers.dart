import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';
import 'package:wow_qaddons_manager/features/addons/local/application/local_addons_use_cases.dart';

class LocalAddonsNotifier
    extends StateNotifier<AsyncValue<List<InstalledAddonGroup>>> {
  final LoadLocalAddonsUseCase _loadLocalAddonsUseCase;
  final RegisterInstalledAddonUseCase _registerInstalledAddonUseCase;
  final ImportLocalAddonUseCase _importLocalAddonUseCase;
  final DeleteLocalAddonsUseCase _deleteLocalAddonsUseCase;
  final GameClient _client;

  LocalAddonsNotifier(
    this._loadLocalAddonsUseCase,
    this._registerInstalledAddonUseCase,
    this._importLocalAddonUseCase,
    this._deleteLocalAddonsUseCase,
    this._client,
  ) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    final previousAddons = state.valueOrNull;
    if (previousAddons == null) {
      state = const AsyncValue.loading();
    }

    try {
      final addons = await _loadLocalAddonsUseCase(_client);
      state = AsyncValue.data(addons);
    } catch (error, stackTrace) {
      if (previousAddons != null) {
        state = AsyncValue.data(previousAddons);
        return;
      }

      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> registerInstalledAddon(
    AddonItem addon,
    List<String> installedFolders,
  ) async {
    try {
      await _registerInstalledAddonUseCase(
        _client,
        addon: addon,
        installedFolders: installedFolders,
      );
      await refresh();
    } catch (_) {
      await refresh();
      rethrow;
    }
  }

  Future<void> importAddonFromArchive(
    String archivePath, {
    bool replaceExisting = false,
  }) async {
    try {
      await _importLocalAddonUseCase(
        _client,
        archivePath: archivePath,
        replaceExisting: replaceExisting,
      );
      await refresh();
    } catch (_) {
      await refresh();
      rethrow;
    }
  }

  Future<void> deleteAddon(InstalledAddonGroup group) async {
    return deleteAddons(<InstalledAddonGroup>[group]);
  }

  Future<void> deleteAddons(List<InstalledAddonGroup> groups) async {
    try {
      await _deleteLocalAddonsUseCase(_client, groups);
      await refresh();
    } catch (_) {
      await refresh();
      rethrow;
    }
  }
}

final localAddonsProvider =
    StateNotifierProvider.family<
      LocalAddonsNotifier,
      AsyncValue<List<InstalledAddonGroup>>,
      GameClient
    >((ref, client) {
      return LocalAddonsNotifier(
        ref.read(loadLocalAddonsUseCaseProvider),
        ref.read(registerInstalledAddonUseCaseProvider),
        ref.read(importLocalAddonUseCaseProvider),
        ref.read(deleteLocalAddonsUseCaseProvider),
        client,
      );
    });
