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
import 'pattern_view.dart';
import 'patterns.dart';
import 'project.dart';
import 'utils.dart';
import 'windows.dart';
import 'audio_assembler.dart';

mixin PlaybackBoxWindow on Window {
  PlaybackBox get box;

  BeatFraction get length => _length;
  BeatFraction _length = BeatFraction(4, 4);
  set length(BeatFraction l) {
    var min = BeatFraction(4, 4);
    if (l < min) l = min;
    _length = l;
    box.length = timeAt(l);
    drawOrientation();
    box.thereAreChanges();
    if (headPosition > length) {
      headPosition = BeatFraction.washy(headPosition.beats % length.beats);
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
      onHeadSet(headPosition);
      drawForeground(headPosition.beats);
      box.position = timeAt(headPosition);
    }
  }

  void onHeadSet(BeatFraction head);
  void drawForeground(double ghost);
  void drawOrientation();

  double timeAt(BeatFraction songLength);
  double beatsAt(double time);

  void onNewTempo() {
    box.handleNewTempo(timeAt(length));
  }
}

abstract class _RollOrTimelineWindow<I extends _RollOrTimelineItem>
    extends Window {
  CssPxVar get _cellHeight;
  static final CssPxVar railHeight = CssPxVar('rail-height');

  BeatFraction get renderedLength;

  CanvasElement _canvasFg;
  CanvasElement _canvasBg;

  HtmlElement get _scrollArea => query('.right');

  final List<I> _items = [];
  Iterable<I> get selectedItems => _items.where((p) => p.selected);

  _RollOrTimelineWindow(HtmlElement element, String title)
      : super(element, title) {
    _canvasBg = query('#background')
      ..onMouseDown.listen((e) {
        if (!(e.shiftKey || e.ctrlKey)) {
          if (selectedItems.isNotEmpty) {
            selectedItems.forEach((i) => i.selected = false);
          } else {
            _addItem(BeatFraction.floor(e.offset.x / beatWidth.value, gridSize),
                ((e.offset.y - railHeight.value) / _cellHeight.value).floor());
          }
        }
      });
    _canvasFg = query('#foreground');
    drawBg();

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

  void _addItem(BeatFraction start, int y);

  void _onScroll() {
    //e.style.top = (-query('#right').scrollTop).toString() + 'px';
    query('#head').parent.style.left =
        (-_scrollArea.scrollLeft).toString() + 'px';
    query('.left').style.top = (-_scrollArea.scrollTop).toString() + 'px';
  }

  PlaybackBoxWindow get bw;

  void _playheadFromPixels(MouseEvent e) {
    bw.headPosition = BeatFraction.round(
        (e.page.x - query('.rail').documentOffset.x) / beatWidth.value,
        gridSize);
  }

  T _extreme<T>(dynamic Function(Transform tr) variable,
      {@required bool max, bool onlyDragged = true, T ifNone}) {
    var list = onlyDragged ? selectedItems : _items;
    return extreme<I, T>(
        list, (item) => variable(_getTransform(item, onlyDragged)),
        max: max, ifNone: ifNone);
  }

  Transform _getTransform(I item, bool dragged) =>
      dragged ? item._draggable.savedVar : item.transform;

  void drawFg(double head, double ghost) {
    var l = renderedLength;
    _canvasFg.width = (l.beats * beatWidth.value).round();
    _canvasFg.height = _canvasHeight + railHeight.value.round();

    var ctx = _canvasFg.context2D;
    ctx.clearRect(0, 0, _canvasFg.width, _canvasFg.height);

    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.5;
    var x = head * beatWidth.value;
    ctx.moveTo(x, 0);
    ctx.lineTo(x, _canvasFg.height);

    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.5;
    x = ghost * beatWidth.value;
    ctx.moveTo(x, 0);
    ctx.lineTo(x, _canvasFg.height);

    ctx.stroke();
  }

  BeatFraction get gridSize;
  CssPxVar get beatWidth;

  void drawBg() {
    _canvasBg.width = (renderedLength.beats * beatWidth.value).round();
    _canvasBg.height = _canvasHeight + railHeight.value.round();

    var ctx = _canvasBg.context2D;
    ctx.clearRect(0, 0, _canvasBg.width, _canvasBg.height);

    _drawPreOrientation(ctx);

    ctx.strokeStyle = '#fff4';
    for (var b = 0.0; b <= renderedLength.beats; b += gridSize.beats) {
      var x = (b * beatWidth.value).round() - 0.5;
      ctx.moveTo(x, 0);
      ctx.lineTo(x, _canvasBg.height);
    }
    ctx.stroke();

    ctx.fillStyle = '#0008';
    ctx.fillRect(bw.length.beats * beatWidth.value, 0,
        (renderedLength - bw.length).beats * beatWidth.value, _canvasBg.height);
  }

  void _drawPreOrientation(CanvasRenderingContext2D ctx) {}

  int get _canvasHeight;

  void windowHeadSet(BeatFraction head) {
    query('#head').style.left = cssCalc(head.beats, beatWidth);
  }
}

abstract class _RollOrTimelineItem<T extends Transform> {
  final _RollOrTimelineWindow window;
  final HtmlElement el;

  BeatFraction _start;
  BeatFraction get start => _start;
  set start(BeatFraction start) {
    if (_silentStart(start)) _onUpdate();
  }

  bool _silentStart(BeatFraction start) {
    var oldStart = _start;
    _start = start.beats >= 0 ? start : BeatFraction(0, 1);
    el.style.left = cssCalc(_start.beats, window.beatWidth);
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
    el.style.width = cssCalc(_length.beats, window.beatWidth);
    if (_length != oldLength) {
      _onWidthSet();
      return true;
    }
    return false;
  }

  void _onWidthSet() {}

  int _y;
  int get y => _y;
  set y(int y) {
    if (_y != y) {
      _y = y;
      _onYSet();
      _onUpdate();
    }
  }

  void _onYSet() {}

  BeatFraction get end => start + length;

  bool _selected = false;
  bool get selected => _selected;
  set selected(bool v) {
    _selected = v;
    el.classes.toggle('selected', v);
  }

  Draggable<T> _draggable;
  T get transform => Transform(start, length, y) as T;
  void applyTransform(T transform) {
    start = transform.start;
    length = transform.length;
    y = transform.y;
  }

  _RollOrTimelineItem(this.el, this.window) {
    el.onMouseDown.listen((e) {
      if (!selected) {
        if (!e.shiftKey) {
          window.selectedItems.forEach((p) => p.selected = false);
        }
        selected = true;
      }
    });
    _draggable = Draggable<T>(el, () => transform, (tr, pixelOff, ev) {
      var xDiff = BeatFraction.round(
          pixelOff.x / window.beatWidth.value, window.gridSize);
      var minXDiff = window._extreme((tr) => tr.start, max: false) * -1;
      if (xDiff < minXDiff) {
        xDiff = minXDiff;
      }
      var minYDiff = -window._extreme<num>((tr) => tr.y, max: false);
      var yDiff =
          max(minYDiff, (pixelOff.y / window._cellHeight.value + 0.5).floor());

      window.selectedItems.forEach((p) {
        p.start = p._draggable.savedVar.start + xDiff;
        p.y = p._draggable.savedVar.y + yDiff;
      });

      if (ev.detail == 1) {
        if (tr != transform) {
          History.registerDoneAction(TransformAction(
              window.selectedItems.toList(growable: false), transform - tr));
        } else if (pixelOff.x == 0 && pixelOff.y == 0) {
          if (!ev.shiftKey) {
            window.selectedItems.forEach((p) => p.selected = false);
          }
          selected = true;
        }
      }
    });
  }

  DivElement stretchElem(bool right, DragSystem<T> dragSystem) {
    var out = DivElement()..className = 'stretch ${right ? 'right' : 'left'}';
    dragSystem.register(Draggable<T>(
      out,
      () => transform,
      (tr, off, ev) {
        var diff =
            BeatFraction.round(off.x / window.beatWidth.value, window.gridSize);
        // diff maximum: lengthOld - 1
        var maxDiff =
            window._extreme((i) => i.length, max: false) - window.gridSize;
        if (right) {
          if (diff < maxDiff * -1) diff = maxDiff * -1;
          window.selectedItems.forEach((p) {
            p.length = p._draggable.savedVar.length + diff;
          });
        } else {
          if (diff > maxDiff) diff = maxDiff;
          diff = _leftStretch(diff);
        }
        if (diff.numerator == 0) return;
        if (ev.detail == 1) {
          // register reversible action
          History.registerDoneAction(TransformAction(
              window.selectedItems.toList(growable: false), transform - tr));
        }
      },
    ));
    return out;
  }

  BeatFraction _leftStretch(BeatFraction diff) {
    var minDiff = window._extreme((i) => i.start, max: false) * -1;
    if (diff < minDiff) diff = minDiff;

    window.selectedItems.forEach((p) {
      if (p._silentLength(p._draggable.savedVar.length - diff)) {
        p.start = p._draggable.savedVar.start + diff;
      }
    });

    return diff;
  }
}

// TIMELINE

class Timeline extends _RollOrTimelineWindow<_PatternInstance>
    with PlaybackBoxWindow {
  // UI stuff
  static final pixelsPerBeat = CssPxVar('timeline-ppb');
  static final pixelsPerTrack = CssPxVar('timeline-ppt');

  int get _trackCount => 4;
  @override
  int get _canvasHeight => (_trackCount * pixelsPerTrack.value).round();

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
    var _cache = <TimelinePlaybackNote>[];
    _items.forEach((pat) {
      var patternStartTime = timeAt(pat.start);
      var patternEndTime = timeAt(pat.end);

      var notes = pat.data.notes();
      notes.forEach((gen, patNotesComp) {
        var swing = patNotesComp.swing;
        patNotesComp.notes.forEach((note) {
          var noteStart = note.start.swingify(swing);
          var noteStartBeats = noteStart.beats - pat.contentShift.beats;

          var noteEndBeats = note.end.beats - pat.contentShift.beats;

          if (noteEndBeats >= 0 && noteStartBeats < pat.length.beats) {
            // note must play at SOME point...
            var shift = pat.start - pat.contentShift;
            _cache.add(TimelinePlaybackNote(
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
    length = _extreme((tr) => tr.start + tr.length,
        max: true, onlyDragged: false, ifNone: BeatFraction(1, 1));
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
        original.data, original.start, original.length, original.y, this);
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
    var drums = grid.drums;
    var osc = Oscillator(grid.drums.gain.context);
    History.perform(GeneratorCreationAction(true, [drums, osc]));
    var gridPatternData = grid.data;
    var crashPatternData = PatternData(
      'Crash!',
      {
        drums: PatternNotesComponent([
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
        osc: PatternNotesComponent([
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
    Project.instance.patternView.patternData = chordPatternData;

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
  CssPxVar get beatWidth => pixelsPerBeat;
  @override
  CssPxVar get _cellHeight => pixelsPerTrack;

  @override
  BeatFraction get gridSize => BeatFraction(1, 4);

  @override
  BeatFraction get renderedLength => length + BeatFraction(16, 1);

  @override
  PlaybackBoxWindow get bw => this;
  @override
  void drawForeground(double ghost) => drawFg(headPosition.beats, ghost);
  @override
  void drawOrientation() => drawBg();

  @override
  PlaybackBox get box => _box;

  @override
  void onHeadSet(BeatFraction head) => windowHeadSet(head);

  @override
  void _addItem(BeatFraction start, int y) {
    // TODO: implement _addItem
  }
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

class _PatternInstance extends _RollOrTimelineItem<PatternTransform> {
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
    _canvas.width = (_length.beats * this.window.beatWidth.value).ceil();
  }

  final PatternData data;

  InputElement _input;
  CanvasElement _canvas;

  static final DragSystem<PatternTransform> _dragSystem = DragSystem();

  _PatternInstance(this.data, BeatFraction start, BeatFraction length,
      int track, Timeline timeline)
      : super(
            timeline
                .query('#patterns')
                .append(DivElement()..className = 'pattern hidden'),
            timeline) {
    _input = InputElement(type: 'text')
      ..className = 'shy'
      ..value = data.name;

    el
      ..append(_input)
      ..append(
          _canvas = CanvasElement(height: Timeline.pixelsPerTrack.value.ceil()))
      ..append(stretchElem(false, _dragSystem))
      ..append(stretchElem(true, _dragSystem));

    _dragSystem.register(_draggable);

    _silentStart(start);
    _silentLength(length ?? data.length().ceilTo(2));
    y = track;
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

  Timeline get timeline => this.window;

  @override
  BeatFraction _leftStretch(BeatFraction diff) {
    // diff minimum: -contentShiftOld
    var minDiff = timeline._extreme<BeatFraction>(
            (i) => (i as PatternTransform).contentShift,
            max: true) *
        -1;

    if (diff < minDiff) diff = minDiff;

    timeline.selectedItems.forEach((p) {
      if (p._silentLength(p._draggable.savedVar.length - diff)) {
        p._silentStart(p._draggable.savedVar.start + diff);
        p.contentShift = p._draggable.savedVar.contentShift + diff;
        p._draw();
      }
    });

    return diff;
  }

  @override
  PatternTransform get transform =>
      PatternTransform(start, length, contentShift, y);

  void _draw() {
    var ctx = _canvas.context2D;
    ctx.clearRect(0, 0, _canvas.width, _canvas.height);
    var minPitch = 1000;
    var maxPitch = 0;
    data.genNotes.values.forEach((component) {
      component.notes.forEach((n) {
        if (n.pitch > maxPitch) maxPitch = n.pitch;
        if (n.pitch < minPitch) minPitch = n.pitch;
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
                (n.pitch - minPitch + 1) * noteHeight,
            Timeline.pixelsPerBeat.value * n.length.beats - 1,
            noteHeight);
      });
    });
  }

  @override
  void applyTransform(PatternTransform transform) {
    super.applyTransform(transform);
    contentShift = transform.contentShift;
    y = transform.y;
  }

  @override
  void _onUpdate() {
    if (end > timeline.length) {
      timeline.length = end;
    } else if (end < timeline.length) {
      timeline.calculateSongLength();
    } else {
      timeline.box.thereAreChanges();
    }
  }

  @override
  void _onYSet() {
    el.style.top = cssCalc(_y, Timeline.pixelsPerTrack);
  }
}

class Transform {
  final BeatFraction start;
  final BeatFraction length;
  final int y;

  Transform(this.start, this.length, this.y);

  @override
  bool operator ==(dynamic other) => other is Transform
      ? start == other.start && length == other.length && y == other.y
      : false;

  Transform operator +(Transform o) => Transform(
        start + o.start,
        length + o.length,
        y + o.y,
      );

  Transform operator -(Transform o) => Transform(
        start - o.start,
        length - o.length,
        y - o.y,
      );
}

class PatternTransform extends Transform {
  final BeatFraction contentShift;

  PatternTransform(
      BeatFraction start, BeatFraction length, this.contentShift, int track)
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

class TransformAction<T extends _RollOrTimelineItem> extends MultipleAction<T> {
  final dynamic diff;

  TransformAction(Iterable<T> items, this.diff) : super(items);

  @override
  void doSingle(T object) {
    object.applyTransform(object.transform + diff);
  }

  @override
  void undoSingle(T object) {
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

class PianoRoll extends _RollOrTimelineWindow<_PianoRollNote> {
  static final pixelsPerKey = CssPxVar('piano-roll-ppk');
  static final pixelsPerBeat = CssPxVar('piano-roll-ppb');

  static const int _octaveMin = 2;
  static const int _octaveMax = 8;
  static int get pitchMin => _octaveMin * 12;
  static int get pitchMax => _octaveMax * 12;

  PatternNotesComponent _comp;
  PatternNotesComponent get component => _comp;
  set component(PatternNotesComponent comp) {
    if (_comp != comp) {
      _comp = comp;
      reloadData();
    }
  }

  final List<_PatternInstance> _patterns = [];
  Iterable<_PatternInstance> get selectedPatterns =>
      _patterns.where((p) => p.selected);

  PianoRoll() : super(querySelector('#pianoRoll'), 'Piano Roll') {
    _buildPianoKeys();
    Future.microtask(() {
      _scrollArea.scrollTop =
          (((_octaveMax - 7) * 12 + 5) * pixelsPerKey.value).round();
    });
  }

  void _buildPianoKeys() {
    var parent = query('.piano-keys');
    for (var i = pitchMax; i >= pitchMin; i--) {
      var common = CommonPitch(i);
      _buildKey(common.description, common.whiteKey, parent,
          common.mod == 0 || common.mod == 5);
    }
  }

  void _buildKey(String description, bool white, HtmlElement parent,
      [bool splitBottom = false]) {
    parent.append(DivElement()
      ..className =
          (white ? 'white' : 'black') + (splitBottom ? ' split-bottom' : '')
      ..text = description);
  }

  void reloadData() {
    _items.forEach((n) => n._dispose());
    _items.clear();
    _items.addAll(_comp.notes.map((n) => _PianoRollNote(this, n)));
    applyToComponent();
  }

  @override
  CssPxVar get beatWidth => pixelsPerBeat;
  @override
  CssPxVar get _cellHeight => pixelsPerKey;

  @override
  int get _canvasHeight =>
      ((pitchMax - pitchMin + 1) * pixelsPerKey.value).round();

  @override
  void _drawPreOrientation(CanvasRenderingContext2D ctx) {
    ctx.fillStyle = '#0005';
    ctx.strokeStyle = '#222';
    for (var o = 0; o < _octaveMax - _octaveMin; o++) {
      var i = o * 12 + 1;
      _drawLine(ctx, i);
      _drawKey(ctx, i + 1);
      _drawKey(ctx, i + 3);
      _drawKey(ctx, i + 5);
      _drawLine(ctx, i + 7);
      _drawKey(ctx, i + 8);
      _drawKey(ctx, i + 10);
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
  BeatFraction get renderedLength => bw.length + BeatFraction(4, 1);

  @override
  PlaybackBoxWindow get bw => Project.instance.patternView;

  @override
  BeatFraction get gridSize => BeatFraction(1, 4);

  Iterable<Note> getNotes() {
    return _items.map((i) => i.note);
  }

  void applyToComponent() {
    component.notes = getNotes();
  }

  void onNoteAction(Note note, bool create) {
    if (create) {
      var prn = _PianoRollNote(this, note)..selected;
      _items.add(prn);
      prn.selected = true;
    } else {
      var prn = _items.singleWhere((i) => i.note.matches(note));
      prn._dispose();
      _items.remove(prn);
    }
  }

  @override
  void _addItem(BeatFraction start, int y) {
    History.perform(NotesComponentAction(component, true,
        [Note(pitch: toPitch(y), start: start, length: BeatFraction(1, 4))]));
  }

  static int toVisual(int pitch) => PianoRoll.pitchMax - pitch;
  static int toPitch(int visual) => PianoRoll.pitchMax - visual;
}

class _PianoRollNote extends _RollOrTimelineItem<Transform> {
  PianoRoll get pianoRoll => this.window;

  static final DragSystem<Transform> _dragSystem = DragSystem();
  SpanElement span;
  final Note note;

  _PianoRollNote(PianoRoll window, this.note)
      : super(window.query('#notes').append(DivElement()..className = 'note'),
            window) {
    el
      ..append(span = SpanElement())
      ..append(stretchElem(false, _dragSystem))
      ..append(stretchElem(true, _dragSystem));

    _dragSystem.register(_draggable);

    _silentStart(note.start);
    _silentLength(note.length);
    y = PianoRoll.toVisual(note.pitch);
  }

  void _dispose() {
    el.remove();
  }

  int get pitch => PianoRoll.toPitch(y);

  @override
  void _onUpdate() {
    note.start = start;
    note.length = length;
    note.pitch = pitch;

    pianoRoll.applyToComponent();

    if (end > pianoRoll.bw.length) {
      pianoRoll.bw.length = end;
    } else if (end < pianoRoll.bw.length) {
      Project.instance.patternView.calculateLength();
    } else {
      pianoRoll.bw.box.thereAreChanges();
    }
  }

  @override
  void _onYSet() {
    el.style.top = cssCalc(y, PianoRoll.pixelsPerKey);
    span.text = CommonPitch(pitch).description;
  }
}
