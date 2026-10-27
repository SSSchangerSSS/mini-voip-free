/// Persian/Arabic digit normalization for extension inputs (spec 10.1, mirrors
/// the server implementation; test T03 on both sides).
///
/// "۱۰۲" and "١٠٢" both become "102". Any non-digit character after trimming
/// whitespace invalidates the whole input — never partially interpreted.
/// Valid output: 3 ASCII digits in 101..199 ("100" is reserved/forbidden).
class DigitNormalizer {
  const DigitNormalizer._();

  static const int _persianZero = 0x06F0; // ۰..۹
  static const int _arabicZero = 0x0660; // ٠..٩

  static String? normalizeInternal(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final buffer = StringBuffer();
    for (final ch in trimmed.runes) {
      if (ch >= 0x30 && ch <= 0x39) {
        buffer.writeCharCode(ch);
      } else if (ch >= _persianZero && ch <= _persianZero + 9) {
        buffer.writeCharCode(0x30 + ch - _persianZero);
      } else if (ch >= _arabicZero && ch <= _arabicZero + 9) {
        buffer.writeCharCode(0x30 + ch - _arabicZero);
      } else {
        return null; // letters, signs, separators, direction marks — reject
      }
    }
    final ascii = buffer.toString();
    if (ascii.length != 3) return null;
    if (!ascii.startsWith('1')) return null;
    if (ascii == '100') return null;
    return ascii;
  }
}
