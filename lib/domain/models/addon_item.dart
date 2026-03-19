class AddonItem {
  final String id;
  final String name;
  final String summary;
  final String? author;
  final String? thumbnailUrl;
  final String providerName;
  final dynamic originalId; // modId for CF, full_name for GH
  final String? sourceSlug;
  final List<String> identityHints;
  final String version;
  final String? verifiedDownloadUrl;
  final String? verifiedFileName;

  AddonItem({
    required this.id,
    required this.name,
    required this.summary,
    this.author,
    this.thumbnailUrl,
    required this.providerName,
    required this.originalId,
    this.sourceSlug,
    this.identityHints = const <String>[],
    this.version = 'N/A',
    this.verifiedDownloadUrl,
    this.verifiedFileName,
  });

  bool get hasVerifiedPayload {
    return verifiedDownloadUrl != null &&
        verifiedDownloadUrl!.isNotEmpty &&
        verifiedFileName != null &&
        verifiedFileName!.isNotEmpty;
  }

  AddonItem copyWith({
    String? id,
    String? name,
    String? summary,
    String? author,
    String? thumbnailUrl,
    String? providerName,
    dynamic originalId,
    String? sourceSlug,
    List<String>? identityHints,
    String? version,
    String? verifiedDownloadUrl,
    String? verifiedFileName,
  }) {
    return AddonItem(
      id: id ?? this.id,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      author: author ?? this.author,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      providerName: providerName ?? this.providerName,
      originalId: originalId ?? this.originalId,
      sourceSlug: sourceSlug ?? this.sourceSlug,
      identityHints: identityHints ?? this.identityHints,
      version: version ?? this.version,
      verifiedDownloadUrl: verifiedDownloadUrl ?? this.verifiedDownloadUrl,
      verifiedFileName: verifiedFileName ?? this.verifiedFileName,
    );
  }
}
