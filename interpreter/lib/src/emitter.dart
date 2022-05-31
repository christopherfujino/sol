/// The interface for an [Scanner], [Parser], and [Interpreter] to communicate
/// with a frontend.

abstract class EmitMessage {
  const EmitMessage();

  @override
  String toString();
}

class InterpreterMessage extends EmitMessage {
  const InterpreterMessage(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef Emitter = Future<Exception?> Function(EmitMessage msg)?;
