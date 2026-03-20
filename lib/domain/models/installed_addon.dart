class InstalledAddonFolder {
  final String folderName;
  final String displayName;
  final String title;
  final List<String> tocNames;
  final List<String> dependencies;
  final String? xPartOf;

  const InstalledAddonFolder({
    required this.folderName,
    required this.displayName,
    required this.title,
    this.tocNames = const <String>[],
    this.dependencies = const <String>[],
    this.xPartOf,
  });
}

class InstalledAddonGroup {
  final String id;
  final String displayName;
  final String? providerName;
  final String? originalId;
  final String? version;
  final String? thumbnailUrl;
  final List<String> installedFolders;
  final bool isManaged;
  final List<InstalledAddonFolder> folderDetails;

  const InstalledAddonGroup({
    required this.id,
    required this.displayName,
    required this.installedFolders,
    this.providerName,
    this.originalId,
    this.version,
    this.thumbnailUrl,
    this.isManaged = false,
    this.folderDetails = const <InstalledAddonFolder>[],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'providerName': providerName,
    'originalId': originalId,
    'version': version,
    'thumbnailUrl': thumbnailUrl,
    'installedFolders': installedFolders,
    'isManaged': isManaged,
  };

  factory InstalledAddonGroup.fromJson(Map<String, dynamic> json) {
    return InstalledAddonGroup(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      providerName: json['providerName'] as String?,
      originalId: json['originalId']?.toString(),
      version: json['version'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      installedFolders:
          ((json['installedFolders'] as List<dynamic>? ?? const <dynamic>[])
                  .whereType<String>())
              .toList(),
      isManaged: json['isManaged'] as bool? ?? false,
    );
  }

  InstalledAddonGroup copyWith({
    String? id,
    String? displayName,
    String? providerName,
    String? originalId,
    String? version,
    String? thumbnailUrl,
    List<String>? installedFolders,
    bool? isManaged,
    List<InstalledAddonFolder>? folderDetails,
  }) {
    return InstalledAddonGroup(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      providerName: providerName ?? this.providerName,
      originalId: originalId ?? this.originalId,
      version: version ?? this.version,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      installedFolders: installedFolders ?? this.installedFolders,
      isManaged: isManaged ?? this.isManaged,
      folderDetails: folderDetails ?? this.folderDetails,
    );
  }
}

class AddonInstallResult {
  final List<String> installedFolders;
  final String displayName;

  const AddonInstallResult({
    required this.installedFolders,
    required this.displayName,
  });
}
