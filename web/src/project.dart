import 'dart:html';
import 'dart:math';

import 'audio_assembler.dart';
import 'beat_grid.dart';
import 'history.dart';
import 'instruments.dart';
import 'timeline.dart';
import 'windows.dart';

class Project {
  final AudioAssembler audioAssembler = AudioAssembler();
  final Timeline timeline = Timeline();
  Window _currentWindow;

  double _bpm;
  double get bpm => _bpm;
  set bpm(double bpm) {
    _bpm = max(40, bpm);
    timeline.onNewTempo();
  }

  static Project _instance;
  static Project get instance => _instance;

  Project({double bpm = 150}) {
    _instance = this;
    this.bpm = bpm;
    _init();
  }

  Future<void> createDemo() async {
    var grid = BeatGrid(querySelector('#grid'),
        await PresetDrums.cymaticsLofiKit(audioAssembler.ctx));

    grid.swaggyBeat();

    timeline.fromBeatGrid(grid);
    _currentWindow = timeline;
  }

  void play() {
    audioAssembler.run(timeline.box);
  }

  void pause() {
    audioAssembler.stopPlayback();
  }

  void _init() {
    querySelector('#play').onClick.listen((e) => play());
    querySelector('#pause').onClick.listen((e) => pause());
    querySelector('#tempo').onInput.listen((e) {
      var bpm = double.tryParse((e.target as InputElement).value);
      if (bpm != null) {
        this.bpm = bpm;
      }
    });

    document.onKeyDown.listen((e) {
      //print('${e.ctrlKey} | ${e.shiftKey} | ${e.key}');
      if (e.ctrlKey) {
        switch (e.keyCode) {
          case 90: // z
            return e.shiftKey ? History.redo() : History.undo();
          case 89: // y
            return History.redo();
        }
      } else {
        switch (e.keyCode) {
          case 8: // backspace
            return _currentWindow.handleDelete();
        }
      }
    });
  }
}
