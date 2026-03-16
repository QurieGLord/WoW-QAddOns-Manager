// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cf_file.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CfFile _$CfFileFromJson(Map<String, dynamic> json) => CfFile(
  id: (json['id'] as num).toInt(),
  fileName: json['fileName'] as String,
  downloadUrl: json['downloadUrl'] as String?,
  gameVersions: (json['gameVersions'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$CfFileToJson(CfFile instance) => <String, dynamic>{
  'id': instance.id,
  'fileName': instance.fileName,
  'downloadUrl': instance.downloadUrl,
  'gameVersions': instance.gameVersions,
};
