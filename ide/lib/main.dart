import 'dart:io' as io; // TODO get rid

import 'package:flutter/material.dart';
import 'package:sol/sol.dart' as sol;
import 'package:code_text_field/code_text_field.dart';
import 'package:google_fonts/google_fonts.dart';

import 'interpreter.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

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

  final List<String> outputLines = <String>[];
  bool isInterpreting = false;

  Future<void> interpret() async {
    if (isInterpreting) {
      return;
    }
    setState(() {
      isInterpreting = true;
      outputLines.clear();
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
      setState(() {
        outputLines.add(err.toString());
        isInterpreting = false;
      });
      return;
    }
    try {
      await IDEInterpreter(
        parseTree: parseTree,
        emitter: null,
        stdoutCb: (String msg) {
          setState(() => outputLines.add(msg));
        },
        stderrCb: (String msg) {
          setState(() => outputLines.add('[error] $msg'));
        },
      ).interpret();
    } on sol.RuntimeError catch (err) {
      setState(() {
        outputLines.add(err.toString());
        isInterpreting = false;
      });
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
              Flexible(
                child: ListView(
                  children: outputLines
                      .map<Text>((String line) =>
                          Text(line, style: GoogleFonts.robotoMono()))
                      .toList(),
                ),
              ),
              //Flexible(child: Text(output, style: GoogleFonts.robotoMono())),
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
