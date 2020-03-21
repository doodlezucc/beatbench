import 'dart:async';
import 'dart:web_audio';

import 'package:meta/meta.dart';

import 'timeline.dart';

class Specs {
  final int sampleRate = 44100;
  final double schedulingTime = 0.02;
}

class AudioAssembler {
  var specs = Specs();
  var ctx = AudioContext();
  Timer updateTimer;

  AudioAssembler();

  void run({@required double bpm, @required Timeline timeline}) async {
    await ctx.resume();

    var startTime = ctx.currentTime;
    var oldCtxTime = startTime;
    if (updateTimer != null) {
      updateTimer.cancel();
    }
    var bps = bpm / 60;
    updateTimer = Timer.periodic(Duration(milliseconds: 1000), (timerInstance) {
      var time = (ctx.currentTime - startTime) % (timeline.lengthInBeats / bps);
      var inBeats = (time * bps);
      var nextInBeats = inBeats + (1 * bps);

      print(inBeats.toStringAsFixed(0));

      timeline.notes.forEach((n) {
        if (n.start.beats >= inBeats && n.start.beats <= nextInBeats) {
          print(
              '${n.coarsePitch} at ${n.start.beats} beats, ${n.start.beats - inBeats} ahead');
          timeline.instruments[0].playNote(n, time, bpm);
        } else if (inBeats <= n.start.beats + timeline.lengthInBeats &&
            n.start.beats + timeline.lengthInBeats < nextInBeats) {
          print(
              '${n.coarsePitch} at ${n.start.beats} beats, ${n.start.beats - inBeats} ahead');
          timeline.instruments[0]
              .playNote(n, time, bpm, timeline.lengthInBeats / bps);
        }
      });

      oldCtxTime = ctx.currentTime;
    });
  }
}
