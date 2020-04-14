import 'dart:html';
import 'dart:math';

import 'audio_assembler.dart';
import 'beat_grid.dart';
import 'generators/base.dart';
import 'generators/drums.dart';
import 'history.dart';
import 'midi_typing.dart';
import 'pattern_view.dart';
import 'timeline_piano_roll.dart';
import 'windows.dart';

class Project {
  final AudioAssembler audioAssembler = AudioAssembler();
  final Timeline timeline = Timeline()..visible = true;

  PianoRoll _pianoRoll;
  PianoRoll get pianoRoll => _pianoRoll;

  Window _currentWindow;
  Window get currentWindow => _currentWindow;
  set currentWindow(Window currentWindow) {
    _currentWindow = currentWindow;
  }

  double _bpm;
  double get bpm => _bpm;
  set bpm(double bpm) {
    _bpm = min(max(bpm, 20), 420);
    timeline.onNewTempo();
  }

  final GeneratorList _generators = GeneratorList();
  GeneratorList get generators => _generators;

  final PatternView patternView = PatternView();

  static Project _instance;
  static Project get instance => _instance;

  Project() {
    _instance = this;
    _init();

    _pianoRoll = PianoRoll()
      ..position = Point(200, 100)
      ..size = Point(700, 500)
      ..visible = true;
  }

  void createDemo() async {
    var grid = BeatGrid(querySelector('#grid'),
        await PresetDrums.cymaticsLofiKit(audioAssembler.ctx));

    grid.swaggyBeat();

    timeline.demoFromBeatGrid(grid);
    _currentWindow = timeline;
  }

  void play() {
    if (currentWindow is Timeline) {
      audioAssembler.run(timeline.box, timeline.timeAt(timeline.headPosition));
    } else {
      audioAssembler.run(
          patternView.box, patternView.timeAt(patternView.headPosition));
    }
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

  void _parseTempoInput() {
    var bpm = double.tryParse((querySelector('#tempo') as InputElement).value);
    if (bpm != null) {
      this.bpm = bpm;
    }
  }

  void _init() {
    querySelector('#play').onClick.listen((e) => play());
    querySelector('#pause').onClick.listen((e) => pause());
    querySelector('#abort').onClick.listen((e) => audioAssembler.ctx.suspend());
    querySelector('#tempo').onInput.listen((e) => _parseTempoInput());
    _parseTempoInput();

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
        var info = MidiTyping.generateNoteInfo(e.key, true);
        if (info != null) {
          generators.selected.noteEvent(
              info, audioAssembler.ctx.currentTime, NoteSignal.NOTE_START);
        }
      }
    });
    document.onKeyUp.listen((e) {
      var info = MidiTyping.getExistingNoteInfo(e.key);
      if (info != null) {
        generators.selected.noteEvent(
            info, audioAssembler.ctx.currentTime, NoteSignal.NOTE_END);
      }
    });
  }
}
