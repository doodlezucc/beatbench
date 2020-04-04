import 'dart:math';

import 'audio_assembler.dart';
import 'timeline.dart';

class Project {
  final AudioAssembler audioAssembler = AudioAssembler();
  final Timeline timeline = Timeline();
  double _bpm;
  double get bpm => _bpm;
  set bpm(double bpm) {
    _bpm = max(40, bpm);
    timeline.onNewTempo();
  }

  static Project _instance;
  static Project get instance => _instance;

  Project({double bpm = 150}) {
    _instance = this;
    this.bpm = bpm;
  }

  void play() {
    audioAssembler.run(timeline.box);
  }

  void pause() {
    audioAssembler.stopPlayback();
  }
}
