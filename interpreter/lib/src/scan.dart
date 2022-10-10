import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'scanner.dart';

class ScanCommand extends Command<void>{
  @override
  final String name = 'scan';

  @override
  final String description = 'Print out token list.';

  ArgResults get _argResults => argResults!;

  @override
  Future<void> run() async {
    if (_argResults.rest.length != 1) {
      throw Exception('Pass one argument as a source file.');
    }
    final String sourceName = _argResults.rest.first;
    final io.File sourceFile = io.File(sourceName).absolute;

    if (!sourceFile.existsSync()) {
      throw Exception(
        'Could not find file $sourceName',
      );
    }
    final SourceCode source = SourceCode(await sourceFile.readAsString());

    final List<Token> tokenList = await Scanner.fromSourceCode(source).scan();

    tokenList.forEach(io.stdout.writeln);
  }
}
