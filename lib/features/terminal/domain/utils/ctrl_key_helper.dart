/// Converts a character to its Ctrl key equivalent.
/// e.g., 'c' or 'C' -> \x03, 'd' -> \x04, 'z' -> \x1A
String ctrlChar(String char) {
  if (char.isEmpty) return '';
  final code = char.codeUnitAt(0);
  if (code >= 65 && code <= 90) return String.fromCharCode(code - 64); // A-Z
  if (code >= 97 && code <= 122) return String.fromCharCode(code - 96); // a-z
  return char;
}
