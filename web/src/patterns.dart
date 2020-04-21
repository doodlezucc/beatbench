import 'dart:async';

import 'package:meta/meta.dart';

import 'generators/base.dart';
import 'history.dart';
import 'notes.dart';
import 'beat_fraction.dart';
import 'project.dart';
import 'utils.dart';
import 'windows/piano_roll.dart';

abstract class PatternDataComponent {
  final StreamController streamController = StreamController.broadcast(
    sync: true,
    //onListen: () => print('hello there?'),
  );
  Stream get stream => streamController.stream;

  BeatFraction length();
}

class PatternNotesComponent extends PatternDataComponent {
  final List<Note> _notes = [];
  final double _swing = 0.5;
  double get swing => _swing;

  Iterable<Note> get notes => _notes;

  void addNote({
    BeatFraction start = const BeatFraction(0, 1),
    BeatFraction length = const BeatFraction(1, 16),
    @required int pitch,
    bool reversibleAction = true,
  }) {
    History.perform(
        NotesComponentAction(this, true,
            [Note(this, start: start, length: length, pitch: pitch)]),
        reversibleAction);
  }

  @override
  BeatFraction length() {
    return extreme<Note, BeatFraction>(notes, (n) => n.end, max: true);
  }
}

class NotesComponentAction extends AddRemoveAction<Note> {
  final PatternNotesComponent component;

  NotesComponentAction(this.component, bool forward, Iterable<Note> notes)
      : super(forward, notes);

  PianoRoll get _pianoRoll => Project.instance.pianoRoll;

  @override
  void doSingle(Note object) {
    if (_pianoRoll.component == component) {
      _pianoRoll.onNoteAction(object, true);
    }
    component._notes.add(object);
  }

  @override
  void undoSingle(Note object) {
    if (_pianoRoll.component == component) {
      _pianoRoll.onNoteAction(object, false);
    }
    component._notes.removeWhere((n) => object == n);
  }

  @override
  void onExecuted(bool didAdd) {
    component.streamController.add(didAdd);
  }
}

class PatternData {
  final Map<Generator, PatternNotesComponent> _genNotes = {};
  Map<Generator, PatternNotesComponent> get genNotes =>
      Map.unmodifiable(_genNotes);
  String name;

  PatternData(this.name, Map<Generator, PatternNotesComponent> genNotes) {
    _genNotes.addAll(genNotes);
  }

  PatternNotesComponent component(Generator gen) {
    return _genNotes[gen];
  }

  Map<Generator, PatternNotesComponent> notes() => Map.unmodifiable(_genNotes);

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
