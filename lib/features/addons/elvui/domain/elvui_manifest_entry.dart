import 'package:wow_qaddons_manager/domain/models/addon_resolution_classification.dart';

class ElvUiManifestEntry {
  final String id;
  final String name;
  final String source;
  final String flavor;
  final String clientFamily;
  final String clientVersionMin;
  final String clientVersionMax;
  final String interfaceMin;
  final String interfaceMax;
  final String packageVersion;
  final String packageUrl;
  final String sha256;
  final AddonResolutionClassification classification;
  final List<String> evidence;
  final String notes;
  final String author;
  final String webUrl;
  final String changelogUrl;
  final String thumbnailUrl;
  final List<String> screenshotUrls;
  final List<String> directories;
  final String summary;

  const ElvUiManifestEntry({
    required this.id,
    required this.name,
    required this.source,
    required this.flavor,
    required this.clientFamily,
    required this.clientVersionMin,
    required this.clientVersionMax,
    required this.interfaceMin,
    required this.interfaceMax,
    required this.packageVersion,
    required this.packageUrl,
    required this.sha256,
    required this.classification,
    required this.evidence,
    required this.notes,
    required this.author,
    required this.webUrl,
    required this.changelogUrl,
    required this.thumbnailUrl,
    required this.screenshotUrls,
    required this.directories,
    required this.summary,
  });

  bool get hasPackagePayload {
    return packageUrl.trim().isNotEmpty && packageVersion.trim().isNotEmpty;
  }

  factory ElvUiManifestEntry.fromJson(Map<String, dynamic> json) {
    return ElvUiManifestEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'ElvUI',
      source: json['source'] as String? ?? '',
      flavor: json['flavor'] as String? ?? '',
      clientFamily: json['clientFamily'] as String? ?? '',
      clientVersionMin: json['clientVersionMin'] as String? ?? '',
      clientVersionMax: json['clientVersionMax'] as String? ?? '',
      interfaceMin: json['interfaceMin'] as String? ?? '',
      interfaceMax: json['interfaceMax'] as String? ?? '',
      packageVersion: json['packageVersion'] as String? ?? '',
      packageUrl: json['packageUrl'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
      classification: AddonResolutionClassification.values.firstWhere(
        (value) => value.name == json['classification'],
        orElse: () => AddonResolutionClassification.notVerified,
      ),
      evidence: (json['evidence'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      notes: json['notes'] as String? ?? '',
      author: json['author'] as String? ?? '',
      webUrl: json['webUrl'] as String? ?? '',
      changelogUrl: json['changelogUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      screenshotUrls:
          (json['screenshotUrls'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      directories: (json['directories'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      summary: json['summary'] as String? ?? '',
    );
  }
}
