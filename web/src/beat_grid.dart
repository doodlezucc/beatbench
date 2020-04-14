import 'dart:html';

import 'generators/drums.dart';
import 'history.dart';
import 'notes.dart';
import 'beat_fraction.dart';
import 'patterns.dart';

class BeatGrid {
  final Element _e;
  final int _height = 4;
  final PatternData data;
  Drums drums;
  PatternNotesComponent _comp;

  BeatGrid(this._e, this.drums)
      : data = PatternData('Beat Grid', {drums: PatternNotesComponent([])}) {
    _comp = data.component(drums);
    _createGrid();
    data.listenToEdits((msg) {
      _e.querySelectorAll('.filled').classes.toggle('filled', false);
      data.component(drums).notes.forEach((n) {
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
          NotesComponentAction(_comp, true, [
            _quickNote(x, y),
          ]),
          undoable);
    } else {
      History.perform(
          NotesComponentAction(_comp, false, [
            _comp.notes.singleWhere((n) =>
                n.start.numerator == x && n.coarsePitch == Note.octave(y, 5)),
          ]),
          undoable);
    }
  }

  void setField(int x, int y, bool active) {
    _e.children[_height - y - 1].children[x].classes.toggle('filled', active);
    _setData(x, y, active, false);
  }

  Note _quickNote(int x, int y) =>
      Note(pitch: Note.octave(y, 5), start: BeatFraction(x, 16));

  void swaggyBeat() {
    History.perform(NotesComponentAction(_comp, true, <Note>[
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
