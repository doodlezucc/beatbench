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
          AddNotesAction(data.component(0), [
            Note(tone: y, octave: 5, start: BeatFraction(x, 16)),
          ]),
          undoable);
    } else {
      History.perform(
          RemoveNotesAction(data.component(0), [
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

  void swaggyBeat() {
    // KICK
    setField(0, 0, true);
    setField(4, 0, true);
    //SNARE
    setField(8, 1, true);
    //HI-HAT
    setField(2, 2, true);
    setField(3, 2, true);

    setField(6, 2, true);
    setField(7, 2, true);
  }
}
