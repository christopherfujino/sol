import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'parser/parser.dart';
import 'scanner.dart';
import 'source_code.dart';

class PrintASTCommand extends Command<void> {
  @override
  String name = 'print-ast';

  @override
  String description =
      'Print the abstract syntax tree (AST) of a Sol application';

  @override
  Future<void> run() async {
    final ArgResults argResults = this.argResults!;

    if (argResults.rest.length != 1) {
      throw Exception('Pass one argument as a source file.');
    }
    final String sourceName = argResults.rest.first;
    final io.File sourceFile = io.File(sourceName).absolute;

    if (!sourceFile.existsSync()) {
      throw Exception(
        'Could not find file $sourceName',
      );
    }
    final SourceCode source = SourceCode(await sourceFile.readAsString());

    final List<Token> tokenList = await Scanner.fromSourceCode(source).scan();

    final ParseTree ast = await Parser(
      entrySourceCode: source,
      tokenList: tokenList,
    ).parse();

    io.stdout.writeln(ast.toString());
  }
}
