import 'dart:io' as io;

import 'package:sol/src/interpreter.dart';

final Future<List<io.File>> sourceFiles = (() async {
  if (io.Platform.isWindows) {
    throw UnimplementedError('hard-coded posix paths');
  }
  final List<io.File> sourceFiles = <io.File>[];
  // package:test requires working directory to be project root
  await io.Directory('test/source_files')
      .absolute
      .list()
      .forEach((io.FileSystemEntity entity) {
    if (entity is io.File) {
      sourceFiles.add(entity);
    }
  });

  return sourceFiles;
})();

class TestInterpreter extends Interpreter {
  TestInterpreter({
    required super.parseTree,
    required super.ctx,
  });

  final StringBuffer stdoutBuffer = StringBuffer();
  @override
  void stdoutPrint(String msg) {
    stdoutBuffer.writeln(msg);
  }

  final StringBuffer stderrBuffer = StringBuffer();
  @override
  void stderrPrint(String msg) {
    stderrBuffer.writeln(msg);
  }
}
