import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'emitter.dart';
import 'interpreter/interpreter.dart';
import 'parser/parser.dart';
import 'scanner.dart';

class RunCommand extends Command<void> {
  RunCommand() {
    argParser.addFlag('debug');
  }

  @override
  String name = 'run';

  @override
  String description = 'Interpret a Sol source file.';

  ArgResults get _argResults => argResults!;

  @override
  Future<void> run() async {
    final bool debug = argResults!['debug']! as bool;

    Emitter? emitter;
    if (debug) {
      emitter = (EmitMessage msg) async {
        io.stderr.writeln(msg.toString());
        return null;
      };
    }

    if (_argResults.rest.length != 1) {
      throw Exception('Pass one argument as a source file.');
    }
    final String sourceName = _argResults.rest.first;
    final io.Directory workingDir = io.Directory.current.absolute;
    final io.File sourceFile = io.File(sourceName).absolute;

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
      workingDir: workingDir,
      emitter: emitter,
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
