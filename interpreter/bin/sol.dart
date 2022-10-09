import 'package:args/command_runner.dart';

import 'package:sol/sol.dart';

Future<void> main(List<String> args) async {
  final CommandRunner<void> runner = CommandRunner<void>(
    'sol',
    'Sol: A Simple, Obvious Language.',
    usageLineLength: 80,
  );

  runner.addCommand(RunCommand());
  runner.addCommand(ScanCommand());
  runner.addCommand(PrintASTCommand());
  await runner.run(args);
}
