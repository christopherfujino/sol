import 'package:meta/meta.dart';

import '../scanner.dart' show Token;
import 'visitors.dart';

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
///
/// TODO: use generic to differentiate List from Map?
class SubExpr extends Expr {
  const SubExpr(this.target, this.subscript);

  /// List or Map that this expression is accessing.
  final Expr target;

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

class StructureLiteral extends Expr {
  const StructureLiteral(this.name, this.fields);

  final String name;

  // when compiling these should be sorted so interpretation is deterministic.
  final Map<String, Expr> fields;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) =>
      visitor.visitStructureLiteral(this);
}

class FieldAccessExpr extends Expr {
  const FieldAccessExpr(this.parent, this.fieldName);

  final Expr parent;
  final IdentifierRef fieldName;

  @override
  T accept<T>(ParseTreeVisitor<T> visitor) =>
      visitor.visitFieldAccessExpr(this);
}
