import 'package:sol/sol.dart' as sol;

class IDEInterpreter extends sol.Interpreter {
  IDEInterpreter();

  @override
  void stdoutPrint(String msg) {}

  @override
  void stderrPrint(String msg) {}
}
