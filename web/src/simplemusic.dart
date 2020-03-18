import 'package:meta/meta.dart';

import 'patterns.dart';

class Beat {
  final RhythmUnit metre;
  final double bpm;
  final List<Layer> patterns;

  const Beat({@required this.metre, this.bpm = 120, this.patterns});
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
      (sampleRate * beats / (bpm / 60)).round();

  int inSamples(double bpm, int sampleRate) =>
      beatsInSamples(beats, bpm, sampleRate);
}
