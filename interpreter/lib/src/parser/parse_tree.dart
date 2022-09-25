import 'declarations.dart';
import 'visitors.dart';

/// A graph of [Decl]s and [Expr]s.
class ParseTree {
  const ParseTree(this.declarations);

  final List<Decl> declarations;

  @override
  String toString() {
    const ParseTreePrinter printer = ParseTreePrinter();
    return printer.print(this);
    //final StringBuffer buffer = StringBuffer('ParseTree: \n');
    //for (final Decl decl in declarations) {
    //  for (final Stmt stmt in (decl as FuncDecl).statements) {
    //    buffer.writeln(stmt.toString());
    //  }
    //}
  }

  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitParseTree(this);
}
