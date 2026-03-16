// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cf_mod.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CfMod _$CfModFromJson(Map<String, dynamic> json) => CfMod(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  summary: json['summary'] as String,
  logo: json['logo'] == null
      ? null
      : CfLogo.fromJson(json['logo'] as Map<String, dynamic>),
  authors:
      (json['authors'] as List<dynamic>?)
          ?.map((e) => CfAuthor.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  latestFiles:
      (json['latestFiles'] as List<dynamic>?)
          ?.map((e) => CfFile.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$CfModToJson(CfMod instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'summary': instance.summary,
  'logo': instance.logo,
  'authors': instance.authors,
  'latestFiles': instance.latestFiles,
};

CfAuthor _$CfAuthorFromJson(Map<String, dynamic> json) =>
    CfAuthor(id: (json['id'] as num).toInt(), name: json['name'] as String);

Map<String, dynamic> _$CfAuthorToJson(CfAuthor instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
};

CfLogo _$CfLogoFromJson(Map<String, dynamic> json) =>
    CfLogo(thumbnailUrl: json['thumbnailUrl'] as String);

Map<String, dynamic> _$CfLogoToJson(CfLogo instance) => <String, dynamic>{
  'thumbnailUrl': instance.thumbnailUrl,
};
