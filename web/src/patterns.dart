import 'dart:async';

import 'package:async/async.dart';
import 'package:meta/meta.dart';

import 'generators/base.dart';
import 'history.dart';
import 'notes.dart';
import 'bar_fraction.dart';
import 'project.dart';
import 'utils.dart';
import 'windows/piano_roll.dart';

abstract class PatternDataComponent {
  final StreamController streamController = StreamController.broadcast(
    sync: true,
    //onListen: () => print('hello there?'),
  );
  Stream get stream => streamController.stream;

  BarFraction length();
}

class PatternNotesComponent extends PatternDataComponent {
  PatternData _data;
  PatternData get data => _data;
  Generator _generator;
  Generator get generator => _generator;

  final List<Note> _notes = [];
  final double _swing = 0.5;
  double get swing => _swing;

  Iterable<Note> get notes => _notes;

  void addNote({
    BarFraction start = const BarFraction.zero(),
    BarFraction length = const BarFraction(1, 16),
    @required int pitch,
    bool actionReversible = true,
  }) {
    History.perform(
        NotesComponentAction(this, actionReversible, true,
            [Note(this, start: start, length: length, pitch: pitch)]),
        actionReversible);
  }

  @override
  BarFraction length() {
    return extreme<Note, BarFraction>(notes, (n) => n.end,
        max: true, ifNone: BarFraction.zero());
  }
}

class NotesComponentAction extends AddRemoveAction<Note> {
  static const String TYPE = 'creation';
  final PatternNotesComponent component;
  bool _userInput;

  NotesComponentAction(
      this.component, this._userInput, bool forward, Iterable<Note> notes)
      : super(forward, notes);

  PianoRoll get _pianoRoll => Project.instance.pianoRoll;

  @override
  void doSingle(Note object) {
    if (_pianoRoll.component == component) {
      _pianoRoll.onNoteAction(object, true, dragNow: _userInput);
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
    component.streamController.add(TYPE);
    _userInput = false;
  }
}

class PatternData {
  final Map<Generator, PatternNotesComponent> _genNotes = {};
  Map<Generator, PatternNotesComponent> get genNotes =>
      Map.unmodifiable(_genNotes);
  String name;

  final _ctrl = StreamGroup.broadcast();

  PatternData(this.name, Map<Generator, PatternNotesComponent> genNotes) {
    genNotes.forEach((g, comp) => addNotesComponent(g, comp));
    History.perform(_PatternCreationAction(true, [this]), false);
  }

  void addNotesComponent(Generator g, PatternNotesComponent comp) {
    _genNotes[g] = comp
      .._data = this
      .._generator = g;
    _ctrl.add(comp.stream);
  }

  PatternNotesComponent component(Generator gen) {
    if (!_genNotes.containsKey(gen)) {
      addNotesComponent(gen, PatternNotesComponent());
    }
    return _genNotes[gen];
  }

  Map<Generator, PatternNotesComponent> notes() => Map.unmodifiable(_genNotes);

  BarFraction length() {
    return _genNotes.values.fold(BarFraction.washy(0), (v, n) {
      var l = n.length();
      return l.beats > v.beats ? l : v;
    });
  }

  StreamSubscription listenToEdits(void Function(dynamic) handler) {
    return _ctrl.stream.listen(handler);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'notes': _genNotes.map((gen, notes) => MapEntry(
            Project.instance.generators.items.indexOf(gen).toString(),
            notes.notes.map((e) => e.toJson()).toList())),
      };
}

class _PatternCreationAction extends AddRemoveAction<PatternData> {
  _PatternCreationAction(bool forward, Iterable<PatternData> list)
      : super(forward, list);

  @override
  void doSingle(PatternData object) {
    Project.instance.patterns.items.add(object);
  }

  @override
  void undoSingle(PatternData object) {
    Project.instance.patterns.items.remove(object);
  }

  @override
  void onExecuted(bool forward) {}
}
