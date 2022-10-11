import 'dart:io' as io;

import 'package:meta/meta.dart';

import '../emitter.dart';
import '../parser/parser.dart';
import '../scanner.dart' show TokenType;

import 'context.dart';
import 'native_functions.dart';
import 'vals.dart';

class CliInterpreter extends Interpreter {
  factory CliInterpreter({
    required ParseTree parseTree,
    required io.Directory workingDir,
    Emitter? emitter,
    Map<String, String> env = const <String, String>{},
  }) {
    return CliInterpreter.internal(
      parseTree: parseTree,
      emitter: emitter,
      env: env,
      workingDir: workingDir,
    );
  }

  @visibleForTesting
  CliInterpreter.internal({
    required super.parseTree,
    required this.workingDir,
    super.emitter,
    this.env = const <String, String>{},
  }) : super(externalFunctions: <String, ExtFuncDecl<CliInterpreter>>{
    'run': CliRunFuncDecl(),
    'print': const CliPrintFuncDecl(),
  });

  final Map<String, String> env;
  final io.Directory workingDir;

  @override
  void stdoutPrint(String msg) {
    io.stdout.writeln(msg);
  }

  @override
  void stderrPrint(String msg) {
    io.stderr.writeln(msg);
  }
}

abstract class Interpreter {
  Interpreter({
    this.emitter,
    required this.parseTree,
    required this.externalFunctions,
  });

  final ParseTree parseTree;
  final Context ctx = Context();

  final Emitter? emitter;

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
  final Map<String, StructureDecl> _structureBindings =
      <String, StructureDecl>{};

  Set<String> get _allBindingNames {
    return <String>{
      ..._functionBindings.keys,
      ..._structureBindings.keys,
    };
  }

  final Map<String, ExtFuncDecl<Interpreter>> externalFunctions;

  void stdoutPrint(String msg);

  void stderrPrint(String msg);

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
      throwRuntimeError('Could not find a "main" function');
    }

    // TODO read CLI args
    final List<Val> args = <Val>[];
    await _executeFunc(mainFunc, args, ctx);
  }

  Future<BlockExit?> _stmt(final Stmt stmt) async {
    if (stmt is ConditionalChainStmt) {
      return _conditionalChainStmt(stmt);
    }
    if (stmt is WhileStmt) {
      return _whileStmt(stmt);
    }
    if (stmt is ForStmt) {
      return _forStmt(stmt);
    }
    if (stmt is ReturnStmt) {
      throw StateError(
        'This should be unreachable, should be handled in the _block loop',
      );
    }
    if (stmt is BareStmt) {
      await _bareStmt(stmt, ctx);
      return null;
    }
    if (stmt is VarDeclStmt) {
      await _varDeclStmt(stmt, ctx);
      return null;
    }
    if (stmt is AssignStmt) {
      await _assignStmt(stmt);
      return null;
    }
    throwRuntimeError('Unimplemented statement type ${stmt.runtimeType}');
  }

  void _registerDeclarations() {
    for (final Decl decl in parseTree.declarations) {
      if (_allBindingNames.contains(decl.name)) {
        throwRuntimeError(
          'There is already a declaration named ${decl.name}',
        );
      }

      if (decl is FuncDecl) {
        _functionBindings[decl.name] = decl;
      } else if (decl is StructureDecl) {
        _structureBindings[decl.name] = decl;
      } else {
        throwRuntimeError('Unknown declaration type ${decl.runtimeType}');
      }
    }
  }

  Future<BlockExit?> _conditionalChainStmt(
    ConditionalChainStmt statement,
  ) async {
    final BoolVal ifCondition;
    try {
      ifCondition = await _expr<BoolVal>(statement.ifStmt.expr);
    } on TypeError catch (err) {
      // TODO make nicer message
      throwRuntimeError('foo ${statement.ifStmt.expr}\n$err');
    }
    if (ifCondition.val) {
      final BlockExit? exit = await _block(
        statement.ifStmt.block,
        Environment(),
      );
      if (exit != null) {
        return exit;
      }
    } else {
      if (statement.elseIfStmts != null) {
        bool hitAnElseIf = false;
        for (final ElseIfStmt stmt in statement.elseIfStmts!) {
          final BoolVal condition = await _expr<BoolVal>(stmt.expr);
          if (condition.val) {
            hitAnElseIf = true;
            final BlockExit? exit = await _block(stmt.block, Environment());
            if (exit != null) {
              return exit;
            }
            break;
          }
        }
        if (!hitAnElseIf && statement.elseStmt != null) {
          final BlockExit? exit = await _block(
            statement.elseStmt!.block,
            Environment(),
          );
          if (exit != null) {
            return exit;
          }
        }
      }
    }
    return null;
  }

  Future<BlockExit?> _whileStmt(WhileStmt stmt) async {
    while ((await _expr<BoolVal>(stmt.condition)).val) {
      final BlockExit? exit = await _block(stmt.block, Environment());
      switch (exit.runtimeType) {
        case BreakSentinel:
          return null;
        case ReturnValue:
          return exit;
        case Null:
          break;
        default:
          throw UnimplementedError('cannot handle ${exit.runtimeType}');
      }
    }
    return null;
  }

  Future<BlockExit?> _forStmt(ForStmt stmt) async {
    final ListVal iterable = await _expr<ListVal>(stmt.iterable);
    final int length = iterable.val.length;
    for (int i = 0; i < length; i += 1) {
      final Environment frame = Environment(varBindings: <String, Val>{
        stmt.index.name: NumVal(i.toDouble()),
        stmt.element.name: iterable.val[i],
      });
      // concurrent modification check?
      final BlockExit? exit = await _block(stmt.block, frame);
      switch (exit.runtimeType) {
        case BreakSentinel:
          return null;
        case ReturnValue:
          return exit;
        case Null:
          break;
        default:
          throw UnimplementedError('cannot handle ${exit.runtimeType}');
      }
    }
    return null;
  }

  Future<void> _bareStmt(BareStmt statement, Context ctx) async {
    await _expr(statement.expression);
  }

  Future<void> _varDeclStmt(VarDeclStmt stmt, Context ctx) async {
    final Val val = await _expr(stmt.expr);
    ctx.setVar(stmt.name, val);
  }

  Future<void> _assignStmt(AssignStmt stmt) async {
    final Val val = await _expr(stmt.expr);
    ctx.reassignVar(stmt.name, val);
  }

  Future<T> _expr<T extends Val>(Expr expr) {
    if (expr is CallExpr) {
      return _callExpr<T>(expr, ctx);
    }

    if (expr is ListLiteral) {
      return _list(expr, ctx) as Future<T>;
    }

    if (expr is StructureLiteral) {
      return _structureLiteral(expr) as Future<T>;
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
      return _resolveIdentifier<T>(expr, ctx);
    }

    if (expr is BinaryExpr) {
      return _binaryExpr<T>(expr);
    }

    if (expr is TypeCast) {
      return _typeCast<T>(expr, ctx);
    }

    if (expr is SubExpr) {
      return _subExpr<T>(expr);
    }

    if (expr is FieldAccessExpr) {
      return _fieldAccessExpr<T>(expr);
    }
    throwRuntimeError('Unimplemented expression type $expr');
  }

  Future<T> _callExpr<T extends Val>(CallExpr expr, Context ctx) async {
    final List<Val> args = <Val>[];
    for (final Expr expr in expr.argList) {
      args.add(await _expr(expr));
    }

    final FuncDecl? func =
        externalFunctions[expr.name] ?? _functionBindings[expr.name];

    if (func == null) {
      throwRuntimeError('Tried to call undeclared function ${expr.name}');
    }

    final T? returnVal = await _executeFunc<T?>(func, args, ctx);
    return returnVal ?? NothingVal() as T;
  }

  /// TODO improve use of generics
  Future<T> _typeCast<T extends Val>(TypeCast expr, Context ctx) async {
    switch (expr.type) {
      case TypeRef.string:
        final Val val = await _expr<Val>(expr.expr);

        return _castToString(val) as T;
      default:
        throw UnimplementedError('Cast to type ${expr.type} not implemented');
    }
  }

  /// Cast from generic [Val] to [StringVal].
  StringVal _castToString(Val val) {
    if (val is StringVal) {
      // no-op
      return val;
    }
    if (val is NumVal) {
      // NumVal.toString() handles int truncation.
      return StringVal(val.toString());
    }
    throw UnimplementedError(
      'TODO implement casting from ${val.runtimeType} to StringVal',
    );
  }

  Future<T> _subExpr<T extends Val>(SubExpr expr) async {
    // TODO implement for maps
    final ListVal list = await _expr<ListVal>(expr.target);
    final NumVal sub = await _expr<NumVal>(expr.subscript);
    if (list.val.length - 1 < sub.val) {
      throwRuntimeError(
        'Tried to access element ${sub.val} from a list with '
        '${list.val.length} elements!',
      );
    }

    return list.val[sub.val.toInt()] as T;
  }

  Future<T> _executeFunc<T extends Val?>(
    FuncDecl func,
    List<Val> args,
    Context ctx,
  ) async {
    await emit('Executing $func');

    final Map<String, Val> arguments = <String, Val>{};
    // TODO check lengths
    for (int idx = 0; idx < func.params.length; idx += 1) {
      final NameTypePair param = func.params[idx];
      final Val arg = args[idx];
      final ValType paramType = _typeRefToValType(param.type);
      if (paramType != arg.type) {
        throwRuntimeError(
          'Parameter named ${param.name} expected to be of type $paramType, '
          'got ${arg.type} to function ${func.name}',
        );
      }
      arguments[param.name] = arg;
    }

    final Environment frame = Environment(
      arguments: arguments,
    );
    final T returnVal;
    if (func is ExtFuncDecl) {
      ctx.pushEnvironment(frame);
      final BlockExit exit = await func.interpret(
        interpreter: this,
        ctx: ctx,
      );
      if (exit is! ReturnValue) {
        throw UnimplementedError(
          'Not sure how to handle a ${exit.runtimeType} returned from a '
          'function block',
        );
      }
      returnVal = exit.val as T;
      ctx.popEnvironment();
    } else {
      final BlockExit? exit = await _block(
        func.statements,
        frame,
      );
      if (exit != null && exit is! ReturnValue) {
        throw UnimplementedError(
          'Not sure how to handle a ${exit.runtimeType} returned from a '
          'function block',
        );
      }
      if (exit == null) {
        returnVal = NothingVal() as T;
      } else {
        returnVal = (exit as ReturnValue).val as T;
      }
    }

    // validate return value type
    final ValType definedType = _typeRefToValType(func.returnType);
    final ValType actualType = returnVal?.type ?? ValType.nothing;
    if (definedType != actualType) {
      throwRuntimeError(
        'Function ${func.name} should return $definedType but it actually '
        'returned $actualType',
      );
    }
    return returnVal;
  }

  Future<BlockExit?> _block(
    Iterable<Stmt> statements,
    Environment nextFrame,
  ) async {
    ctx.pushEnvironment(nextFrame);
    try {
      for (final Stmt stmt in statements) {
        if (stmt is BlockExitStmt) {
          switch (stmt.runtimeType) {
            case ContinueStmt:
              // Don't actually execute a [ContinueStmt] as there is no work to
              // do
              continue;
            case BreakStmt:
              // Don't actually execute a [BreakStmt] as there is nothing to do
              return BreakSentinel();
            case ReturnStmt:
              final ReturnStmt returnStmt = stmt as ReturnStmt;
              if (returnStmt.returnValue == null) {
                return ReturnValue.nothing;
              }
              return ReturnValue(await _expr(returnStmt.returnValue!));
            // TODO handle continue statement
          }
        }
        final BlockExit? exit = await _stmt(stmt);
        if (exit != null) {
          return exit;
        }
      }
    } finally {
      ctx.popEnvironment();
    }
    return null;
  }

  Future<T> _resolveIdentifier<T extends Val>(
    IdentifierRef identifier,
    Context ctx,
  ) async {
    final T val = ctx.getVal<T>(identifier.name);
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
        final StructureDecl? structDecl = _structureBindings[ref.name];
        if (structDecl != null) {
          return StructureValType(ref.name);
        }
        throw UnimplementedError('Unknown TypeRef $ref');
    }
  }

  Future<T> _binaryExpr<T extends Val>(BinaryExpr expr) async {
    final Val leftVal = await _expr(expr.left);
    final Val rightVal = await _expr(expr.right);
    // TODO lift check to compiler
    if (leftVal.type != rightVal.type) {
      throwRuntimeError(
        'The left ($leftVal) and right hand sides ($rightVal) of '
        'a ${expr.operatorToken} expression do not match!',
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
        throwRuntimeError(
          '"+" operator not implemented for types ${leftVal.runtimeType} and '
          '${rightVal.runtimeType}',
        );
      case TokenType.minus:
        if (leftVal is NumVal && rightVal is NumVal) {
          return NumVal(leftVal.val - rightVal.val) as T;
        }
        throwRuntimeError(
          '"${expr.operatorToken}" operator not implemented for types '
          '${leftVal.runtimeType} and ${rightVal.runtimeType}',
        );
      case TokenType.multiply:
        if (leftVal is NumVal && rightVal is NumVal) {
          return NumVal(leftVal.val * rightVal.val) as T;
        }
        throwRuntimeError(
          '"${expr.operatorToken}" operator not implemented for types '
          '${leftVal.runtimeType} and ${rightVal.runtimeType}',
        );
      case TokenType.divide:
        if (leftVal is NumVal && rightVal is NumVal) {
          // TODO divide by zero?
          return NumVal(leftVal.val / rightVal.val) as T;
        }
        throwRuntimeError(
          '"${expr.operatorToken}" operator not implemented for types '
          '${leftVal.runtimeType} and ${rightVal.runtimeType}',
        );
      case TokenType.modulo:
        if (leftVal is NumVal && rightVal is NumVal) {
          return NumVal(leftVal.val % rightVal.val) as T;
        }
        throwRuntimeError(
          '"${expr.operatorToken}" operator not implemented for types '
          '${leftVal.runtimeType} and ${rightVal.runtimeType}',
        );
      case TokenType.equals:
        return BoolVal(leftVal.equalsTo(rightVal)) as T;
      case TokenType.notEquals:
        return BoolVal(!leftVal.equalsTo(rightVal)) as T;
      case TokenType.greaterThan:
        if (leftVal is! NumVal) {
          // TODO compiler error
          throwRuntimeError('> operator can only be used on numbers');
        }
        // safe cast because of the type check at the start of this function
        return BoolVal(leftVal.val > (rightVal as NumVal).val) as T;
      case TokenType.greaterOrEqual:
        if (leftVal is! NumVal) {
          // TODO compiler error
          throwRuntimeError('>= operator can only be used on numbers');
        }
        // safe cast because of the type check at the start of this function
        return BoolVal(leftVal.val >= (rightVal as NumVal).val) as T;
      case TokenType.lessThan:
        if (leftVal is! NumVal) {
          // TODO compiler error
          throwRuntimeError('< operator can only be used on numbers');
        }
        // safe cast because of the type check at the start of this function
        return BoolVal(leftVal.val < (rightVal as NumVal).val) as T;
      case TokenType.lessOrEqual:
        if (leftVal is! NumVal) {
          // TODO compiler error
          throwRuntimeError('<= operator can only be used on numbers');
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

  Future<StructureVal> _structureLiteral(StructureLiteral expr) async {
    final Map<String, Val> fields = <String, Val>{};
    for (final MapEntry<String, Expr> entry in expr.fields.entries) {
      final String name = entry.key;
      if (fields.containsKey(name)) {
        throwRuntimeError(
          'Duplicate field name $name found while interpreting struct literal '
          '$expr',
        );
      }
      final Val val = await _expr(entry.value);
      fields[name] = val;
    }
    return StructureVal(expr.name, fields);
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

  Future<T> _fieldAccessExpr<T extends Val>(FieldAccessExpr expr) async {
    final StructureVal currentVal = await _expr<StructureVal>(expr.parent);
    final Val? fieldVal = currentVal.fields[expr.fieldName.name];
    if (fieldVal == null) {
      throwRuntimeError(
        'Failed accessing "${expr.fieldName.name}" from $currentVal with '
        'fields ${currentVal.fields.keys}',
      );
    }
    if (fieldVal is! T) {
      throwRuntimeError(
        'Expected field ${expr.fieldName} to be of type $T, but it was of '
        'type ${fieldVal.runtimeType}',
      );
    }
    return fieldVal;

    //for (int i = 1; i < expr.identifierChain.length; i += 1) {
    //  final IdentifierRef currentIdentifier = expr.identifierChain[i];
    //  // TODO support methods
    //  final Val? fieldVal =
    //      (currentVal as StructureVal).fields[currentIdentifier.name];
    //}
  }
}

/// Interface for [ReturnValue], [BreakSentinel] and [ContinueSentinel].
abstract class BlockExit {
  const BlockExit();
}

class BreakSentinel extends BlockExit {
  factory BreakSentinel() => instance;
  const BreakSentinel._();

  static const BreakSentinel instance = BreakSentinel._();
}

class ReturnValue extends BlockExit {
  const ReturnValue(this.val);

  final Val val;

  static const ReturnValue nothing = ReturnValue(NothingVal.instance);
}

// TODO accept token
Never throwRuntimeError(String message) => throw RuntimeError(message);

class RuntimeError implements Exception {
  const RuntimeError(this.message);

  final String message;

  @override
  String toString() => message;
}
