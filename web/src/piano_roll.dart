import 'dart:html';

import 'beat_fraction.dart';
import 'patterns.dart';
import 'project.dart';
import 'timeline.dart';
import 'utils.dart';
import 'windows.dart';

class PianoRoll extends RollOrTimelineWindow {
  static final pixelsPerKey = CssPxVar('piano-roll-ppk', 20);
  static final pixelsPerBeat = CssPxVar('piano-roll-ppb', 20);

  PatternNotesComponent _notesComponent;
  PatternNotesComponent get notesComponent => _notesComponent;
  set notesComponent(PatternNotesComponent notesComponent) {
    _notesComponent = notesComponent;
  }

  final List<PatternInstance> _patterns = [];
  Iterable<PatternInstance> get selectedPatterns =>
      _patterns.where((p) => p.selected);

  PianoRoll() : super(querySelector('#pianoRoll'), 'Piano Roll') {
    _buildPianoKeys();
  }

  void _buildPianoKeys() {
    var parent = query('.piano-keys');
    for (var octave = 8; octave >= 0; octave--) {
      _buildKey('H', octave, true, parent);
      _buildKey('A#', octave, false, parent);
      _buildKey('A', octave, true, parent);
      _buildKey('G#', octave, false, parent);
      _buildKey('G', octave, true, parent);
      _buildKey('F#', octave, false, parent);
      _buildKey('F', octave, true, parent);
      _buildKey('E', octave, true, parent);
      _buildKey('D#', octave, false, parent);
      _buildKey('D', octave, true, parent);
      _buildKey('C#', octave, false, parent);
      _buildKey('C', octave, true, parent);
    }
  }

  void _buildKey(String name, int octave, bool white, HtmlElement parent) {
    parent.append(DivElement()
      ..className = white ? 'white' : 'black'
      ..text = '$name$octave');
  }

  @override
  CssPxVar get beatWidth => pixelsPerBeat;

  @override
  int get canvasHeight => (8 * 12 * pixelsPerKey.value).round();

  @override
  Iterable<PlaybackNote> notesCache() {
    // TODO: implement notesCache
    return null;
  }

  @override
  void onBackgroundClick(MouseEvent e) {
    // TODO: implement onBackgroundClick
  }

  @override
  double timeAt(BeatFraction bf) {
    return bf.beats / (Project.instance.bpm / 60);
  }

  @override
  double beatsAt(double seconds) {
    return seconds * (Project.instance.bpm / 60);
  }
}
