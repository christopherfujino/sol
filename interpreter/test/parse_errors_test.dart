import 'dart:io' as io;

import 'package:sol/src/parser/parser.dart';
import 'package:sol/src/scanner.dart';
import 'package:test/test.dart';

Future<void> main() async {
  Future<Parser> createParser(String sourcePath) async {
    final SourceCode sourceCode = SourceCode(
      await io.File(sourcePath).readAsString(),
    );
    final List<Token> tokenList =
        await Scanner.fromSourceCode(sourceCode).scan();
    return Parser(
      tokenList: tokenList,
      entrySourceCode: sourceCode,
    );
  }

  test('parse errors include reference to token', () async {
    try {
      await (await createParser('test/error_files/parse_error.sol')).parse();
    } on ParseError catch (err) {
      expect(err.message.trim(), '''
function main(() {}
             ^

Parse error: [1, 14] openParen - Expected a identifier, got a openParen
Previous token: [1, 13] openParen''');
    }
  });
}
