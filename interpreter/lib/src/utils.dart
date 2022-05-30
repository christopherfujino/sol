import 'dart:io' as io;

/// Asynchronously run a [Process] with inherited STDIO.
Future<void> stream(
  List<String> command, {
  Map<String, String>? env,
  String? workingDirectory,
}) async {
  final String message = <String>[
    'Spawning subprocess "${command.join(' ')}"',
    if (workingDirectory != null)
      ' in "$workingDirectory"',
    if (env != null)
      ' with env $env',
    '...',
  ].join();
  print(message); // ignore: avoid_print
  final io.Process process = await io.Process.start(
    command.first,
    command.skip(1).toList(),
    mode: io.ProcessStartMode.inheritStdio,
    environment: env,
    workingDirectory: workingDirectory,
  );
  final int exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw Exception(
      'Command "${command.join(' ')}" failed with code $exitCode',
    );
  }
}

/// Root //flutter_nvim [io.Directory].
///
/// This assumes the entrypoint is a dart file in //flutter_nvim/tools.
io.Directory get repoRoot {
  final io.File script = io.File.fromUri(io.Platform.script);
  return script
      // flutter_nvim/tools/
      .parent
      // flutter_nvim/
      .parent;
}

/// Synchronously verify that a path exists on disk.
///
/// Will throw an [Exception] if the path does not exist.
void checkPath(String path) {
  final io.FileSystemEntityType type = io.FileSystemEntity.typeSync(path);
  final io.FileSystemEntity entity;
  if (type == io.FileSystemEntityType.file) {
    entity = io.File(path);
  } else if (type == io.FileSystemEntityType.directory) {
    entity = io.Directory(path);
  } else {
    throw Exception('Unknown FileSystemEntityType $type');
  }
  if (!entity.existsSync()) {
    throw Exception('The path $path does not exist on disk!');
  }
}

String joinPath(List<String> parts) {
  return parts.join(io.Platform.pathSeparator);
}

/// Run a [List] of commands in sequence.
Future<void> sequence(List<String> commands) async {
  for (final String command in commands) {
    await stream(command.split(' '));
  }
}

/// Run a [List] of commands in parallel.
Future<void> parallel(List<String> commands) async {
  final Iterable<Future<void>> futures = commands.map((String command) {
    return stream(command.split(' '));
  });
  await Future.wait(futures);
}
