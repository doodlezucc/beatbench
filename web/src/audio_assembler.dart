import 'dart:async';
import 'dart:web_audio';

import 'generators/oscillator.dart';
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

  void run(PlaybackBox box, double start) async {
    stopPlayback();
    _box = box;
    await ctx.resume();
    _box._run(ctx, specs, start);
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
  final List<PlaybackNote> _notesPlaying = [];

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

  set position(double position) {
    if (_running) {
      //_bufferedSeconds = _bufferedSeconds - (_ctx.currentTime - _contextTimeOnStart);
      _bufferedSeconds = 0;
      _contextTimeOnStart = _ctx.currentTime;
    }
    _positionOnStart = position % length;
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
  void Function() onStop;

  void _run(AudioContext ctx, Specs specs, double start) {
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
    _positionOnStart = start;

    _bufferTo(scheduleAhead);
  }

  void stopPlayback() {
    _running = false;
    _audioTimer.cancel();
    _videoTimer.cancel();

    _notesPlaying
        .forEach((n) => n.generator.noteEvent(n.note, _ctx.currentTime, false));

    if (onStop != null) onStop();
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
        _bufferRegion(0, end % length, true);
      }
      _bufferRegion(startMod, end);
      _bufferedSeconds = seconds;
    } else {
      print('nah');
    }
  }

  void _bufferRegion(double from, double to, [bool wrap = false]) {
    var time = _positionOnStart + _ctx.currentTime - _contextTimeOnStart;

    _cache.forEach((pn) {
      var noteOn;
      var when = _ctx.currentTime - (time % length);
      if (pn.startInSeconds >= from && pn.startInSeconds < to) {
        noteOn = true;
        when += pn.startInSeconds;
      } else if (pn.endInSeconds >= from && pn.endInSeconds < to) {
        noteOn = false;
        when += pn.endInSeconds;
      } else {
        return;
      }
      if (wrap) when += length;
      if (pn.generator is Oscillator) {
        print(
            '${pn.note.coarsePitch} (${noteOn ? 'on' : 'off'}) at $when seconds');
      }
      pn.generator.noteEvent(pn.note, when, noteOn);
      _notesPlaying.add(pn);
    });
  }
}
