import 'package:meta/meta.dart';

import 'beat_fraction.dart';

class CommonPitch {
  static const _keyNames = [
    'C',
    null,
    'D',
    null,
    'E',
    'F',
    null,
    'G',
    null,
    'A',
    null,
    'B'
  ];

  final int pitch;
  final int mod; // pitch % 12
  String get description => '$name$octave';
  bool get whiteKey => _keyNames[mod] != null;
  String get name => _keyNames[mod] ?? _keyNames[mod - 1] + '#';
  int get octave => (pitch / 12).floor();

  CommonPitch(this.pitch) : mod = pitch % 12;
}

class NoteInfo {
  final int coarsePitch;
  final double velocity;

  const NoteInfo(this.coarsePitch, this.velocity);
}

class Note {
  int pitch;

  BeatFraction start;
  BeatFraction length;

  BeatFraction get end => start + length;

  static int octave(int tone, int octave) => tone + octave * 12;

  Note(
      {@required this.pitch,
      this.start = const BeatFraction(0, 4),
      this.length = const BeatFraction(1, 16)});

  bool matches(Note other) =>
      pitch == other.pitch && start == other.start && length == other.length;

  NoteInfo createInfo() => NoteInfo(pitch, 1);

  static const int C = 0;
  static const int D = 2;
  static const int E = 4;
  static const int F = 5;
  static const int G = 7;
  static const int A = 9;
  static const int B = 11;
}
