import 'package:beatbench/patterns.dart';
import 'package:beatbench/simplemusic.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "BeatBench",
      theme: ThemeData(
        primarySwatch: Colors.brown,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("BeatBench"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Beat(
            bpm: 120,
            metre: RhythmUnit(4, 4),
            patterns: [Layer(data: PatternData())],
          ),
        ));
  }
}
