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
  PlaybackBox _box;
  PlaybackBox get box => _box;
  bool get isRunning => _box != null;

  void run(PlaybackBox box) async {
    stopPlayback();
    _box = box;
    await ctx.resume();
    _box._run(ctx, specs);
  }

  void stopPlayback() {
    if (isRunning) {
      _box.stopPlayback();
      _box = null;
    }
  }
}

class PlaybackBox {
  List<PlaybackNote> _cache = [];
  set cache(Iterable<PlaybackNote> l) {
    _cache = l.toList(growable: false);
  }

  double _bufferedSeconds;
  double _contextTimeOnStart;
  double _positionOnStart = 0;
  Timer _audioTimer;
  Timer _videoTimer;
  AudioContext _ctx;
  bool _running = false;

  double _length = 1;
  double get length => _length;
  set length(double length) {
    if (_length != length) {
      if (_running) {
        var position =
            (_positionOnStart + _ctx.currentTime - _contextTimeOnStart) %
                _length;
        _bufferedSeconds =
            _bufferedSeconds - (_ctx.currentTime - _contextTimeOnStart);
        _contextTimeOnStart = _ctx.currentTime;
        _positionOnStart = position % length;
      }

      _length = length;
    }
  }

  void handleNewTempo(double newLength) {
    if (_running) {
      var position = (newLength / length) *
          ((_positionOnStart + _ctx.currentTime - _contextTimeOnStart) %
              _length);
      _bufferedSeconds =
          _bufferedSeconds - (_ctx.currentTime - _contextTimeOnStart);
      _contextTimeOnStart = _ctx.currentTime;
      _positionOnStart = position % newLength;
    }

    _length = newLength;
  }

  void Function(double timeMod) onUpdateVisuals;

  void _run(AudioContext ctx, Specs specs) {
    _ctx = ctx;
    _running = true;
    _videoTimer = Timer.periodic(
      Duration(milliseconds: specs.frameDuration),
      (timerInstance) {
        _updateVisuals();
      },
    );
    var scheduleAhead = specs.schedulingMs / 1000;

    _audioTimer = Timer.periodic(
      Duration(
        milliseconds: (specs.schedulingMs * 0.8).round(),
      ),
      (timerInstance) {
        _bufferTo(ctx.currentTime - _contextTimeOnStart + scheduleAhead);
      },
    );
    _contextTimeOnStart = ctx.currentTime;
    _bufferedSeconds = 0;

    _bufferTo(scheduleAhead);
  }

  void stopPlayback() {
    _running = false;
    _audioTimer.cancel();
    _videoTimer.cancel();
  }

  void _updateVisuals() {
    onUpdateVisuals(
        (_positionOnStart + _ctx.currentTime - _contextTimeOnStart) % length);
  }

  void _bufferTo(double seconds) {
    if (seconds > _bufferedSeconds) {
      var buffLength = seconds - _bufferedSeconds;
      var startMod = (_bufferedSeconds + _positionOnStart) % length;
      var end = startMod + buffLength;
      if (end >= length) {
        // Wrap to start
        _bufferRegionWrap(end % length);
      }
      _bufferRegion(startMod, end);
      _bufferedSeconds = seconds;
    } else {
      print('nah');
    }
  }

  void _bufferRegionWrap(double to) {
    var time = _positionOnStart + _ctx.currentTime - _contextTimeOnStart;
    _getNotes(0, to).forEach((pn) {
      var when =
          _ctx.currentTime + pn.startInSeconds - (time % length) + length;
      pn.instrument.playNote(pn.note, when);
    });
  }

  void _bufferRegion(double from, double to) {
    var time = _positionOnStart + _ctx.currentTime - _contextTimeOnStart;
    _getNotes(from, to).forEach((pn) {
      var when = _ctx.currentTime + pn.startInSeconds - (time % length);
      //print('scheduling ${pn.note.coarsePitch} to play at $when seconds');
      pn.instrument.playNote(pn.note, when);
    });
  }

  Iterable<PlaybackNote> _getNotes(double from, double to) {
    return _cache
        .where((pn) => pn.startInSeconds >= from && pn.startInSeconds < to);
  }
}
