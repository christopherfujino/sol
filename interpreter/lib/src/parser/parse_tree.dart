import 'declarations.dart';
import 'visitors.dart';

/// A graph of [Decl]s and [Expr]s.
class ParseTree {
  const ParseTree(this.declarations);

  final List<Decl> declarations;

  @override
  String toString() {
    const ParseTreePrinter printer = ParseTreePrinter();
    return printer.printTree(this);
  }

  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitParseTree(this);
}
