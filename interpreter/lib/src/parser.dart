import 'dart:async';

import 'package:meta/meta.dart';

import 'scanner.dart';
import 'source_code.dart';

/// A graph of [Decl]s and [Expr]s.
class ParseTree {
  const ParseTree(this.declarations);

  final List<Decl> declarations;

  @override
  String toString() {
    const ParseTreePrinter printer = ParseTreePrinter();
    return printer.print(this);
    //final StringBuffer buffer = StringBuffer('ParseTree: \n');
    //for (final Decl decl in declarations) {
    //  for (final Stmt stmt in (decl as FuncDecl).statements) {
    //    buffer.writeln(stmt.toString());
    //  }
    //}
  }

  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitParseTree(this);
}

abstract class ParseTreeVisitor<T> {
  T visitParseTree(ParseTree that);

  // Declarations
  T visitConstDecl(ConstDecl that);
  T visitFuncDecl(FuncDecl that);

  // Expressions
  T visitNothingExpr(NothingExpr that);
  T visitBinaryExpr(BinaryExpr that);
  T visitUnaryExpr(UnaryExpr that);
  T visitCallExpr(CallExpr that);
  T visitSubExpr(SubExpr that);
  T visitTypeCast(TypeCast that);
  T visitTypeRef(TypeRef that);
  T visitListTypeRef(ListTypeRef that);
  T visitIdentifierRef(IdentifierRef that);
  T visitBoolLiteral(BoolLiteral that);
  T visitStringLiteral(StringLiteral that);
  T visitNumLiteral(NumLiteral that);
  T visitListLiteral(ListLiteral that);

  // Statements
  T visitVarDeclStmt(VarDeclStmt that);
  T visitAssignStmt(AssignStmt that);
  T visitBreakStmt(BreakStmt that);
  T visitReturnStmt(ReturnStmt that);
  T visitBareStmt(BareStmt that);
  T visitConditionalChainStmt(ConditionalChainStmt that);
  T visitWhileStmt(WhileStmt that);
  T visitIfStmt(IfStmt that);
  T visitElseIfStmt(ElseIfStmt that);
  T visitElseStmt(ElseStmt that);
}

String _indentString(String msg, [int level = 1]) => '${'  ' * level}$msg';
String _escapeString(String msg) {
  // TODO actually escape
  return '"$msg"';
}

class ParseTreePrinter implements ParseTreeVisitor<Iterable<String>> {
  const ParseTreePrinter();

  Iterable<String> _indentBlock(Iterable<String> Function() cb,
      {int level = 1}) sync* {
    for (final String line in cb()) {
      yield _indentString(line, level);
    }
  }

  String print(ParseTree that) {
    final StringBuffer buffer = StringBuffer();
    that.accept(this).forEach(buffer.writeln);
    return buffer.toString();
  }

  @override
  Iterable<String> visitParseTree(ParseTree that) sync* {
    yield '(ParseTree';
    yield* _indentBlock(() sync* {
      for (final Decl decl in that.declarations) {
        for (final String line in decl.accept(this)) {
          yield _indentString(line);
        }
      }
    });

    yield ')';
  }

  @override
  Iterable<String> visitConstDecl(ConstDecl that) sync* {
    yield '(ConstDecl';
    yield _indentString('${that.initialValue.accept(this)})');
  }

  @override
  Iterable<String> visitFuncDecl(FuncDecl that) sync* {
    yield '(FuncDecl';
    yield* _indentBlock(() sync* {
      yield '(params: ';

      yield* _indentBlock(() sync* {
        for (final Parameter param in that.params) {
          yield '($param)';
        }
      });

      yield '),';
      yield '(block: ';
      yield* _indentBlock(() sync* {
        for (final Stmt stmt in that.statements) {
          yield* stmt.accept(this);
        }
      });
      yield ')';
    });
    yield ')';
  }

  // Expressions

  @override
  Iterable<String> visitNothingExpr(NothingExpr that) {
    return const <String>['(NothingExpr)'];
  }

  @override
  Iterable<String> visitBinaryExpr(BinaryExpr that) sync* {
    yield '(BinaryExpr';

    // indent
    for (final String left in that.left.accept(this)) {
      yield _indentString(left);
    }
    yield _indentString(that.operatorToken.type.toString());

    for (final String right in that.right.accept(this)) {
      yield _indentString(right);
    }
    // dedent
    yield ')';
  }

  @override
  Iterable<String> visitUnaryExpr(UnaryExpr that) sync* {
    yield '(UnaryExpr';
    yield* _indentBlock(() sync* {
      yield '${that.operatorToken.type},';
      yield* that.primary.accept(this);
    });
    yield ')';
  }

  @override
  Iterable<String> visitCallExpr(CallExpr that) sync* {
    yield '(CallExpr';
    yield* _indentBlock(() sync* {
      yield '(name: ${that.name})';
      yield '(argList';
      yield* _indentBlock(() sync* {
        for (final Expr arg in that.argList) {
          yield* arg.accept(this);
        }
      });
      yield ')';
    });
    yield ')';
  }

  @override
  Iterable<String> visitSubExpr(SubExpr that) sync* {
    yield '(SubExpr';
    yield* _indentBlock(() sync* {
      yield 'target: ${that.target}';
      yield* that.subscript.accept(this);
    });
    yield ')';
  }

  @override
  Iterable<String> visitTypeCast(TypeCast that) sync* {
    yield '(TypeCast';
    yield* _indentBlock(() sync* {
      yield 'type: ';
      yield* that.type.accept(this);
    });
    yield ')';
  }

  @override
  Iterable<String> visitTypeRef(TypeRef that) {
    return <String>['(TypeRef ${that.name})'];
  }

  @override
  Iterable<String> visitListTypeRef(ListTypeRef that) sync* {
    throw UnimplementedError('TODO');
  }

  @override
  Iterable<String> visitIdentifierRef(IdentifierRef that) sync* {
    throw UnimplementedError('TODO');
  }

  @override
  Iterable<String> visitBoolLiteral(BoolLiteral that) sync* {
    throw UnimplementedError('TODO');
  }

  @override
  Iterable<String> visitStringLiteral(StringLiteral that) sync* {
    yield '(StringLiteral';
    yield* _indentBlock(() => <String>[_escapeString(that.value)]);
    yield ')';
  }

  @override
  Iterable<String> visitNumLiteral(NumLiteral that) sync* {
    yield '(NumLiteral';
    yield* _indentBlock(() => <String>[that.value.toString()]);
    yield ')';
  }

  @override
  Iterable<String> visitListLiteral(ListLiteral that) sync* {
    yield '(ListLiteral';
    yield* _indentBlock(() sync* {
      yield '(type: ';
      yield* _indentBlock(() sync* {
        yield* that.type.accept(this);
      });
      yield ')';
      yield '(elements:';
      yield* _indentBlock(() sync* {
        for (final Expr element in that.elements) {
          yield* element.accept(this);
        }
      });
      yield ')';
    });
    yield ')';
  }

  // Statements

  @override
  Iterable<String> visitVarDeclStmt(VarDeclStmt that) sync* {
    yield '(VarDeclStmt';
    yield* _indentBlock(() sync* {
      yield '(name: ${that.name})';
      yield '(isConstant: ${that.isConstant})';
      yield '(expr: ';
      yield* _indentBlock(() sync* {
        yield* that.expr.accept(this);
      });
      yield ')';
    });
    yield ')';
  }

  @override
  Iterable<String> visitAssignStmt(AssignStmt that) sync* {
    throw UnimplementedError('TODO');
  }

  @override
  Iterable<String> visitBreakStmt(BreakStmt that) sync* {
    throw UnimplementedError('TODO');
  }

  @override
  Iterable<String> visitReturnStmt(ReturnStmt that) sync* {
    throw UnimplementedError('TODO');
  }

  @override
  Iterable<String> visitBareStmt(BareStmt that) sync* {
    yield '(BareStmt';
    yield* _indentBlock(() => that.expression.accept(this));
    yield ')';
  }

  @override
  Iterable<String> visitConditionalChainStmt(ConditionalChainStmt that) sync* {
    throw UnimplementedError('TODO');
  }

  @override
  Iterable<String> visitIfStmt(IfStmt that) sync* {
    throw UnimplementedError('TODO');
  }

  @override
  Iterable<String> visitElseIfStmt(ElseIfStmt that) sync* {
    throw UnimplementedError('TODO');
  }

  @override
  Iterable<String> visitElseStmt(ElseStmt that) sync* {
    throw UnimplementedError('TODO');
  }

  @override
  Iterable<String> visitWhileStmt(WhileStmt that) sync* {
    throw UnimplementedError('TODO');
  }
}

class Parser {
  Parser({
    required this.tokenList,
    required this.entrySourceCode,
  });

  final List<Token> tokenList;
  final SourceCode entrySourceCode;

  // For debugging.
  Token? _previousToken;

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
      'Parse error: $token - $message\nPrevious token: $_previousToken',
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
    final List<Parameter> params = _paramList();
    _consume(TokenType.closeParen);

    TypeRef? returnType;
    if (_currentToken!.type == TokenType.arrow) {
      _consume(TokenType.arrow);
      returnType = _typeExpr();
    }

    final Iterable<Stmt> statements = _block();
    return FuncDecl(
      name: name.value,
      params: params,
      statements: statements,
      returnType: returnType,
    );
  }

  Iterable<Stmt> _block() {
    _consume(TokenType.openCurlyBracket);

    final List<Stmt> statements = <Stmt>[];
    while (_currentToken!.type != TokenType.closeCurlyBracket) {
      statements.add(_stmt());
    }
    _consume(TokenType.closeCurlyBracket);

    return statements;
  }

  Stmt _stmt() {
    if (_currentToken!.type == TokenType.ifKeyword) {
      return _conditionalChainStmt();
    }
    if (_currentToken!.type == TokenType.whileKeyword) {
      return _whileStmt();
    }
    if (_currentToken!.type == TokenType.breakKeyword) {
      return _breakStmt();
    }
    if (_currentToken!.type == TokenType.returnKeyword) {
      return _returnStmt();
    }
    if (_currentToken!.type == TokenType.variable) {
      return _varDeclStmt();
    }
    if (_tokenLookahead(<TokenType>[
      TokenType.identifier,
      TokenType.assignment,
    ])) {
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

  ConditionalChainStmt _conditionalChainStmt() {
    final IfStmt ifStmt;
    List<ElseIfStmt>? elseIfStmts;
    ElseStmt? elseStmt;

    // If, required
    _consume(TokenType.ifKeyword);
    final Expr ifExpr = _expr();
    final Iterable<Stmt> ifBlock = _block();
    ifStmt = IfStmt(ifExpr, ifBlock);

    // Else if, zero or more times
    while (_tokenLookahead(<TokenType>[
      TokenType.elseKeyword,
      TokenType.ifKeyword,
    ])) {
      _consume(TokenType.elseKeyword);
      _consume(TokenType.ifKeyword);

      elseIfStmts ??= <ElseIfStmt>[];

      final Expr elseIfExpr = _expr();
      final Iterable<Stmt> elseIfBlock = _block();

      elseIfStmts.add(ElseIfStmt(elseIfExpr, elseIfBlock));
    }

    // Else, zero or one time, must be last
    if (_currentToken!.type == TokenType.elseKeyword) {
      _consume(TokenType.elseKeyword);
      elseStmt = ElseStmt(_block());
    }

    return ConditionalChainStmt(
      ifStmt: ifStmt,
      elseIfStmts: elseIfStmts,
      elseStmt: elseStmt,
    );
  }

  WhileStmt _whileStmt() {
    _consume(TokenType.whileKeyword);
    final Expr condition = _expr();
    final Iterable<Stmt> block = _block();
    return WhileStmt(condition, block);
  }

  BreakStmt _breakStmt() {
    _consume(TokenType.breakKeyword);
    _consume(TokenType.semicolon);
    return BreakStmt();
  }

  ReturnStmt _returnStmt() {
    _consume(TokenType.returnKeyword);
    if (_currentToken!.type == TokenType.semicolon) {
      _consume(TokenType.semicolon);
      return const ReturnStmt(null);
    }
    final Expr returnValue = _expr();
    _consume(TokenType.semicolon);
    return ReturnStmt(returnValue);
  }

  VarDeclStmt _varDeclStmt() {
    _consume(TokenType.variable);
    final StringToken name = _consume(TokenType.identifier) as StringToken;
    _consume(TokenType.assignment);
    final Expr expr = _expr();
    _consume(TokenType.semicolon);
    return VarDeclStmt(
      name.value,
      expr,
    );
  }

  AssignStmt _assignStmt() {
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

  /// Expressions.
  ///
  /// expression
  /// equality
  /// comparison
  /// term
  /// factor
  /// unary
  /// primary
  Expr _expr() {
    return _equality();
  }

  /// Equality expression.
  ///
  /// comparison ( ( "!=" | "==" ) comparison )* ;
  Expr _equality() {
    Expr leftSide = _comparison();
    while (_currentToken!.type == TokenType.equals ||
        _currentToken!.type == TokenType.notEquals) {
      leftSide = BinaryExpr(
        leftSide,
        _consume(_currentToken!.type),
        _comparison(),
      );
    }
    return leftSide;
  }

  /// term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
  Expr _comparison() {
    Expr leftSide = _term();
    while (_currentToken!.type == TokenType.greaterThan ||
        _currentToken!.type == TokenType.lessThan ||
        _currentToken!.type == TokenType.greaterOrEqual ||
        _currentToken!.type == TokenType.lessOrEqual) {
      leftSide = BinaryExpr(
        leftSide,
        _consume(_currentToken!.type),
        _term(),
      );
    }

    return leftSide;
  }

  /// factor ( ( "-" | "+" ) factor )* ;
  Expr _term() {
    Expr left = _factor();
    while (_currentToken!.type == TokenType.plus ||
        _currentToken!.type == TokenType.minus) {
      final Token operatorToken = _consume(_currentToken!.type);
      final Expr right = _factor();
      left = BinaryExpr(left, operatorToken, right);
    }
    return left;
  }

  /// unary ( ( "/" | "*" ) unary )* ;
  Expr _factor() {
    Expr left = _unary();
    while (_currentToken!.type == TokenType.divide ||
        _currentToken!.type == TokenType.multiply) {
      final Token operatorToken = _consume(_currentToken!.type);
      final Expr right = _factor();
      left = BinaryExpr(left, operatorToken, right);
    }
    return left;
  }

  /// ( "!" | "-" ) unary | primary ;
  Expr _unary() {
    if (_currentToken!.type == TokenType.bang ||
        _currentToken!.type == TokenType.minus) {
      final Token operatorToken = _consume(_currentToken!.type);
      final Expr unary = _unary();
      return UnaryExpr(operatorToken, unary);
    }
    return _primary();
  }

  /// NUMBER | STRING | "true" | "false" | "(" expression ")" ;
  Expr _primary() {
    if (_currentToken!.type == TokenType.stringLiteral) {
      return _stringLiteral();
    }
    if (_tokenLookahead(const <TokenType>[
      TokenType.identifier,
      TokenType.openParen,
    ])) {
      return _callExpr();
    }

    if (_tokenLookahead(const <TokenType>[
      TokenType.identifier,
      TokenType.openSquareBracket,
    ])) {
      return _subExpr();
    }

    if (_currentToken!.type == TokenType.booleanLiteral) {
      return _boolLiteral();
    }

    if (_currentToken!.type == TokenType.numberLiteral) {
      return _numberLiteral();
    }

    if (_currentToken!.type == TokenType.type) {
      if (_tokenLookahead(const <TokenType>[
        TokenType.type,
        TokenType.openSquareBracket,
      ])) {
        return _listLiteral();
      }

      if (_tokenLookahead(const <TokenType>[
        TokenType.type,
        TokenType.openParen,
      ])) {
        return _typeCast();
      }

      return _typeExpr();
    }

    if (_currentToken!.type == TokenType.openParen) {
      _consume(TokenType.openParen);
      final Expr expr = _expr();
      _consume(TokenType.closeParen);
      return expr;
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
    // TODO could be list type
    return TypeRef(token.value);
  }

  /// A type cast.
  ///
  /// Looks like `TypeRef(expr) -> Val`.
  TypeCast _typeCast() {
    final TypeRef type = _typeExpr();
    _consume(TokenType.openParen);
    final Expr expr = _expr();
    _consume(TokenType.closeParen);

    return TypeCast(type, expr);
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

  // sub_expression ::= identifier, "[", String | Number, "]"
  SubExpr _subExpr() {
    final StringToken name = _consume(TokenType.identifier) as StringToken;
    _consume(TokenType.openSquareBracket);

    // TODO check this is a string/num expression during compilation
    final Expr expr = _expr();

    _consume(TokenType.closeSquareBracket);
    return SubExpr(
      name.value,
      expr,
    );
  }

  /// Parses identifiers (comma delimited) until a [TokenType.closeParen] is
  /// reached (but not consumed).
  List<Parameter> _paramList() {
    final List<Parameter> list = <Parameter>[];
    while (_currentToken?.type != TokenType.closeParen) {
      final IdentifierRef name = _identifierExpr();
      final TypeRef type = _typeExpr();
      list.add(Parameter(name, type));
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

  BoolLiteral _boolLiteral() {
    final StringToken token = _consume(TokenType.booleanLiteral) as StringToken;
    if (token.value == 'true') {
      return const BoolLiteral(true);
    } else if (token.value == 'false') {
      return const BoolLiteral(false);
    } else {
      _throwParseError(
        token,
        'Invalid string value "${token.value}" for a boolean literal token',
      );
    }
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
    // this should only be called if you know what's there.
    if (_currentToken!.type != type) {
      _throwParseError(
        _currentToken,
        'Expected a ${type.name}, got a ${_currentToken!.type.name}',
      );
    }
    _previousToken = _currentToken;
    _index += 1;
    return _previousToken!;
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

  T accept<T>(ParseTreeVisitor<T> visitor);
}

class ConstDecl extends Decl {
  ConstDecl({
    required super.name,
    required this.initialValue,
  });

  final Expr initialValue;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitConstDecl(this);
}

class FuncDecl extends Decl {
  const FuncDecl({
    required super.name,
    required this.statements,
    required this.params,
    this.returnType,
  });

  final Iterable<Stmt> statements;
  final List<Parameter> params;
  final TypeRef? returnType;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitFuncDecl(this);

  @override
  String toString() {
    if (returnType == null) {
      final String paramString =
          params.map((Parameter param) => param.toString()).join(', ');
      return 'function $name($paramString)';
    }
    final String paramString =
        params.map((Parameter param) => param.toString()).join(', ');
    return 'function $name($paramString) -> $returnType';
  }
}

@immutable
abstract class Stmt {
  const Stmt();

  T accept<T>(ParseTreeVisitor<T> visitor);
}

/// Declaration of a variable (or constant).
class VarDeclStmt extends Stmt {
  const VarDeclStmt(this.name, this.expr, {this.isConstant = false});

  final String name;
  final Expr expr;
  final bool isConstant;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitVarDeclStmt(this);
}

/// Re-assignment of a variable.
///
/// It will be a compilation error if [name] resolves to a constant.
class AssignStmt extends Stmt {
  const AssignStmt(this.name, this.expr);

  final String name;
  final Expr expr;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitAssignStmt(this);
}

/// Interface for [ReturnStmt], etc.
abstract class BlockExitStmt extends Stmt {
  const BlockExitStmt();
}

class BreakStmt extends BlockExitStmt {
  factory BreakStmt() => instance;

  const BreakStmt._();

  static const BreakStmt instance = BreakStmt._();

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitBreakStmt(this);
}

class ReturnStmt extends BlockExitStmt {
  const ReturnStmt(this.returnValue);

  final Expr? returnValue;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitReturnStmt(this);
}

class BareStmt extends Stmt {
  const BareStmt({required this.expression});

  final Expr expression;

  @override
  String toString() {
    return expression.toString();
  }

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitBareStmt(this);
}

/// Wraps a single opening if statement (with block), zero or more else if
/// statements, and an optional final else statement.
class ConditionalChainStmt extends Stmt {
  const ConditionalChainStmt({
    required this.ifStmt,
    this.elseIfStmts,
    this.elseStmt,
  });

  final IfStmt ifStmt;
  final Iterable<ElseIfStmt>? elseIfStmts;
  final ElseStmt? elseStmt;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) =>
      visitor.visitConditionalChainStmt(this);
}

class WhileStmt extends Stmt {
  const WhileStmt(this.condition, this.block);

  final Expr condition;
  final Iterable<Stmt> block;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitWhileStmt(this);
}

class IfStmt extends Stmt {
  const IfStmt(this.expr, this.block);

  final Expr expr;
  final Iterable<Stmt> block;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitIfStmt(this);
}

class ElseIfStmt extends IfStmt {
  const ElseIfStmt(super.expr, super.block);

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitElseIfStmt(this);
}

class ElseStmt extends Stmt {
  const ElseStmt(this.block);

  final Iterable<Stmt> block;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitElseStmt(this);
}

@immutable
abstract class Expr {
  const Expr();

  // TODO create compiled version with a static type
  // TODO track token

  T accept<T>(ParseTreeVisitor<T> visitor);
}

class NothingExpr extends Expr {
  const NothingExpr();

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitNothingExpr(this);
}

class BinaryExpr extends Expr {
  const BinaryExpr(
    this.left,
    this.operatorToken,
    this.right,
  );

  final Expr left;
  final Token operatorToken;
  final Expr right;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitBinaryExpr(this);
}

class UnaryExpr extends Expr {
  const UnaryExpr(
    this.operatorToken,
    this.primary,
  );

  final Token operatorToken;
  final Expr primary;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitUnaryExpr(this);
}

class CallExpr extends Expr {
  const CallExpr(this.name, this.argList);

  final String name;

  final List<Expr> argList;

  @override
  String toString() {
    // This could be faster
    final String paramString = argList
        .map(
          (Expr expr) => expr.toString(),
        )
        .join(', ');
    return 'function $name($paramString)';
  }

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitCallExpr(this);
}

/// An expression dereferencing a data structure with square brackets.
class SubExpr extends Expr {
  const SubExpr(this.target, this.subscript);

  /// List or Map that this expression is accessing.
  final String target;

  final Expr subscript;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitSubExpr(this);
}

class TypeCast extends Expr {
  const TypeCast(this.type, this.expr);

  final TypeRef type;
  final Expr expr;

  @override
  String toString() {
    return 'TypeCast ($expr) -> $type';
  }

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitTypeCast(this);
}

class TypeRef extends Expr {
  factory TypeRef(String name) {
    TypeRef? maybe = _instances[name];
    if (maybe != null) {
      return maybe;
    }
    maybe = TypeRef._(name);
    _instances[name] = maybe;
    return maybe;
  }

  const TypeRef._(this.name);

  static final Map<String, TypeRef> _instances = <String, TypeRef>{
    'String': string,
  };
  static const TypeRef string = TypeRef._('String');

  final String name;

  @override
  String toString() => name;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitTypeRef(this);
}

class ListTypeRef implements TypeRef {
  factory ListTypeRef(TypeRef subType) {
    ListTypeRef? maybe = _instances[subType];
    if (maybe != null) {
      return maybe;
    }
    maybe = ListTypeRef._(subType);
    _instances[subType] = maybe;
    return maybe;
  }

  const ListTypeRef._(this.subType);

  static final Map<TypeRef, ListTypeRef> _instances = <TypeRef, ListTypeRef>{};

  final TypeRef subType;

  @override
  String get name => '${subType.name}[]';

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitListTypeRef(this);

  @override
  String toString() => 'ListTypeRef: $name';
}

/// A pairing of an [IdentifierRef] and a [TypeRef].
class Parameter {
  const Parameter(this.name, this.type);

  final IdentifierRef name;
  final TypeRef type;

  @override
  String toString() {
    return '$name $type';
  }
}

class IdentifierRef extends Expr {
  const IdentifierRef(this.name);

  final String name;

  @override
  String toString() => name;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitIdentifierRef(this);
}

class BoolLiteral extends Expr {
  const BoolLiteral(this.value);

  final bool value;

  @override
  String toString() => '$value';

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitBoolLiteral(this);
}

class StringLiteral extends Expr {
  const StringLiteral(this.value);

  final String value;

  @override
  String toString() => '"$value"';

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitStringLiteral(this);
}

class NumLiteral extends Expr {
  const NumLiteral(this.value);

  final double value;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitNumLiteral(this);
}

class ListLiteral extends Expr {
  const ListLiteral(this.elements, this.type);

  final List<Expr> elements;
  final TypeRef type;

  @override
  String toString() {
    final String elementString =
        elements.map((Expr expr) => expr.toString()).join(', ');
    return '${type.name}[$elementString]';
  }

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitListLiteral(this);
}

class ParseError implements Exception {
  const ParseError(this.message);

  final String message;

  @override
  String toString() => message;
}
