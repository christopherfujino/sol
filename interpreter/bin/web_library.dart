import 'package:js/js.dart';

@JS('compileSolProgram')
external set _compileSolProgram(void Function(String) f);

void main() {
  print('print from main');
  _compileSolProgram = allowInterop(_interpret);
}

void _interpret(String program) {
  print(program);
}
