import 'dart:async';
import 'dart:web_audio';

import 'package:meta/meta.dart';

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
  final List<PlaybackNote> _cache = [];

  double _bufferedSeconds;
  double _contextTimeOnStart;
  double _positionOnStart = 0;
  Timer _audioTimer;
  Timer _videoTimer;
  AudioContext _ctx;
  bool _running = false;
  final Set<PlaybackNote> _notesPlaying = {};
  bool _shouldUpdateCache = true;

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
    _resetPlayingNotes();
  }

  PlaybackBox(
      {@required this.onUpdateVisuals,
      @required this.onStop,
      @required this.getNotes});

  void _resetPlayingNotes() {
    _sendStopNotes();
  }

  void _sendStopNotes() {
    _notesPlaying.forEach(
        (n) => n.generator.noteEvent(n.note.info, _ctx.currentTime, false));
    _notesPlaying.clear();
  }

  void thereAreChanges() {
    _shouldUpdateCache = true;
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
    thereAreChanges();
  }

  final void Function(double timeMod) onUpdateVisuals;
  final void Function() onStop;
  final Iterable<PlaybackNote> Function() getNotes;

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

    _sendStopNotes();

    if (onStop != null) onStop();
  }

  void _updateVisuals() {
    onUpdateVisuals(
        (_positionOnStart + _ctx.currentTime - _contextTimeOnStart) % length);
  }

  void _bufferTo(double seconds) {
    if (_shouldUpdateCache) {
      _cache.clear();
      _cache.addAll(getNotes());
      _shouldUpdateCache = false;
      print('Updated cache');
    }
    if (seconds > _bufferedSeconds) {
      var buffLength = seconds - _bufferedSeconds;
      var startMod = (_bufferedSeconds + _positionOnStart) % length;
      var end = startMod + buffLength;
      _bufferRegion(startMod, end);
      if (end >= length) {
        // Wrap to start
        _bufferRegion(0, end % length, wrap: true);
      }
      _bufferedSeconds = seconds;
    } else {
      print('nah');
    }
  }

  void _sendNoteEvent(PlaybackNote pn, double when, bool noteOn, bool wrap) {
    if (wrap) when += length;
    if (pn.generator is Oscillator) {
      print(
          '${pn.note.coarsePitch} (${noteOn ? 'on' : 'off'}) at ${when.toStringAsFixed(2)} seconds');
    }
    pn.generator.noteEvent(pn.note.info, when, noteOn);
  }

  void _bufferRegion(double from, double to, {bool wrap = false}) {
    var time = _positionOnStart + _ctx.currentTime - _contextTimeOnStart;

    _cache.forEach((pn) {
      var when = _ctx.currentTime - (time % length);
      if (pn.startInSeconds >= from && pn.startInSeconds < to) {
        _sendNoteEvent(pn, when + pn.startInSeconds, true, wrap);
        _notesPlaying.add(pn);
      }
      if (pn.endInSeconds >= from && pn.endInSeconds < to) {
        _sendNoteEvent(pn, when + pn.endInSeconds, false, wrap);
        if (!_notesPlaying.remove(pn)) {
          _notesPlaying.removeWhere((n) => n.note.info == pn.note.info);
        }
      }
    });
  }
}
