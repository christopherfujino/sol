import 'dart:convert';
import 'dart:io' as io;

import 'emitter.dart';
import 'parser.dart';
import 'scanner.dart';

class Interpreter {
  Interpreter({
    required this.parseTree,
    required this.ctx,
    this.emitter,
  });

  final ParseTree parseTree;
  final Context ctx;

  final Emitter emitter;

  Future<void> emit(String msg) async {
    if (emitter == null) {
      return;
    }
    final Exception? error = await emitter!(InterpreterMessage(msg));
    if (error != null) {
      throw error;
    }
  }

  final Map<String, FuncDecl> _functionBindings = <String, FuncDecl>{};

  static final Map<String, ExtFuncDecl> _externalFunctions =
      <String, ExtFuncDecl>{
    'run': RunFuncDecl(),
    'print': const PrintFuncDecl(),
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

  Future<void> _stmt(final Stmt stmt) async {
    if (stmt is ConditionalChainStmt) {
      return _conditionalChainStmt(stmt);
    }
    if (stmt is WhileStmt) {
      return _whileStmt(stmt);
    }
    if (stmt is ReturnStmt) {
      ctx.returnValue = await _expr(stmt.returnValue);
      return;
    }
    if (stmt is BareStmt) {
      return _bareStmt(stmt, ctx);
    }
    if (stmt is VarDeclStmt) {
      return _varDeclStmt(stmt, ctx);
    }
    if (stmt is AssignStmt) {
      return _assignStmt(stmt);
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

  Future<void> _conditionalChainStmt(ConditionalChainStmt statement) async {
    final BoolVal ifCondition;
    try {
      ifCondition = await _expr<BoolVal>(statement.ifStmt.expr);
    } on TypeError catch (err) {
      // TODO make nicer message
      _throwRuntimeError('foo ${statement.ifStmt.expr}\n$err');
    }
    if (ifCondition.val) {
      await _block(statement.ifStmt.block);
    } else {
      if (statement.elseIfStmts != null) {
        bool hitAnElseIf = false;
        for (final ElseIfStmt stmt in statement.elseIfStmts!) {
          final BoolVal condition = await _expr<BoolVal>(stmt.expr);
          if (condition.val) {
            hitAnElseIf = true;
            await _block(stmt.block);
            break;
          }
        }
        if (!hitAnElseIf && statement.elseStmt != null) {
          await _block(statement.elseStmt!.block);
        }
      }
    }
  }

  Future<void> _whileStmt(WhileStmt stmt) async {
    while ((await _expr<BoolVal>(stmt.condition)).val) {
      await _block(stmt.block);
    }
  }

  Future<void> _bareStmt(BareStmt statement, Context ctx) async {
    await _expr(statement.expression);
  }

  Future<void> _varDeclStmt(VarDeclStmt stmt, Context ctx) async {
    final Val val = await _expr<Val>(stmt.expr);
    ctx.setVar(stmt.name, val);
  }

  Future<void> _assignStmt(AssignStmt stmt) async {
    final Val val = await _expr<Val>(stmt.expr);
    ctx.resetVar(stmt.name, val);
  }

  Future<T> _expr<T extends Val>(Expr expr) {
    if (expr is CallExpr) {
      return _callExpr<T>(expr, ctx);
    }

    if (expr is ListLiteral) {
      return _list(expr, ctx) as Future<T>;
    }

    if (expr is StringLiteral) {
      return _stringLiteral(expr) as Future<T>;
    }

    if (expr is BoolLiteral) {
      return _boolLiteral(expr) as Future<T>;
    }

    if (expr is NumLiteral) {
      return _numLiteral(expr) as Future<T>;
    }

    if (expr is IdentifierRef) {
      return _resolveIdentifier(expr, ctx) as Future<T>;
    }

    if (expr is BinaryExpr) {
      return _binaryExpr<T>(expr);
    }

    if (expr is TypeCast) {
      return _typeCast(expr, ctx) as Future<T>;
    }
    _throwRuntimeError('Unimplemented expression type $expr');
  }

  Future<T> _callExpr<T extends Val>(CallExpr expr, Context ctx) async {
    final List<Val> args = <Val>[];
    for (final Expr expr in expr.argList) {
      args.add(await _expr(expr));
    }

    final FuncDecl? func =
        _externalFunctions[expr.name] ?? _functionBindings[expr.name];

    if (func == null) {
      _throwRuntimeError('Tried to call undeclared function ${expr.name}');
    }

    final T? returnVal = await _executeFunc<T?>(func, args, ctx);
    return returnVal ?? NothingVal.instance as T;
  }

  Future<Val> _typeCast(TypeCast expr, Context ctx) async {
    switch (expr.type) {
      case TypeRef.string:
        final Val val = await _expr(expr.expr);
        return StringVal(val.toString());
      default:
        throw UnimplementedError('Cast to type ${expr.type} not implemented');
    }
  }

  Future<T> _executeFunc<T extends Val?>(
    FuncDecl func,
    List<Val> args,
    Context ctx,
  ) async {
    await emit('Executing $func');
    ctx.pushFrame();

    // TODO check lengths
    for (int idx = 0; idx < func.params.length; idx += 1) {
      final Parameter param = func.params[idx];
      final Val arg = args[idx];
      final ValType paramType = _typeRefToValType(param.type);
      if (paramType != arg.type) {
        _throwRuntimeError(
          'Parameter named ${param.name} expected to be of type $paramType, '
          'got ${arg.type} to function ${func.name}',
        );
      }
      ctx.setArg(param.name.name, arg);
    }

    if (func is ExtFuncDecl) {
      await func.interpret(
        interpreter: this,
        ctx: ctx,
      );
    } else {
      await _block(func.statements);
    }

    final T returnVal = ctx.popFrame().returnVal as T;
    // validate return value type
    final ValType definedType = _typeRefToValType(func.returnType);
    final ValType actualType = returnVal?.type ?? ValType.nothing;
    if (definedType != actualType) {
      _throwRuntimeError(
        'Function ${func.name} should return $definedType but it actually '
        'returned $actualType',
      );
    }
    return returnVal;
  }

  Future<void> _block(Iterable<Stmt> statements) async {
    for (final Stmt stmt in statements) {
      await _stmt(stmt);
    }
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

  ValType _typeRefToValType(TypeRef? ref) {
    if (ref == null) {
      return ValType.nothing;
    }
    if (ref is ListTypeRef) {
      return ListValType(_typeRefToValType(ref.subType));
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

  Future<T> _binaryExpr<T extends Val>(BinaryExpr expr) async {
    final Val leftVal = await _expr(expr.left);
    final Val rightVal = await _expr(expr.right);
    // TODO lift check to compiler
    if (leftVal.type != rightVal.type) {
      _throwRuntimeError(
        'The left and right hand sides of a ${expr.operatorToken} expression '
        'do not match!',
      );
    }
    switch (expr.operatorToken.type) {
      case TokenType.plus:
        if (leftVal is NumVal && rightVal is NumVal) {
          return NumVal(leftVal.val + rightVal.val) as T;
        }
        if (leftVal is StringVal && rightVal is StringVal) {
          return StringVal(leftVal.val + rightVal.val) as T;
        }
        _throwRuntimeError(
          '"+" operator not implemented for types ${leftVal.runtimeType} and '
          '${rightVal.runtimeType}',
        );
      case TokenType.equals:
        return BoolVal(leftVal.equalsTo(rightVal)) as T;
      case TokenType.notEquals:
        return BoolVal(!leftVal.equalsTo(rightVal)) as T;
      case TokenType.greaterThan:
        if (leftVal is! NumVal) {
          // TODO compiler error
          _throwRuntimeError('> operator can only be used on numbers');
        }
        // safe cast because of the type check at the start of this function
        return BoolVal(leftVal.val > (rightVal as NumVal).val) as T;
      case TokenType.greaterOrEqual:
        if (leftVal is! NumVal) {
          // TODO compiler error
          _throwRuntimeError('>= operator can only be used on numbers');
        }
        // safe cast because of the type check at the start of this function
        return BoolVal(leftVal.val >= (rightVal as NumVal).val) as T;
      case TokenType.lessThan:
        if (leftVal is! NumVal) {
          // TODO compiler error
          _throwRuntimeError('< operator can only be used on numbers');
        }
        // safe cast because of the type check at the start of this function
        return BoolVal(leftVal.val < (rightVal as NumVal).val) as T;
      case TokenType.lessOrEqual:
        if (leftVal is! NumVal) {
          // TODO compiler error
          _throwRuntimeError('<= operator can only be used on numbers');
        }
        // safe cast because of the type check at the start of this function
        return BoolVal(leftVal.val <= (rightVal as NumVal).val) as T;
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
      elements.add(await _expr(element));
    }
    return ListVal(
      _typeRefToValType(listLiteral.type),
      elements,
    );
  }

  Future<BoolVal> _boolLiteral(BoolLiteral expr) {
    return Future<BoolVal>.value(
      BoolVal(expr.value),
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

  Map<String, Val> get args => _callStack.last.arguments;

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
    // verify name not already used
    if (_callStack.last.arguments[name] != null) {
      _throwRuntimeError(
        'Tried to declare identifier $name, but it is already the name of an '
        'argument',
      );
    }
    // TODO check global constants
    if (_callStack.last.constBindings[name] != null) {
      _throwRuntimeError(
        'Tried to declare identifier $name, but it has already been declared '
        'as a constant',
      );
    }
    if (_callStack.last.varBindings[name] != null) {
      _throwRuntimeError(
        'Tried to declare identifier $name, but it has already been declared '
        'as a variable',
      );
    }
    _callStack.last.varBindings[name] = val;
  }

  void resetVar(String name, Val val) {
    // verify already exists as a var
    final Val? prevVal = _callStack.last.varBindings[name];
    if (prevVal == null) {
      _throwRuntimeError(
        '$name is not a variable',
      );
    }
    if (prevVal.type != val.type) {
      _throwRuntimeError(
        '$name is of type ${prevVal.type}, but the assignment value $val is of '
        'type ${val.type}',
      );
    }
    _callStack.last.varBindings[name] = val;
  }

  void setArg(String name, Val val) {
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
    required Interpreter interpreter,
    required Context ctx,
  });
}

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
      _throwRuntimeError('Cannot compare two values of different types!');
    }
    return val == other.val;
  }
}

/// A null value.
///
/// Should only be used for return values of functions that return
/// [ValType.nothing]
class NothingVal extends Val {
  const NothingVal._() : super(ValType.nothing);

  static const NothingVal instance = NothingVal._();

  @override
  Null get val => null;

  @override
  bool equalsTo(NothingVal other) => _throwRuntimeError(
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
    required Interpreter interpreter,
    required Context ctx,
  }) async {
    final StringVal message = ctx.args['msg']! as StringVal;
    // Don't call toString, else we get quotes
    interpreter.stdoutPrint(
      message.val,
    );
  }
}

class RunFuncDecl extends ExtFuncDecl {
  RunFuncDecl()
      : super(
          name: 'run',
          params: <Parameter>[
            Parameter(
                const IdentifierRef('command'), ListTypeRef(TypeRef.string))
          ],
        );

  @override
  Future<void> interpret({
    required Interpreter interpreter,
    required Context ctx,
  }) async {
    if (!ctx.args.containsKey('command')) {
      _throwRuntimeError(
        'Function run() expected one arg, got ${ctx.args}',
      );
    }

    final Val value = ctx.args['command']!;
    final List<String> command = <String>[];
    if (value is ListVal) {
      for (final Val element in value.val) {
        command.add((element as StringVal).val);
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
