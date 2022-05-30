import 'dart:convert';
import 'dart:io' as io;

import 'parser.dart';
import 'scanner.dart';

typedef Printer = void Function(String);

class Interpreter {
  Interpreter({
    required this.parseTree,
    required this.ctx,
  });

  final ParseTree parseTree;
  final Context ctx;

  final Map<String, FuncDecl> _functionBindings = <String, FuncDecl>{};

  static const Map<String, ExtFuncDecl> _externalFunctions =
      <String, ExtFuncDecl>{
    'run': RunFuncDecl(),
    'print': PrintFuncDecl(),
  };

  //visibleForOverriding
  void stdoutPrint(String msg) {
    io.stdout.writeln(msg);
  }

  //visibleForOverriding
  void stderrPrint(String msg) {
    io.stderr.writeln(msg);
  }

  Future<void> interpret() async {
    // Register declarations
    _registerDeclarations();

    // interpret target
    await _interpret(ctx);
  }

  Future<void> _interpret(
    Context ctx,
  ) async {
    final FuncDecl? mainFunc = _functionBindings['main'];
    if (mainFunc == null) {
      _throwRuntimeError('Could not find a "main" function');
    }

    // TODO read CLI args
    final List<Val> args = <Val>[];
    await _executeFunc(mainFunc, args, ctx);
  }

  Future<void> _stmt(Stmt stmt, Context ctx) async {
    if (stmt is ReturnStmt) {
      ctx.returnValue = await _expr(stmt.returnValue, ctx);
      return;
    }
    if (stmt is BareStmt) {
      await _bareStmt(stmt, ctx);
      return;
    }
    if (stmt is AssignStmt) {
      await _assignStmt(stmt, ctx);
      return;
    }
    _throwRuntimeError('Unimplemented statement type ${stmt.runtimeType}');
  }

  void _registerDeclarations() {
    for (final Decl decl in parseTree.declarations) {
      if (decl is FuncDecl) {
        // TODO should check globally for any identifier with this name
        if (_functionBindings.containsKey(decl.name)) {
          _throwRuntimeError('Duplicate function named ${decl.name}');
        }
        _functionBindings[decl.name] = decl;
      } else {
        _throwRuntimeError('Unknown declaration type ${decl.runtimeType}');
      }
    }
  }

  Future<void> _bareStmt(BareStmt statement, Context ctx) async {
    await _expr(statement.expression, ctx);
  }

  Future<void> _assignStmt(AssignStmt stmt, Context ctx) async {
    final Val val = (await _expr(stmt.expr, ctx))!;
    ctx.setVar(stmt.name, val);
  }

  Future<Val?> _expr(Expr expr, Context ctx) {
    if (expr is CallExpr) {
      return _callExpr(expr, ctx);
    }

    if (expr is ListLiteral) {
      return _list(expr, ctx);
    }

    if (expr is StringLiteral) {
      return _stringLiteral(expr);
    }

    if (expr is NumLiteral) {
      return _numLiteral(expr);
    }

    if (expr is IdentifierRef) {
      return _resolveIdentifier(expr, ctx);
    }

    if (expr is BinaryExpr) {
      return _binaryExpr(expr, ctx);
    }
    _throwRuntimeError('Unimplemented expression type $expr');
  }

  Future<Val?> _callExpr(CallExpr expr, Context ctx) async {
    final List<Val> args = <Val>[];
    for (final Expr expr in expr.argList) {
      args.add((await _expr(expr, ctx))!);
    }

    if (_externalFunctions.containsKey(expr.name)) {
      final ExtFuncDecl func = _externalFunctions[expr.name]!;
      ctx.pushFrame();
      await func.interpret(
        argVals: args,
        interpreter: this,
        ctx: ctx,
      );
      final CallFrame frame = ctx.popFrame();
      return frame.returnVal;
    } else {
      final FuncDecl? func = _functionBindings[expr.name];
      if (func == null) {
        _throwRuntimeError('Tried to call undeclared function ${expr.name}');
      }

      return _executeFunc(func, args, ctx);
    }
  }

  Future<Val?> _executeFunc(FuncDecl func, List<Val> args, Context ctx) async {
    ctx.pushFrame();
    for (int idx = 0; idx < func.params.length; idx += 1) {
      final Parameter param = func.params[idx];
      final Val arg = args[idx];
      if (_typeRefToValType(param.type) != arg.type) {
        _throwRuntimeError(
          'Expected arg of type ${func.params[idx].type}, got ${args[idx].type}',
        );
      }
      ctx.setArg(param.name.name, arg);
    }
    // TODO interpret higher level control flow
    for (final Stmt stmt in func.statements) {
      await _stmt(stmt, ctx);
    }

    final Val? returnVal = ctx.popFrame().returnVal;
    // validate return value type
    if (_typeRefToValType(func.returnType) != returnVal?.type) {
      _throwRuntimeError(
          'Function ${func.name} should return ${func.returnType?.name ?? 'Nothing'} but it actually returned ${returnVal?.type.name ?? 'Nothing'}');
    }
    return returnVal;
  }

  Future<Val> _resolveIdentifier(
    IdentifierRef identifier,
    Context ctx,
  ) async {
    final Val? val = ctx.getVal(identifier.name);
    if (val == null) {
      throw UnimplementedError(
        "Don't know how to resolve identifier ${identifier.name}",
      );
    }
    return val;
  }

  ValType? _typeRefToValType(TypeRef? ref) {
    if (ref == null) {
      return null;
    }
    switch (ref.name) {
      case 'String':
        return ValType.string;
      case 'Number':
        return ValType.number;
      default:
        // TODO implement user-defined types
        throw UnimplementedError('Unknown TypeRef $ref');
    }
  }

  Future<Val> _binaryExpr(BinaryExpr expr, Context ctx) async {
    switch (expr.operatorToken.type) {
      case TokenType.plus:
        final Val leftVal = (await _expr(expr.left, ctx))!;
        final Val rightVal = (await _expr(expr.right, ctx))!;
        if (leftVal is! NumVal || rightVal is! NumVal) {
          _throwRuntimeError(
            '"+" operator not implemented for types ${leftVal.runtimeType} and ${rightVal.runtimeType}',
          );
        }
        return NumVal(leftVal.val + rightVal.val);
      default:
        throw UnimplementedError(
          "Don't know how to calculate ${expr.operatorToken}",
        );
    }
  }

  Future<ListVal> _list(ListLiteral listLiteral, Context ctx) async {
    final List<Val> elements = <Val>[];
    for (final Expr element in listLiteral.elements) {
      // expressions must be evaluated in order
      elements.add((await _expr(element, ctx))!);
    }
    return ListVal(
      _typeRefToValType(listLiteral.type)!,
      elements,
    );
  }

  Future<StringVal> _stringLiteral(StringLiteral expr) {
    return Future<StringVal>.value(
      StringVal(expr.value),
    );
  }

  Future<NumVal> _numLiteral(NumLiteral expr) {
    return Future<NumVal>.value(
      NumVal(expr.value),
    );
  }

  Future<int> runProcess({
    required List<String> command,
    io.Directory? workingDir,
  }) async {
    stdoutPrint('Running command "${command.join(' ')}"...');
    final String executable = command.first;
    final List<String> rest = command.sublist(1);
    final io.Process process = await io.Process.start(
      executable,
      rest,
      workingDirectory: workingDir?.absolute.path,
    );
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
      stdoutPrint(line);
    });
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
      stderrPrint(line);
    });
    return process.exitCode;
  }
}

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

  Val? getVal(String name) {
    final CallFrame frame = _callStack.last;
    Val? val = frame.arguments[name];
    if (val != null) {
      return val;
    }
    val = frame.constBindings[name];
    if (val != null) {
      return val;
    }
    val = frame.varBindings[name];
    if (val != null) {
      return val;
    }
    return null;
  }

  void setVar(String name, Val val) {
    // TODO verify name not already used
    _callStack.last.varBindings[name] = val;
  }

  void setArg(String name, Val val) {
    // TODO verify name not already used
    _callStack.last.arguments[name] = val;
  }

  set returnValue(Val? val) => _callStack.last.returnVal = val;
  Val? get returnValue => _callStack.last.returnVal;
}

class CallFrame {
  Val? returnVal;
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

/// An external [FunctionDecl].
abstract class ExtFuncDecl extends FuncDecl {
  const ExtFuncDecl({
    required super.name,
    required super.params,
  }) : super(statements: const <Stmt>[]);

  Future<void> interpret({
    required Iterable<Val> argVals,
    required Interpreter interpreter,
    required Context ctx,
  });
}

class ValType {
  const ValType._(this.name);

  factory ValType.list(ValType subtype) {
    // TODO cache
    return ValType._('$subtype[]');
  }

  final String name;

  static const ValType string = ValType._('String');
  static const ValType number = ValType._('Number');
  static const ValType nothing = ValType._('Nothing');

  @override
  String toString() => 'ValType: $name';
}

abstract class Val {
  const Val(this.type);

  final ValType type;
}

class StringVal extends Val {
  const StringVal(this.val) : super(ValType.string);

  final String val;

  @override
  String toString() => val;
}

class NumVal extends Val {
  const NumVal(this.val) : super(ValType.number);

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

class ListVal extends Val {
  ListVal(this.subType, this.elements) : super(ValType.list(subType));

  final List<Val> elements;
  final ValType subType;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('[');
    buffer.write(
      elements.map<String>((Val val) => val.toString()).join(', '),
    );
    buffer.write(']');
    return buffer.toString();
  }
}

class PrintFuncDecl extends ExtFuncDecl {
  const PrintFuncDecl()
      : super(
          name: 'print',
          params: const <Parameter>[
            Parameter(IdentifierRef('msg'), TypeRef.string)
          ],
        );

  @override
  Future<void> interpret({
    required Iterable<Val> argVals,
    required Interpreter interpreter,
    required Context ctx,
  }) async {
    if (argVals.length != 1) {
      _throwRuntimeError(
        'Function run() expected one arg, got $argVals',
      );
    }
    interpreter.stdoutPrint(
      argVals.first.toString(),
    );
  }
}

class RunFuncDecl extends ExtFuncDecl {
  const RunFuncDecl()
      : super(
          name: 'run',
          params: const <Parameter>[
            Parameter(IdentifierRef('command'), ListTypeRef('String'))
          ],
        );

  @override
  Future<void> interpret({
    required Iterable<Val> argVals,
    required Interpreter interpreter,
    required Context ctx,
  }) async {
    if (argVals.length != 1) {
      _throwRuntimeError(
        'Function run() expected one arg, got $argVals',
      );
    }

    final Val value = argVals.first;
    final List<String> command = <String>[];
    if (value is ListVal) {
      for (final Val element in value.elements) {
        command.add((element as StringVal).toString());
      }
    } else {
      _throwRuntimeError(
        'Function run() expected an arg of either String or List<String>, got '
        '${value.runtimeType}',
      );
    }

    final int exitCode = await interpreter.runProcess(
      command: command,
      workingDir: ctx.workingDir,
    );
    if (exitCode != 0) {
      _throwRuntimeError('"${command.join(' ')}" exited with code $exitCode');
    }
  }
}

// TODO accept token
Never _throwRuntimeError(String message) => throw RuntimeError(message);

class RuntimeError implements Exception {
  const RuntimeError(this.message);

  final String message;

  @override
  String toString() => message;
}
