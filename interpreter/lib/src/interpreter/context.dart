import 'main.dart' show throwRuntimeError;
import 'vals.dart';

/// Runtime context, used for resolving identifiers.
class Context {
  Context({
    this.parent,
  });

  final Context? parent;

  final List<Environment> _environments = <Environment>[];

  /// Create a new [Environment].
  // TODO make this private and create instead a public helper that manages
  // popping frame.
  void pushEnvironment(Environment nextFrame) => _environments.add(nextFrame);

  /// Pop the last [Environment].
  Environment popEnvironment() => _environments.removeLast();

  Map<String, Val> get args => _environments.last.arguments;

  T getVal<T extends Val>(String name) {
    for (int i = _environments.length - 1; i >= 0; i -= 1) {
      final Environment env = _environments[i];
      Val? val = env.arguments[name];
      if (val != null) {
        return val as T;
      }
      // TODO verify no collisions with varBindings
      val = env.constBindings[name];
      if (val != null) {
        return val as T;
      }
      val = env.varBindings[name];
      if (val != null) {
        return val as T;
      }
    }
    throwRuntimeError('Could not resolve identifier "$name" of type $T');
  }

  void setVar(String name, Val val) {
    // verify name not already used
    if (_environments.last.arguments[name] != null) {
      throwRuntimeError(
        'Tried to declare identifier $name, but it is already the name of an '
        'argument',
      );
    }
    // TODO check global constants
    if (_environments.last.constBindings[name] != null) {
      throwRuntimeError(
        'Tried to declare identifier $name, but it has already been declared '
        'as a constant',
      );
    }
    if (_environments.last.varBindings[name] != null) {
      throwRuntimeError(
        'Tried to declare identifier $name, but it has already been declared '
        'as a variable',
      );
    }
    _environments.last.varBindings[name] = val;
  }

  // An assignment expression (not declaration) must overwrite an already
  // declared name.
  void reassignVar(String name, Val val) {
    for (int i = _environments.length - 1; i >= 0; i -= 1) {
      final Environment env = _environments[i];
      // verify already exists as a var
      final Val? prevVal = env.varBindings[name];
      if (prevVal == null) {
        continue;
      }
      // TODO compile time error!
      if (prevVal.type != val.type) {
        throwRuntimeError(
          '$name is of type ${prevVal.type}, but the assignment value $val is '
          'of type ${val.type}',
        );
      }
      env.varBindings[name] = val;
      return;
    }
    throwRuntimeError('$name is not a variable');
  }

  void setArg(String name, Val val) {
    _environments.last.arguments[name] = val;
  }
}

class Environment {
  Environment({
    Map<String, Val>? arguments,
    Map<String, Val>? varBindings,
    Map<String, Val>? constBindings,
  })  : arguments = arguments ?? <String, Val>{},
        varBindings = varBindings ?? <String, Val>{},
        constBindings = constBindings ?? <String, Val>{};

  final Map<String, Val> arguments;
  final Map<String, Val> varBindings;
  final Map<String, Val> constBindings;

  @override
  String toString() => '''
CallFrame:
Arguments: ${arguments.entries.map((MapEntry<String, Val> entry) => '${entry.key} -> ${entry.value}').join(', ')}
Variables: ${varBindings.entries.map((MapEntry<String, Val> entry) => '${entry.key} -> ${entry.value}').join(', ')}
Constants: ${constBindings.entries.map((MapEntry<String, Val> entry) => '${entry.key} -> ${entry.value}').join(', ')}
''';
}
