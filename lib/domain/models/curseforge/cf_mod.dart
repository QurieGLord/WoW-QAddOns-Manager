import 'package:wow_qaddons_manager/domain/models/curseforge/cf_file.dart';

class CfMod {
  final int id;
  final String name;
  final String slug;
  final String summary;
  final CfLogo? logo;
  final List<String> screenshotUrls;
  final List<CfAuthor> authors;
  final List<CfFile> latestFiles;

  CfMod({
    required this.id,
    required this.name,
    required this.slug,
    required this.summary,
    this.logo,
    this.screenshotUrls = const <String>[],
    this.authors = const [],
    this.latestFiles = const [],
  });

  String? get primaryAuthor => authors.isNotEmpty ? authors.first.name : null;

  String get latestVersion {
    if (latestFiles.isEmpty) {
      return 'N/A';
    }

    // Берем версию из самого свежего файла
    final versions = latestFiles.first.gameVersions;
    // Ищем строку, похожую на версию (цифры с точками), исключая "Retail", "WotLK" и т.д.
    for (var v in versions) {
      if (RegExp(r'^\d+\.').hasMatch(v)) {
        return v;
      }
    }
    return versions.first;
  }

  factory CfMod.fromJson(Map<String, dynamic> json) {
    return CfMod(
      id: _readInt(json['id']),
      name: _readString(json['name']) ?? 'Unknown CurseForge mod',
      slug: _readString(json['slug']) ?? '',
      summary: _readString(json['summary']) ?? 'No description available',
      logo: json['logo'] is Map
          ? CfLogo.fromJson(Map<String, dynamic>.from(json['logo'] as Map))
          : null,
      screenshotUrls: _readScreenshotUrls(json['screenshots']),
      authors: _readObjectList(
        json['authors'],
      ).map(CfAuthor.fromJson).toList(growable: false),
      latestFiles: _readObjectList(
        json['latestFiles'],
      ).map(CfFile.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'slug': slug,
    'summary': summary,
    'logo': logo?.toJson(),
    'screenshots': screenshotUrls,
    'authors': authors.map((author) => author.toJson()).toList(growable: false),
    'latestFiles': latestFiles
        .map((file) => file.toJson())
        .toList(growable: false),
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

  static List<Map<String, dynamic>> _readObjectList(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  static List<String> _readScreenshotUrls(Object? value) {
    return _readObjectList(value)
        .map(
          (entry) =>
              _readString(entry['url']) ?? _readString(entry['thumbnailUrl']),
        )
        .whereType<String>()
        .toList(growable: false);
  }
}

class CfAuthor {
  final int id;
  final String name;

  CfAuthor({required this.id, required this.name});

  factory CfAuthor.fromJson(Map<String, dynamic> json) => CfAuthor(
    id: CfMod._readInt(json['id']),
    name: CfMod._readString(json['name']) ?? 'Unknown',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};
}

class CfLogo {
  final String? thumbnailUrl;

  CfLogo({this.thumbnailUrl});

  factory CfLogo.fromJson(Map<String, dynamic> json) =>
      CfLogo(thumbnailUrl: CfMod._readString(json['thumbnailUrl']));

  Map<String, dynamic> toJson() => <String, dynamic>{
    'thumbnailUrl': thumbnailUrl,
  };
}
