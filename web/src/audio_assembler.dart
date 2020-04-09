import 'dart:async';
import 'dart:web_audio';

import 'package:meta/meta.dart';

import 'generators/base.dart';
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

class _SentSignal {
  final NoteSignal sig;
  final double time;

  _SentSignal(this.sig, this.time);
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
  final Map<PlaybackNote, _SentSignal> _sentSignals = {};
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
        _correctPlayingNotes();
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
    if (_running) _correctPlayingNotes();
  }

  PlaybackBox(
      {@required this.onUpdateVisuals,
      @required this.onStop,
      @required this.getNotes});

  void _correctPlayingNotes() {
    var time = _positionOnStart + _ctx.currentTime - _contextTimeOnStart;
    var now = time % length;

    _cache.forEach((pn) {
      var signal = pn.startInSeconds <= now && pn.endInSeconds > now
          ? NoteSignal.NOTE_RESUME
          : NoteSignal.NOTE_END;
      //print('Refresh');
      _sendNoteEvent(pn, _ctx.currentTime, signal);
    });

    //_notesPlaying.clear();
    //_notesPlaying.addAll(newNotesPlaying);
  }

  void _sendStopNotes() {
    _sentSignals.forEach((pn, sig) {
      if (sig.sig.noteOn) {
        _sendNoteEvent(pn, _ctx.currentTime, NoteSignal.NOTE_END, force: true);
      }
    });
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
        if (_shouldUpdateCache) {
          _forceUpdateCache();
          _correctPlayingNotes();
        }
        _bufferTo(ctx.currentTime - _contextTimeOnStart + scheduleAhead);
      },
    );
    _contextTimeOnStart = ctx.currentTime;
    _bufferedSeconds = 0;
    _positionOnStart = start;

    _forceUpdateCache();
    _bufferTo(scheduleAhead);
    _correctPlayingNotes();
  }

  void stopPlayback() {
    _running = false;
    _audioTimer.cancel();
    _videoTimer.cancel();

    _sendStopNotes();
    _sentSignals.clear();

    if (onStop != null) onStop();
  }

  void _updateVisuals() {
    onUpdateVisuals(
        (_positionOnStart + _ctx.currentTime - _contextTimeOnStart) % length);
  }

  void _forceUpdateCache() {
    _cache.clear();
    _cache.addAll(getNotes());
    //_refreshPlayingNotes();
    _shouldUpdateCache = false;
    //print('Updated cache');
  }

  void _bufferTo(double seconds) {
    if (seconds > _bufferedSeconds) {
      var buffLength = seconds - _bufferedSeconds;
      var startMod = (_bufferedSeconds + _positionOnStart) % length;
      var end = startMod + buffLength;
      _bufferRegion(startMod, end,
          wrap: ((_ctx.currentTime - _contextTimeOnStart + _positionOnStart) /
                      length)
                  .floor() <
              ((_bufferedSeconds + _positionOnStart) / length).floor());
      if (end >= length) {
        // Wrap to start
        _bufferRegion(0, end % length, wrap: true);
      }
      _bufferedSeconds = seconds;
    } else {
      print('nah');
    }
  }

  bool _sendNoteEvent(PlaybackNote pn, double when, NoteSignal sig,
      {bool force = false}) {
    var key = _sentSignals.keys.firstWhere((n) => n == pn, orElse: () => null);
    if (key != null) {
      if (_sentSignals[key].sig.noteOn == sig.noteOn) return false;
      if (when < _sentSignals[key].time) {
        if (force) {
          return _sendNoteEvent(pn, _sentSignals[key].time, sig);
        }
        print('did not send signal because another one is scheduled later');
        return false;
      }
    }
    _sentSignals[key ?? pn] = _SentSignal(sig, when);
    pn.generator.noteEvent(pn.note.info, when, sig);
    return true;
  }

  void _bufferRegion(double from, double to, {bool wrap = false}) {
    var time = _positionOnStart + _ctx.currentTime - _contextTimeOnStart;
    var when = _ctx.currentTime - (time % length);
    if (wrap) {
      when += length;
    }

    _cache.forEach((pn) {
      if (pn.startInSeconds >= from && pn.startInSeconds < to) {
        _sendNoteEvent(pn, when + pn.startInSeconds, NoteSignal.NOTE_START);
      }
      if (pn.endInSeconds >= from && pn.endInSeconds < to) {
        _sendNoteEvent(pn, when + pn.endInSeconds, NoteSignal.NOTE_END);
      }
    });
  }
}
