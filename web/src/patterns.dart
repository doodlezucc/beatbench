import 'dart:html';
import 'dart:math';

import 'drag.dart';
import 'notes.dart';
import 'beat_fraction.dart';
import 'timeline.dart';
import 'utils.dart';

abstract class PatternDataComponent {
  BeatFraction length();
}

class PatternNotesComponent extends PatternDataComponent {
  List<Note> notes;

  PatternNotesComponent(this.notes);

  @override
  BeatFraction length() {
    return notes.fold(
        BeatFraction.washy(0), (v, n) => n.end.beats > v.beats ? n.end : v);
  }
}

class PatternData {
  Map<int, PatternNotesComponent> instrumentNotes;
  String name;

  PatternData(this.name, this.instrumentNotes);

  BeatFraction length() {
    return const BeatFraction(4, 4);
  }
}

class PatternInstance {
  BeatFraction _start;
  BeatFraction get start => _start;
  set start(BeatFraction start) {
    _start = start;
    _e.style.left = cssCalc(start.beats, Timeline.pixelsPerBeat);
  }

  BeatFraction _length;
  BeatFraction get length => _length;
  set length(BeatFraction length) {
    _length = length;
    _e.style.width = cssCalc(length.beats, Timeline.pixelsPerBeat);
    _canvas.width = (length.beats * Timeline.pixelsPerBeat.value).ceil();
  }

  int _track;
  int get track => _track;
  set track(int track) {
    _track = track;
    _e.style.top = cssCalc(track, Timeline.pixelsPerTrack);
  }

  PatternData _data;
  PatternData get data => _data;
  set data(PatternData data) {
    _data = data;
    _input.value = data.name;
    _draw();
  }

  HtmlElement _e;
  InputElement _input;
  CanvasElement _canvas;

  BeatFraction get end => start + length;

  PatternInstance(
    PatternData data, {
    BeatFraction start = const BeatFraction(0, 1),
    BeatFraction length,
    int track = 0,
  }) {
    _input = InputElement(type: 'text')
      ..className = 'shy'
      ..value = data.name;

    _e = querySelector('#patterns').append(DivElement()
      ..className = 'pattern'
      ..append(_input)
      ..append(
          _canvas = CanvasElement(height: Timeline.pixelsPerTrack.value.ceil()))
      ..append(stretchElem('left'))
      ..append(stretchElem('right')));

    Draggable(_e, () => this.start, () => this.track,
        (firstStart, firstTrack, pixelOff) {
      this.start = (firstStart as BeatFraction) +
          BeatFraction.washy(pixelOff.x / Timeline.pixelsPerBeat.value);
      this.track = (firstTrack as int) +
          (pixelOff.y / Timeline.pixelsPerTrack.value + 0.5).floor();
    });

    this.data = data;
    this.start = start;
    this.length = length ?? data.length();
    this.track = track;
    _draw();
  }

  DivElement stretchElem(String side) {
    return DivElement()..className = 'stretch $side';
  }

  void _draw() {
    var ctx = _canvas.context2D;
    var minPitch = 1000;
    var maxPitch = 0;
    data.instrumentNotes.forEach((instrument, component) {
      component.notes.forEach((n) {
        if (n.coarsePitch > maxPitch) maxPitch = n.coarsePitch;
        if (n.coarsePitch < minPitch) minPitch = n.coarsePitch;
      });
    });

    var diff = maxPitch - minPitch;
    var noteHeight = Timeline.pixelsPerTrack.value / max(diff + 1, 8);

    ctx.fillStyle = '#fff';

    data.instrumentNotes.forEach((instrument, component) {
      component.notes.forEach((n) {
        ctx.fillRect(
            Timeline.pixelsPerBeat.value * n.start.beats,
            Timeline.pixelsPerTrack.value -
                (n.coarsePitch - minPitch + 1) * noteHeight,
            Timeline.pixelsPerBeat.value * n.length.beats - 1,
            noteHeight);
      });
    });
  }
}
