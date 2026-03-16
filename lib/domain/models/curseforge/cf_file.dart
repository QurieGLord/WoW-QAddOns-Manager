class CfFile {
  final int id;
  final String fileName;
  final String? displayName;
  final String? downloadUrl;
  final List<String> gameVersions;

  CfFile({
    required this.id,
    required this.fileName,
    this.displayName,
    this.downloadUrl,
    required this.gameVersions,
  });

  factory CfFile.fromJson(Map<String, dynamic> json) {
    final id = _readInt(json['id']);
    final fileName = _readString(json['fileName']) ?? 'curseforge-$id.zip';

    return CfFile(
      id: id,
      fileName: fileName,
      displayName: _readString(json['displayName']),
      downloadUrl: _readString(json['downloadUrl']),
      gameVersions: _readStringList(json['gameVersions']),
    );
  }

  CfFile copyWith({
    String? fileName,
    String? displayName,
    String? downloadUrl,
    List<String>? gameVersions,
  }) {
    return CfFile(
      id: id,
      fileName: fileName ?? this.fileName,
      displayName: displayName ?? this.displayName,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      gameVersions: gameVersions ?? this.gameVersions,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'fileName': fileName,
    'displayName': displayName,
    'downloadUrl': downloadUrl,
    'gameVersions': gameVersions,
  };

  static int _readInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  static String? _readString(Object? value) {
    if (value == null) {
      return null;
    }

    final stringValue = value.toString().trim();
    if (stringValue.isEmpty || stringValue.toLowerCase() == 'null') {
      return null;
    }

    return stringValue;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .map(_readString)
        .whereType<String>()
        .toList(growable: false);
  }
}
