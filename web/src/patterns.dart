import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'drag.dart';
import 'history.dart';
import 'notes.dart';
import 'beat_fraction.dart';
import 'project.dart';
import 'timeline.dart';
import 'utils.dart';

abstract class PatternDataComponent {
  final StreamController _streamController = StreamController.broadcast(
    sync: true,
    //onListen: () => print('hello there?'),
  );
  Stream get stream => _streamController.stream;

  BeatFraction length();
}

class PatternNotesComponent extends PatternDataComponent {
  final List<Note> _notes;
  final double _swing = 0.5;
  Iterable<Note> get notesWithSwing =>
      _notes.map((n) => n.cloneKeepInfo(start: n.start.swingify(_swing)));

  Iterable<Note> get notes => Iterable.castFrom(_notes);

  PatternNotesComponent(Iterable<Note> notes) : _notes = notes.toList();

  @override
  BeatFraction length() {
    return notes.fold(
        BeatFraction.washy(0), (v, n) => n.end.beats > v.beats ? n.end : v);
  }
}

class NotesComponentAction extends AddRemoveAction<Note> {
  final PatternNotesComponent component;

  NotesComponentAction(this.component, bool forward, Iterable<Note> notes)
      : super(forward, notes);

  @override
  void doSingle(Note object) {
    component._notes.add(object);
  }

  @override
  void undoSingle(Note object) {
    component._notes.remove(object);
  }

  @override
  void onExecuted(bool didAdd) {
    component._streamController.add(didAdd);
  }
}

class PatternData {
  final Map<int, PatternNotesComponent> _genNotes = {};
  String name;

  PatternData(this.name, Map<int, PatternNotesComponent> genNotes) {
    _genNotes.addAll(genNotes);
  }

  PatternNotesComponent component(int gen) {
    return _genNotes[gen];
  }

  Map<int, PatternNotesComponent> notes() => Map.unmodifiable(_genNotes);

  BeatFraction length() {
    return _genNotes.values.fold(BeatFraction.washy(0), (v, n) {
      var l = n.length();
      return l.beats > v.beats ? l : v;
    });
  }

  void listenToEdits(void Function(dynamic) handler) {
    _genNotes.values.forEach((comp) => comp.stream.listen(handler));
  }
}

class PatternInstance {
  BeatFraction _contentShift = BeatFraction(0, 1);
  BeatFraction get contentShift => _contentShift;
  set contentShift(BeatFraction contentShift) {
    if (_contentShift != contentShift) {
      _contentShift = contentShift;
      _draw();
      _onUpdate();
    }
  }

  BeatFraction _start;
  BeatFraction get start => _start;
  set start(BeatFraction start) {
    if (_silentStart(start)) _onUpdate();
  }

  bool _silentStart(BeatFraction start) {
    var oldStart = _start;
    _start = start.beats >= 0 ? start : BeatFraction(0, 1);
    _e.style.left = cssCalc(_start.beats, Timeline.pixelsPerBeat);
    return _start != oldStart;
  }

  BeatFraction _length;
  BeatFraction get length => _length;
  set length(BeatFraction length) {
    if (_silentLength(length)) {
      _draw();
      _onUpdate();
    }
  }

  bool _silentLength(BeatFraction length) {
    var oldLength = _length;
    _length = length.beats >= 1 ? length : BeatFraction(1, 4);
    _e.style.width = cssCalc(_length.beats, Timeline.pixelsPerBeat);
    if (_length != oldLength) {
      _canvas.width = (_length.beats * Timeline.pixelsPerBeat.value).ceil();
      return true;
    }
    return false;
  }

  int _track;
  int get track => _track;
  set track(int track) {
    _track = max(0, track);
    _e.style.top = cssCalc(_track, Timeline.pixelsPerTrack);
  }

  final void Function() _onUpdate;
  final PatternData data;

  HtmlElement _e;
  InputElement _input;
  CanvasElement _canvas;

  BeatFraction get end => start + length;

  bool _selected = false;
  bool get selected => _selected;
  set selected(bool v) {
    _selected = v;
    _e.classes.toggle('selected', v);
  }

  Draggable<PatternTransform> _draggable;
  static final DragSystem<PatternTransform> _dragSystem = DragSystem();

  PatternInstance(this.data, BeatFraction start, BeatFraction length, int track,
      void Function() onUpdate, Timeline timeline)
      : _onUpdate = onUpdate {
    _input = InputElement(type: 'text')
      ..className = 'shy'
      ..value = data.name;

    _e = timeline.query('#patterns').append(DivElement()
      ..className = 'pattern hidden'
      ..append(_input)
      ..append(
          _canvas = CanvasElement(height: Timeline.pixelsPerTrack.value.ceil()))
      ..append(stretchElem(false))
      ..append(stretchElem(true)));

    _e.onMouseDown.listen((e) {
      if (!selected) {
        if (!e.shiftKey) {
          Project.instance.timeline.selectedPatterns
              .forEach((p) => p.selected = false);
        }
        selected = true;
      }
    });

    _draggable =
        Draggable<PatternTransform>(_e, () => transform, (tr, pixelOff, ev) {
      var xDiff =
          BeatFraction((pixelOff.x / Timeline.pixelsPerBeat.value).round(), 4);
      var minXDiff = Project.instance.timeline.selectedPatterns
              .fold<BeatFraction>(
                  tr.start,
                  (v, p) => p._draggable.savedVar.start < v
                      ? p._draggable.savedVar.start
                      : v) *
          -1;
      if (xDiff < minXDiff) {
        xDiff = minXDiff;
      }
      var minYDiff = -Project.instance.timeline.selectedPatterns.fold<num>(
          tr.track,
          (v, p) => p._draggable.savedVar.track < v
              ? p._draggable.savedVar.track
              : v);
      var yDiff = max(
          minYDiff, (pixelOff.y / Timeline.pixelsPerTrack.value + 0.5).floor());

      Project.instance.timeline.selectedPatterns.forEach((p) {
        p.start = p._draggable.savedVar.start + xDiff;
        p.track = p._draggable.savedVar.track + yDiff;
      });

      if (ev.detail == 1) {
        if (tr != transform) {
          History.registerDoneAction(PatternTransformAction(
              Project.instance.timeline.selectedPatterns
                  .toList(growable: false),
              transform - tr));
        } else if (pixelOff.x == 0 && pixelOff.y == 0) {
          if (!ev.shiftKey) {
            Project.instance.timeline.selectedPatterns
                .forEach((p) => p.selected = false);
          }
          selected = true;
        }
      }
    });
    _dragSystem.register(_draggable);

    _silentStart(start);
    _silentLength(length ?? data.length().ceilTo(2));
    this.track = track;
    _draw();

    data.listenToEdits((ev) {
      if (!_e.classes.contains('hidden')) {
        //print('EDIT: $ev');
        _draw();
        _onUpdate();
      }
    });

    setExistence(false);
  }

  void setExistence(bool v) {
    _e.classes.toggle('hidden', !v);
  }

  DivElement stretchElem(bool right) {
    var out = DivElement()..className = 'stretch ${right ? 'right' : 'left'}';
    _dragSystem.register(Draggable<PatternTransform>(
      out,
      () => transform,
      (tr, off, ev) {
        var diff =
            BeatFraction((off.x / Timeline.pixelsPerBeat.value).round(), 4);
        var maxDiff = Project.instance.timeline.selectedPatterns
                .fold<BeatFraction>(
                    tr.length,
                    (v, p) => p._draggable.savedVar.length < v
                        ? p._draggable.savedVar.length
                        : v) -
            BeatFraction(1, 4);
        if (right) {
          if (diff < maxDiff * -1) diff = maxDiff * -1;
          Project.instance.timeline.selectedPatterns.forEach((p) {
            p.length = p._draggable.savedVar.length + diff;
          });
        } else {
          // diff maximum: lengthOld - 1
          if (diff > maxDiff) diff = maxDiff;

          // diff minimum: -contentShiftOld
          var minDiff = Project.instance.timeline.selectedPatterns
                  .fold<BeatFraction>(
                      tr.contentShift,
                      (v, p) => p._draggable.savedVar.contentShift > v
                          ? p._draggable.savedVar.contentShift
                          : v) *
              -1;
          if (diff < minDiff) diff = minDiff;

          Project.instance.timeline.selectedPatterns.forEach((p) {
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
              Project.instance.timeline.selectedPatterns
                  .toList(growable: false),
              transform - tr));
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
    data._genNotes.values.forEach((component) {
      component.notes.forEach((n) {
        if (n.coarsePitch > maxPitch) maxPitch = n.coarsePitch;
        if (n.coarsePitch < minPitch) minPitch = n.coarsePitch;
      });
    });

    var diff = maxPitch - minPitch;
    var noteHeight = Timeline.pixelsPerTrack.value / max(diff + 1, 8);

    ctx.fillStyle = '#fff';

    data._genNotes.values.forEach((component) {
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

class PatternTransformAction extends MultipleAction<PatternInstance> {
  final PatternTransform diff;

  PatternTransformAction(Iterable<PatternInstance> patterns, this.diff)
      : super(patterns);

  @override
  void doSingle(PatternInstance object) {
    object.applyTransform(object.transform + diff);
  }

  @override
  void undoSingle(PatternInstance object) {
    object.applyTransform(object.transform - diff);
  }
}
