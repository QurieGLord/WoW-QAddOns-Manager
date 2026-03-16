import 'package:json_annotation/json_annotation.dart';

part 'cf_file.g.dart';

@JsonSerializable()
class CfFile {
  final int id;
  final String fileName;
  final String? downloadUrl;
  final List<String> gameVersions;

  CfFile({
    required this.id,
    required this.fileName,
    this.downloadUrl,
    required this.gameVersions,
  });

  factory CfFile.fromJson(Map<String, dynamic> json) => _$CfFileFromJson(json);
  Map<String, dynamic> toJson() => _$CfFileToJson(this);
}
