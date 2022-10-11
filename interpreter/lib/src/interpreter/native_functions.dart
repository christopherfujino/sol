import 'dart:convert' show LineSplitter, utf8;
import 'dart:io' as io;
import '../parser/parser.dart'
    show FuncDecl, ListTypeRef, NameTypePair, Stmt, TypeRef;
import 'context.dart';
import 'main.dart'
    show throwRuntimeError, BlockExit, CliInterpreter, Interpreter, ReturnValue;
import 'vals.dart';

/// An external [FunctionDecl].
///
/// TODO: These should not extend the parser interface [FuncDecl], but should
/// instead implement an IR interface.
abstract class ExtFuncDecl<T extends Interpreter> extends FuncDecl {
  const ExtFuncDecl({
    required super.name,
    required super.params,
  }) : super(statements: const <Stmt>[]);

  Future<BlockExit> interpret({
    required T interpreter,
    required Context ctx,
  });
}

class PrintFuncDecl extends ExtFuncDecl<Interpreter> {
  const PrintFuncDecl()
      : super(
          name: 'print',
          params: const <NameTypePair>[NameTypePair('msg', TypeRef.string)],
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

class CliRunFuncDecl extends ExtFuncDecl<CliInterpreter> {
  CliRunFuncDecl()
      : super(
          name: 'run',
          params: <NameTypePair>[
            NameTypePair('command', ListTypeRef(TypeRef.string))
          ],
        );

  @override
  Future<BlockExit> interpret({
    required CliInterpreter interpreter,
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

    interpreter.stdoutPrint('Running command "${command.join(' ')}"...');
    final String executable = command.first;
    final List<String> rest = command.sublist(1);
    final io.Process process = await io.Process.start(
      executable,
      rest,
      workingDirectory: interpreter.workingDir.absolute.path,
    );
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
      interpreter.stdoutPrint(line);
    });
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
      interpreter.stderrPrint(line);
    });

    final int exitCode = await process.exitCode;
    if (exitCode != 0) {
      throwRuntimeError('"${command.join(' ')}" exited with code $exitCode');
    }
    // TODO should this be a number?
    return ReturnValue.nothing;
  }
}
