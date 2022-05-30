import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'interpreter.dart';
import 'parser.dart';
import 'scanner.dart';
import 'source_code.dart';

const String kSourceFileName = 'micro.build';

class RunCommand extends Command<void> {
  @override
  String name = 'run';

  @override
  String description = 'Interpret a Sol source file.';

  ArgResults get _argResults => argResults!;

  @override
  Future<void> run() async {
    if (_argResults.rest.length != 1) {
      throw Exception('Pass one argument as a source file.');
    }
    final String sourceName = _argResults.rest.first;
    final io.Directory workingDir = io.Directory.current.absolute;
    final io.File sourceFile = io.File(sourceName).absolute;
    final Context ctx = Context(workingDir: workingDir);

    if (!sourceFile.existsSync()) {
      throw RuntimeError(
        'Could not find file $sourceName',
      );
    }
    final SourceCode source = SourceCode(await sourceFile.readAsString());

    final List<Token> tokenList = await Scanner.fromSourceCode(source).scan();

    final ParseTree config = await _parse(source, tokenList);

    await Interpreter(
      parseTree: config,
      ctx: ctx,
    ).interpret();
  }
}

Future<ParseTree> _parse(SourceCode source, List<Token> tokenList) async {
  try {
    final ParseTree config = await Parser(
      entrySourceCode: source,
      tokenList: tokenList,
    ).parse();
    return config;
  } on ParseError catch (err, trace) {
    // catch so we can better format error message
    io.stderr.writeln('ParseError!\n');
    io.stderr.writeln(trace);
    io.stderr.writeln(err.message);
    io.exit(1);
  }
}
