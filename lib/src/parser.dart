import 'dart:io';

import 'scanner.dart';
import 'source_code.dart';

class ParseTree {
  const ParseTree(this.declarations);

  final List<Decl> declarations;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer();
    for (final Decl decl in declarations) {
      for (final Stmt stmt in (decl as FuncDecl).statements) {
        buffer.writeln(stmt.toString());
      }
    }
    return buffer.toString();
  }
}

class Parser {
  Parser({
    required this.tokenList,
    required this.entrySourceCode,
  });

  final List<Token> tokenList;
  final SourceCode entrySourceCode;

  /// Index for current token being parsed.
  int _index = 0;
  Token? get _currentToken {
    if (_index >= tokenList.length) {
      return null;
    }
    return tokenList[_index];
  }

  final List<Decl> declarations = <Decl>[];

  Future<ParseTree> parse() async {
    while (_currentToken != null) {
      declarations.add(_decl());
    }

    return ParseTree(declarations);
  }

  /// Parse a [Decl].
  ///
  /// If [allowedDeclarations] is null, all declaration types are checked for.
  Decl _decl({Set<Type>? allowedDeclarations}) {
    final Token currentToken = _currentToken!;
    switch (currentToken.type) {
      case TokenType.constant:
        if (allowedDeclarations != null &&
            !allowedDeclarations.contains(ConstDecl)) {
          _throwParseError(
            currentToken,
            'A constant declaration is not allowed in the current context.',
          );
        }
        return _constDecl();
      case TokenType.func:
        if (allowedDeclarations != null &&
            !allowedDeclarations.contains(FuncDecl)) {
          _throwParseError(
            currentToken,
            'A constant declaration is not allowed in the current context.',
          );
        }
        return _funcDecl();
      default:
        _throwParseError(
          currentToken,
          'Unknown declaration type ${currentToken.type.name}',
        );
    }
  }

  Never _throwParseError(Token? token, String message) {
    if (token == null) {
      throw ParseError('Parse error: $message');
    }
    throw ParseError(
      '\n${entrySourceCode.getDebugMessage(token.line, token.char)}\n'
      'Parse error: $token - $message\n',
    );
  }

  /// Parse a [ConstDecl].
  ConstDecl _constDecl() {
    _consume(TokenType.constant);
    final StringToken name = _consume(TokenType.identifier) as StringToken;

    _consume(TokenType.assignment);

    final Expr value = _expr();

    _consume(TokenType.semicolon);

    return ConstDecl(
      name: name.value,
      initialValue: value,
    );
  }

  FuncDecl _funcDecl() {
    _consume(TokenType.func);
    final StringToken name = _consume(TokenType.identifier) as StringToken;
    _consume(TokenType.openParen);
    final List<IdentifierRef> params = _paramList();
    _consume(TokenType.closeParen);

    _consume(TokenType.openCurlyBracket);

    final List<Stmt> statements = <Stmt>[];
    while (_currentToken!.type != TokenType.closeCurlyBracket) {
      statements.add(_stmt());
    }
    _consume(TokenType.closeCurlyBracket);

    return FuncDecl(
      name: name.value,
      params: params,
      statements: statements,
    );
  }

  Stmt _stmt() {
    if (_currentToken!.type == TokenType.variable) {
      return _assignStmt();
    }
    return _exprStmt();
  }

  // bare_statement ::= expression, ";"
  BareStmt _exprStmt() {
    final Expr expression = _expr();
    _consume(TokenType.semicolon);
    return BareStmt(expression: expression);
  }

  AssignStmt _assignStmt() {
    _consume(TokenType.variable);
    final StringToken name = _consume(TokenType.identifier) as StringToken;
    _consume(TokenType.assignment);
    final Expr expr = _expr();
    _consume(TokenType.semicolon);
    return AssignStmt(
      name.value,
      expr,
    );
  }

  // Expressions

  Expr _expr() {
    if (_currentToken!.type == TokenType.stringLiteral) {
      return _stringLiteral();
    }
    if (_tokenLookahead(const <TokenType>[
      TokenType.identifier,
      TokenType.openParen,
    ])) {
      return _callExpr();
    }

    if (_currentToken!.type == TokenType.numberLiteral) {
      return _numberLiteral();
    }

    if (_tokenLookahead(const <TokenType>[
      TokenType.type,
      TokenType.openSquareBracket,
    ])) {
      return _listLiteral();
    }

    if (_currentToken!.type == TokenType.type) {
      return _typeExpr();
    }

    // This should be last
    if (_currentToken!.type == TokenType.identifier) {
      return _identifierExpr();
    }
    _throwParseError(_currentToken, 'Unimplemented expression type');
  }

  /// An identifier reference.
  ///
  /// Either a variable or constant.
  IdentifierRef _identifierExpr() {
    final StringToken token = _consume(TokenType.identifier) as StringToken;
    return IdentifierRef(token.value);
  }

  /// A type reference.
  ///
  /// Either intrinsic or user-defined.
  TypeRef _typeExpr() {
    final StringToken token = _consume(TokenType.type) as StringToken;
    return TypeRef(token.value);
  }

  ListLiteral _listLiteral() {
    final TypeRef type = _typeExpr();
    final List<Expr> elements = <Expr>[];

    _consume(TokenType.openSquareBracket);
    while (_currentToken!.type != TokenType.closeSquareBracket) {
      // TODO validate type
      elements.add(_expr());

      if (_currentToken!.type == TokenType.closeSquareBracket) {
        break;
      }
      // The previous break will allow optional trailing comma
      _consume(TokenType.comma);
    }

    _consume(TokenType.closeSquareBracket);
    return ListLiteral(elements, type);
  }

  // call_expression ::= identifier, "(", arg_list?, ")"
  CallExpr _callExpr() {
    final StringToken name = _consume(TokenType.identifier) as StringToken;
    List<Expr>? argList;
    _consume(TokenType.openParen);
    if (_currentToken?.type != TokenType.closeParen) {
      argList = _argList();
    }
    _consume(TokenType.closeParen);
    return CallExpr(
      name.value,
      argList ?? const <Expr>[],
    );
  }

  /// Parses identifiers (comma delimited) until a [TokenType.closeParen] is
  /// reached (but not consumed).
  List<IdentifierRef> _paramList() {
    final List<IdentifierRef> list = <IdentifierRef>[];
    while (_currentToken?.type != TokenType.closeParen) {
      list.add(_identifierExpr());
      if (_currentToken?.type == TokenType.closeParen) {
        break;
      }
      // else this should be a comma
      _consume(TokenType.comma);
    }

    return list;
  }

  /// Parses expressions (comma delimited) until a [TokenType.closeParen] is
  /// reached (but not consumed).
  List<Expr> _argList() {
    final List<Expr> list = <Expr>[];
    while (_currentToken?.type != TokenType.closeParen) {
      list.add(_expr());
      if (_currentToken?.type == TokenType.closeParen) {
        break;
      }
      // else this should be a comma
      _consume(TokenType.comma);
    }

    return list;
  }

  StringLiteral _stringLiteral() {
    final StringToken token = _consume(TokenType.stringLiteral) as StringToken;
    return StringLiteral(token.value);
  }

  NumLiteral _numberLiteral() {
    final NumToken token = _consume(TokenType.numberLiteral) as NumToken;
    return NumLiteral(token.value);
  }

  /// Consume and return the next token iff it matches [type].
  ///
  /// Throws [ParseError] if the type is not correct.
  Token _consume(TokenType type) {
    // coerce type as this should only be called if you know what's there.
    final Token consumedToken = _currentToken!;
    if (consumedToken.type != type) {
      _throwParseError(consumedToken,
          'Expected a ${type.name}, got a ${consumedToken.type.name}');
    }
    _index += 1;
    return consumedToken;
  }

  /// Verifies whether or not the [tokenTypes] are next in the [tokenList].
  ///
  /// Does not mutate [_index].
  bool _tokenLookahead(List<TokenType> tokenTypes) {
    // note must use >
    // Consider a tokenlist of 4 tokens: [a, b, c, d]
    // where _index == 1 (b)
    // and tokenTypes has 3 elements (b, c, d)
    // this is valid, thus 1 + 3 == 4, not >
    if (_index + tokenTypes.length > tokenList.length) {
      // tokenTypes reaches beyond the end of the list, not possible
      return false;
    }
    for (int i = 0; i < tokenTypes.length; i += 1) {
      if (tokenList[_index + i].type != tokenTypes[i]) {
        return false;
      }
    }
    return true;
  }
}

// TODO track token for error handling
abstract class Decl {
  const Decl({
    required this.name,
  });

  final String name;
}

class ConstDecl extends Decl {
  ConstDecl({
    required super.name,
    required this.initialValue,
  });

  final Expr initialValue;
}

class FuncDecl extends Decl {
  const FuncDecl({
    required super.name,
    required this.statements,
    required this.params,
  });

  final List<Stmt> statements;
  final List<IdentifierRef> params;
}

abstract class Stmt {
  const Stmt();
}

class AssignStmt extends Stmt {
  const AssignStmt(this.name, this.expr);

  final String name;
  final Expr expr;
}

/// Interface for [ReturnStmt], etc.
abstract class FunctionExitStmt extends Stmt {
  const FunctionExitStmt(this.returnValue);

  final Expr returnValue;
}

class BareStmt extends Stmt {
  const BareStmt({required this.expression});

  final Expr expression;

  @override
  String toString() {
    return expression.toString();
  }
}

abstract class Expr {
  const Expr();
}

class CallExpr extends Expr {
  const CallExpr(this.name, this.argList);

  final String name;

  final List<Expr> argList;

  @override
  String toString() {
    return 'function $name(${argList.map((Expr expr) => expr.toString()).join(', ')})';
  }
}

class TypeRef extends Expr {
  const TypeRef(this.name);

  final String name;

  @override
  String toString() => 'TypeRef: "$name"';
}

class IdentifierRef extends Expr {
  const IdentifierRef(this.name);

  final String name;

  @override
  String toString() => 'IdentifierRef: "$name"';
}

class StringLiteral extends Expr {
  const StringLiteral(this.value);

  final String value;

  @override
  String toString() => 'StringLiteral: "$value"';
}

class NumLiteral extends Expr {
  const NumLiteral(this.value);

  final double value;
}

class ListLiteral extends Expr {
  const ListLiteral(this.elements, this.type);

  final List<Expr> elements;
  final TypeRef type;

  @override
  String toString() {
    return '${type.name}[${elements.map((Expr expr) => expr.toString()).join(', ')}]';
  }
}

class ParseError implements Exception {
  const ParseError(this.message);

  final String message;

  @override
  String toString() => message;
}
