import 'dart:html';

import 'src/audio_assembler.dart';
import 'src/beat_grid.dart';
import 'src/instruments.dart';

void main() {
  initStuff();
}

void initStuff() async {
  querySelector('#output').text = 'Beatbench written in Dart!';

  var a = AudioAssembler();
  var grid = BeatGrid(
      querySelector('#grid'), await PresetDrums.cymaticsLofiKit(a.ctx));

  grid.swaggyBeat();

  querySelector('button').onClick.listen((e) {
    a.run();
  });
}
