import 'dart:io' as io;

import 'main.dart' show throwRuntimeError;
import 'vals.dart';

/// Runtime context, used for resolving identifiers.
class Context {
  Context({
    this.workingDir,
    this.env,
    this.parent,
  });

  final io.Directory? workingDir;
  final Map<String, String>? env;
  final Context? parent;

  final List<CallFrame> _callStack = <CallFrame>[];

  /// Create a new [CallFrame].
  void pushFrame() => _callStack.add(CallFrame());

  /// Pop the last [CallFrame].
  CallFrame popFrame() => _callStack.removeLast();

  Map<String, Val> get args => _callStack.last.arguments;

  T getVal<T extends Val>(String name) {
    final CallFrame frame = _callStack.last;
    Val? val = frame.arguments[name];
    if (val != null) {
      return val as T;
    }
    // TODO verify no collisions with varBindings
    val = frame.constBindings[name];
    if (val != null) {
      return val as T;
    }
    val = frame.varBindings[name];
    if (val != null) {
      return val as T;
    }
    throwRuntimeError('Could not resolve identifier $name of type $T');
  }

  void setVar(String name, Val val) {
    // verify name not already used
    if (_callStack.last.arguments[name] != null) {
      throwRuntimeError(
        'Tried to declare identifier $name, but it is already the name of an '
        'argument',
      );
    }
    // TODO check global constants
    if (_callStack.last.constBindings[name] != null) {
      throwRuntimeError(
        'Tried to declare identifier $name, but it has already been declared '
        'as a constant',
      );
    }
    if (_callStack.last.varBindings[name] != null) {
      throwRuntimeError(
        'Tried to declare identifier $name, but it has already been declared '
        'as a variable',
      );
    }
    _callStack.last.varBindings[name] = val;
  }

  // An assignment expression (not declaration) must overwrite an already
  // declared name.
  void resetVar(String name, Val val) {
    // verify already exists as a var
    final Val? prevVal = _callStack.last.varBindings[name];
    if (prevVal == null) {
      throwRuntimeError(
        '$name is not a variable',
      );
    }
    // TODO compile time error!
    if (prevVal.type != val.type) {
      throwRuntimeError(
        '$name is of type ${prevVal.type}, but the assignment value $val is of '
        'type ${val.type}',
      );
    }
    _callStack.last.varBindings[name] = val;
  }

  void setArg(String name, Val val) {
    _callStack.last.arguments[name] = val;
  }
}

class CallFrame {
  final Map<String, Val> arguments = <String, Val>{};
  final Map<String, Val> varBindings = <String, Val>{};
  final Map<String, Val> constBindings = <String, Val>{};

  @override
  String toString() => '''
CallFrame:
Arguments: ${arguments.entries.map((MapEntry<String, Val> entry) => '${entry.key} -> ${entry.value}').join(', ')}
Variables: ${varBindings.entries.map((MapEntry<String, Val> entry) => '${entry.key} -> ${entry.value}').join(', ')}
Constants: ${constBindings.entries.map((MapEntry<String, Val> entry) => '${entry.key} -> ${entry.value}').join(', ')}
''';
}
