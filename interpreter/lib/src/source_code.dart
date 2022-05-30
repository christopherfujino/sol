class SourceCode {
  SourceCode(
    this.text,
  ) : _lines = text.split('\n');

  late final List<String> _lines;
  final String text;

  /// Get character at [line], [char] coordinate.
  ///
  /// Note that both are 1-indexed.
  String getDebugMessage(int lineNum, int charNum) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(_lines[lineNum - 1]);
    buffer.write(' ' * (charNum - 1));
    buffer.writeln('^');
    return buffer.toString();
  }
}
