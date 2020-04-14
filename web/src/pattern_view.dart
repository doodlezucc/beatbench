import 'dart:html';

import 'audio_assembler.dart';
import 'beat_fraction.dart';
import 'generators/base.dart';
import 'history.dart';
import 'patterns.dart';
import 'project.dart';
import 'timeline_piano_roll.dart';
import 'utils.dart';
import 'windows.dart';

class PatternView extends Window with PlaybackBoxWindow {
  PlaybackBox _box;
  @override
  PlaybackBox get box => _box;

  BeatFraction _length = BeatFraction(4, 4);
  @override
  BeatFraction get length => _length;
  set length(BeatFraction l) {
    var min = BeatFraction(4, 4);
    if (l < min) l = min;
    _length = l;
    box.length = timeAt(l);
    Project.instance.pianoRoll.drawOrientation();
    box.thereAreChanges();
    if (headPosition > length) {
      headPosition = BeatFraction.washy(headPosition.beats % length.beats);
    }
  }

  PatternData _patternData;
  PatternData get patternData => _patternData;
  set patternData(PatternData patternData) {
    if (_patternData != patternData) {
      _patternData = patternData;
      Project.instance.pianoRoll.component =
          _patternData.component(Project.instance.generators.selected);
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
    length = extreme<PatternNotesComponent, BeatFraction>(
        patternData.genNotes.values, (comp) => comp.length(),
        max: true);
  }

  Iterable<PlaybackNote> notesCache() {
    var _cache = <PlaybackNote>[];
    patternData.genNotes.forEach((gen, comp) {
      comp.notesWithSwing.forEach((note) {
        var shift = BeatFraction.washy(0);
        _cache.add(PlaybackNote(
          noteInfo: note.info,
          generator: gen,
          startInSeconds: timeAt(note.start + shift),
          endInSeconds: timeAt(note.end + shift),
        ));
      });
    });
    return _cache;
  }

  @override
  double timeAt(BeatFraction bf) => bf.beats / (Project.instance.bpm / 60);

  @override
  double beatsAt(double seconds) => seconds * (Project.instance.bpm / 60);

  @override
  void drawForeground(double ghost) {
    Project.instance.pianoRoll.drawForeground(ghost);
  }
}

class GeneratorList {
  final List<Generator> _list = [];
  final int _selected = 1;
  Generator get selected => _list[_selected];
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
