import 'package:json_annotation/json_annotation.dart';
import 'package:wow_qaddons_manager/domain/models/curseforge/cf_file.dart';

part 'cf_mod.g.dart';

@JsonSerializable()
class CfMod {
  final int id;
  final String name;
  final String summary;
  final CfLogo? logo;
  final List<CfAuthor> authors;
  final List<CfFile> latestFiles;

  CfMod({
    required this.id,
    required this.name,
    required this.summary,
    this.logo,
    this.authors = const [],
    this.latestFiles = const [],
  });

  String? get primaryAuthor => authors.isNotEmpty ? authors.first.name : null;
  
  String get latestVersion {
    if (latestFiles.isEmpty) return 'N/A';
    // Берем версию из самого свежего файла
    final versions = latestFiles.first.gameVersions;
    // Ищем строку, похожую на версию (цифры с точками), исключая "Retail", "WotLK" и т.д.
    for (var v in versions) {
      if (RegExp(r'^\d+\.').hasMatch(v)) return v;
    }
    return versions.first;
  }

  factory CfMod.fromJson(Map<String, dynamic> json) => _$CfModFromJson(json);
  Map<String, dynamic> toJson() => _$CfModToJson(this);
}

@JsonSerializable()
class CfAuthor {
  final int id;
  final String name;

  CfAuthor({required this.id, required this.name});

  factory CfAuthor.fromJson(Map<String, dynamic> json) => _$CfAuthorFromJson(json);
  Map<String, dynamic> toJson() => _$CfAuthorToJson(this);
}

@JsonSerializable()
class CfLogo {
  final String thumbnailUrl;

  CfLogo({required this.thumbnailUrl});

  factory CfLogo.fromJson(Map<String, dynamic> json) => _$CfLogoFromJson(json);
  Map<String, dynamic> toJson() => _$CfLogoToJson(this);
}
