import 'dart:html';

import 'package:meta/meta.dart';

import 'beat_grid.dart';
import 'drag.dart';
import 'history.dart';
import 'instruments.dart';
import 'notes.dart';
import 'beat_fraction.dart';
import 'patterns.dart';
import 'project.dart';
import 'utils.dart';
import 'audio_assembler.dart';
import 'windows.dart';

class Timeline extends Window {
  // UI stuff
  static final pixelsPerBeat = CssPxVar('timeline-ppb', 20);
  static final pixelsPerTrack = CssPxVar('timeline-ppt', 70);

  BeatFraction _songLength = BeatFraction(4, 4);
  BeatFraction get songLength => _songLength;
  BeatFraction get renderLength => _songLength + BeatFraction(16, 1);
  set songLength(BeatFraction l) {
    var min = BeatFraction(4, 4);
    if (l < min) l = min;
    _songLength = l;
    box.length = timeAt(l);
    _drawOrientation();
    thereAreChanges();
    if (headPosition > renderLength) {
      headPosition =
          BeatFraction.washy(headPosition.beats % renderLength.beats);
    }
  }

  BeatFraction _headPosition = BeatFraction(0, 1);
  BeatFraction get headPosition => _headPosition;
  set headPosition(BeatFraction headPosition) {
    if (headPosition > songLength) {
      headPosition = songLength;
    }
    if (headPosition != _headPosition) {
      _headPosition = headPosition;
      querySelector('#head').style.left =
          cssCalc(headPosition.beats, pixelsPerBeat);
      _drawForeground(headPosition.beats, headPosition.beats);
      box.position = timeAt(headPosition);
    }
  }

  int get _trackCount => 4;
  int get canvasHeight => (_trackCount * pixelsPerTrack.value).round();

  List<Instrument> instruments;
  final List<PatternInstance> _patterns = [];
  Iterable<PatternInstance> get selectedPatterns =>
      _patterns.where((p) => p.selected);
  final HtmlElement _e;
  CanvasElement _canvasBg;
  CanvasElement _canvasFg;
  final PlaybackBox box;

  bool _hasChanges = false;
  bool get hasChanges => _hasChanges;

  Timeline()
      : box = PlaybackBox(),
        _e = querySelector('#timeline') {
    _canvasBg = _e.querySelector('#background')
      ..onClick.listen((e) {
        selectedPatterns.forEach((p) => p.selected = false);
      });
    _canvasFg = _e.querySelector('#foreground');
    _drawOrientation();
    box
      ..onUpdateVisuals = (time) {
        _drawForeground(headPosition.beats, beatsAt(time));
      }
      ..onStop = () {
        _drawForeground(headPosition.beats, headPosition.beats);
      };

    _scrollArea.onScroll.listen((ev) => _onScroll());
    _onScroll();

    var headDragSystem = DragSystem<BeatFraction>();
    headDragSystem.register(Draggable<BeatFraction>(
        querySelector('#head'), () => headPosition, (src, off, ev) {
      var diff =
          BeatFraction((off.x / Timeline.pixelsPerBeat.value).round(), 4);
      var minDiff = src * -1;
      if (diff < minDiff) diff = minDiff;

      headPosition = src + diff;
    }));
  }

  HtmlElement get _scrollArea => querySelector('#patterns');

  void _onScroll() {
    //e.style.top = (-querySelector('#right').scrollTop).toString() + 'px';
    querySelector('#head').parent.style.left =
        (100 - _scrollArea.scrollLeft).toString() + 'px';
    querySelector('#tracks').style.top =
        (-_scrollArea.scrollTop).toString() + 'px';
  }

  void updatePlaybackCache() {
    _hasChanges = false;

    var _cache = <PlaybackNote>[];
    _patterns.forEach((pat) {
      var notes = pat.data.notes();
      notes.forEach((i, patNotesComp) {
        _cache.addAll(patNotesComp.notesWithSwing.where((note) {
          return note.start >= pat.contentShift &&
              note.start < pat.length + pat.contentShift;
        }).map((note) {
          var shift = pat.start - pat.contentShift;
          return PlaybackNote(
            note: note,
            instrument: instruments[i],
            startInSeconds: timeAt(note.start + shift),
            endInSeconds: timeAt(note.end + shift),
          );
        }));
      });
    });
    box.cache = _cache;
  }

  void _drawForeground(double head, double ghost) {
    var l = renderLength;
    _canvasFg.width = (l.beats * pixelsPerBeat.value).round();
    _canvasFg.height = canvasHeight;

    var ctx = _canvasFg.context2D;
    ctx.clearRect(0, 0, _canvasFg.width, _canvasFg.height);

    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.5;
    var x = head * pixelsPerBeat.value;
    ctx.moveTo(x, 0);
    ctx.lineTo(x, _canvasFg.height);

    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.5;
    x = ghost * pixelsPerBeat.value;
    ctx.moveTo(x, 0);
    ctx.lineTo(x, _canvasFg.height);

    ctx.stroke();
  }

  void _drawOrientation() {
    var l = renderLength;
    _canvasBg.width = (l.beats * pixelsPerBeat.value).round();
    _canvasBg.height = canvasHeight;

    var ctx = _canvasBg.context2D;
    ctx.clearRect(0, 0, _canvasBg.width, _canvasBg.height);

    ctx.strokeStyle = '#fff4';
    for (var b = 0; b <= l.beats; b++) {
      var x = (b * pixelsPerBeat.value).round() - 0.5;
      ctx.moveTo(x, 0);
      ctx.lineTo(x, _canvasBg.height);
    }
    ctx.stroke();

    ctx.fillStyle = '#0008';
    ctx.fillRect(
        songLength.beats * pixelsPerBeat.value,
        0,
        (renderLength - songLength).beats * pixelsPerBeat.value,
        _canvasBg.height);
  }

  void onNewTempo() {
    updatePlaybackCache();
    box.handleNewTempo(timeAt(songLength));
  }

  void thereAreChanges() {
    //print('bruv there are changes');
    _hasChanges = true;
    updatePlaybackCache();
  }

  double timeAt(BeatFraction bf) {
    return bf.beats / (Project.instance.bpm / 60);
  }

  double beatsAt(double seconds) {
    return seconds * (Project.instance.bpm / 60);
  }

  void calculateSongLength() {
    songLength = _patterns.fold(
        BeatFraction.washy(0), (v, pat) => pat.end > v ? pat.end : v);
  }

  void cloneSelectedPatterns() {
    var clones = <PatternInstance>[];
    selectedPatterns.forEach((p) {
      clones.add(_clonePattern(p)..selected = true);
      p.selected = false;
    });
    History.perform(PatternsCreationAction(true, clones));
  }

  PatternInstance _clonePattern(PatternInstance original) {
    PatternInstance instance;
    instance = PatternInstance(
        original.data, original.start, original.length, original.track, () {
      if (instance.end > songLength) {
        songLength = instance.end;
      } else if (instance.end < songLength) {
        calculateSongLength();
      } else {
        thereAreChanges();
      }
    })
      ..contentShift = original.contentShift;
    if (instance.end > songLength) {
      songLength = instance.end;
    }
    return instance;
  }

  PatternInstance instantiatePattern(PatternData data,
      {BeatFraction start = const BeatFraction(0, 1), int track = 0}) {
    PatternInstance instance;
    instance = PatternInstance(data, start, null, track, () {
      if (instance.end > songLength) {
        songLength = instance.end;
      } else if (instance.end < songLength) {
        calculateSongLength();
      } else {
        thereAreChanges();
      }
    });
    if (instance.end > songLength) {
      songLength = instance.end;
    }
    History.perform(PatternsCreationAction(true, [instance]));
    return instance;
  }

  void demoFromBeatGrid(BeatGrid grid) {
    instruments = [grid.drums];
    var gridPatternData = grid.data;
    var crashPatternData = PatternData(
      'Crash!',
      {
        0: PatternNotesComponent([
          Note(tone: Note.D + 1, octave: 5),
        ])
      },
    );
    for (var i = 0; i < 4; i++) {
      instantiatePattern(gridPatternData, start: BeatFraction(i, 1));
    }
    instantiatePattern(crashPatternData, track: 1);
    calculateSongLength();
    thereAreChanges();
  }

  @override
  bool handleDelete() {
    if (selectedPatterns.isNotEmpty) {
      History.perform(PatternsCreationAction(
          false, selectedPatterns.toList(growable: false)));
    }
    return true;
  }

  @override
  bool handleSelectAll() {
    if (_patterns.isNotEmpty) {
      var doSelect = !_patterns.every((pattern) => pattern.selected);
      _patterns.forEach((p) {
        p.selected = doSelect;
      });
    }
    return true;
  }

  @override
  bool handleClone() {
    cloneSelectedPatterns();
    return true;
  }
}

class PlaybackNote {
  final Instrument instrument;
  final Note note;
  final double startInSeconds;
  final double endInSeconds;

  PlaybackNote({
    @required this.startInSeconds,
    @required this.endInSeconds,
    @required this.note,
    @required this.instrument,
  });

  PlaybackNote clone({double startInSeconds}) {
    return PlaybackNote(
      startInSeconds: startInSeconds ?? this.startInSeconds,
      endInSeconds: endInSeconds,
      note: note,
      instrument: instrument,
    );
  }
}

class PatternsCreationAction extends AddRemoveAction<PatternInstance> {
  PatternsCreationAction(bool forward, Iterable<PatternInstance> list)
      : super(forward, list);

  @override
  void doSingle(PatternInstance object) {
    object.setExistence(true);
    Project.instance.timeline._patterns.add(object);
  }

  @override
  void undoSingle(PatternInstance object) {
    object.setExistence(false);
    Project.instance.timeline._patterns.remove(object);
  }

  @override
  void onExecuted(bool forward) {
    Project.instance.timeline.calculateSongLength();
  }
}
