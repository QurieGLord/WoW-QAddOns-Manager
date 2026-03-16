class AddonItem {
  final String id;
  final String name;
  final String summary;
  final String? author;
  final String? thumbnailUrl;
  final String providerName;
  final dynamic originalId; // modId for CF, full_name for GH
  final String version;

  AddonItem({
    required this.id,
    required this.name,
    required this.summary,
    this.author,
    this.thumbnailUrl,
    required this.providerName,
    required this.originalId,
    this.version = 'N/A',
  });
}
