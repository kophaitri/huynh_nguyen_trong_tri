enum TextLanguage {
  english('Tiếng Anh'),
  vietnamese('Tiếng Việt');

  const TextLanguage(this.label);
  final String label;
  TextLanguage get opposite => this == english ? vietnamese : english;
}

class TextScanResult {
  const TextScanResult({required this.original, this.translation = ''});
  final String original;
  final String translation;
}
