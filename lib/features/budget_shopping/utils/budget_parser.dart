class BudgetParser {
  /// Parses a currency input string (e.g. "Rp 100.000", "1.000.000", "100000,50") into a double.
  /// Returns `null` if the input is empty, non-numeric, zero, negative, or otherwise invalid.
  static double? parse(String input) {
    var clean = input.replaceAll(' ', '');
    if (clean.toUpperCase().startsWith('RP')) {
      clean = clean.substring(2);
    }
    if (clean.isEmpty) return null;

    // Handle combinations of dot and comma separators
    if (clean.contains('.') && clean.contains(',')) {
      final dotIndex = clean.indexOf('.');
      final commaIndex = clean.indexOf(',');
      if (dotIndex < commaIndex) {
        // Indonesian format: dot is thousands, comma is decimal (e.g. 1.000,50)
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // English format: comma is thousands, dot is decimal (e.g. 1,000.50)
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains(',')) {
      // Only comma is present.
      final parts = clean.split(',');
      if (parts.length == 2 && parts[1].length != 3) {
        // Comma is decimal separator (e.g. 100000,50)
        clean = clean.replaceAll(',', '.');
      } else if (parts.length == 2 && parts[1].length == 3) {
        // Comma is thousand separator (e.g. 100,000)
        clean = clean.replaceAll(',', '');
      } else {
        // Multiple commas: thousand separators
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains('.')) {
      // Only dot is present.
      final parts = clean.split('.');
      if (parts.length > 2) {
        // Multiple dots: thousand separators (e.g. 1.000.000)
        clean = clean.replaceAll('.', '');
      } else {
        // Single dot. (e.g. "100.000" vs "100.5")
        if (parts[1].length == 3) {
          // Dot is thousand separator
          clean = clean.replaceAll('.', '');
        } else {
          // Dot is decimal separator
          // Keep the dot as is
        }
      }
    }

    final parsed = double.tryParse(clean);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }
}
