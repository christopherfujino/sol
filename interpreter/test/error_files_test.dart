import 'dart:io' as io;

import 'package:sol/src/interpreter.dart';
import 'package:sol/src/parser.dart';
import 'package:sol/src/scanner.dart';
import 'package:sol/src/source_code.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  late final io.Directory tempDir;

  setUp(() async {
    tempDir = await io.Directory.systemTemp.createTemp('interpreter_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<void> interpret(String path) async {
    final SourceCode sourceCode =
        SourceCode(await io.File(path).readAsString());
    final List<Token> tokenList =
        await Scanner.fromSourceCode(sourceCode).scan();
    final ParseTree tree =
        await Parser(tokenList: tokenList, entrySourceCode: sourceCode).parse();

    await TestInterpreter(
      parseTree: tree,
      ctx: Context(workingDir: tempDir),
    ).interpret();
  }

  test('RuntimeError if a () -> Nothing functions returns something', () async {
    await expectLater(
      () => interpret('test/error_files/no_return_value_specified.sol'),
      throwsA(
        isA<RuntimeError>().having(
          (RuntimeError err) => err.message,
          'correct message',
          contains(
            'Function func_that_returns should return ValType: Nothing but it '
            'actually returned ValType: Number',
          ),
        ),
      ),
    );
  });
}
