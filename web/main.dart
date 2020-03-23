import 'dart:html';

import 'src/beat_grid.dart';
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
  querySelector('#output').text = 'Beatbench written in Dart!';

  var project = Project(bpm: 130);

  var grid = BeatGrid(querySelector('#grid'),
      await PresetDrums.cymaticsLofiKit(project.audioAssembler.ctx));

  grid.swaggyBeat();

  project.timeline.fromBeatGrid(grid);

  querySelector('#play').onClick.listen((e) {
    project.timeline.fromBeatGrid(grid);
    project.play();
  });
  querySelector('#pause').onClick.listen((e) {
    project.pause();
  });

  print('init stuff done in ' +
      (DateTime.now().millisecondsSinceEpoch - time).toString() +
      'ms');
}
