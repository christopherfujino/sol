import 'dart:io' as io;

import 'package:sol/src/scanner.dart';
import 'package:test/test.dart';

import 'common.dart';

Future<void> main() async {
  for (final io.File buildFile in await sourceFiles) {
    late final SourceCode sourceCode;

    setUpAll(() async {
      sourceCode = SourceCode(await buildFile.readAsString());
    });

    test('can scan ${buildFile.path}', () async {
      await Scanner.fromSourceCode(sourceCode).scan();
    });
  }
}
