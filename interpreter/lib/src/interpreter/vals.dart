import 'main.dart' show throwRuntimeError;

class ValType {
  const ValType._(this.name);

  final String name;

  static const ValType string = ValType._('String');
  static const ValType number = ValType._('Number');
  static const ValType nothing = ValType._('Nothing');
  static const ValType boolean = ValType._('Boolean');

  @override
  String toString() => 'ValType: $name';
}

class StructureValType extends ValType {
  factory StructureValType(String name) {
    if (_instances.containsKey(name)) {
      return _instances[name]!;
    }

    _instances[name] = StructureValType._(name);
    return _instances[name]!;
  }

  const StructureValType._(super.name) : super._();

  static final Map<String, StructureValType> _instances =
      <String, StructureValType>{};
}

class ListValType extends ValType {
  factory ListValType(ValType subType) {
    ListValType? maybe = _instances[subType];
    if (maybe != null) {
      return maybe;
    }
    maybe = ListValType._(subType);
    _instances[subType] = maybe;
    return maybe;
  }

  ListValType._(this.subType) : super._(subType.name);

  static final Map<ValType, ListValType> _instances = <ValType, ListValType>{};

  final ValType subType;

  @override
  String toString() => 'ListValType: $name[]';
}

abstract class Val {
  const Val(this.type);

  final ValType type;

  Object? get val;

  bool equalsTo(covariant Val other) {
    if (runtimeType != other.runtimeType) {
      throwRuntimeError('Cannot compare two values of different types!');
    }
    return val == other.val;
  }
}

/// A null value.
///
/// Should only be used for return values of functions that return
/// [ValType.nothing]. All variables should always have a non-Nothing value.
class NothingVal extends Val {
  factory NothingVal() => instance;

  const NothingVal._() : super(ValType.nothing);

  static const NothingVal instance = NothingVal._();

  @override
  Never get val => throwRuntimeError('You cannot reference a Nothing value!');

  @override
  bool equalsTo(NothingVal other) => throwRuntimeError(
        'You should not be comparing Nothing!',
      );
}

class BoolVal extends Val {
  factory BoolVal(bool val) {
    return val ? trueVal : falseVal;
  }

  const BoolVal._(this.val) : super(ValType.boolean);

  static const BoolVal trueVal = BoolVal._(true);
  static const BoolVal falseVal = BoolVal._(false);

  @override
  final bool val;

  @override
  bool equalsTo(BoolVal other) => val == other.val;

  @override
  String toString() => val.toString();
}

class StringVal extends Val {
  factory StringVal(String val) {
    StringVal? maybe = _instances[val];
    if (maybe != null) {
      return maybe;
    }
    maybe = StringVal._(val);
    _instances[val] = maybe;
    return maybe;
  }

  const StringVal._(this.val) : super(ValType.string);

  static final Map<String, StringVal> _instances = <String, StringVal>{};

  @override
  final String val;

  @override
  String toString() => '"$val"';
}

class NumVal extends Val {
  factory NumVal(double val) {
    NumVal? maybe = _instances[val];
    if (maybe != null) {
      return maybe;
    }
    maybe = NumVal._(val);
    _instances[val] = maybe;
    return maybe;
  }

  const NumVal._(this.val) : super(ValType.number);

  static final Map<double, NumVal> _instances = <double, NumVal>{};

  @override
  final double val;

  @override
  String toString() {
    if (val == val.ceil()) {
      return val.toStringAsFixed(0);
    } else {
      return val.toString();
    }
  }
}

class NameValTypePair {
  const NameValTypePair(this.name, this.type);

  final String name;
  final ValType type;
}

class StructureVal extends Val {
  StructureVal(String name, this.fields) : super(StructureValType(name));

  final Map<NameValTypePair, Val> fields;

  @override
  Object? get val => throw UnimplementedError('Not sure how to implement');

  @override
  bool equalsTo(ListVal other) {
    throw UnimplementedError('TODO implement');
  }

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('${type.name}{');
    fields.forEach((NameValTypePair pair, Val val) {
      buffer.writeln('${pair.name}: $val');
    });
    buffer.writeln('}');
    return buffer.toString();
  }
}

class ListVal extends Val {
  ListVal(this.subType, this.val) : super(ListValType(subType));

  @override
  final List<Val> val;
  final ValType subType;

  @override
  bool equalsTo(ListVal other) {
    if (val.length != other.val.length) {
      return false;
    }
    for (int i = 0; i < val.length; i += 1) {
      if (!val[i].equalsTo(other.val[i])) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('[');
    buffer.write(
      val.map<String>((Val val) => val.toString()).join(', '),
    );
    buffer.write(']');
    return buffer.toString();
  }
}
