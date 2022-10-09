import 'package:meta/meta.dart';

import 'expressions.dart';
import 'visitors.dart' show ParseTreeVisitor;

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

class ContinueStmt extends BlockExitStmt {
  factory ContinueStmt() => instance;

  const ContinueStmt._();

  static const ContinueStmt instance = ContinueStmt._();

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitContinueStmt(this);
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

class ForStmt extends Stmt {
  const ForStmt(this.index, this.element, this.iterable, this.block);

  final IdentifierRef index;
  final IdentifierRef element;
  final Expr iterable;
  final Iterable<Stmt> block;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitForStmt(this);
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
