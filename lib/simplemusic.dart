import 'package:beatbench/patterns.dart';
import 'package:flutter/material.dart';

class Beat extends StatefulWidget {
  final RhythmUnit metre;
  final double bpm;
  final List<Layer> patterns;

  const Beat({Key key, this.metre, this.bpm = 120, this.patterns})
      : super(key: key);

  @override
  _BeatState createState() => _BeatState();
}

class _BeatState extends State<Beat> {
  @override
  Widget build(BuildContext context) {
    return Column(children: widget.patterns);
  }
}

class RhythmUnit {
  final int numerator;
  final int denominator;
  final double beats;

  const RhythmUnit(this.numerator, this.denominator)
      : beats = 4 * numerator / denominator;

  bool equals(RhythmUnit other) =>
      numerator == other.numerator && denominator == other.denominator;

  int compare(RhythmUnit other) =>
      equals(other) ? 0 : (beats > other.beats ? 1 : -1);

  static int beatsInSamples(double beats, double bpm, int sampleRate) =>
      (beats * (bpm / 60) * sampleRate).round();

  int inSamples(double bpm, int sampleRate) =>
      beatsInSamples(beats, bpm, sampleRate);
}
