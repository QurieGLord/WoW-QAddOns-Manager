import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';

enum ClientType {
  retail,
  classic,
  ptr,
  legacy,
  unknown,
}

class GameClient {
  final String id;
  final String path;
  final String version;
  final String build;
  final ClientType type;
  final String? productCode;
  final String? executableName;
  final String? displayName;

  String get resolvedDisplayName => buildDisplayName(
    version: version,
    type: type,
    productCode: productCode,
    executableName: executableName,
  );

  GameClient({
    required this.id,
    required this.path,
    required this.version,
    required this.build,
    required this.type,
    this.productCode,
    this.executableName,
    this.displayName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'version': version,
    'build': build,
    'type': type.name,
    'productCode': productCode,
    'executableName': executableName,
    'displayName': displayName,
  };

  factory GameClient.fromJson(Map<String, dynamic> json) => GameClient(
    id: json['id'],
    path: json['path'],
    version: json['version'],
    build: json['build'],
    type: ClientType.values.firstWhere((e) => e.name == json['type']),
    productCode: json['productCode'],
    executableName: json['executableName'],
    displayName: json['displayName'],
  );

  GameClient copyWith({
    String? displayName,
    String? version,
    String? build,
    ClientType? type,
    String? productCode,
  }) {
    return GameClient(
      id: id,
      path: path,
      version: version ?? this.version,
      build: build ?? this.build,
      type: type ?? this.type,
      productCode: productCode ?? this.productCode,
      executableName: executableName,
      displayName: displayName ?? this.displayName,
    );
  }

  static ClientType inferTypeForVersion(
    String version, {
    String? productCode,
    ClientType? fallbackType,
  }) {
    final normalizedProduct = productCode?.trim().toLowerCase() ?? '';
    if (normalizedProduct.contains('ptr')) {
      return ClientType.ptr;
    }
    if (normalizedProduct.contains('classic') || normalizedProduct.contains('era')) {
      return ClientType.classic;
    }
    if (normalizedProduct == 'wow' || normalizedProduct == 'wow_beta') {
      return ClientType.retail;
    }

    final profile = WowVersionProfile.parse(version);
    return switch (profile.family) {
      WowVersionFamily.battleForAzeroth ||
      WowVersionFamily.shadowlands ||
      WowVersionFamily.dragonflight ||
      WowVersionFamily.warWithin => ClientType.retail,
      WowVersionFamily.vanilla => fallbackType == ClientType.classic
          ? ClientType.classic
          : ClientType.legacy,
      WowVersionFamily.unknown => fallbackType ?? ClientType.legacy,
      _ => ClientType.legacy,
    };
  }

  static String buildDisplayName({
    required String version,
    required ClientType type,
    String? productCode,
    String? executableName,
  }) {
    if (version.trim().isEmpty || version == 'Unknown') {
      return executableName?.replaceAll('.exe', '') ?? 'World of Warcraft: Legacy Client';
    }

    final profile = WowVersionProfile.parse(version);
    var label = _labelForProfile(
      profile,
      type: type,
      productCode: productCode,
    );

    if (type == ClientType.ptr && !label.endsWith('PTR')) {
      label = '$label PTR';
    }

    return 'World of Warcraft: $label (${profile.exactVersion})';
  }

  static String _labelForProfile(
    WowVersionProfile profile, {
    required ClientType type,
    String? productCode,
  }) {
    final normalizedProduct = productCode?.trim().toLowerCase() ?? '';
    final isClassicProduct =
        normalizedProduct.contains('classic') || normalizedProduct.contains('era');

    return switch (profile.family) {
      WowVersionFamily.vanilla =>
        profile.exactVersion.startsWith('1.15') || normalizedProduct.contains('sod')
            ? 'Season of Discovery'
            : type == ClientType.classic || isClassicProduct
            ? 'Classic Era'
            : 'Vanilla',
      WowVersionFamily.burningCrusade =>
        type == ClientType.classic || isClassicProduct
            ? 'Burning Crusade Classic'
            : 'Burning Crusade',
      WowVersionFamily.wrath =>
        type == ClientType.classic || isClassicProduct
            ? 'Wrath Classic'
            : 'Wrath of the Lich King',
      WowVersionFamily.cataclysm =>
        type == ClientType.classic || isClassicProduct
            ? 'Cataclysm Classic'
            : 'Cataclysm',
      WowVersionFamily.mistsOfPandaria => 'Mists of Pandaria',
      WowVersionFamily.warlordsOfDraenor => 'Warlords of Draenor',
      WowVersionFamily.legion => 'Legion',
      WowVersionFamily.battleForAzeroth => 'Battle for Azeroth',
      WowVersionFamily.shadowlands => 'Shadowlands',
      WowVersionFamily.dragonflight => 'Dragonflight',
      WowVersionFamily.warWithin => 'The War Within',
      WowVersionFamily.unknown => switch (type) {
        ClientType.retail => 'Retail',
        ClientType.classic => 'Classic',
        ClientType.ptr => 'PTR',
        _ => 'Legacy Client',
      },
    };
  }
}
