import 'declarations.dart';
import 'expressions.dart';
import 'parse_tree.dart';
import 'statements.dart';

// Utility functions
String _indentString(String msg, [int level = 1]) => '${'  ' * level}$msg';
String _escapeString(String msg) {
  // TODO actually escape
  return '"$msg"';
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

class ParseTreePrinter implements ParseTreeVisitor<Iterable<String>> {
  const ParseTreePrinter();

  Iterable<String> _indentBlock(
    Iterable<String> Function() cb, {
    int level = 1,
  }) sync* {
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
      yield '(declarations:';
      yield* _indentBlock(() sync* {
        for (final Decl decl in that.declarations) {
          yield* decl.accept(this);
        }
      });
      yield ')';
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
      yield '(name: ${that.name})';
      if (that.params.isEmpty) {
        yield '(params: ())';
      } else {
        yield '(params: ';

        yield* _indentBlock(() sync* {
          for (final Parameter param in that.params) {
            yield '($param)';
          }
        });

        yield '),';
      }
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

    yield* _indentBlock(() sync* {
      // left
      yield '(left:';
      yield* _indentBlock(() sync* {
        yield* that.left.accept(this);
      });
      yield ')';

      // token
      yield '(operatorToken: ${that.operatorToken.type})';

      // right
      yield '(right:';
      yield* _indentBlock(() sync* {
        yield* that.right.accept(this);
      });
      yield ')';
    });

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
      yield '(argList:';
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
      yield '(target: ${that.target})';

      yield '(subscript: ';
      yield* _indentBlock(() sync* {
        yield* that.subscript.accept(this);
      });
      yield ')';
    });
    yield ')';
  }

  @override
  Iterable<String> visitTypeCast(TypeCast that) sync* {
    yield '(TypeCast';
    yield* _indentBlock(() sync* {
      yield '(type: ';
      yield* _indentBlock(() sync* {
        yield* that.type.accept(this);
      });
      yield ')';
      yield '(expr: ';
      yield* _indentBlock(() sync* {
        yield* that.expr.accept(this);
      });
      yield ')';
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
    yield '(IdentifierRef ${that.name})';
  }

  @override
  Iterable<String> visitBoolLiteral(BoolLiteral that) sync* {
    throw UnimplementedError('TODO');
  }

  @override
  Iterable<String> visitStringLiteral(StringLiteral that) sync* {
    yield '(StringLiteral ${_escapeString(that.value)})';
  }

  @override
  Iterable<String> visitNumLiteral(NumLiteral that) sync* {
    yield '(NumLiteral ${that.value})';
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
    yield '(AssignStmt';
    yield* _indentBlock(() sync* {
      yield '(name: ${that.name})';
      yield '(expr:';
      yield* _indentBlock(() sync* {
        yield* that.expr.accept(this);
      });
      yield ')';
    });
    yield ')';
  }

  @override
  Iterable<String> visitBreakStmt(BreakStmt that) sync* {
    throw UnimplementedError('TODO');
  }

  @override
  Iterable<String> visitReturnStmt(ReturnStmt that) sync* {
    if (that.returnValue == null) {
      yield '(ReturnStmt)';
    } else {
      yield '(ReturnStmt';
      yield* _indentBlock(() sync* {
        yield* that.returnValue!.accept(this);
      });
      yield ')';
    }
  }

  @override
  Iterable<String> visitBareStmt(BareStmt that) sync* {
    yield '(BareStmt';
    yield* _indentBlock(() => that.expression.accept(this));
    yield ')';
  }

  @override
  Iterable<String> visitConditionalChainStmt(ConditionalChainStmt that) sync* {
    yield '(ConditionalChainStmt';
    yield* _indentBlock(() sync* {
      yield* that.ifStmt.accept(this);
    });
    yield ')';
  }

  @override
  Iterable<String> visitIfStmt(IfStmt that) sync* {
    yield '(IfStmt';
    yield* _indentBlock(() sync* {
      // .expr: Expr
      yield '(expr:';
      yield* _indentBlock(() sync* {
        yield* that.expr.accept(this);
      });
      yield ')';

      // .block: Iterable<Stmt>
      yield '(block:';
      yield* _indentBlock(() sync* {
        for (final Stmt stmt in that.block) {
          yield* stmt.accept(this);
        }
      });
      yield ')';
    });
    yield ')';
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
