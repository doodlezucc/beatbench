import 'dart:math';
import 'dart:web_audio';

import '../notes.dart';
import 'base.dart';

class Oscillator extends Generator {
  Oscillator(AudioContext ctx) : super(ctx) {
    node.gain.value = 0.08;
  }

  final Map<NoteInfo, OscillatorNode> _nodes = {};

  @override
  void noteEvent(NoteInfo info, double when, NoteSignal signal) {
    //print('Received ${signal.noteOn} on ${info.coarsePitch}');
    if (_nodes.containsKey(info)) {
      if (signal.isResumed) {
        return;
      }
      _nodes[info].stop(when);
    }
    if (signal.noteOn) {
      var freq = 440 * pow(2, (info.coarsePitch - 69) / 12);
      //print('Frequency: $freq');
      _nodes[info] = node.context.createOscillator()
        ..frequency.value = freq
        ..connectNode(node)
        ..start2(when);
    }
  }
}
