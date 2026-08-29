/// Removes secrets from any string before it reaches a log sink or an error
/// surface.
///
/// Spec §25: never log passwords, never log API keys, sanitize error messages.
abstract final class LogSanitizer {
  static const String _mask = '***REDACTED***';

  static final List<RegExp> _patterns = [
    // key/value pairs in maps, JSON, XML-RPC dumps and query strings
    RegExp(
      r'(?<key>"?(password|passwd|pwd|api[_-]?key|apikey|token|secret|'
      r'authorization|session_id|access_token)"?\s*[:=]\s*)'
      r'("[^"]*"|'
      r"'[^']*'"
      r'|[^\s,}&;]+)',
      caseSensitive: false,
    ),
    // XML-RPC positional secrets: <value><string>...</string></value> that
    // follow a password-ish tag
    RegExp(
      r'<(password|api_key|token)>.*?</\1>',
      caseSensitive: false,
      dotAll: true,
    ),
    // Basic-auth credentials embedded in a URL
    RegExp(r'(https?://)([^:/\s]+):([^@/\s]+)@', caseSensitive: false),
  ];

  static String scrub(String input) {
    var output = input;

    output = output.replaceAllMapped(
      _patterns[0],
      (m) => '${(m as RegExpMatch).namedGroup('key')}$_mask',
    );
    output = output.replaceAllMapped(
      _patterns[1],
      (m) => '<${m.group(1)}>$_mask</${m.group(1)}>',
    );
    output = output.replaceAllMapped(
      _patterns[2],
      (m) => '${m.group(1)}${m.group(2)}:$_mask@',
    );

    return output;
  }
}
