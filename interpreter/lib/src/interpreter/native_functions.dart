import '../parser/parser.dart' show FuncDecl, IdentifierRef, ListTypeRef, Parameter, Stmt, TypeRef;
import 'context.dart';
import 'main.dart' show throwRuntimeError, BlockExit, Interpreter, ReturnValue;
import 'vals.dart';

/// An external [FunctionDecl].
///
/// TODO: These should not extend the parser interface [FuncDecl], but should
/// instead implement an IR interface.
abstract class ExtFuncDecl extends FuncDecl {
  const ExtFuncDecl({
    required super.name,
    required super.params,
  }) : super(statements: const <Stmt>[]);

  Future<BlockExit> interpret({
    required Interpreter interpreter,
    required Context ctx,
  });
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
  Future<BlockExit> interpret({
    required Interpreter interpreter,
    required Context ctx,
  }) async {
    final StringVal message = ctx.args['msg']! as StringVal;
    // Don't call toString, else we get quotes
    interpreter.stdoutPrint(
      message.val,
    );

    return ReturnValue.nothing;
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
  Future<BlockExit> interpret({
    required Interpreter interpreter,
    required Context ctx,
  }) async {
    if (!ctx.args.containsKey('command')) {
      throwRuntimeError(
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
      throwRuntimeError(
        'Function run() expected an arg of either String or List<String>, got '
        '${value.runtimeType}',
      );
    }

    final int exitCode = await interpreter.runProcess(
      command: command,
      workingDir: ctx.workingDir,
    );
    if (exitCode != 0) {
      throwRuntimeError('"${command.join(' ')}" exited with code $exitCode');
    }
    return ReturnValue.nothing;
  }
}
