import 'dart:html';

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
    (_e.querySelector('input') as InputElement).value = data.name;
    // TODO bob ross stuff
  }

  HtmlElement _e;

  BeatFraction get end => start + length;

  PatternInstance(
    PatternData data, {
    start = const BeatFraction(0, 1),
    BeatFraction length,
    int track = 0,
  }) {
    var nameInput = InputElement(type: 'text')
      ..className = 'shy'
      ..value = data.name;

    _e = querySelector('#patterns').append(DivElement()
      ..className = 'pattern'
      ..append(nameInput));

    this.data = data;
    this.start = start;
    this.length = length ?? data.length();
    this.track = track;
  }
}
