import 'dart:html';

import 'package:meta/meta.dart';

import 'beat_grid.dart';
import 'generators/base.dart';
import 'generators/oscillator/oscillator.dart';
import 'history.dart';
import 'notes.dart';
import 'beat_fraction.dart';
import 'patterns.dart';
import 'project.dart';
import 'utils.dart';
import 'windows.dart';

class Timeline extends RollOrTimelineWindow {
  // UI stuff
  static final pixelsPerBeat = CssPxVar('timeline-ppb', 20);
  static final pixelsPerTrack = CssPxVar('timeline-ppt', 70);

  int get _trackCount => 4;
  @override
  int get canvasHeight => (_trackCount * pixelsPerTrack.value).round();

  final List<Generator> generators = [];
  final List<PatternInstance> _patterns = [];
  Iterable<PatternInstance> get selectedPatterns =>
      _patterns.where((p) => p.selected);

  Timeline() : super(querySelector('#timeline'), 'Timeline');

  @override
  Iterable<PlaybackNote> notesCache() {
    var _cache = <PlaybackNote>[];
    _patterns.forEach((pat) {
      var patternStartTime = timeAt(pat.start);
      var patternEndTime = timeAt(pat.end);

      var notes = pat.data.notes();
      notes.forEach((i, patNotesComp) {
        patNotesComp.notesWithSwing.forEach((note) {
          var noteStartBeats = note.start.beats - pat.contentShift.beats;
          var noteEndBeats = note.end.beats - pat.contentShift.beats;
          if (noteEndBeats >= 0 && noteStartBeats < pat.length.beats) {
            // note must play at SOME point...
            var shift = pat.start - pat.contentShift;
            _cache.add(PlaybackNote(
              noteInfo: note.info,
              generator: generators[i],
              startInSeconds: (noteStartBeats > 0)
                  ? timeAt(note.start + shift)
                  : patternStartTime,
              endInSeconds: (noteEndBeats < pat.length.beats)
                  ? timeAt(note.end + shift)
                  : patternEndTime,
              pattern: pat,
            ));
          }
        });
      });
    });
    return _cache;
  }

  @override
  double timeAt(BeatFraction bf) {
    return bf.beats / (Project.instance.bpm / 60);
  }

  @override
  double beatsAt(double seconds) {
    return seconds * (Project.instance.bpm / 60);
  }

  void calculateSongLength() {
    length = _patterns.fold(
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
      if (instance.end > length) {
        length = instance.end;
      } else if (instance.end < length) {
        calculateSongLength();
      } else {
        thereAreChanges();
      }
    }, this);
    instance.contentShift = original.contentShift;
    if (instance.end > length) {
      length = instance.end;
    }
    return instance;
  }

  PatternInstance instantiatePattern(PatternData data,
      {BeatFraction start = const BeatFraction(0, 1), int track = 0}) {
    PatternInstance instance;
    instance = PatternInstance(data, start, null, track, () {
      if (instance.end > length) {
        length = instance.end;
      } else if (instance.end < length) {
        calculateSongLength();
      } else {
        thereAreChanges();
      }
    }, this);
    if (instance.end > length) {
      length = instance.end;
    }
    History.perform(PatternsCreationAction(true, [instance]));
    return instance;
  }

  void demoFromBeatGrid(BeatGrid grid) {
    generators.addAll([grid.drums, Oscillator(grid.drums.node.context)]);
    var gridPatternData = grid.data;
    var crashPatternData = PatternData(
      'Crash!',
      {
        0: PatternNotesComponent([
          Note(pitch: Note.octave(Note.D + 1, 5)),
        ])
      },
    );
    for (var i = 0; i < 4; i++) {
      instantiatePattern(gridPatternData, start: BeatFraction(i, 1));
    }
    instantiatePattern(crashPatternData, track: 1);

    var chordPatternData = PatternData(
      'My Little Cheap Oscillator',
      {
        1: PatternNotesComponent([
          // Cmaj7
          _demoChordNote(Note.C, 0),
          _demoChordNote(Note.G, 0),
          _demoChordNote(Note.E, 0),
          _demoChordNote(Note.B, 0),
          // E7
          _demoChordNote(Note.D + 12, 1),
          _demoChordNote(Note.E, 1),
          _demoChordNote(Note.G + 1, 1),
          _demoChordNote(Note.B, 1),
          // Fmaj7
          _demoChordNote(Note.F, 2),
          _demoChordNote(Note.A, 2),
          _demoChordNote(Note.C, 2),
          _demoChordNote(Note.E + 12, 2),
          // G7
          _demoChordNote(Note.G, 3),
          _demoChordNote(Note.B, 3),
          _demoChordNote(Note.F, 3),
          _demoChordNote(Note.D, 3),
        ])
      },
    );

    var src = instantiatePattern(chordPatternData, track: 2)
      ..length = BeatFraction(6, 4);
    History.perform(PatternsCreationAction(true, [
      _clonePattern(src)
        ..start = BeatFraction(6, 4)
        ..contentShift = BeatFraction(8, 4)
        ..length = BeatFraction(2, 4),
      _clonePattern(src)
        ..start = BeatFraction(9, 4)
        ..contentShift = BeatFraction(0, 4)
        ..length = BeatFraction(3, 4),
      _clonePattern(src)
        ..start = BeatFraction(12, 4)
        ..contentShift = BeatFraction(12, 4)
        ..length = BeatFraction(3, 4),
    ]));

    //calculateSongLength();
  }

  Note _demoChordNote(int tone, int start) => Note(
      pitch: Note.octave(tone, 5),
      start: BeatFraction(start, 1),
      length: BeatFraction(1, 1));

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

  @override
  void onBackgroundClick(MouseEvent e) {
    selectedPatterns.forEach((p) => p.selected = false);
  }

  @override
  CssPxVar get beatWidth => pixelsPerBeat;
}

class PlaybackNote {
  final Generator generator;
  final NoteInfo noteInfo;
  final double startInSeconds;
  final double endInSeconds;
  final PatternInstance pattern;

  PlaybackNote({
    @required this.startInSeconds,
    @required this.endInSeconds,
    @required this.noteInfo,
    @required this.generator,
    @required this.pattern,
  });

  @override
  bool operator ==(dynamic other) =>
      generator == other.generator &&
      noteInfo == other.noteInfo &&
      pattern == other.pattern;
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
