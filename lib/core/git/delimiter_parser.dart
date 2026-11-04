// Ported from GitHub Desktop (MIT): app/src/lib/git/git-delimiter-parser.ts (via GitHub+ v1 src/main/git/git-delimiter-parser.ts)
/// NUL-delimited fields and records preserve multiline messages and control characters.
class LogParser {
  LogParser(Map<String, String> fields) : _keys = fields.keys.toList(), _formats = fields.values.toList() {
    if (_keys.isEmpty) throw ArgumentError('At least one log field is required');
  }
  final List<String> _keys;
  final List<String> _formats;
  List<String> get formatArgs => ['-z', '--format=${_formats.join('%x00')}'];
  List<Map<String, String>> parse(String value) {
    final tokens = value.split('\x00');
    return [
      for (var i = 0; i + _keys.length < tokens.length; i += _keys.length)
        {for (var j = 0; j < _keys.length; j++) _keys[j]: tokens[i + j]},
    ];
  }
}
