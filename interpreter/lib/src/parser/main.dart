import 'dart:async';

import '../scanner.dart';

import 'declarations.dart';
import 'expressions.dart';
import 'parse_tree.dart';
import 'statements.dart';

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
  // TODO what is allowedDeclarations for?
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
            'A function declaration is not allowed in the current context.',
          );
        }
        return _funcDecl();
      case TokenType.structureKeyword:
        if (allowedDeclarations != null &&
            !allowedDeclarations.contains(StructureDecl)) {
          _throwParseError(
            currentToken,
            'A structure declaration is not allowed in the current context.',
          );
        }
        return _structureDecl();
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
    final StringToken name = _consume<StringToken>(TokenType.identifier);
    _consume(TokenType.openParen);
    final List<NameTypePair> params = _paramList();
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

  StructureDecl _structureDecl() {
    _consume(TokenType.structureKeyword);
    final StringToken typeName = _consume<StringToken>(TokenType.type);
    _consume(TokenType.openCurlyBracket);
    final Map<String, TypeRef> fields = <String, TypeRef>{};

    while (_currentToken!.type != TokenType.closeCurlyBracket) {
      final NameTypePair fieldPair = _nameTypePair();
      _consume(TokenType.semicolon);
      if (fields.containsKey(fieldPair.name)) {
        // should this be a compiler error?
        _throwParseError(
          null,
          'The field name ${fieldPair.name} appears twice in the '
          'structure declaration ${fieldPair.name}',
        );
      }
      fields[fieldPair.name] = fieldPair.type;
    }

    _consume(TokenType.closeCurlyBracket);

    return StructureDecl(
      name: typeName.value,
      fields: fields,
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
    if (_currentToken!.type == TokenType.forKeyword) {
      return _forStmt();
    }
    if (_currentToken!.type == TokenType.breakKeyword) {
      return _breakStmt();
    }
    if (_currentToken!.type == TokenType.continueKeyword) {
      return _continueStmt();
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
    final Token token = _consume(TokenType.semicolon);
    return BareStmt(token, expression: expression);
  }

  ConditionalChainStmt _conditionalChainStmt() {
    final IfStmt ifStmt;
    List<ElseIfStmt>? elseIfStmts;
    ElseStmt? elseStmt;

    // If, required
    final Token ifToken = _consume(TokenType.ifKeyword);
    final Expr ifExpr = _expr();
    final Iterable<Stmt> ifBlock = _block();
    ifStmt = IfStmt(ifExpr, ifBlock, ifToken);

    // Else if, zero or more times
    while (_tokenLookahead(<TokenType>[
      TokenType.elseKeyword,
      TokenType.ifKeyword,
    ])) {
      final Token token = _consume(TokenType.elseKeyword);
      _consume(TokenType.ifKeyword);

      elseIfStmts ??= <ElseIfStmt>[];

      final Expr elseIfExpr = _expr();
      final Iterable<Stmt> elseIfBlock = _block();

      elseIfStmts.add(ElseIfStmt(elseIfExpr, elseIfBlock, token));
    }

    // Else, zero or one time, must be last
    if (_currentToken!.type == TokenType.elseKeyword) {
      final Token token = _consume(TokenType.elseKeyword);
      elseStmt = ElseStmt(_block(), token);
    }

    return ConditionalChainStmt(
      ifToken,
      ifStmt: ifStmt,
      elseIfStmts: elseIfStmts,
      elseStmt: elseStmt,
    );
  }

  WhileStmt _whileStmt() {
    final Token token = _consume(TokenType.whileKeyword);
    final Expr condition = _expr();
    final Iterable<Stmt> block = _block();
    return WhileStmt(condition, block, token);
  }

  ForStmt _forStmt() {
    final Token token = _consume(TokenType.forKeyword);
    final IdentifierRef index = _identifierExpr();
    _consume(TokenType.comma);
    final IdentifierRef element = _identifierExpr();
    _consume(TokenType.inKeyword);
    final Expr iterable = _expr();
    final Iterable<Stmt> block = _block();
    return ForStmt(index, element, iterable, block, token);
  }

  BreakStmt _breakStmt() {
    final Token token = _consume(TokenType.breakKeyword);
    _consume(TokenType.semicolon);
    return BreakStmt(token);
  }

  ContinueStmt _continueStmt() {
    final Token token = _consume(TokenType.continueKeyword);
    _consume(TokenType.semicolon);
    return ContinueStmt(token);
  }

  ReturnStmt _returnStmt() {
    final Token token = _consume(TokenType.returnKeyword);
    if (_currentToken!.type == TokenType.semicolon) {
      _consume(TokenType.semicolon);
      return ReturnStmt(null, token);
    }
    final Expr returnValue = _expr();
    _consume(TokenType.semicolon);
    return ReturnStmt(returnValue, token);
  }

  VarDeclStmt _varDeclStmt() {
    final Token token = _consume(TokenType.variable);
    final StringToken name = _consume(TokenType.identifier) as StringToken;
    _consume(TokenType.assignment);
    final Expr expr = _expr();
    _consume(TokenType.semicolon);
    return VarDeclStmt(
      name.value,
      expr,
      token,
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
      name,
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

  /// unary ( ( "/" | "*" | "%" ) unary )* ;
  Expr _factor() {
    Expr left = _unary();
    while (_currentToken!.type == TokenType.divide ||
        _currentToken!.type == TokenType.multiply ||
        _currentToken!.type == TokenType.modulo) {
      final Token operatorToken = _consume(_currentToken!.type);
      final Expr right = _factor();
      left = BinaryExpr(left, operatorToken, right);
    }
    return left;
  }

  /// Unary
  ///
  /// ( "!" | "-" ) unary | call ;
  Expr _unary() {
    if (_currentToken!.type == TokenType.bang ||
        _currentToken!.type == TokenType.minus) {
      final Token operatorToken = _consume(_currentToken!.type);
      final Expr unary = _unary();
      return UnaryExpr(operatorToken, unary);
    }
    return _call();
  }

  /// Function call or field access call.
  ///
  /// primary ( "(" arguments? ")" | "." IDENTIFIER )* ;
  Expr _call() {
    Expr expr = _primary();
    // TODO Should we only match open paren if [expr] is IdentifierRef?
    while (true) {
      if (_currentToken!.type == TokenType.openParen) {
        expr = _callExpr(expr as IdentifierRef); // should this be Expr?
      } else if (_currentToken!.type == TokenType.dot) {
        _consume(TokenType.dot);
        expr = FieldAccessExpr(expr, _identifierExpr());
      } else if (_currentToken!.type == TokenType.openSquareBracket) {
        expr = _subExpr(expr);
      } else {
        break;
      }
    }
    return expr;
  }

  /// NUMBER | STRING | "true" | "false" | "(" expression ")" | IDENTIFIER;
  Expr _primary() {
    if (_currentToken!.type == TokenType.stringLiteral) {
      return _stringLiteral();
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

      if (_tokenLookahead(const <TokenType>[
        TokenType.type,
        TokenType.openCurlyBracket,
      ])) {
        return _structureLiteral();
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

  /// A field access.
  //FieldAccessExpr _fieldAccessExpr(Expr parent) {
  //  final List<Expr> expressions = <Expr>[parent];
  //  while (_tokenLookahead(const <TokenType>[
  //    TokenType.identifier,
  //    TokenType.dot,
  //  ])) {
  //    identifiers.add(_identifierExpr());
  //    _consume(TokenType.dot);
  //  }
  //  // there should be one last trailing identifier
  //  identifiers.add(_identifierExpr());

  //  return FieldAccessExpr(identifiers);
  //}

  /// A type reference.
  ///
  /// Either intrinsic or user-defined.
  TypeRef _typeExpr() {
    final StringToken token = _consume<StringToken>(TokenType.type);
    final TypeRef type = TypeRef(token.value);

    // list type
    if (_currentToken!.type == TokenType.openSquareBracket) {
      _consume(TokenType.openSquareBracket);
      _consume(TokenType.closeSquareBracket);
      return ListTypeRef(type);
    }
    return type;
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

  /// A type cast.
  ///
  /// Looks like `TypeRef(expr) -> Val`.
  StructureLiteral _structureLiteral() {
    final Map<String, Expr> fields = <String, Expr>{};
    final StringToken typeName = _consume<StringToken>(TokenType.type);
    _consume(TokenType.openCurlyBracket);
    while (_currentToken!.type != TokenType.closeCurlyBracket) {
      final NameExprPair pair = _nameExprPair();
      if (fields.containsKey(pair.name.name)) {
        _throwParseError(
          null, // TODO
          'Tried to parse a structure literal with duplicate '
          'fields named ${pair.name.name}',
        );
      }
      fields[pair.name.name] = pair.expr;

      if (_currentToken!.type == TokenType.closeCurlyBracket) {
        break;
      }
      // else this should be a comma
      _consume(TokenType.comma);
    }
    _consume(TokenType.closeCurlyBracket);

    return StructureLiteral(typeName.value, fields);
  }

  ListLiteral _listLiteral() {
    final StringToken token = _consume<StringToken>(TokenType.type);
    final TypeRef type = TypeRef(token.value);

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
  CallExpr _callExpr(IdentifierRef name) {
    List<Expr>? argList;
    _consume(TokenType.openParen);
    if (_currentToken?.type != TokenType.closeParen) {
      argList = _argList();
    }
    _consume(TokenType.closeParen);
    return CallExpr(
      name.name,
      argList ?? const <Expr>[],
    );
  }

  // sub_expression ::= identifier, "[", String | Number, "]"
  SubExpr _subExpr(Expr parent) {
    _consume(TokenType.openSquareBracket);

    // TODO check this is a string/num expression during compilation
    final Expr expr = _expr();

    _consume(TokenType.closeSquareBracket);
    return SubExpr(
      parent,
      expr,
    );
  }

  /// An identifier followed by a [Expr] separated by a colon.
  ///
  /// Used in argument lists and structure literals.
  NameExprPair _nameExprPair() {
    final IdentifierRef name = _identifierExpr();
    _consume(TokenType.colon);
    final Expr expr = _expr();
    return NameExprPair(name, expr);
  }

  /// An identifier followed by a type.
  ///
  /// Used in parameter lists and structure declarations.
  NameTypePair _nameTypePair() {
    final IdentifierRef name = _identifierExpr();
    final TypeRef type = _typeExpr();
    return NameTypePair(name.name, type);
  }

  /// Parses identifiers (comma delimited) until a [TokenType.closeParen] is
  /// reached (but not consumed).
  List<NameTypePair> _paramList() {
    final List<NameTypePair> list = <NameTypePair>[];
    while (_currentToken?.type != TokenType.closeParen) {
      list.add(_nameTypePair());
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
  T _consume<T extends Token>(TokenType type) {
    // this should only be called if you know what's there.
    if (_currentToken!.type != type) {
      _throwParseError(
        _currentToken,
        'Expected a ${type.name}, got a ${_currentToken!.type.name}',
      );
    }
    _previousToken = _currentToken;
    _index += 1;
    return _previousToken! as T;
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

class ParseError implements Exception {
  const ParseError(this.message);

  final String message;

  @override
  String toString() => message;
}
