import 'package:js/js.dart';

@JS('compileSolProgram')
external set _compileSolProgram(void Function(String) f);

void main() {
  _compileSolProgram = allowInterop(_interpret);
}

void _interpret(String program) {
  // TODO do some work
}
