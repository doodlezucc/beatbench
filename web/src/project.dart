import 'audio_assembler.dart';
import 'timeline.dart';

class Project {
  final AudioAssembler audioAssembler = AudioAssembler();
  final Timeline timeline = Timeline();
  double bpm;

  static Project _instance;
  static Project get instance => _instance;

  Project({this.bpm = 120}) {
    _instance = this;
  }

  void play() {
    audioAssembler.run(timeline.box);
  }

  void pause() {
    audioAssembler.stopPlayback();
  }
}
