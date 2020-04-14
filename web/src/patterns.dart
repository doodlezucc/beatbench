import 'dart:async';

import 'generators/base.dart';
import 'history.dart';
import 'notes.dart';
import 'beat_fraction.dart';
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
  List<Note> _notes;
  final double _swing = 0.5;
  Iterable<Note> get notesWithSwing =>
      notes.map((n) => n.cloneKeepInfo(start: n.start.swingify(_swing)));

  Iterable<Note> get notes => _notes;
  set notes(Iterable<Note> notes) {
    _notes = notes.toList();
    _streamController.add('set');
  }

  PatternNotesComponent(Iterable<Note> notes) : _notes = notes.toList();

  @override
  BeatFraction length() {
    return extreme<Note, BeatFraction>(notes, (n) => n.end, max: true);
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
