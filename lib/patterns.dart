import 'package:beatbench/simplemusic.dart';
import 'package:flutter/material.dart';

class Pitched {
  int coarsePitch;

  Pitched(this.coarsePitch);
}

class Note extends Pitched {
  double velocity;
  RhythmUnit start;
  RhythmUnit length;

  static getPitch(int tone, int octave) => tone + octave * 12;

  Note(
      {@required int tone,
      int octave = 4,
      this.start,
      this.length = const RhythmUnit(1, 16)})
      : super(getPitch(tone, octave));
  Note.exact(int pitch) : super(pitch);

  static const int C = 0;
  static const int D = 2;
  static const int E = 4;
  static const int F = 5;
  static const int G = 7;
  static const int A = 9;
  static const int B = 11;
}

class InstrumentPattern {}

class PatternData {}

class Layer extends StatelessWidget {
  final bool active;
  final PatternData data;

  const Layer({Key key, @required this.data, this.active = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.amber,
      child: Column(
        children: <Widget>[
          Text("I'm a layer"),
          Column(
            children: <Widget>[],
          )
        ],
      ),
    );
  }
}
