import 'dart:html';

import 'instruments.dart';
import 'patterns.dart';
import 'simplemusic.dart';

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
    setField(0, 0, true);
    setField(2, 0, true);
    setField(7, 0, true);
    setField(9, 0, true);

    setField(4, 1, true);
    setField(12, 1, true);
  }

  List<Note> getNotes() {
    return _e
        .querySelectorAll('.filled')
        .map((el) => Note(
            tone: int.tryParse(el.attributes['y']),
            octave: 5,
            start: RhythmUnit(int.tryParse(el.attributes['x']), 16)))
        .toList();
  }
}
