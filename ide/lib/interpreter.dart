import 'package:sol/sol.dart' as sol;

const Map<String, sol.ExtFuncDecl<sol.Interpreter>> _externalFunctions =
    <String, sol.ExtFuncDecl<sol.Interpreter>>{
  'print': sol.PrintFuncDecl(),
};

class IDEInterpreter extends sol.Interpreter {
  IDEInterpreter({
    required super.parseTree,
    required this.stdoutCb,
    required this.stderrCb,
    super.emitter,
  }) : super(externalFunctions: _externalFunctions);

  final void Function(String) stdoutCb;
  final void Function(String) stderrCb;

  @override
  void stdoutPrint(String msg) => stdoutCb(msg);

  @override
  void stderrPrint(String msg) => stderrCb(msg);
}
