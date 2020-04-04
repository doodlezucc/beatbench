import 'package:meta/meta.dart';

import 'beat_fraction.dart';

class Pitched {
  int coarsePitch;

  Pitched(this.coarsePitch);
}

class Note extends Pitched {
  double velocity;
  BeatFraction start;
  BeatFraction length;

  BeatFraction get end => start + length;

  static int getPitch(int tone, int octave) => tone + octave * 12;

  Note(
      {@required int tone,
      int octave = 4,
      this.start = const BeatFraction(0, 4),
      this.length = const BeatFraction(1, 16)})
      : super(getPitch(tone, octave));
  Note.exact(int pitch) : super(pitch);

  Note clone({int pitch, BeatFraction start, BeatFraction length}) {
    return Note(
        tone: pitch ?? coarsePitch,
        octave: 0,
        start: start ?? this.start,
        length: length ?? this.length);
  }

  static const int C = 0;
  static const int D = 2;
  static const int E = 4;
  static const int F = 5;
  static const int G = 7;
  static const int A = 9;
  static const int B = 11;
}
