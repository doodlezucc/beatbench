import 'dart:async';
import 'dart:web_audio';

import 'package:meta/meta.dart';

import 'generators/base.dart';
import 'notes.dart';
import 'project.dart';

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
  bool _shouldUpdateCache = true;
  bool _newTempo = false;

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

  static const double _smallValue = 0.0001;

  void _correctPlayingNotes({bool firstRun = false}) {
    var time = _positionOnStart;
    if (!firstRun) {
      time += _ctx.currentTime - _contextTimeOnStart;
    }
    var now = time % length;

    var idealPlayingNotes = {for (var g in generators) g: <PlaybackNote>[]};

    _cache.forEach((pn) {
      if (pn.startInSeconds <= now + _smallValue &&
          pn.endInSeconds > now + _smallValue) {
        idealPlayingNotes[pn.generator].add(pn);
      }
    });

    generators.forEach((generator) {
      // Stop playing notes which should not play
      generator.playingNodes.forEach((playingNoteNode) {
        if (!idealPlayingNotes[generator].any((pn) =>
            pn.noteInfo.coarsePitch == playingNoteNode.info.coarsePitch)) {
          _sendNoteOff(
              generator, playingNoteNode.info.coarsePitch, _ctx.currentTime);
        }
      });
      // Start notes which should play
      idealPlayingNotes[generator].forEach((pn) {
        if (!generator.playingNodes
            .any((node) => node.info.coarsePitch == pn.noteInfo.coarsePitch)) {
          _sendNoteOn(generator, pn.noteInfo, _ctx.currentTime,
              isResumed: !firstRun);
        }
      });
    });
  }

  Iterable<Generator> get generators => Project.instance.generators.list;

  void _sendStopNotes() {
    generators.forEach((generator) {
      generator.playingNodes.forEach((playingNoteNode) {
        generator.noteEnd(playingNoteNode.info.coarsePitch, _ctx.currentTime);
      });
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
      _bufferedSeconds = (newLength / length) *
          (_bufferedSeconds - (_ctx.currentTime - _contextTimeOnStart));
      _contextTimeOnStart = _ctx.currentTime;
      _positionOnStart = position % newLength;
      _newTempo = true;
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
          if (_newTempo) {
            _newTempo = false;
          } else {
            _correctPlayingNotes();
            _bufferedSeconds = ctx.currentTime - _contextTimeOnStart;
            _bufferTo(_bufferedSeconds, onlyOff: true);
          }
        }
        _bufferTo(ctx.currentTime - _contextTimeOnStart + scheduleAhead);
      },
    );
    _bufferedSeconds = _smallValue;
    _positionOnStart = start;
    _newTempo = false;

    _forceUpdateCache();
    _contextTimeOnStart = ctx.currentTime;
    _correctPlayingNotes(firstRun: true);
    _bufferTo(scheduleAhead, onlyOff: true);
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

  void _forceUpdateCache() {
    _cache.clear();
    _cache.addAll(getNotes());
    //_refreshPlayingNotes();
    _shouldUpdateCache = false;
    print('Updated cache');
  }

  void _bufferTo(double seconds, {bool onlyOff = false}) {
    if (seconds <= _bufferedSeconds && !onlyOff) {
      print('Buffering already buffered stuff');
    }
    var buffLength = seconds - _bufferedSeconds;
    var startMod = (_bufferedSeconds + _positionOnStart) % length;
    var end = startMod + buffLength;
    var ctxTime = _ctx.currentTime;
    _bufferRegion(startMod, end,
        ctxTime: ctxTime, onlyOff: onlyOff, wrap: false);
    if (end >= length) {
      // Wrap to start
      _bufferRegion(startMod - length, end - length,
          ctxTime: ctxTime, onlyOff: onlyOff, wrap: true);
    }
    _bufferedSeconds = seconds;
  }

  void _debugNoteEvent(Generator gen, int pitch, double when, bool noteOn,
      {bool isResumed = false}) {
    var common = CommonPitch(pitch);
    print('${gen.runtimeType}: ${common.description} / ${noteOn}' +
        (isResumed ? ' (resumed)' : ''));
  }

  bool _sendNoteOn(Generator gen, NoteInfo info, double when,
      {bool isResumed = false}) {
    _debugNoteEvent(gen, info.coarsePitch, when, true, isResumed: isResumed);
    gen.noteStart(info, when, isResumed);
    //print('sent');
    return true;
  }

  bool _sendNoteOff(Generator gen, int pitch, double when,
      {bool isResumed = false}) {
    _debugNoteEvent(gen, pitch, when, false);
    gen.noteEnd(pitch, when);
    //print('sent');
    return true;
  }

  void _bufferRegion(double from, double to,
      {@required double ctxTime, bool wrap = false, bool onlyOff = false}) {
    var time = _positionOnStart + ctxTime - _contextTimeOnStart;
    var loopStart = ctxTime - (time % length);
    if (wrap) {
      loopStart += length;
    }

    _cache.forEach((pn) {
      if (!onlyOff && pn.startInSeconds >= from && pn.startInSeconds < to) {
        _sendNoteOn(pn.generator, pn.noteInfo, loopStart + pn.startInSeconds);
      }
      if (pn.endInSeconds >= from && pn.endInSeconds < to) {
        _sendNoteOff(
            pn.generator, pn.noteInfo.coarsePitch, loopStart + pn.endInSeconds);
      }
    });
  }
}

class PlaybackNote {
  final Generator generator;
  final NoteInfo noteInfo;
  final double startInSeconds;
  final double endInSeconds;

  PlaybackNote({
    @required this.startInSeconds,
    @required this.endInSeconds,
    @required this.noteInfo,
    @required this.generator,
  });

  @override
  bool operator ==(dynamic other) =>
      generator == other.generator && noteInfo == other.noteInfo;
}
