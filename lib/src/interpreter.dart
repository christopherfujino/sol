import 'dart:convert';
import 'dart:io' as io;

import 'parser.dart';

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

    await _executeFunc(mainFunc, ctx);
  }

  Future<void> _stmt(Stmt stmt, Context ctx) async {
    if (stmt is FunctionExitStmt) {
      _throwRuntimeError('Unimplemented statement type ${stmt.runtimeType}');
    }
    if (stmt is BareStmt) {
      await _bareStatement(stmt, ctx);
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

  Future<void> _bareStatement(BareStmt statement, Context ctx) async {
    await _expr(statement.expression, ctx);
  }

  Future<Object?> _expr(Expr expr, Context ctx) {
    if (expr is CallExpr) {
      return _callExpr(expr, ctx);
    }

    if (expr is ListLiteral) {
      return _list(expr.elements, ctx);
    }

    if (expr is StringLiteral) {
      return _stringLiteral(expr);
    }

    if (expr is IdentifierRef) {
      return _resolveIdentifier(expr, ctx);
    }
    _throwRuntimeError('Unimplemented expression type $expr');
  }

  Future<Object?> _callExpr(CallExpr expr, Context ctx) async {
    if (_externalFunctions.containsKey(expr.name)) {
      final ExtFuncDecl func = _externalFunctions[expr.name]!;
      await func.interpret(
        argExpressions: expr.argList,
        interpreter: this,
        ctx: ctx,
      );
      return null;
    }

    final FuncDecl? func = _functionBindings[expr.name];
    if (func == null) {
      _throwRuntimeError('Tried to call undeclared function ${expr.name}');
    }

    return _executeFunc(func, ctx);
  }

  Future<Object?> _executeFunc(FuncDecl func, Context ctx) async {
    for (final Stmt stmt in func.statements) {
      if (stmt is FunctionExitStmt) {
        return _expr(stmt.returnValue, ctx);
      }
      await _stmt(stmt, ctx);
    }
    return null;
  }

  Future<Object?> _resolveIdentifier(
      IdentifierRef identifier, Context ctx) async {
    if (_functionBindings.containsKey(identifier.name)) {
      return _functionBindings[identifier.name]!;
    }
    throw UnimplementedError(
        "Don't know how to resolve identifier ${identifier.name}");
  }

  Future<List<Object?>> _list(List<Expr> expressions, Context ctx) async {
    final List<Object?> elements = <Object?>[];
    for (final Expr element in expressions) {
      elements.add(await _expr(element, ctx));
    }
    return elements;
  }

  Future<String> _stringLiteral(StringLiteral expr) {
    return Future<String>.value(expr.value);
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

  String _castExprToString(Expr expr) {
    switch (expr.runtimeType) {
      case StringLiteral:
        return (expr as StringLiteral).value;
      case ListLiteral:
        final StringBuffer buffer = StringBuffer('[');
        buffer.write(
          (expr as ListLiteral)
              .elements
              .map<String>((Expr expr) => _castExprToString(expr))
              .join(', '),
        );
        buffer.write(']');
        return buffer.toString();
    }
    throw UnimplementedError(expr.runtimeType.toString());
  }
}

class Context {
  const Context({
    this.workingDir,
    this.env,
    this.parent,
  });

  final io.Directory? workingDir;
  final Map<String, String>? env;
  final Context? parent;
}

/// An external [FunctionDecl].
abstract class ExtFuncDecl extends FuncDecl {
  const ExtFuncDecl({
    required super.name,
    required super.params,
  }) : super(statements: const <Stmt>[]);

  Future<void> interpret({
    required List<Expr> argExpressions,
    required Interpreter interpreter,
    required Context ctx,
  });
}

class PrintFuncDecl extends ExtFuncDecl {
  const PrintFuncDecl()
      : super(
          name: 'print',
          params: const <IdentifierRef>[IdentifierRef('msg')],
        );

  @override
  Future<void> interpret({
    required List<Expr> argExpressions,
    required Interpreter interpreter,
    required Context ctx,
  }) async {
    if (argExpressions.length != 1) {
      _throwRuntimeError(
        'Function run() expected one arg, got $argExpressions',
      );
    }
    interpreter.stdoutPrint(
      interpreter._castExprToString(argExpressions.first),
    );
  }
}

class RunFuncDecl extends ExtFuncDecl {
  const RunFuncDecl()
      : super(
          name: 'run',
          params: const <IdentifierRef>[IdentifierRef('command')],
        );

  @override
  Future<void> interpret({
    required List<Expr> argExpressions,
    required Interpreter interpreter,
    required Context ctx,
  }) async {
    if (argExpressions.length != 1) {
      _throwRuntimeError(
        'Function run() expected one arg, got $argExpressions',
      );
    }

    final Object? value = await interpreter._expr(argExpressions.first, ctx);
    final List<String> command;
    if (value is String) {
      command = value.split(' ');
    } else if (value is List<String>) {
      command = value;
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
