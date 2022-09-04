import 'dart:io' as io;

import 'package:sol/src/parser.dart';
import 'package:sol/src/scanner.dart';
import 'package:sol/src/source_code.dart';
import 'package:test/test.dart';

import 'common.dart';

Future<void> main() async {
  for (final io.File buildFile in await sourceFiles) {
    late final SourceCode sourceCode;

    setUpAll(() async {
      sourceCode = SourceCode(await buildFile.readAsString());
    });

    test('can scan and parse ${buildFile.path}', () async {
      final List<Token> tokenList =
          await Scanner.fromSourceCode(sourceCode).scan();
      await Parser(tokenList: tokenList, entrySourceCode: sourceCode).parse();
    });
  }
}
