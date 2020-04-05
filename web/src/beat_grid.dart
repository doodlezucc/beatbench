import 'dart:html';

import 'history.dart';
import 'instruments.dart';
import 'notes.dart';
import 'beat_fraction.dart';
import 'patterns.dart';

class BeatGrid {
  final Element _e;
  final int _height = 4;
  final PatternData data;
  Drums drums;

  BeatGrid(this._e, this.drums)
      : data = PatternData('Beat Grid', {0: PatternNotesComponent([])}) {
    _createGrid();
    data.listenToEdits((msg) {
      _e.querySelectorAll('.filled').classes.toggle('filled', false);
      data.component(0).notes.forEach((n) {
        _e.children[_height - (n.coarsePitch - 60) - 1]
            .children[(4 * n.start.beats).round()].classes
            .toggle('filled', true);
      });
    });
  }

  void _createGrid() {
    Element createTd(int x, int y) {
      var td = Element.td()
        ..attributes['x'] = x.toString()
        ..attributes['y'] = y.toString();
      td.onClick.listen((e) {
        var active = td.classes.toggle('filled');
        _setData(x, y, active, true);
      });
      return td;
    }

    Element createRow(int length, int y) {
      var row = Element.tr();
      for (var x = 0; x < length; x++) {
        row.append(createTd(x, y));
      }
      return row;
    }

    for (var i = _height - 1; i >= 0; i--) {
      _e.append(createRow(16, i));
    }
  }

  void _setData(int x, int y, bool active, bool undoable) {
    if (active) {
      History.perform(
          NotesComponentAction(data.component(0), true, [
            _quickNote(x, y),
          ]),
          undoable);
    } else {
      History.perform(
          NotesComponentAction(data.component(0), false, [
            data.component(0).notes.singleWhere((n) =>
                n.start.numerator == x && n.coarsePitch == Note.getPitch(y, 5)),
          ]),
          undoable);
    }
  }

  void setField(int x, int y, bool active) {
    _e.children[_height - y - 1].children[x].classes.toggle('filled', active);
    _setData(x, y, active, false);
  }

  Note _quickNote(int x, int y) =>
      Note(tone: y, octave: 5, start: BeatFraction(x, 16));

  void swaggyBeat() {
    History.perform(NotesComponentAction(data.component(0), true, <Note>[
      // Kick
      _quickNote(0, 0),
      _quickNote(3, 0),
      _quickNote(6, 0),
      _quickNote(10, 0),
      // Snare
      _quickNote(4, 1),
      _quickNote(12, 1),
      //Hi-Hat
      _quickNote(2, 2),
      _quickNote(10, 2),
    ]));
  }
}
