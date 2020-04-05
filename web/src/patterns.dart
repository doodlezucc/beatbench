import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'drag.dart';
import 'history.dart';
import 'notes.dart';
import 'beat_fraction.dart';
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
      _notes.map((n) => n.clone(start: n.start.swingify(_swing)));

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
  final Map<int, PatternNotesComponent> _instrumentNotes = {};
  String name;

  PatternData(this.name, Map<int, PatternNotesComponent> instrumentNotes) {
    _instrumentNotes.addAll(instrumentNotes);
  }

  PatternNotesComponent component(int instrument) {
    return _instrumentNotes[instrument];
  }

  Map<int, PatternNotesComponent> notes() => Map.unmodifiable(_instrumentNotes);

  BeatFraction length() {
    return _instrumentNotes.values.fold(BeatFraction.washy(0), (v, n) {
      var l = n.length();
      return l.beats > v.beats ? l : v;
    });
  }

  void listenToEdits(void Function(dynamic) handler) {
    _instrumentNotes.values.forEach((comp) => comp.stream.listen(handler));
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

  PatternInstance(
    this.data,
    BeatFraction start,
    BeatFraction length,
    int track,
    void Function() onUpdate,
  ) : _onUpdate = onUpdate {
    _input = InputElement(type: 'text')
      ..className = 'shy'
      ..value = data.name;

    _e = querySelector('#patterns').append(DivElement()
      ..className = 'pattern hidden'
      ..append(_input)
      ..append(
          _canvas = CanvasElement(height: Timeline.pixelsPerTrack.value.ceil()))
      ..append(stretchElem(false))
      ..append(stretchElem(true)));

    _e.onDoubleClick.listen((e) {});

    Draggable<PatternTransform>(_e, () => transform, (tr, pixelOff, mouseUp) {
      this.start = tr.start +
          BeatFraction((pixelOff.x / Timeline.pixelsPerBeat.value).round(), 4);
      this.track =
          tr.track + (pixelOff.y / Timeline.pixelsPerTrack.value + 0.5).floor();

      if (mouseUp) {
        print('hoof');
        History.registerDoneAction(PatternTransformAction(this, tr, transform));
      }
    });

    _silentStart(start);
    _silentLength(length ?? data.length().ceilTo(2));
    this.track = track;
    _draw();

    data.listenToEdits((ev) {
      //print('EDIT: $ev');
      _draw();
      _onUpdate();
    });

    setExistence(false);
  }

  void setExistence(bool v) {
    _e.classes.toggle('hidden', !v);
  }

  DivElement stretchElem(bool right) {
    var out = DivElement()..className = 'stretch ${right ? 'right' : 'left'}';
    Draggable<PatternTransform>(
      out,
      () => transform,
      (tr, off, up) {
        if (right) {
          length = tr.length +
              BeatFraction((off.x / Timeline.pixelsPerBeat.value).round(), 4);
        } else {
          var diff =
              BeatFraction((off.x / Timeline.pixelsPerBeat.value).round(), 4);
          // diff maximum: lengthOld - 1
          var maxDiff = tr.length.beats - 1;
          if (diff.beats > maxDiff) diff = BeatFraction.washy(maxDiff);
          // diff minimum: -contentShiftOld
          var minDiff = tr.contentShift * -1;
          if (diff < minDiff) diff = minDiff;

          _silentStart(tr.start + diff);
          _silentLength(tr.length - diff);
          contentShift = tr.contentShift + diff;
          _draw();
        }
        if (up) {
          // register reversible action
          print('hoof');
          History.registerDoneAction(
              PatternTransformAction(this, tr, transform));
        }
      },
    );
    return out;
  }

  PatternTransform get transform =>
      PatternTransform(start, length, contentShift, track);

  void _draw() {
    var ctx = _canvas.context2D;
    ctx.clearRect(0, 0, _canvas.width, _canvas.height);
    var minPitch = 1000;
    var maxPitch = 0;
    data._instrumentNotes.forEach((instrument, component) {
      component.notes.forEach((n) {
        if (n.coarsePitch > maxPitch) maxPitch = n.coarsePitch;
        if (n.coarsePitch < minPitch) minPitch = n.coarsePitch;
      });
    });

    var diff = maxPitch - minPitch;
    var noteHeight = Timeline.pixelsPerTrack.value / max(diff + 1, 8);

    ctx.fillStyle = '#fff';

    data._instrumentNotes.forEach((instrument, component) {
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
}

class PatternTransformAction extends Action {
  final PatternInstance pattern;
  final PatternTransform transformA;
  final PatternTransform transformB;

  PatternTransformAction(this.pattern, this.transformA, this.transformB);

  @override
  void doAction() => pattern.applyTransform(transformB);

  @override
  void undoAction() => pattern.applyTransform(transformA);
}
