import 'dart:html';

import 'package:meta/meta.dart';

import 'beat_grid.dart';
import 'instruments.dart';
import 'notes.dart';
import 'beat_fraction.dart';
import 'patterns.dart';
import 'project.dart';
import 'utils.dart';
import 'audio_assembler.dart';

class Timeline {
  // UI stuff
  static final pixelsPerBeat = CssPxVar('timeline-ppb', 20);
  static final pixelsPerTrack = CssPxVar('timeline-ppt', 70);

  BeatFraction _songLength = BeatFraction(4, 4);
  set songLength(BeatFraction l) {
    _songLength = l;
    box.length = getTimeAt(l);
    _drawOrientation();
  }

  BeatFraction get songLength => _songLength;

  BeatFraction _songPosition = BeatFraction(0, 1);
  BeatFraction get songPosition => _songPosition;
  set songPosition(BeatFraction songPosition) {
    _songPosition = songPosition;
    _drawForeground();
  }

  List<Instrument> instruments;
  final List<PatternInstance> _patterns = [];
  final HtmlElement _e;
  CanvasElement _canvasBg;
  CanvasElement _canvasFg;
  final PlaybackBox box;

  bool _hasChanges = false;
  bool get hasChanges => _hasChanges;

  Timeline()
      : box = PlaybackBox(),
        _e = querySelector('#timeline') {
    _canvasBg = _e.querySelector('#background');
    _canvasFg = _e.querySelector('#foreground');
    _drawOrientation();
  }

  void updateNoteShiftBuffer() {
    _hasChanges = false;

    var _cache = <PlaybackNote>[];
    _patterns.forEach((pat) {
      var notes = pat.data.notes();
      notes.forEach((i, patNotesComp) {
        _cache.addAll(patNotesComp.notes.where((note) {
          return note.start >= pat.contentShift &&
              note.start < pat.length + pat.contentShift;
        }).map((note) {
          var shift = pat.start - pat.contentShift;
          return PlaybackNote(
            note: note,
            instrument: instruments[i],
            startInSeconds: getTimeAt(note.start + shift),
            endInSeconds: getTimeAt(note.end + shift),
          );
        }));
      });
    });
    box.cache = _cache;
  }

  void _drawForeground() {
    var l = songLength;
    _canvasFg.width = (l.beats * pixelsPerBeat.value).round();
    _canvasFg.height = 200;

    var ctx = _canvasFg.context2D;
    ctx.clearRect(0, 0, _canvasFg.width, _canvasFg.height);
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.5;

    var x = songPosition.beats * pixelsPerBeat.value;
    ctx.moveTo(x, 0);
    ctx.lineTo(x, _canvasFg.height);

    ctx.stroke();
  }

  void _drawOrientation() {
    var l = songLength;
    _canvasBg.width = (l.beats * pixelsPerBeat.value).round();
    _canvasBg.height = 200;

    var ctx = _canvasBg.context2D;
    ctx.clearRect(0, 0, _canvasBg.width, _canvasBg.height);
    ctx.strokeStyle = '#fff4';
    for (var b = 0; b <= l.beats; b++) {
      var x = (b * pixelsPerBeat.value).round() - 0.5;
      ctx.moveTo(x, 0);
      ctx.lineTo(x, _canvasBg.height);
    }
    ctx.stroke();
  }

  void thereAreChanges() {
    //print('bruv there are changes');
    _hasChanges = true;
    updateNoteShiftBuffer();
  }

  double getTimeAt(BeatFraction bf) {
    return bf.beats / (Project.instance.bpm / 60);
  }

  void calculateSongLength() {
    songLength = _patterns.fold(
        BeatFraction.washy(0), (v, pat) => pat.end > v ? pat.end : v);
  }

  PatternInstance insertPattern(PatternData data,
      {BeatFraction start = const BeatFraction(0, 1), int track = 0}) {
    PatternInstance instance;
    instance = PatternInstance(data, start, null, track, () {
      if (instance.end > songLength) {
        songLength = instance.end;
      } else if (instance.end < songLength) {
        calculateSongLength();
      }
      thereAreChanges();
    });
    if (instance.end > songLength) {
      songLength = instance.end;
    }
    _patterns.add(instance);
    thereAreChanges();
    return instance;
  }

  void fromBeatGrid(BeatGrid grid) {
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
      insertPattern(gridPatternData, start: BeatFraction(i, 1));
    }
    insertPattern(crashPatternData, track: 1);
    calculateSongLength();
    thereAreChanges();
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
