import 'dart:convert';
import 'dart:typed_data';

/// Decoding for the binary fields Odoo puts on the wire.
///
/// ## Why this is not just `base64Decode`
///
/// Dart's decoder is strict, and the payloads are not. Three shapes reach the
/// app, all of them legitimate:
///
/// * **Line-wrapped.** Python's `base64.encodebytes` — which is what
///   `xmlrpc.client` uses for a `<base64>` element — inserts a newline every
///   76 characters. `base64Decode` throws on the first one.
/// * **Unpadded.** Some Odoo modules and proxies strip the trailing `=`.
/// * **Genuinely corrupt.** An instance that has been through a bad migration
///   can hold a `datas` value that is not base64 at all.
///
/// Only the third is an error. The first two used to be treated as one, and
/// the result was a photo that existed in Odoo, downloaded correctly, and
/// then rendered as "no photo" with nothing anywhere saying why.
abstract final class OdooBinary {
  /// Decodes [value], or returns null when it is absent or unreadable.
  ///
  /// Odoo sends `false` for an unset binary field, so a non-string is an
  /// ordinary "not set" rather than a problem.
  static Uint8List? tryDecode(Object? value) {
    if (value is Uint8List) return value;
    if (value is! String) return null;

    final normalized = normalize(value);
    if (normalized.isEmpty) return null;

    try {
      return base64.decode(normalized);
    } on FormatException {
      return null;
    }
  }

  /// Strips the whitespace an encoder may have wrapped the payload in, and
  /// restores the padding a proxy may have stripped.
  ///
  /// Returns the empty string when nothing base64-shaped is left, which the
  /// callers read as "not set".
  static String normalize(String raw) {
    final compact = raw.replaceAll(_whitespace, '');
    if (compact.isEmpty) return '';

    // base64 is four characters per three bytes; a length that is not a
    // multiple of four is either unpadded or truncated. Padding it lets the
    // decoder tell us which.
    final remainder = compact.length % 4;
    if (remainder == 0) return compact;
    if (remainder == 1) return compact; // Never valid — let the decoder say so.
    return compact.padRight(compact.length + (4 - remainder), '=');
  }

  static final RegExp _whitespace = RegExp(r'\s');

  const OdooBinary._();
}
