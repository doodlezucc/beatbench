import 'dart:html';

import 'beat_grid.dart';
import 'instruments.dart';
import 'notes.dart';
import 'beat_fraction.dart';
import 'patterns.dart';
import 'utils.dart';

class Timeline {
  // UI stuff
  static final pixelsPerBeat = CssPxVar('timeline-ppb', 20);
  static final pixelsPerTrack = CssPxVar('timeline-ppt', 70);

  BeatFraction _songLength = BeatFraction(4, 4);
  double get lengthInBeats => _songLength.beats;

  List<Instrument> instruments;
  final List<PatternInstance> _patterns = [];
  List<List<NoteShift>> _noteShiftBuffer;
  final HtmlElement _e;
  CanvasElement _canvas;

  Timeline() : _e = querySelector('#timeline') {
    _canvas = _e.querySelector('#timelineCanvas');
    _drawOrientation();
  }

  double beatsAt(double seconds, double bps) {
    return wrappedBeats(seconds * bps);
  }

  double wrappedBeats(double beats) {
    return beats % lengthInBeats;
  }

  void updateNoteShiftBuffer() {
    _noteShiftBuffer =
        List<List<NoteShift>>.filled(instruments.length, <NoteShift>[]);
    _patterns.forEach((pat) {
      var notes = pat.data.notes();
      for (var i = 0; i < _noteShiftBuffer.length; i++) {
        _noteShiftBuffer[i].addAll(notes[i].notes.where((note) {
          return note.start >= pat.contentShift &&
              note.start < pat.length + pat.contentShift;
        }).map((note) => NoteShift(note, pat.start - pat.contentShift)));
      }
    });
  }

  void _drawOrientation() {
    var l = _songLength;
    _canvas.width = (l.beats * pixelsPerBeat.value).round();
    _canvas.height = 250;

    var ctx = _canvas.context2D;
    ctx.clearRect(0, 0, _canvas.width, _canvas.height);
    ctx.strokeStyle = '#fff7';
    ctx.lineWidth = 0.5;
    for (var b = 0; b <= l.beats; b++) {
      var x = (b * pixelsPerBeat.value).round() - 0.5;
      ctx.moveTo(x, 0);
      ctx.lineTo(x, _canvas.height);
    }
    ctx.stroke();
  }

  // WARNING: doesn't do more than one wrap!
  Iterable<Iterable<NoteShift>> getNotes(
      double startInBeats, double lengthInBeats) {
    var endInBeats = startInBeats + lengthInBeats;
    var loopCount = (startInBeats / this.lengthInBeats).floor();
    var shiftBeats = _songLength.beats * loopCount;

    return _noteShiftBuffer.map((patShiftedNotesOfAnInstr) =>
        patShiftedNotesOfAnInstr
            .where((n) {
              var shiftedStart =
                  n.note.start.beats + n.shift.beats + shiftBeats;
              return shiftedStart >= startInBeats && shiftedStart < endInBeats;
            })
            .map((n) => NoteShift(n.note, n.shift + _songLength * loopCount))
            // wrapping
            .followedBy(patShiftedNotesOfAnInstr
                .where((n) =>
                    n.note.start.beats + n.shift.beats + shiftBeats <
                    endInBeats - this.lengthInBeats)
                .map((n) => NoteShift(
                    n.note, n.shift + _songLength * (loopCount + 1)))));
  }

  void calculateSongLength() {
    _songLength = _patterns.fold(
        BeatFraction.washy(0), (v, pat) => pat.end > v ? pat.end : v);
    _drawOrientation();
  }

  PatternInstance insertPattern(PatternData data,
      {BeatFraction start = const BeatFraction(0, 1), int track = 0}) {
    PatternInstance instance;
    instance = PatternInstance(data, start, null, track, () {
      if (instance.end > _songLength) {
        _songLength = instance.end;
        _drawOrientation();
      } else if (instance.end < _songLength) {
        calculateSongLength();
      }
    });
    if (instance.end > _songLength) {
      _songLength = instance.end;
      _drawOrientation();
    }
    _patterns.add(instance);
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
    updateNoteShiftBuffer();
  }
}

class NoteShift {
  final Note note;
  final BeatFraction shift;

  const NoteShift(this.note, this.shift);
}
