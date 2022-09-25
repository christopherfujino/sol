import 'dart:io' as io;

import 'package:sol/src/parser/parser.dart';
import 'package:sol/src/scanner.dart';
import 'package:sol/src/source_code.dart';
import 'package:test/test.dart';

import 'common.dart';

Future<void> main() async {
  late final io.Directory tempDir;

  Future<TestInterpreter> createInterpreter(String path) async {
    final SourceCode sourceCode =
        SourceCode(await io.File(path).readAsString());
    final List<Token> tokenList =
        await Scanner.fromSourceCode(sourceCode).scan();
    final ParseTree tree =
        await Parser(tokenList: tokenList, entrySourceCode: sourceCode).parse();
    return TestInterpreter(
      parseTree: tree,
      workingDir: tempDir,
    );
  }

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

    await (await createInterpreter('test/source_files/git_submodule_init.sol'))
        .interpret();
  });

  test('comments are skipped', () async {
    final TestInterpreter interpreter =
        await createInterpreter('test/source_files/comments.sol');
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().trim(),
      isNot(contains('hello world')),
    );
  });

  test('print prints', () async {
    final TestInterpreter interpreter =
        await createInterpreter('test/source_files/print_test.sol');
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().split('\n'),
      contains('Hello, world!'),
    );
  });

  test('function arguments and return values are passed', () async {
    final TestInterpreter interpreter =
        await createInterpreter('test/source_files/function_arguments.sol');
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().split('\n'),
      contains('3'),
    );
  });

  test('String implements + operator', () async {
    final TestInterpreter interpreter =
        await createInterpreter('test/source_files/string_concatenation.sol');
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().split('\n'),
      contains('Hello, world!'),
    );
  });

  test('Type coercion works', () async {
    final TestInterpreter interpreter =
        await createInterpreter('test/source_files/type_coercion.sol');
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().split('\n'),
      contains('42'),
    );
  });

  test('can reassign variables', () async {
    final TestInterpreter interpreter =
        await createInterpreter('test/source_files/reassignment.sol');
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().split('\n'),
      contains('1'),
    );
  });

  test('control flow works', () async {
    final TestInterpreter interpreter =
        await createInterpreter('test/source_files/control_flow.sol');
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().trim().split('\n'),
      orderedEquals(<String>['reachable 1', 'reachable 2', 'reachable 3']),
    );
  });

  test('comparison works', () async {
    final TestInterpreter interpreter =
        await createInterpreter('test/source_files/comparison.sol');
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().trim().split('\n'),
      orderedEquals(<String>[
        'reachable 1',
        'reachable 2',
        'reachable 3',
        'reachable 4',
        'reachable 5',
        'reachable 6',
        'reachable 7',
        'reachable 8',
      ]),
    );
  });

  test('early return does not execute dead code', () async {
    final TestInterpreter interpreter =
        await createInterpreter('test/source_files/early_return.sol');
    await interpreter.interpret();

    expect(
      interpreter.stdoutBuffer.toString().trim().split('\n'),
      // apparently `''.split('\n') == ['']`
      orderedEquals(<String>['']),
    );
  });

  test('while loop works', () async {
    final TestInterpreter interpreter =
        await createInterpreter('test/source_files/while_loop.sol');
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().trim().split('\n'),
      orderedEquals(<String>[
        '0',
        '1',
        '2',
      ]),
    );
  });

  test('parentheses force precedence', () async {
    final TestInterpreter interpreter =
        await createInterpreter('test/source_files/parens.sol');
    await interpreter.interpret();
    expect(
      interpreter.stdoutBuffer.toString().trim().split('\n'),
      orderedEquals(<String>[
        '2',
        '0',
      ]),
    );
  });

  test('list literals work', () async {
    final TestInterpreter interpreter =
        await createInterpreter('test/source_files/lists.sol');
    try {
      await interpreter.interpret();
    } on Object catch (err, stacktrace) {
      print('hit interpreter error');
      print(interpreter.parseTree);
      print(err);
      print(stacktrace);
      fail('TODO: remove try-catch');
    }

    expect(
      interpreter.stdoutBuffer.toString().trim().split('\n'),
      contains('foo bar'),
    );
  });
}
