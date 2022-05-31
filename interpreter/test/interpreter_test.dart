import 'dart:io' as io;

import 'package:sol/src/interpreter.dart';
import 'package:sol/src/parser.dart';
import 'package:sol/src/scanner.dart';
import 'package:sol/src/source_code.dart';
import 'package:test/test.dart';

import 'common.dart';

Future<void> main() async {
  late final io.Directory tempDir;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('interpreter_test');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('can scan, parse and interpret git_submodule_init.sol', () async {
    await io.Process.run(
      'git',
      <String>['init'],
      workingDirectory: tempDir.absolute.path,
    );
    final SourceCode sourceCode = SourceCode(
        await io.File('test/source_files/git_submodule_init.sol')
            .readAsString());
    final List<Token> tokenList =
        await Scanner.fromSourceCode(sourceCode).scan();
    final ParseTree tree =
        await Parser(tokenList: tokenList, entrySourceCode: sourceCode).parse();

    await TestInterpreter(
      parseTree: tree,
      ctx: Context(workingDir: tempDir),
    ).interpret();
  });

  test('comments are skipped', () async {
    final SourceCode sourceCode = SourceCode(
        await io.File('test/source_files/comments.sol').readAsString());
    final List<Token> tokenList =
        await Scanner.fromSourceCode(sourceCode).scan();
    final ParseTree tree =
        await Parser(tokenList: tokenList, entrySourceCode: sourceCode).parse();
    final TestInterpreter interpreter = TestInterpreter(
      parseTree: tree,
      ctx: Context(workingDir: tempDir),
    );
    await interpreter.interpret();
    expect(interpreter.stdoutBuffer.toString().trim(), isNot(contains('hello world')));
  });

  test('print prints', () async {
    final SourceCode sourceCode = SourceCode(
        await io.File('test/source_files/print_test.sol').readAsString());
    final List<Token> tokenList =
        await Scanner.fromSourceCode(sourceCode).scan();
    final ParseTree tree =
        await Parser(tokenList: tokenList, entrySourceCode: sourceCode).parse();
    final TestInterpreter interpreter = TestInterpreter(
      parseTree: tree,
      ctx: Context(workingDir: tempDir),
    );
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().split('\n'),
      contains('Hello, world!'),
    );
  });

  test('function arguments and return values are passed', () async {
    final SourceCode sourceCode = SourceCode(
        await io.File('test/source_files/function_arguments.sol').readAsString());
    final List<Token> tokenList =
        await Scanner.fromSourceCode(sourceCode).scan();
    final ParseTree tree =
        await Parser(tokenList: tokenList, entrySourceCode: sourceCode).parse();
    final TestInterpreter interpreter = TestInterpreter(
      parseTree: tree,
      ctx: Context(workingDir: tempDir),
    );
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().split('\n'),
      contains('3'),
    );
  });

  test('String implements + operator', () async {
    final SourceCode sourceCode = SourceCode(
        await io.File('test/source_files/string_concatenation.sol').readAsString());
    final List<Token> tokenList =
        await Scanner.fromSourceCode(sourceCode).scan();
    final ParseTree tree =
        await Parser(tokenList: tokenList, entrySourceCode: sourceCode).parse();
    final TestInterpreter interpreter = TestInterpreter(
      parseTree: tree,
      ctx: Context(workingDir: tempDir),
    );
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().split('\n'),
      contains('Hello, world!'),
    );
  });

  test('Type coercion works', () async {
    final SourceCode sourceCode = SourceCode(
        await io.File('test/source_files/type_coercion.sol').readAsString());
    final List<Token> tokenList =
        await Scanner.fromSourceCode(sourceCode).scan();
    final ParseTree tree =
        await Parser(tokenList: tokenList, entrySourceCode: sourceCode).parse();
    final TestInterpreter interpreter = TestInterpreter(
      parseTree: tree,
      ctx: Context(workingDir: tempDir),
    );
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().split('\n'),
      contains('42'),
    );
  });
}
