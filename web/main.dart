import 'dart:html';

import 'src/beat_grid.dart';
import 'src/history.dart';
import 'src/instruments.dart';
import 'src/project.dart';

void main() {
  var styleWorkbench = false;
  if (!styleWorkbench) {
    initStuff();
  }
}

void initStuff() async {
  var time = DateTime.now().millisecondsSinceEpoch;

  var project = Project();

  var grid = BeatGrid(querySelector('#grid'),
      await PresetDrums.cymaticsLofiKit(project.audioAssembler.ctx));

  grid.swaggyBeat();

  project.timeline.fromBeatGrid(grid);

  querySelector('#play').onClick.listen((e) {
    project.play();
  });
  querySelector('#pause').onClick.listen((e) {
    project.pause();
  });
  querySelector('#tempo').onInput.listen((e) {
    var bpm = double.tryParse((e.target as InputElement).value);
    if (bpm != null) {
      project.bpm = bpm;
    }
  });

  document.onKeyDown.listen((e) {
    //print('${e.ctrlKey} | ${e.shiftKey} | ${e.key}');
    if (e.ctrlKey) {
      switch (e.keyCode) {
        case 90: // z
          e.shiftKey ? History.redo() : History.undo();
          return;
        case 89: // y
          History.redo();
          return;
      }
    }
  });

  print('init stuff done in ' +
      (DateTime.now().millisecondsSinceEpoch - time).toString() +
      'ms');
}
