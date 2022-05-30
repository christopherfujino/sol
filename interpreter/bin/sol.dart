import 'package:args/command_runner.dart';

import 'package:sol/sol.dart';

Future<void> main(List<String> args) async {
  final CommandRunner<void> runner = CommandRunner<void>(
    'sol',
    'A Simple, Obvious Language.',
    usageLineLength: 80,
  );

  runner.addCommand(RunCommand());
  await runner.run(args);
}
