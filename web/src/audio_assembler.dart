import 'dart:async';
import 'dart:web_audio';

import 'timeline.dart';

class Specs {
  final int sampleRate = 44100;
  final int schedulingMs = 100;
  final int frameDuration = 20; // 50fps
}

class AudioAssembler {
  var specs = Specs();
  var ctx = AudioContext();
  Timer _audioTimer;
  Timer _videoTimer;
  PlaybackBox _box;
  PlaybackBox get box => _box;
  bool get isRunning => _box != null;
  double get scheduleAhead => specs.schedulingMs / 1000;

  void run(PlaybackBox box) async {
    await ctx.resume();

    if (_audioTimer != null) {
      _audioTimer.cancel();
      _videoTimer.cancel();
    }

    _videoTimer = Timer.periodic(
      Duration(milliseconds: specs.frameDuration),
      (timerInstance) {},
    );
    _audioTimer = Timer.periodic(
      Duration(
        milliseconds: (specs.schedulingMs * 0.8).round(),
      ),
      (timerInstance) {
        box._bufferTo(ctx.currentTime + scheduleAhead, ctx);
      },
    );
    box._bufferTo(scheduleAhead, ctx);
  }

  void stopPlayback() {
    _audioTimer.cancel();
    _videoTimer.cancel();
    _box = null;
  }
}

class PlaybackBox {
  List<PlaybackNote> _cache = [];
  set cache(Iterable<PlaybackNote> l) {
    _cache = l.toList(growable: false);
  }

  double bufferedSeconds = 0;

  double _length;
  double get length => _length;
  set length(double length) {
    _length = length;
  }

  void _bufferTo(double seconds, AudioContext ctx) {
    if (seconds > bufferedSeconds) {
      var buffLength = seconds - bufferedSeconds;
      var startMod = bufferedSeconds % length;
      var end = startMod + buffLength;
      if (end >= length) {
        // Wrap to start
        _bufferRegionWrap(end % length, ctx);
      }
      _bufferRegion(startMod, end, ctx);
      bufferedSeconds = seconds;
    } else {
      print('nah');
    }
  }

  void _bufferRegionWrap(double to, AudioContext ctx) {
    _getNotes(0, to).forEach((pn) {
      var when = ctx.currentTime +
          pn.startInSeconds -
          (ctx.currentTime % length) +
          length;
      pn.instrument.playNote(pn.note, when);
    });
  }

  void _bufferRegion(double from, double to, AudioContext ctx) {
    _getNotes(from, to).forEach((pn) {
      var when =
          ctx.currentTime + pn.startInSeconds - (ctx.currentTime % length);
      if (when < ctx.currentTime) {
        print('hmmmm');
        print(pn.note.coarsePitch);
        print(ctx.currentTime);
        print(when);
        print(bufferedSeconds);
        print(length);
      }
      //print('scheduling ${pn.note.coarsePitch} to play at $when seconds');
      pn.instrument.playNote(pn.note, when);
    });
  }

  Iterable<PlaybackNote> _getNotes(double from, double to) {
    return _cache
        .where((pn) => pn.startInSeconds >= from && pn.startInSeconds < to);
  }
}
