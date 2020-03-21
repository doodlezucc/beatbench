import 'dart:async';
import 'dart:web_audio';

import 'package:meta/meta.dart';

import 'timeline.dart';

class Specs {
  final int sampleRate = 44100;
  final int schedulingMs = 100;
}

class AudioAssembler {
  var specs = Specs();
  var ctx = AudioContext();
  Timer updateTimer;
  bool isRunning;

  AudioAssembler();

  void run({@required double bpm, @required Timeline timeline}) async {
    await ctx.resume();
    isRunning = true;

    var startTime = ctx.currentTime;

    if (updateTimer != null) {
      updateTimer.cancel();
    }
    updateTimer = Timer.periodic(
      Duration(
        milliseconds: specs.schedulingMs,
      ),
      (timerInstance) {
        _bufferNotes(
            bps: bpm / 60, timeline: timeline, contextStartTime: startTime);
      },
    );
    _bufferNotes(
        bps: bpm / 60, timeline: timeline, contextStartTime: startTime);
  }

  void _bufferNotes(
      {@required double bps,
      @required Timeline timeline,
      @required double contextStartTime}) {
    var time =
        (ctx.currentTime - contextStartTime) % (timeline.lengthInBeats / bps);
    var inBeats = (time * bps);
    var nextInBeats = inBeats + (bps * specs.schedulingMs / 1000);

    print(inBeats.toStringAsFixed(0));

    timeline.notes.forEach((n) {
      if (n.start.beats >= inBeats && n.start.beats <= nextInBeats) {
        print('${n.coarsePitch} at ${n.start.beats} beats');
        timeline.instruments[0].playNote(n, time, bps);
      } else if (inBeats <= n.start.beats + timeline.lengthInBeats &&
          n.start.beats + timeline.lengthInBeats < nextInBeats) {
        print('${n.coarsePitch} at ${n.start.beats} beats');
        timeline.instruments[0]
            .playNote(n, time, bps, timeline.lengthInBeats / bps);
      }
    });
  }

  void stopPlayback() {
    updateTimer.cancel();
    isRunning = false;
  }
}
