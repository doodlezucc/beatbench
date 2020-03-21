import 'audio_assembler.dart';
import 'timeline.dart';

class Project {
  final AudioAssembler audioAssembler = AudioAssembler();
  final Timeline timeline = Timeline();
  double bpm;

  Project({this.bpm = 120});

  void play() {
    audioAssembler.run(bpm: bpm, timeline: timeline);
  }

  void pause() {
    audioAssembler.stopPlayback();
    print('suspended');
  }
}
