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
  int bufferedIndex;
  double regionLength; // duration of a single region (in seconds)

  AudioAssembler() {
    regionLength = specs.schedulingMs / 1000;
  }

  void run({@required double bpm, @required Timeline timeline}) async {
    await ctx.resume();
    isRunning = true;
    bufferedIndex = -1;

    var startTime = ctx.currentTime;

    if (updateTimer != null) {
      updateTimer.cancel();
    }
    timeline.updateNoteShiftBuffer();
    updateTimer = Timer.periodic(
      Duration(
        milliseconds: (specs.schedulingMs * 0.8).round(),
      ),
      (timerInstance) {
        _bufferNotes(
            bps: bpm / 60, timeline: timeline, contextStartTime: startTime);
      },
    );
    _bufferNotes(
        bps: bpm / 60, timeline: timeline, contextStartTime: startTime);
  }

  void _bufferNotes({
    @required double bps,
    @required Timeline timeline,
    @required double contextStartTime,
  }) {
    // time since playback was started (in seconds)
    var timeAbsolute = ctx.currentTime - contextStartTime;

    var floor = (timeAbsolute / regionLength).floor();
    var ceil = floor + 1;

    // in the rare case of "floor" not having been buffered in the previous run, buffer it now
    if (bufferedIndex < floor) {
      print('lulwat');
      _bufferRegion(
        bps: bps,
        timeline: timeline,
        contextStartTime: contextStartTime,
        regionIndex: floor,
      );
    }
    // buffer "ceil" (if it wasn't already)
    if (bufferedIndex < ceil) {
      _bufferRegion(
        bps: bps,
        timeline: timeline,
        contextStartTime: contextStartTime,
        regionIndex: ceil,
      );
      bufferedIndex = ceil;
    }
  }

  void _bufferRegion({
    @required double bps,
    @required Timeline timeline,
    @required double contextStartTime,
    @required int regionIndex,
  }) {
    var regionStartSec = regionIndex * regionLength;
    var regionEndSec = (regionIndex + 1) * regionLength;

    var regionStartBeats = regionStartSec * bps;
    var regionEndBeats = regionEndSec * bps;

    var instrumentNotes =
        timeline.getNotes(regionStartBeats, regionEndBeats - regionStartBeats);
    for (var i = 0; i < instrumentNotes.length; i++) {
      instrumentNotes.elementAt(i).forEach((noteShift) {
        var n = noteShift.note;
        print(
            '${n.coarsePitch} at ${n.start.beats + noteShift.shift.beats} beats (shift: ${noteShift.shift.beats})');
        timeline.instruments[0].playNote(n,
            contextStartTime + (n.start.beats + noteShift.shift.beats) / bps);
      });
    }
  }

  void stopPlayback() {
    updateTimer.cancel();
    isRunning = false;
  }
}
