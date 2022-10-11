import 'dart:io' as io; // TODO get rid

import 'package:flutter/material.dart';
import 'package:sol/sol.dart' as sol;
import 'package:code_text_field/code_text_field.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
      ),
      home: const IDE(title: 'Sol IDE'),
    );
  }
}

class IDE extends StatefulWidget {
  const IDE({super.key, required this.title});

  final String title;

  @override
  State<IDE> createState() => _IDEState();
}

class _IDEState extends State<IDE> {
  final CodeController _controller = CodeController(
    text: '''
function main() {
  print("Hello, world!");
}
''',
    webSpaceFix: false,
  );

  String output = '';
  bool isInterpreting = false;

  Future<void> interpret() async {
    if (isInterpreting) {
      return;
    }
    setState(() {
      isInterpreting = true;
      output = '';
    });
    final sol.SourceCode sourceCode = sol.SourceCode(_controller.text);
    final List<sol.Token> tokenList =
        await sol.Scanner.fromSourceCode(sourceCode).scan();
    final sol.ParseTree parseTree;
    try {
      parseTree = await sol.Parser(
        tokenList: tokenList,
        entrySourceCode: sourceCode,
      ).parse();
    } on sol.ParseError catch (err) {
      debugPrint(err.toString());
      //io.stderr.writeln(err);
      setState(() => isInterpreting = false);
      return;
    }
    try {
      await sol.Interpreter(
          parseTree: parseTree,
          workingDir: io.Directory('.'), // TODO get rid of
          emitter: null,
          stdoutOverride: (String msg) {
            setState(() => output += '$msg\n');
          }).interpret();
    } on sol.RuntimeError catch (err) {
      debugPrint(err.toString());
      //io.stderr.writeln(err);
      setState(() => isInterpreting = false);
      return;
    }

    setState(() => isInterpreting = false);
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
                child: Row(children: <Widget>[
              Flexible(
                  child: CodeField(
                controller: _controller,
                textStyle: GoogleFonts.robotoMono(),
              )),
              Flexible(child: Text(output, style: GoogleFonts.robotoMono())),
            ])),
            ElevatedButton(
              onPressed: isInterpreting ? null : interpret,
              child: const Text('Run'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}
