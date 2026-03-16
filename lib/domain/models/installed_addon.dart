class InstalledAddonFolder {
  final String folderName;
  final String displayName;
  final String title;
  final List<String> dependencies;
  final String? xPartOf;

  const InstalledAddonFolder({
    required this.folderName,
    required this.displayName,
    required this.title,
    this.dependencies = const <String>[],
    this.xPartOf,
  });
}

class InstalledAddonGroup {
  final String id;
  final String displayName;
  final String? providerName;
  final String? version;
  final List<String> installedFolders;
  final bool isManaged;

  const InstalledAddonGroup({
    required this.id,
    required this.displayName,
    required this.installedFolders,
    this.providerName,
    this.version,
    this.isManaged = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'providerName': providerName,
        'version': version,
        'installedFolders': installedFolders,
        'isManaged': isManaged,
      };

  factory InstalledAddonGroup.fromJson(Map<String, dynamic> json) {
    return InstalledAddonGroup(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      providerName: json['providerName'] as String?,
      version: json['version'] as String?,
      installedFolders: ((json['installedFolders'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>())
          .toList(),
      isManaged: json['isManaged'] as bool? ?? false,
    );
  }

  InstalledAddonGroup copyWith({
    String? id,
    String? displayName,
    String? providerName,
    String? version,
    List<String>? installedFolders,
    bool? isManaged,
  }) {
    return InstalledAddonGroup(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      providerName: providerName ?? this.providerName,
      version: version ?? this.version,
      installedFolders: installedFolders ?? this.installedFolders,
      isManaged: isManaged ?? this.isManaged,
    );
  }
}

class AddonInstallResult {
  final List<String> installedFolders;

  const AddonInstallResult({required this.installedFolders});
}
