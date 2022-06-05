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

/// A simple callback passed by a frontend to the backend for emitting messages.
///
/// A frontend can halt execution of the backend by (asynchronously) returning
/// an [Exception] from its [Emitter].
typedef Emitter = Future<Exception?> Function(EmitMessage msg)?;
