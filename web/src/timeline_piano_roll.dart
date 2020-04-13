import 'dart:html';
import 'dart:math';

import 'package:meta/meta.dart';

import 'beat_grid.dart';
import 'drag.dart';
import 'generators/base.dart';
import 'generators/oscillator/oscillator.dart';
import 'history.dart';
import 'notes.dart';
import 'beat_fraction.dart';
import 'patterns.dart';
import 'project.dart';
import 'utils.dart';
import 'windows.dart';
import 'audio_assembler.dart';

abstract class _RollOrTimelineWindow<I extends _RollOrTimelineItem>
    extends Window {
  CssPxVar get _beatWidth;
  static final CssPxVar railHeight = CssPxVar('rail-height');

  BeatFraction _length = BeatFraction(4, 4);
  BeatFraction get length => _length;
  BeatFraction get renderedLength;
  set length(BeatFraction l) {
    var min = BeatFraction(4, 4);
    if (l < min) l = min;
    _length = l;
    box.length = timeAt(l);
    _drawOrientation();
    box.thereAreChanges();
    if (headPosition > renderedLength) {
      headPosition =
          BeatFraction.washy(headPosition.beats % renderedLength.beats);
    }
  }

  BeatFraction _headPosition = BeatFraction(0, 1);
  BeatFraction get headPosition => _headPosition;
  set headPosition(BeatFraction headPosition) {
    if (headPosition > length) {
      headPosition = length;
    } else if (headPosition.numerator < 0) {
      headPosition = BeatFraction(0, 4);
    }
    if (headPosition != _headPosition) {
      _headPosition = headPosition;
      query('#head').style.left = cssCalc(headPosition.beats, _beatWidth);
      _drawForeground(headPosition.beats);
      box.position = timeAt(headPosition);
    }
  }

  CanvasElement _canvasFg;
  CanvasElement _canvasBg;

  PlaybackBox _box;
  PlaybackBox get box => _box;

  HtmlElement get _scrollArea => query('.right');

  final List<I> _items = [];
  Iterable<I> get selectedItems => _items.where((p) => p.selected);

  _RollOrTimelineWindow(HtmlElement element, String title)
      : super(element, title) {
    _canvasBg = query('#background')
      ..onClick.listen((e) {
        selectedItems.forEach((i) => i.selected = false);
      });
    _canvasFg = query('#foreground');
    _drawOrientation();
    _box = PlaybackBox(
      onUpdateVisuals: (time) {
        _drawForeground(beatsAt(time));
      },
      onStop: () {
        _drawForeground(headPosition.beats);
      },
      getNotes: notesCache,
    );

    _scrollArea.onScroll.listen((ev) => _onScroll());
    _onScroll();

    var handle = query('#head .handle');
    query('.rail').onMouseDown.listen((e) {
      handle.classes.toggle('dragged', true);
      _playheadFromPixels(e);
      var sub = document.onMouseMove.listen(_playheadFromPixels);
      var sub2;
      sub2 = document.onMouseUp.listen((e) {
        handle.classes.toggle('dragged', false);
        sub.cancel();
        sub2.cancel();
      });
    });
  }

  void _onScroll() {
    //e.style.top = (-query('#right').scrollTop).toString() + 'px';
    query('#head').parent.style.left =
        (-_scrollArea.scrollLeft).toString() + 'px';
    query('.left').style.top = (-_scrollArea.scrollTop).toString() + 'px';
  }

  void _playheadFromPixels(MouseEvent e) {
    headPosition = BeatFraction(
        ((e.client.x - query('.rail').documentOffset.x) / _beatWidth.value)
            .floor(),
        4);
  }

  void onNewTempo() {
    box.handleNewTempo(timeAt(length));
  }

  void thereAreChanges() {
    box.thereAreChanges();
  }

  void _drawForeground(double ghost) {
    var l = renderedLength;
    _canvasFg.width = (l.beats * _beatWidth.value).round();
    _canvasFg.height = _canvasHeight;

    var ctx = _canvasFg.context2D;
    ctx.clearRect(0, 0, _canvasFg.width, _canvasFg.height);

    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.5;
    var x = headPosition.beats * _beatWidth.value;
    ctx.moveTo(x, 0);
    ctx.lineTo(x, _canvasFg.height);

    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.5;
    x = ghost * _beatWidth.value;
    ctx.moveTo(x, 0);
    ctx.lineTo(x, _canvasFg.height);

    ctx.stroke();
  }

  BeatFraction get _gridSize;

  void _drawOrientation() {
    _canvasBg.width = (renderedLength.beats * _beatWidth.value).round();
    _canvasBg.height = _canvasHeight;

    var ctx = _canvasBg.context2D;
    ctx.clearRect(0, 0, _canvasBg.width, _canvasBg.height);

    _drawPreOrientation(ctx);

    ctx.strokeStyle = '#fff4';
    for (var b = 0.0; b <= renderedLength.beats; b += _gridSize.beats) {
      var x = (b * _beatWidth.value).round() - 0.5;
      ctx.moveTo(x, 0);
      ctx.lineTo(x, _canvasBg.height);
    }
    ctx.stroke();

    ctx.fillStyle = '#0008';
    ctx.fillRect(length.beats * _beatWidth.value, 0,
        (renderedLength - length).beats * _beatWidth.value, _canvasBg.height);
  }

  void _drawPreOrientation(CanvasRenderingContext2D ctx) {}

  int get _canvasHeight;

  double timeAt(BeatFraction songLength);

  double beatsAt(double time);

  Iterable<PlaybackNote> notesCache();
}

abstract class _RollOrTimelineItem {
  final _RollOrTimelineWindow window;
  HtmlElement el;

  BeatFraction _start;
  BeatFraction get start => _start;
  set start(BeatFraction start) {
    if (_silentStart(start)) _onUpdate();
  }

  bool _silentStart(BeatFraction start) {
    var oldStart = _start;
    _start = start.beats >= 0 ? start : BeatFraction(0, 1);
    el.style.left = cssCalc(_start.beats, window._beatWidth);
    return _start != oldStart;
  }

  void _onUpdate();

  BeatFraction _length;
  BeatFraction get length => _length;
  set length(BeatFraction length) {
    if (_silentLength(length)) {
      _onUpdate();
    }
  }

  bool _silentLength(BeatFraction length) {
    var oldLength = _length;
    _length = length.beats >= 1 ? length : BeatFraction(1, 4);
    el.style.width = cssCalc(_length.beats, window._beatWidth);
    if (_length != oldLength) {
      _onWidthSet();
      return true;
    }
    return false;
  }

  void _onWidthSet() {}

  BeatFraction get end => start + length;

  bool _selected = false;
  bool get selected => _selected;
  set selected(bool v) {
    _selected = v;
    el.classes.toggle('selected', v);
  }

  _RollOrTimelineItem(this.window);
}

// TIMELINE

class Timeline extends _RollOrTimelineWindow<_PatternInstance> {
  // UI stuff
  static final pixelsPerBeat = CssPxVar('timeline-ppb');
  static final pixelsPerTrack = CssPxVar('timeline-ppt');

  int get _trackCount => 4;
  @override
  int get _canvasHeight => (_trackCount * pixelsPerTrack.value).round();

  final List<Generator> generators = [];

  Timeline() : super(querySelector('#timeline'), 'Timeline');

  @override
  Iterable<PlaybackNote> notesCache() {
    var _cache = <TimelinePlaybackNote>[];
    _items.forEach((pat) {
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
            _cache.add(TimelinePlaybackNote(
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
    length = _items.fold(
        BeatFraction.washy(0), (v, pat) => pat.end > v ? pat.end : v);
  }

  void cloneSelectedPatterns() {
    var clones = <_PatternInstance>[];
    selectedItems.forEach((p) {
      clones.add(_clonePattern(p)..selected = true);
      p.selected = false;
    });
    History.perform(PatternsCreationAction(this, true, clones));
  }

  _PatternInstance _clonePattern(_PatternInstance original) {
    _PatternInstance instance;
    instance = _PatternInstance(
        original.data, original.start, original.length, original.track, this);
    instance.contentShift = original.contentShift;
    if (instance.end > length) {
      length = instance.end;
    }
    return instance;
  }

  _PatternInstance instantiatePattern(PatternData data,
      {BeatFraction start = const BeatFraction(0, 1), int track = 0}) {
    _PatternInstance instance;
    instance = _PatternInstance(data, start, null, track, this);
    if (instance.end > length) {
      length = instance.end;
    }
    History.perform(PatternsCreationAction(this, true, [instance]));
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
    Project.instance.pianoRoll.patternData = chordPatternData;

    var src = instantiatePattern(chordPatternData, track: 2)
      ..length = BeatFraction(6, 4);
    History.perform(PatternsCreationAction(this, true, [
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
    if (selectedItems.isNotEmpty) {
      History.perform(PatternsCreationAction(
          this, false, selectedItems.toList(growable: false)));
    }
    return true;
  }

  @override
  bool handleSelectAll() {
    if (_items.isNotEmpty) {
      var doSelect = !_items.every((pattern) => pattern.selected);
      _items.forEach((p) {
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
  CssPxVar get _beatWidth => pixelsPerBeat;

  @override
  BeatFraction get _gridSize => BeatFraction(1, 4);

  @override
  BeatFraction get renderedLength => BeatFraction(16, 1);
}

class PatternsCreationAction extends AddRemoveAction<_PatternInstance> {
  final Timeline timeline;

  PatternsCreationAction(
      this.timeline, bool forward, Iterable<_PatternInstance> list)
      : super(forward, list);

  @override
  void doSingle(_PatternInstance object) {
    object.setExistence(true);
    timeline._items.add(object);
  }

  @override
  void undoSingle(_PatternInstance object) {
    object.setExistence(false);
    timeline._items.remove(object);
  }

  @override
  void onExecuted(bool forward) {
    timeline.calculateSongLength();
  }
}

class _PatternInstance extends _RollOrTimelineItem {
  BeatFraction _contentShift = BeatFraction(0, 1);
  BeatFraction get contentShift => _contentShift;
  set contentShift(BeatFraction contentShift) {
    if (_contentShift != contentShift) {
      _contentShift = contentShift;
      _draw();
      _onUpdate();
    }
  }

  @override
  set length(BeatFraction length) {
    super.length = length;
    _draw();
  }

  @override
  void _onWidthSet() {
    _canvas.width = (_length.beats * this.window._beatWidth.value).ceil();
  }

  int _track;
  int get track => _track;
  set track(int track) {
    _track = max(0, track);
    el.style.top = cssCalc(_track, Timeline.pixelsPerTrack);
  }

  final PatternData data;

  InputElement _input;
  CanvasElement _canvas;

  Draggable<PatternTransform> _draggable;
  static final DragSystem<PatternTransform> _dragSystem = DragSystem();

  _PatternInstance(this.data, BeatFraction start, BeatFraction length,
      int track, Timeline timeline)
      : super(timeline) {
    _input = InputElement(type: 'text')
      ..className = 'shy'
      ..value = data.name;

    el = timeline.query('#patterns').append(DivElement()
      ..className = 'pattern hidden'
      ..append(_input)
      ..append(
          _canvas = CanvasElement(height: Timeline.pixelsPerTrack.value.ceil()))
      ..append(stretchElem(timeline, false))
      ..append(stretchElem(timeline, true)));

    el.onMouseDown.listen((e) {
      if (!selected) {
        if (!e.shiftKey) {
          timeline.selectedItems.forEach((p) => p.selected = false);
        }
        selected = true;
      }
    });

    _draggable =
        Draggable<PatternTransform>(el, () => transform, (tr, pixelOff, ev) {
      var xDiff =
          BeatFraction((pixelOff.x / timeline._beatWidth.value).round(), 4);
      var minXDiff = timeline.selectedItems.fold<BeatFraction>(
              tr.start,
              (v, p) => p._draggable.savedVar.start < v
                  ? p._draggable.savedVar.start
                  : v) *
          -1;
      if (xDiff < minXDiff) {
        xDiff = minXDiff;
      }
      var minYDiff = -timeline.selectedItems.fold<num>(
          tr.track,
          (v, p) => p._draggable.savedVar.track < v
              ? p._draggable.savedVar.track
              : v);
      var yDiff = max(
          minYDiff, (pixelOff.y / Timeline.pixelsPerTrack.value + 0.5).floor());

      timeline.selectedItems.forEach((p) {
        p.start = p._draggable.savedVar.start + xDiff;
        p.track = p._draggable.savedVar.track + yDiff;
      });

      if (ev.detail == 1) {
        if (tr != transform) {
          History.registerDoneAction(PatternTransformAction(
              timeline.selectedItems.toList(growable: false), transform - tr));
        } else if (pixelOff.x == 0 && pixelOff.y == 0) {
          if (!ev.shiftKey) {
            timeline.selectedItems.forEach((p) => p.selected = false);
          }
          selected = true;
        }
      }
    });
    _dragSystem.register(_draggable);

    this.track = track;
    _silentStart(start);
    _silentLength(length ?? data.length().ceilTo(2));
    _draw();

    data.listenToEdits((ev) {
      if (!el.classes.contains('hidden')) {
        //print('EDIT: $ev');
        _draw();
        _onUpdate();
      }
    });

    setExistence(false);
  }

  void setExistence(bool v) {
    el.classes.toggle('hidden', !v);
  }

  DivElement stretchElem(Timeline timeline, bool right) {
    var out = DivElement()..className = 'stretch ${right ? 'right' : 'left'}';
    _dragSystem.register(Draggable<PatternTransform>(
      out,
      () => transform,
      (tr, off, ev) {
        var diff =
            BeatFraction((off.x / Timeline.pixelsPerBeat.value).round(), 4);
        var maxDiff = timeline.selectedItems.fold<BeatFraction>(
                tr.length,
                (v, p) => p._draggable.savedVar.length < v
                    ? p._draggable.savedVar.length
                    : v) -
            BeatFraction(1, 4);
        if (right) {
          if (diff < maxDiff * -1) diff = maxDiff * -1;
          timeline.selectedItems.forEach((p) {
            p.length = p._draggable.savedVar.length + diff;
          });
        } else {
          // diff maximum: lengthOld - 1
          if (diff > maxDiff) diff = maxDiff;

          // diff minimum: -contentShiftOld
          var minDiff = timeline.selectedItems.fold<BeatFraction>(
                  tr.contentShift,
                  (v, p) => p._draggable.savedVar.contentShift > v
                      ? p._draggable.savedVar.contentShift
                      : v) *
              -1;
          if (diff < minDiff) diff = minDiff;

          timeline.selectedItems.forEach((p) {
            if (p._silentLength(p._draggable.savedVar.length - diff)) {
              p._silentStart(p._draggable.savedVar.start + diff);
              p.contentShift = p._draggable.savedVar.contentShift + diff;
              p._draw();
            }
          });
        }
        if (diff.numerator == 0) return;
        if (ev.detail == 1) {
          // register reversible action
          History.registerDoneAction(PatternTransformAction(
              timeline.selectedItems.toList(growable: false), transform - tr));
        }
      },
    ));
    return out;
  }

  PatternTransform get transform =>
      PatternTransform(start, length, contentShift, track);

  void _draw() {
    var ctx = _canvas.context2D;
    ctx.clearRect(0, 0, _canvas.width, _canvas.height);
    var minPitch = 1000;
    var maxPitch = 0;
    data.genNotes.values.forEach((component) {
      component.notes.forEach((n) {
        if (n.coarsePitch > maxPitch) maxPitch = n.coarsePitch;
        if (n.coarsePitch < minPitch) minPitch = n.coarsePitch;
      });
    });

    var diff = maxPitch - minPitch;
    var noteHeight = Timeline.pixelsPerTrack.value / max(diff + 1, 8);

    ctx.fillStyle = '#fff';

    data.genNotes.values.forEach((component) {
      component.notes.forEach((n) {
        ctx.fillRect(
            Timeline.pixelsPerBeat.value * (n.start - contentShift).beats,
            Timeline.pixelsPerTrack.value -
                (n.coarsePitch - minPitch + 1) * noteHeight,
            Timeline.pixelsPerBeat.value * n.length.beats - 1,
            noteHeight);
      });
    });
  }

  void applyTransform(PatternTransform transform) {
    start = transform.start;
    length = transform.length;
    contentShift = transform.contentShift;
    track = transform.track;
  }

  @override
  void _onUpdate() {
    var timeline = this.window as Timeline;
    if (end > timeline.length) {
      timeline.length = end;
    } else if (end < timeline.length) {
      timeline.calculateSongLength();
    } else {
      timeline.thereAreChanges();
    }
  }
}

class PatternTransform {
  final BeatFraction start;
  final BeatFraction length;
  final BeatFraction contentShift;
  final int track;

  PatternTransform(this.start, this.length, this.contentShift, this.track);

  @override
  bool operator ==(dynamic other) => other is PatternTransform
      ? start == other.start &&
          length == other.length &&
          contentShift == other.contentShift &&
          track == other.track
      : false;

  PatternTransform operator +(PatternTransform o) => PatternTransform(
        start + o.start,
        length + o.length,
        contentShift + o.contentShift,
        track + o.track,
      );

  PatternTransform operator -(PatternTransform o) => PatternTransform(
        start - o.start,
        length - o.length,
        contentShift - o.contentShift,
        track - o.track,
      );
}

class PatternTransformAction extends MultipleAction<_PatternInstance> {
  final PatternTransform diff;

  PatternTransformAction(Iterable<_PatternInstance> patterns, this.diff)
      : super(patterns);

  @override
  void doSingle(_PatternInstance object) {
    object.applyTransform(object.transform + diff);
  }

  @override
  void undoSingle(_PatternInstance object) {
    object.applyTransform(object.transform - diff);
  }
}

class TimelinePlaybackNote extends PlaybackNote {
  final _PatternInstance pattern;

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

// PIANO ROLL

class PianoRoll extends _RollOrTimelineWindow<PianoRollNote> {
  static final pixelsPerKey = CssPxVar('piano-roll-ppk');
  static final pixelsPerBeat = CssPxVar('piano-roll-ppb');

  PatternData _patternData;
  PatternData get patternData => _patternData;
  set patternData(PatternData patternData) {
    if (_patternData != patternData) {
      _patternData = patternData;
      reloadData();
    }
  }

  int _componentIndex = 1;
  int get componentIndex => _componentIndex;
  set componentIndex(int componentIndex) {
    if (_componentIndex != componentIndex) {
      _componentIndex = componentIndex;
      reloadData();
    }
  }

  final List<_PatternInstance> _patterns = [];
  Iterable<_PatternInstance> get selectedPatterns =>
      _patterns.where((p) => p.selected);

  PianoRoll() : super(querySelector('#pianoRoll'), 'Piano Roll') {
    _buildPianoKeys();
  }

  void reloadData() {
    _items.forEach((n) => n._dispose());
    _items.clear();
    length = BeatFraction(4, 1);
  }

  void _buildPianoKeys() {
    var parent = query('.piano-keys');
    for (var octave = 6; octave >= 4; octave--) {
      _buildKey('H', octave, true, parent);
      _buildKey('A#', octave, false, parent);
      _buildKey('A', octave, true, parent);
      _buildKey('G#', octave, false, parent);
      _buildKey('G', octave, true, parent);
      _buildKey('F#', octave, false, parent);
      _buildKey('F', octave, true, parent, true);
      _buildKey('E', octave, true, parent);
      _buildKey('D#', octave, false, parent);
      _buildKey('D', octave, true, parent);
      _buildKey('C#', octave, false, parent);
      _buildKey('C', octave, true, parent, true);
    }
  }

  void _buildKey(String name, int octave, bool white, HtmlElement parent,
      [bool splitBottom = false]) {
    parent.append(DivElement()
      ..className =
          (white ? 'white' : 'black') + (splitBottom ? ' split-bottom' : '')
      ..text = '$name$octave');
  }

  @override
  CssPxVar get _beatWidth => pixelsPerBeat;

  @override
  int get _canvasHeight => (4 * 12 * pixelsPerKey.value).round();

  @override
  Iterable<PlaybackNote> notesCache() {
    var _cache = <PlaybackNote>[];
    patternData.genNotes.forEach((i, comp) {
      comp.notesWithSwing.forEach((note) {
        var shift = BeatFraction.washy(0);
        _cache.add(PlaybackNote(
          noteInfo: note.info,
          generator: Project.instance.timeline.generators[i],
          startInSeconds: timeAt(note.start + shift),
          endInSeconds: timeAt(note.end + shift),
        ));
      });
    });
    return _cache;
  }

  @override
  void _drawPreOrientation(CanvasRenderingContext2D ctx) {
    ctx.fillStyle = '#0005';
    ctx.strokeStyle = '#222';
    for (var o = 0; o <= 3; o++) {
      var i = o * 12;
      _drawKey(ctx, i + 1);
      _drawKey(ctx, i + 3);
      _drawKey(ctx, i + 5);
      _drawLine(ctx, i + 7);
      _drawKey(ctx, i + 8);
      _drawKey(ctx, i + 10);
      _drawLine(ctx, i + 12);
    }
    ctx.stroke();
  }

  void _drawKey(CanvasRenderingContext2D ctx, int i) {
    var y = i * pixelsPerKey.value + _RollOrTimelineWindow.railHeight.value;
    ctx.fillRect(0, y, _canvasBg.width, pixelsPerKey.value);
  }

  void _drawLine(CanvasRenderingContext2D ctx, int i) {
    var y =
        i * pixelsPerKey.value + _RollOrTimelineWindow.railHeight.value - 0.5;
    ctx.moveTo(0, y);
    ctx.lineTo(_canvasBg.width, y);
  }

  @override
  double timeAt(BeatFraction bf) {
    return bf.beats / (Project.instance.bpm / 60);
  }

  @override
  double beatsAt(double seconds) {
    return seconds * (Project.instance.bpm / 60);
  }

  @override
  BeatFraction get _gridSize => BeatFraction(1, 4);

  @override
  BeatFraction get renderedLength => length + BeatFraction(4, 1);
}

class PianoRollNote extends _RollOrTimelineItem {
  PianoRoll get pianoRoll => window as PianoRoll;

  PianoRollNote(PianoRoll window) : super(window);

  void _dispose() {
    el.remove();
  }

  @override
  void _onUpdate() {
    // TODO: implement _onUpdate
  }
}
