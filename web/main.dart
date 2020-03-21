import 'dart:html';

import 'src/beat_grid.dart';
import 'src/instruments.dart';
import 'src/project.dart';

void main() {
  initStuff();
}

void initStuff() async {
  querySelector('#output').text = 'Beatbench written in Dart!';

  var project = Project(bpm: 80);

  var grid = BeatGrid(querySelector('#grid'),
      await PresetDrums.cymaticsLofiKit(project.audioAssembler.ctx));

  grid.swaggyBeat();

  querySelector('button').onClick.listen((e) {
    project.timeline.fromBeatGrid(grid);
    project.play();
  });
}
