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

  void createDemo() async {
    var grid = BeatGrid(querySelector('#grid'),
        await PresetDrums.cymaticsLofiKit(audioAssembler.ctx));

    grid.swaggyBeat();

    timeline.demoFromBeatGrid(grid);
    _currentWindow = timeline;
  }

  void play() {
    audioAssembler.run(timeline.box, timeline.timeAt(timeline.headPosition));
  }

  void pause() {
    audioAssembler.stopPlayback();
  }

  void togglePlayPause() {
    if (audioAssembler.isRunning) {
      pause();
    } else {
      play();
    }
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
      if (e.target is InputElement) return;
      if (e.ctrlKey) {
        switch (e.keyCode) {
          case 90: // z
            e.shiftKey ? History.redo() : History.undo();
            return e.preventDefault();
          case 89: // y
            History.redo();
            return e.preventDefault();
          case 65: // a
            if (_currentWindow.handleSelectAll()) e.preventDefault();
            return;
        }
      } else if (e.altKey) {
        switch (e.keyCode) {
          case 67: // c
            if (_currentWindow.handleClone()) e.preventDefault();
            return;
        }
      } else {
        switch (e.keyCode) {
          case 8: // backspace
            if (_currentWindow.handleDelete()) e.preventDefault();
            return;
          case 32: // space
            e.preventDefault();
            return togglePlayPause();
        }
      }
    });
  }
}
