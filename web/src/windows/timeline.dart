import 'dart:html';
import 'dart:math';

import 'package:meta/meta.dart';

import '../audio_assembler.dart';
import '../bar_fraction.dart';
import '../beat_grid.dart';
import '../drag.dart';
import '../generators/base.dart';
import '../generators/oscillator/oscillator.dart';
import '../history.dart';
import '../notes.dart';
import '../patterns.dart';
import '../project.dart';
import '../transformable.dart';
import '../utils.dart';
import 'pattern_view.dart';
import 'specific_windows.dart';

class Timeline extends RollOrTimelineWindow<PatternInstance>
    with PlaybackBoxWindow {
  // UI stuff
  static final pixelsPerBeat = CssPxVar('timeline-ppb');
  static final pixelsPerTrack = CssPxVar('timeline-ppt');

  int get _trackCount => 4;
  @override
  int get canvasHeight => (_trackCount * pixelsPerTrack.value).round();

  PlaybackBox _box;

  Timeline() : super(querySelector('#timeline'), 'Timeline') {
    _box = PlaybackBox(
      onUpdateVisuals: (time) {
        drawFg(headPosition.beats, beatsAt(time));
      },
      onStop: () {
        drawFg(headPosition.beats, headPosition.beats);
      },
      getNotes: notesCache,
    );
  }

  Iterable<PlaybackNote> notesCache() {
    var cache = <TimelinePlaybackNote>[];
    items.forEach((pat) {
      var patternStartTime = timeAt(pat.start);
      var patternEndTime = timeAt(pat.end);

      var notes = pat.data.notes();
      notes.forEach((gen, patNotesComp) {
        var swing = patNotesComp.swing;
        patNotesComp.notes.forEach((note) {
          var noteStart = note.start.swingify(swing);
          var noteStartBeats = noteStart.beats - pat.contentShift.beats;

          var noteEndBeats = note.end.beats - pat.contentShift.beats;

          if (noteEndBeats > 0 && noteStartBeats < pat.length.beats) {
            // note must play at SOME point...
            var shift = pat.start - pat.contentShift;
            cache.add(TimelinePlaybackNote(
              noteInfo: note.createInfo(),
              generator: gen,
              startInSeconds: (noteStartBeats > 0)
                  ? timeAt(noteStart + shift)
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
    return cache;
  }

  @override
  double timeAt(BarFraction bf) {
    return bf.beats / (Project.instance.bpm / 60);
  }

  @override
  double beatsAt(double seconds) {
    return seconds * (Project.instance.bpm / 60);
  }

  void calculateSongLength() {
    length = extremeItem((tr) => tr.start + tr.length,
        max: true, onlyDragged: false, ifNone: BarFraction(1, 1));
  }

  void cloneSelectedPatterns() {
    var clones = <PatternInstance>[];
    selectedItems.forEach((p) {
      clones.add(_clonePattern(p)..selected = true);
      p.selected = false;
    });
    History.perform(PatternsCreationAction(this, true, clones));
  }

  PatternInstance _clonePattern(PatternInstance original) {
    PatternInstance instance;
    instance = PatternInstance(
        original.data, original.start, original.length, original.y, this);
    instance.contentShift = original.contentShift;
    if (instance.end > length) {
      length = instance.end;
    }
    return instance;
  }

  PatternInstance instantiatePattern(PatternData data,
      {BarFraction start = const BarFraction.zero(),
      int track = 0,
      bool reversible = false}) {
    PatternInstance instance;
    instance = PatternInstance(data, start, null, track, this);
    if (instance.end > length) {
      length = instance.end;
    }
    History.perform(PatternsCreationAction(this, true, [instance]), reversible);
    return instance;
  }

  void demoFromBeatGrid(BeatGrid grid) {
    var drums = grid.drums;
    var osc = Oscillator(grid.drums.gain.context);
    History.perform(GeneratorCreationAction(true, [drums, osc]), false);
    var gridPatternData = grid.data;
    var crashPatternData = PatternData(
      'Crash!',
      {
        drums: PatternNotesComponent()
          ..addNote(pitch: Note.octave(Note.D + 1, 5), actionReversible: false)
      },
    );
    for (var i = 0; i < 4; i++) {
      instantiatePattern(gridPatternData, start: BarFraction(i, 1));
    }
    instantiatePattern(crashPatternData, track: 1);

    var chordPatternData = PatternData(
      'My Little Cheap Oscillator',
      {osc: PatternNotesComponent()},
    );
    var comp = chordPatternData.component(osc);
    // Cmaj7
    _demoChordNote(comp, Note.C, 0);
    _demoChordNote(comp, Note.G, 0);
    _demoChordNote(comp, Note.E, 0);
    _demoChordNote(comp, Note.B, 0);
    // E7
    _demoChordNote(comp, Note.D + 12, 1);
    _demoChordNote(comp, Note.E, 1);
    _demoChordNote(comp, Note.G + 1, 1);
    _demoChordNote(comp, Note.B, 1);
    // Fmaj7
    _demoChordNote(comp, Note.F, 2);
    _demoChordNote(comp, Note.A, 2);
    _demoChordNote(comp, Note.C, 2);
    _demoChordNote(comp, Note.E + 12, 2);
    // G7
    _demoChordNote(comp, Note.G, 3);
    _demoChordNote(comp, Note.B, 3);
    _demoChordNote(comp, Note.F, 3);
    _demoChordNote(comp, Note.D, 3);
    Project.instance.patternView.patternData = chordPatternData;

    var src = instantiatePattern(chordPatternData, track: 2)
      ..length = BarFraction(6, 4);
    History.perform(
        PatternsCreationAction(this, true, [
          _clonePattern(src)
            ..start = BarFraction(6, 4)
            ..contentShift = BarFraction(8, 4)
            ..length = BarFraction(2, 4),
          _clonePattern(src)
            ..start = BarFraction(9, 4)
            ..contentShift = BarFraction(0, 4)
            ..length = BarFraction(3, 4),
          _clonePattern(src)
            ..start = BarFraction(12, 4)
            ..contentShift = BarFraction(12, 4)
            ..length = BarFraction(3, 4),
        ]),
        false);

    //calculateSongLength();
  }

  void _demoChordNote(PatternNotesComponent comp, int tone, int start) =>
      comp.addNote(
          pitch: Note.octave(tone, 5),
          start: BarFraction(start, 1),
          length: BarFraction(1, 1),
          actionReversible: false);

  @override
  bool handleDelete() {
    if (selectedItems.isNotEmpty) {
      History.perform(PatternsCreationAction(
          this, false, selectedItems.toList(growable: false)));
    }
    return true;
  }

  @override
  bool handleSelectAll() {
    if (items.isNotEmpty) {
      var doSelect = !items.every((pattern) => pattern.selected);
      items.forEach((p) {
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
  CssPxVar get beatWidth => pixelsPerBeat;
  @override
  CssPxVar get cellHeight => pixelsPerTrack;

  @override
  BarFraction get gridSize => BarFraction(1, 8);

  @override
  BarFraction get renderedLength => length + BarFraction(16, 1);

  @override
  PlaybackBoxWindow get bw => this;
  @override
  void drawForeground(double ghost) => drawFg(headPosition.beats, ghost);
  @override
  void drawOrientation() => drawBg();

  @override
  PlaybackBox get box => _box;

  @override
  void onHeadSet(BarFraction head) => windowHeadSet(head);

  @override
  void addItem(BarFraction start, int y) {
    // TODO: implement _addItem
  }
}

class PatternsCreationAction extends AddRemoveAction<PatternInstance> {
  final Timeline timeline;

  PatternsCreationAction(
      this.timeline, bool forward, Iterable<PatternInstance> list)
      : super(forward, list);

  @override
  void doSingle(PatternInstance object) {
    object.setExistence(true);
    timeline.items.add(object);
  }

  @override
  void undoSingle(PatternInstance object) {
    object.setExistence(false);
    timeline.items.remove(object);
  }

  @override
  void onExecuted(bool forward) {
    timeline.calculateSongLength();
  }
}

class PatternInstance extends RollOrTimelineItem<PatternTransform>
    with Transformable<PatternTransform> {
  BarFraction _contentShift = const BarFraction.zero();
  BarFraction get contentShift => _contentShift;
  set contentShift(BarFraction contentShift) {
    if (_contentShift != contentShift) {
      _contentShift = contentShift;
      _draw();
      onTransformed();
    }
  }

  @override
  set length(BarFraction length) {
    super.length = length;
    updateCanvasWidth();
  }

  void updateCanvasWidth() {
    _canvas.width = (length.beats * this.window.beatWidth.value).ceil();
    _draw();
  }

  final PatternData data;

  InputElement _input;
  CanvasElement _canvas;

  static final DragSystem<PatternTransform> _dragSystem = DragSystem();

  PatternInstance(this.data, BarFraction start, BarFraction length, int track,
      Timeline timeline)
      : super(
            timeline
                .query('#patterns')
                .append(DivElement()..className = 'pattern hidden'),
            timeline,
            false) {
    _input = InputElement(type: 'text')
      ..className = 'shy'
      ..value = data.name;

    el
      ..append(_input)
      ..append(
          _canvas = CanvasElement(height: Timeline.pixelsPerTrack.value.ceil()))
      ..append(stretchElem(false, _dragSystem))
      ..append(stretchElem(true, _dragSystem));

    _dragSystem.register(draggable);

    applyTransform(PatternTransform(start, length ?? data.length().ceilTo(2),
        const BarFraction.zero(), track));

    data.listenToEdits((ev) {
      if (!el.classes.contains('hidden')) {
        //print('EDIT: $ev');
        _draw();
        onTransformed();
      }
    });

    setExistence(false);
  }

  @override
  void onMouseDown() {
    Project.instance.patternView.patternData = data;
  }

  void setExistence(bool v) {
    el.classes.toggle('hidden', !v);
  }

  Timeline get timeline => this.window;

  @override
  BarFraction leftStretch(BarFraction diff) {
    // diff minimum: -contentShiftOld
    var minDiff = timeline.extremeItem<BarFraction>(
            (i) => (i as PatternTransform).contentShift,
            max: false) *
        -1;

    if (diff < minDiff) diff = minDiff;

    timeline.selectedItems.forEach((p) {
      p.length = p.draggable.savedVar.length - diff;

      p.start = p.draggable.savedVar.start + diff;
      p.contentShift = p.draggable.savedVar.contentShift + diff;
    });

    return diff;
  }

  @override
  PatternTransform get transform =>
      PatternTransform(start, length, contentShift, y);
  @override
  void applyTransform(PatternTransform transform) {
    contentShift = transform.contentShift;
    super.applyTransform(transform);
    updateCanvasWidth();
    itemPosition();
  }

  void _draw() {
    var ctx = _canvas.context2D;
    ctx.clearRect(0, 0, _canvas.width, _canvas.height);
    var minPitch = 1000;
    var maxPitch = 0;
    data.genNotes.values.forEach((component) {
      component.notes.forEach((n) {
        if (n.y > maxPitch) maxPitch = n.y;
        if (n.y < minPitch) minPitch = n.y;
      });
    });

    var diff = maxPitch - minPitch;
    var noteHeight = Timeline.pixelsPerTrack.value / max(diff + 1, 8);

    ctx.fillStyle = '#fff';

    data.genNotes.values.forEach((component) {
      component.notes.forEach((n) {
        ctx.fillRect(
            Timeline.pixelsPerBeat.value * (n.start - contentShift).beats,
            Timeline.pixelsPerTrack.value - (n.y - minPitch + 1) * noteHeight,
            Timeline.pixelsPerBeat.value * n.length.beats - 1,
            noteHeight);
      });
    });
  }

  @override
  void onTransformed() {
    itemPosition();

    if (end > timeline.length) {
      timeline.length = end;
    } else if (end < timeline.length) {
      timeline.calculateSongLength();
    } else {
      timeline.box.thereAreChanges();
    }
  }

  @override
  void onYSet() {
    el.style.top = cssCalc(y, Timeline.pixelsPerTrack);
  }

  @override
  Transformable<PatternTransform> get tr => this;
}

class TimelinePlaybackNote extends PlaybackNote {
  final PatternInstance pattern;

  TimelinePlaybackNote({
    @required double startInSeconds,
    @required double endInSeconds,
    @required NoteInfo noteInfo,
    @required Generator generator,
    @required this.pattern,
  }) : super(
          startInSeconds: startInSeconds,
          endInSeconds: endInSeconds,
          noteInfo: noteInfo,
          generator: generator,
        );

  @override
  bool operator ==(dynamic other) =>
      generator == other.generator &&
      noteInfo == other.noteInfo &&
      pattern == other.pattern;
}

class PatternTransform extends Transform {
  final BarFraction contentShift;

  PatternTransform(
      BarFraction start, BarFraction length, this.contentShift, int track)
      : super(start, length, track);

  @override
  bool operator ==(dynamic other) => other is PatternTransform
      ? start == other.start &&
          length == other.length &&
          contentShift == other.contentShift &&
          y == other.y
      : false;

  @override
  PatternTransform operator +(dynamic o) => PatternTransform(
        start + o.start,
        length + o.length,
        contentShift + o.contentShift,
        y + o.y,
      );

  @override
  PatternTransform operator -(dynamic o) => PatternTransform(
        start - o.start,
        length - o.length,
        contentShift - o.contentShift,
        y - o.y,
      );
}
