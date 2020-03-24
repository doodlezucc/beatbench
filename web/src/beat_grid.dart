import 'dart:html';

import 'instruments.dart';
import 'notes.dart';
import 'beat_fraction.dart';

class BeatGrid {
  final Element _e;
  final int _height = 4;
  Drums drums;

  BeatGrid(this._e, this.drums) {
    _createGrid();
  }

  void _createGrid() {
    Element createTd(int x, int y) {
      var td = Element.td()
        ..attributes['x'] = x.toString()
        ..attributes['y'] = y.toString();
      td.onClick.listen((e) {
        td.classes.toggle('filled');
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

  void setField(int x, int y, bool active) {
    _e.children[_height - y - 1].children[x].classes.toggle('filled', active);
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

  List<Note> getNotes() {
    return _e
        .querySelectorAll('.filled')
        .map((el) => Note(
            tone: int.tryParse(el.attributes['y']),
            octave: 5,
            start: BeatFraction(int.tryParse(el.attributes['x']), 16)))
        .toList();
  }
}
