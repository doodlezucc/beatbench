import 'dart:web_audio';

class Specs {
  final int sampleRate = 44100;
  final double schedulingTime = 0.02;
}

class AudioAssembler {
  var specs = Specs();
  var ctx = AudioContext();

  AudioAssembler();

  void run() async {
    await ctx.resume();
  }
}
