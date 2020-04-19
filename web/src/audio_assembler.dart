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

    var idealPitchesPlaying = {for (var g in generators) g: <NoteInfo>[]};

    var smallValue = 0.0001;
    _cache.forEach((pn) {
      if (pn.startInSeconds <= now + smallValue &&
          pn.endInSeconds > now + smallValue) {
        idealPitchesPlaying[pn.generator].add(pn.noteInfo);
      }
    });

    generators.forEach((generator) {
      // Stop playing notes which should not play
      generator.playingNodes.forEach((playingNoteNode) {
        if (!idealPitchesPlaying[generator].any(
            (info) => info.coarsePitch == playingNoteNode.info.coarsePitch)) {
          _sendNoteOff(
              generator, playingNoteNode.info.coarsePitch, _ctx.currentTime);
        }
      });
      // Start notes which should play
      idealPitchesPlaying[generator].forEach((info) {
        if (!generator.playingNodes
            .any((node) => node.info.coarsePitch == info.coarsePitch)) {
          _sendNoteOn(generator, info, _ctx.currentTime);
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

  void _debugNoteEvent(Generator gen, int pitch, double when, bool noteOn,
      {bool isResumed = false}) {
    var common = CommonPitch(pitch);
    print('${common.description} / ${noteOn}');
  }

  bool _sendNoteOn(Generator gen, NoteInfo info, double when,
      {bool isResumed = false}) {
    _debugNoteEvent(gen, info.coarsePitch, when, true);
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

  void _bufferRegion(double from, double to, {bool wrap = false}) {
    var time = _positionOnStart + _ctx.currentTime - _contextTimeOnStart;
    var when = _ctx.currentTime - (time % length);
    if (wrap) {
      when += length;
    }

    _cache.forEach((pn) {
      if (pn.startInSeconds >= from && pn.startInSeconds < to) {
        _sendNoteOn(pn.generator, pn.noteInfo, when + pn.startInSeconds);
      }
      if (pn.endInSeconds >= from && pn.endInSeconds < to) {
        _sendNoteOff(
            pn.generator, pn.noteInfo.coarsePitch, when + pn.endInSeconds);
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
