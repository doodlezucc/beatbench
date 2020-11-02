import 'dart:async';
import 'dart:html';

import '../audio_assembler.dart';
import '../bar_fraction.dart';
import '../generators/base.dart';
import '../history.dart';
import '../patterns.dart';
import '../project.dart';
import '../utils.dart';
import 'specific_windows.dart';
import 'windows.dart';

class PatternView extends Window with PlaybackBoxWindow {
  PlaybackBox _box;
  @override
  PlaybackBox get box => _box;

  StreamSubscription _patternEditSub;

  PatternData _patternData;
  PatternData get patternData => _patternData;
  set patternData(PatternData patternData) {
    if (_patternData != patternData) {
      _patternData = patternData;
      var comp = _patternData.component(Project.instance.generators.selected);
      Project.instance.pianoRoll.component = comp;
      _patternEditSub?.cancel();
      _patternEditSub = comp.data.listenToEdits((msg) {
        if (msg == NotesComponentAction.TYPE) {
          calculateLength();
        }
      });
      calculateLength();
    }
  }

  PatternView() : super(DivElement(), 'Pattern View') {
    _box = PlaybackBox(
      onUpdateVisuals: (time) {
        drawForeground(beatsAt(time));
      },
      onStop: () {
        drawForeground(headPosition.beats);
      },
      getNotes: notesCache,
    );
  }

  void calculateLength() {
    length = extreme<PatternNotesComponent, BarFraction>(
        patternData.genNotes.values, (comp) => comp.length(),
        max: true, ifNone: BarFraction(1, 1));
  }

  Iterable<PlaybackNote> notesCache() {
    var _cache = <PlaybackNote>[];
    patternData.genNotes.forEach((gen, comp) {
      var swing = comp.swing;
      comp.notes.forEach((note) {
        _cache.add(PlaybackNote(
          noteInfo: note.createInfo(),
          generator: gen,
          startInSeconds: timeAt(note.start.swingify(swing)),
          endInSeconds: timeAt(note.end.swingify(swing)),
        ));
      });
    });
    return _cache;
  }

  @override
  double timeAt(BarFraction bf) => bf.beats / (Project.instance.bpm / 60);

  @override
  double beatsAt(double seconds) => seconds * (Project.instance.bpm / 60);

  @override
  void drawForeground(double ghost) {
    Project.instance.pianoRoll.drawFg(headPosition.beats, ghost);
  }

  @override
  void drawOrientation() {
    Project.instance.pianoRoll.drawBg();
  }

  @override
  void onHeadSet(BarFraction head) {
    Project.instance.pianoRoll.windowHeadSet(head);
  }
}

class GeneratorList {
  final List<Generator> _list = [];
  final int _selected = 1;
  Generator get selected => _list[_selected];

  Iterable<Generator> get list => _list;
}

class GeneratorCreationAction extends AddRemoveAction<Generator> {
  GeneratorCreationAction(bool forward, Iterable<Generator> list)
      : super(forward, list);

  @override
  void doSingle(Generator object) {
    Project.instance.generators._list.add(object);
  }

  @override
  void undoSingle(Generator object) {
    Project.instance.generators._list.remove(object);
  }

  @override
  void onExecuted(bool forward) {}
}
