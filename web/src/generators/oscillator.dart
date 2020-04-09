import 'dart:math';
import 'dart:web_audio';

import '../notes.dart';
import 'base.dart';

class Oscillator extends Generator {
  Oscillator(AudioContext ctx) : super(ctx) {
    node.gain.value = 0.05;
  }

  final Map<NoteInfo, OscillatorNode> _nodes = {};

  @override
  void noteEvent(NoteInfo info, double when, NoteSignal signal) {
    if (_nodes.containsKey(info)) {
      _nodes[info].stop(when);
    }
    if (signal.noteOn) {
      var freq = 440 * pow(2, (info.coarsePitch - 69) / 12);
      //print('Frequency: $freq');
      if (_nodes.containsKey(info)) {
        _nodes[info].stop(when);
      }
      _nodes[info] = node.context.createOscillator()
        ..frequency.value = freq
        ..connectNode(node)
        ..start2(when);
    } else {
      _nodes.remove(info);
    }
  }
}
