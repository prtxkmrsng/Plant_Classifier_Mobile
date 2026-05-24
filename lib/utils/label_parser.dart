/// Parses taxonomy-encoded labels from the model into structured, human-readable data.
///
/// Label format: `00000_Animalia_Annelida_Clitellata_Haplotaxida_Lumbricidae_Lumbricus_terrestris`
/// Structure:    `INDEX_Kingdom_Phylum_Class_Order_Family_Genus_species`
class TaxonomyResult {
  final String index;
  final String kingdom;
  final String phylum;
  final String className;
  final String order;
  final String family;
  final String genus;
  final String species;

  const TaxonomyResult({
    required this.index,
    required this.kingdom,
    required this.phylum,
    required this.className,
    required this.order,
    required this.family,
    required this.genus,
    required this.species,
  });

  /// Human-readable scientific name: "Genus species"
  String get displayName => '$genus $species';

  /// Short taxonomy breadcrumb for UI display
  String get taxonomyBreadcrumb =>
      '$kingdom › $phylum › $className › $order › $family';

  /// Full family label: "Family Genus"
  String get familyLabel => family;
}

class LabelParser {
  /// Parse a raw model label string into a structured [TaxonomyResult].
  ///
  /// Expected format: `00000_Kingdom_Phylum_Class_Order_Family_Genus_species`
  /// If the label has fewer parts, missing fields are filled with "Unknown".
  static TaxonomyResult parse(String rawLabel) {
    final parts = rawLabel.trim().split('_');

    return TaxonomyResult(
      index: parts.isNotEmpty ? parts[0] : '',
      kingdom: parts.length > 1 ? parts[1] : 'Unknown',
      phylum: parts.length > 2 ? parts[2] : 'Unknown',
      className: parts.length > 3 ? parts[3] : 'Unknown',
      order: parts.length > 4 ? parts[4] : 'Unknown',
      family: parts.length > 5 ? parts[5] : 'Unknown',
      genus: parts.length > 6 ? parts[6] : 'Unknown',
      species: parts.length > 7 ? parts[7] : 'sp.',
    );
  }

  /// Convenience: parse and return just the display name.
  static String displayName(String rawLabel) => parse(rawLabel).displayName;
}
