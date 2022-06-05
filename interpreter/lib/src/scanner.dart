import 'parser.dart';
import 'source_code.dart';

enum TokenType {
  // keywords

  /// Keyword "const".
  constant,

  /// Keyword "function".
  func,

  /// Keyword "variable".
  variable,

  /// Keyword "return".
  returnKeyword,

  /// Keyword "if".
  ifKeyword,

  /// Keyword "else".
  ///
  /// Can be chained as "else if" to be semantically distinct.
  elseKeyword,

  // operators

  /// Operator "=".
  assignment,

  /// Operator "==".
  equals,

  /// Operator "!=".
  notEquals,

  /// Operator ">"
  greaterThan,

  /// Operator "+".
  plus,

  /// Operator "-".
  minus,

  /// Operator "*".
  multiply,

  /// Operator "/".
  divide,

  /// Operator "!".
  bang,

  /// Operator "->".
  ///
  /// Denotes a function's return type.
  arrow,

  // brackets
  openParen,
  closeParen,

  openSquareBracket,
  closeSquareBracket,

  openCurlyBracket,
  closeCurlyBracket,

  // String-like tokens
  identifier,
  stringLiteral,
  numberLiteral,
  booleanLiteral,

  /// Either primitive or user defined type.
  type,

  // misc
  comma,
  semicolon,
  hash, // #
}

class Token {
  Token({
    required this.type,
    required this.line,
    required this.char,
  });

  final TokenType type;
  final int line;
  final int char;

  @override
  String toString() => '[$line, $char] ${type.name}';
}

class StringToken extends Token {
  StringToken({
    required super.type,
    required this.value,
    required super.line,
    required super.char,
  });

  /// The contents of this string, excluding quotes.
  final String value;

  @override
  String toString() => '${super.toString()}: "$value"';
}

class NumToken extends Token {
  NumToken({
    required this.value,
    required super.line,
    required super.char,
  }) : super(type: TokenType.numberLiteral);

  /// The contents of this string, excluding quotes.
  final double value;

  @override
  String toString() => '${super.toString()}: "$value"';
}

class Scanner {
  Scanner._(this.source);

  factory Scanner.fromSourceCode(SourceCode sourceCode) {
    return Scanner._(sourceCode.text);
  }

  final String source;
  final List<Token> _tokenList = <Token>[];

  int _index = 0;
  int _line = 1;
  int _lastNewlineIndex = 0;
  int get _char => _index - _lastNewlineIndex;

  // TODO figure out unicode
  Future<List<Token>> scan() async {
    while (_index < source.length) {
      if (_scanWhitespace()) {
        continue;
      }

      if (_scanOperator()) {
        continue;
      }

      // handle brackets (parens, square, and curly)
      if (_scanBracket()) {
        continue;
      }

      if (_scanKeyword()) {
        continue;
      }

      if (_scanBoolean()) {
        continue;
      }

      if (_scanString()) {
        continue;
      }

      if (_scanNumber()) {
        continue;
      }

      if (_scanTypeName()) {
        continue;
      }

      // handle named identifiers--must run after [_scanKeyword()],
      // [_scanString()]
      if (_scanIdentifier()) {
        continue;
      }

      if (_scanMisc()) {
        continue;
      }

      throw ScanException('''
Unknown token:
"${source.substring(_index)}"
Last scanned token: ${_tokenList.last}
''');
    }
    return _tokenList;
  }

  bool _scanKeyword() {
    // TODO this can be faster, use linear search, not [.startsWith()]
    final String rest = source.substring(_index);

    // We have to use [kIdentifierPattern] or else we would get false positives
    final Match? match = kIdentifierPattern.matchAsPrefix(rest);
    if (match == null) {
      return false;
    }
    TokenType? tokenType;
    final String keyword = match.group(0)!;
    switch (keyword) {
      case 'constant':
        tokenType = TokenType.constant;
        break;
      case 'function':
        tokenType = TokenType.func;
        break;
      case 'variable':
        tokenType = TokenType.variable;
        break;
      case 'return':
        tokenType = TokenType.returnKeyword;
        break;
      case 'if':
        tokenType = TokenType.ifKeyword;
        break;
      case 'else':
        tokenType = TokenType.elseKeyword;
        break;
      default:
        return false;
    }
    _tokenList.add(
      Token(
        type: tokenType,
        line: _line,
        char: _char,
      ),
    );
    _index += keyword.length;
    return true;
  }

  bool _scanBoolean() {
    // TODO this can be faster, use linear search, not [.startsWith()]
    final String rest = source.substring(_index);

    // We have to use [kIdentifierPattern] or else we would get false positives
    // with identifiers that start with a bool name, such as trueString.
    final Match? match = kIdentifierPattern.matchAsPrefix(rest);
    if (match == null) {
      return false;
    }
    final String matchString = match.group(0)!;
    if (matchString != 'true' && matchString != 'false') {
      return false;
    }
    _tokenList.add(StringToken(
      type: TokenType.booleanLiteral,
      value: matchString,
      line: _line,
      char: _char,
    ));
    _index += matchString.length;
    return true;
  }

  bool _scanOperator() {
    if (source[_index] == '!') {
      if (source[_index + 1] == '=') {
        _tokenList.add(
          Token(
            type: TokenType.notEquals,
            line: _line,
            char: _char,
          ),
        );
        _index += 2;
        return true;
      }
      _tokenList.add(
        Token(
          type: TokenType.bang,
          line: _line,
          char: _char,
        ),
      );
      _index += 1;
      return true;
    }
    if (source[_index] == '*') {
      _tokenList.add(
        Token(
          type: TokenType.multiply,
          line: _line,
          char: _char,
        ),
      );
      _index += 1;
      return true;
    }
    if (source[_index] == '/') {
      _tokenList.add(
        Token(
          type: TokenType.divide,
          line: _line,
          char: _char,
        ),
      );
      _index += 1;
      return true;
    }
    if (source[_index] == '>') {
      _tokenList.add(
        Token(
          type: TokenType.greaterThan,
          line: _line,
          char: _char,
        ),
      );
      _index += 1;
      return true;
    }
    if (source[_index] == '+') {
      _tokenList.add(
        Token(
          type: TokenType.plus,
          line: _line,
          char: _char,
        ),
      );
      _index += 1;
      return true;
    }
    if (source[_index] == '=') {
      if (source[_index + 1] == '=') {
        _tokenList.add(
          Token(
            type: TokenType.equals,
            line: _line,
            char: _char,
          ),
        );
        _index += 2;
        return true;
      }
      _tokenList.add(
        Token(
          type: TokenType.assignment,
          line: _line,
          char: _char,
        ),
      );
      _index += 1;
      return true;
    }
    if (source[_index] == '-') {
      if (source[_index + 1] == '>') {
        _tokenList.add(
          Token(
            type: TokenType.arrow,
            line: _line,
            char: _char,
          ),
        );
        _index += 2;
        return true;
      }
      _tokenList.add(
        Token(
          type: TokenType.minus,
          line: _line,
          char: _char,
        ),
      );
      _index += 1;
    }
    return false;
  }

  // TODO: handle escapes?
  static final RegExp kStringPattern = RegExp(r'"([^"]*)"');

  bool _scanString() {
    // TODO this can be faster
    final String rest = source.substring(_index);
    final Match? match = kStringPattern.matchAsPrefix(rest);
    if (match != null) {
      _tokenList.add(
        StringToken(
          type: TokenType.stringLiteral,
          // store the sub-group, excluding quotes
          value: match.group(1)!,
          line: _line,
          char: _char,
        ),
      );
      // increment index including quotes
      _index += match.group(0)!.length;
      return true;
    }
    return false;
  }

  static final RegExp kIdentifierPattern = RegExp(r'[a-z][a-zA-Z0-9_]*');

  bool _scanIdentifier() {
    // TODO this can be faster
    final String rest = source.substring(_index);
    final Match? match = kIdentifierPattern.matchAsPrefix(rest);
    if (match != null) {
      final String stringMatch = match.group(0)!;
      _tokenList.add(
        StringToken(
          type: TokenType.identifier,
          value: stringMatch,
          line: _line,
          char: _char,
        ),
      );
      _index += stringMatch.length;
      return true;
    }
    return false;
  }

  static final RegExp kTypePattern = RegExp(r'[A-Z][a-zA-Z0-9_]*');

  bool _scanTypeName() {
    // TODO this can be faster
    final String rest = source.substring(_index);
    final Match? match = kTypePattern.matchAsPrefix(rest);
    if (match != null) {
      final String typeMatch = match.group(0)!;
      _tokenList.add(
        StringToken(
          type: TokenType.type,
          value: typeMatch,
          line: _line,
          char: _char,
        ),
      );
      _index += typeMatch.length;
      return true;
    }
    return false;
  }

  // TODO implement decimal
  static final RegExp kNumberPattern = RegExp(r'([0-9]+)');
  bool _scanNumber() {
    // TODO this can be faster
    final String rest = source.substring(_index);
    final Match? match = kNumberPattern.matchAsPrefix(rest);
    if (match != null) {
      final String num = match.group(0)!;
      _tokenList.add(
        NumToken(
          value: double.tryParse(num)!,
          line: _line,
          char: _char,
        ),
      );
      _index += num.length;
      return true;
    }
    return false;
  }

  bool _scanWhitespace() {
    switch (source[_index]) {
      case ' ':
      case '\t':
      case '\r':
        _index += 1;
        return true;
      case '\n':
        _lastNewlineIndex = _index;
        _line += 1;
        _index += 1;
        return true;
      default:
        return false;
    }
  }

  bool _scanBracket() {
    switch (source[_index]) {
      case '{':
        _tokenList.add(
          Token(
            type: TokenType.openCurlyBracket,
            line: _line,
            char: _char,
          ),
        );
        _index += 1;
        return true;
      case '}':
        _tokenList.add(
          Token(
            type: TokenType.closeCurlyBracket,
            line: _line,
            char: _char,
          ),
        );
        _index += 1;
        return true;
      case '[':
        _tokenList.add(
          Token(
            type: TokenType.openSquareBracket,
            line: _line,
            char: _char,
          ),
        );
        _index += 1;
        return true;
      case ']':
        _tokenList.add(
          Token(
            type: TokenType.closeSquareBracket,
            line: _line,
            char: _char,
          ),
        );
        _index += 1;
        return true;
      case '(':
        _tokenList.add(
          Token(
            type: TokenType.openParen,
            line: _line,
            char: _char,
          ),
        );
        _index += 1;
        return true;
      case ')':
        _tokenList.add(
          Token(
            type: TokenType.closeParen,
            line: _line,
            char: _char,
          ),
        );
        _index += 1;
        return true;
      default:
        return false;
    }
  }

  bool _scanMisc() {
    switch (source[_index]) {
      case ',':
        _tokenList.add(
          Token(
            type: TokenType.comma,
            line: _line,
            char: _char,
          ),
        );
        _index += 1;
        return true;
      case ';':
        _tokenList.add(
          Token(
            type: TokenType.semicolon,
            line: _line,
            char: _char,
          ),
        );
        _index += 1;
        return true;
      case '#':
        // eat all text until end of line
        while (source[_index] != '\n') {
          _index += 1;
        }
        // does the parser need a comment token?
        return true;
    }

    return false;
  }
}

class ScanException implements Exception {
  ScanException(this.msg);

  final String msg;

  @override
  String toString() => 'ScanException: $msg';
}
