import 'dart:io' as io; // TODO get rid

import 'package:flutter/material.dart';
import 'package:sol/sol.dart' as sol;

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
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController(text: '''
function main() {
  print("Hello, world!");
}
''');
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
      io.stderr.writeln(err);
      setState(() => isInterpreting = false);
      return;
    }
    try {
      await sol.Interpreter(
        parseTree: parseTree,
        workingDir: io.Directory('.'), // TODO get rid of
        emitter: (sol.EmitMessage msg) async {
          return null;
        },
        stdoutOverride: (String msg) {
          setState(() => output += '$msg\n');
        }
      ).interpret();
    } on sol.RuntimeError catch (err) {
      io.stderr.writeln(err);
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
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            child: Row(children: <Widget>[
              Flexible(
                  child: TextFormField(
                controller: _controller,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                maxLines: 40,
                minLines: 1,
                style: const TextStyle(fontFamily: 'monospace'),
              )),
              Flexible(child: Text(output)),
            ]),
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
