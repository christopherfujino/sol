import 'expressions.dart';
import 'statements.dart';
import 'visitors.dart';

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

class StructureDecl extends Decl {
  StructureDecl({
    required super.name,
    required this.fields,
  });

  final Map<String, TypeRef> fields;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitStructureDecl(this);
}

class FuncDecl extends Decl {
  const FuncDecl({
    required super.name,
    required this.statements,
    required this.params,
    this.returnType,
  });

  final Iterable<Stmt> statements;
  final List<NameTypePair> params;
  final TypeRef? returnType;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitFuncDecl(this);

  @override
  String toString() {
    if (returnType == null) {
      final String paramString =
          params.map((NameTypePair param) => param.toString()).join(', ');
      return 'function $name($paramString)';
    }
    final String paramString =
        params.map((NameTypePair param) => param.toString()).join(', ');
    return 'function $name($paramString) -> $returnType';
  }
}

/// A pairing of a [String] and a [TypeRef].
class NameTypePair {
  const NameTypePair(this.name, this.type);

  final String name;
  final TypeRef type;

  @override
  String toString() {
    return '$name $type';
  }
}

/// A pairing of an [IdentifierRef] and an [Expr].
class NameExprPair {
  const NameExprPair(this.name, this.expr);

  final IdentifierRef name;
  final Expr expr;

  @override
  String toString() {
    return '$name $expr';
  }
}
