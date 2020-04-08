import 'package:meta/meta.dart';

import 'beat_fraction.dart';

class Pitched {
  int coarsePitch;

  Pitched(this.coarsePitch);
}

class NoteInfo extends Pitched {
  double velocity;

  NoteInfo(int coarsePitch) : super(coarsePitch);
}

class Note {
  final NoteInfo info;
  int get coarsePitch => info.coarsePitch;

  BeatFraction start;
  BeatFraction length;

  BeatFraction get end => start + length;

  static int getPitch(int tone, int octave) => tone + octave * 12;

  Note(
      {@required int pitch,
      this.start = const BeatFraction(0, 4),
      this.length = const BeatFraction(1, 16)})
      : info = NoteInfo(pitch);
  Note._withInfo(this.info, this.start, this.length);

  Note cloneKeepInfo({int pitch, BeatFraction start, BeatFraction length}) {
    return Note._withInfo(info, start ?? this.start, length ?? this.length);
  }

  static const int C = 0;
  static const int D = 2;
  static const int E = 4;
  static const int F = 5;
  static const int G = 7;
  static const int A = 9;
  static const int B = 11;
}
