import 'package:wow_qaddons_manager/domain/models/addon_resolution_classification.dart';

class AddonItem {
  final String id;
  final String name;
  final String summary;
  final String? author;
  final String? thumbnailUrl;
  final List<String> screenshotUrls;
  final String providerName;
  final dynamic originalId; // modId for CF, full_name for GH
  final String? sourceSlug;
  final List<String> identityHints;
  final String version;
  final String? verifiedDownloadUrl;
  final String? verifiedFileName;
  final AddonResolutionClassification resolutionClassification;

  AddonItem({
    required this.id,
    required this.name,
    required this.summary,
    this.author,
    this.thumbnailUrl,
    this.screenshotUrls = const <String>[],
    required this.providerName,
    required this.originalId,
    this.sourceSlug,
    this.identityHints = const <String>[],
    this.version = 'N/A',
    this.verifiedDownloadUrl,
    this.verifiedFileName,
    this.resolutionClassification = AddonResolutionClassification.standard,
  });

  bool get hasVerifiedPayload {
    return verifiedDownloadUrl != null &&
        verifiedDownloadUrl!.isNotEmpty &&
        verifiedFileName != null &&
        verifiedFileName!.isNotEmpty;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'summary': summary,
    'author': author,
    'thumbnailUrl': thumbnailUrl,
    'screenshotUrls': screenshotUrls,
    'providerName': providerName,
    'originalId': originalId,
    'sourceSlug': sourceSlug,
    'identityHints': identityHints,
    'version': version,
    'verifiedDownloadUrl': verifiedDownloadUrl,
    'verifiedFileName': verifiedFileName,
    'resolutionClassification': resolutionClassification.name,
  };

  factory AddonItem.fromJson(Map<String, dynamic> json) {
    return AddonItem(
      id: json['id'] as String,
      name: json['name'] as String,
      summary: json['summary'] as String,
      author: json['author'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      screenshotUrls:
          (json['screenshotUrls'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      providerName: json['providerName'] as String,
      originalId: json['originalId'],
      sourceSlug: json['sourceSlug'] as String?,
      identityHints:
          (json['identityHints'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      version: json['version'] as String? ?? 'N/A',
      verifiedDownloadUrl: json['verifiedDownloadUrl'] as String?,
      verifiedFileName: json['verifiedFileName'] as String?,
      resolutionClassification: AddonResolutionClassification.values.firstWhere(
        (value) => value.name == json['resolutionClassification'],
        orElse: () => AddonResolutionClassification.standard,
      ),
    );
  }

  AddonItem copyWith({
    String? id,
    String? name,
    String? summary,
    String? author,
    String? thumbnailUrl,
    List<String>? screenshotUrls,
    String? providerName,
    dynamic originalId,
    String? sourceSlug,
    List<String>? identityHints,
    String? version,
    String? verifiedDownloadUrl,
    String? verifiedFileName,
    AddonResolutionClassification? resolutionClassification,
  }) {
    return AddonItem(
      id: id ?? this.id,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      author: author ?? this.author,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      screenshotUrls: screenshotUrls ?? this.screenshotUrls,
      providerName: providerName ?? this.providerName,
      originalId: originalId ?? this.originalId,
      sourceSlug: sourceSlug ?? this.sourceSlug,
      identityHints: identityHints ?? this.identityHints,
      version: version ?? this.version,
      verifiedDownloadUrl: verifiedDownloadUrl ?? this.verifiedDownloadUrl,
      verifiedFileName: verifiedFileName ?? this.verifiedFileName,
      resolutionClassification:
          resolutionClassification ?? this.resolutionClassification,
    );
  }
}
