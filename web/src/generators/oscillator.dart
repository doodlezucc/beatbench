import 'dart:math';
import 'dart:web_audio';

import '../notes.dart';
import 'base.dart';

class Oscillator extends Generator {
  Oscillator(AudioContext ctx) : super(ctx) {
    node.gain.value = 0.05;
  }

  final Map<Note, OscillatorNode> _nodes = {};

  @override
  void noteEvent(Note note, double when, bool noteOn) {
    if (noteOn) {
      var freq = 440 * pow(2, (note.coarsePitch + 12 - 69) / 12);
      print('Frequency: $freq');
      if (_nodes.containsKey(note)) {
        _nodes[note].stop(when);
      }
      _nodes[note] = node.context.createOscillator()
        ..frequency.value = freq
        ..connectNode(node)
        ..start2(when);
    } else {
      _nodes[note].stop(when);
      _nodes.remove(note);
    }
  }
}
