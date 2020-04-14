import 'dart:html';
import 'dart:math';
import 'dart:web_audio';

import '../../notes.dart';
import '../base.dart';

class Oscillator extends Generator {
  final Map<NoteInfo, OscillatorNode> _nodes = {};
  static const shapeTypes = ['sine', 'square', 'sawtooth', 'triangle'];

  @override
  _OscillatorInterface get visible => super.visible;

  String _type = shapeTypes[0];
  String get type => _type;
  void setType(int typeIndex, [bool isUserInteraction = false]) {
    _type = shapeTypes[typeIndex];
    _nodes.forEach((note, node) {
      node.type = _type;
    });
    if (!isUserInteraction) {
      visible?.shapeSelect?.selectedIndex = typeIndex;
    }
  }

  Oscillator(AudioContext ctx) : super(ctx, _OscillatorInterface()) {
    node.gain.value = 0.1;
  }

  @override
  void noteEvent(NoteInfo info, double when, NoteSignal signal) {
    if (_nodes.containsKey(info)) {
      _nodes[info].stop(when);
    }
    if (signal.noteOn) {
      var freq = 440 * pow(2, (info.coarsePitch - 69) / 12);
      //print('Frequency: $freq');
      _nodes[info] = node.context.createOscillator()
        ..type = type
        ..frequency.value = freq
        ..connectNode(node)
        ..start2(when);
    }
  }

  @override
  String get name => 'My Little Cheap Oscillator';
}

class _OscillatorInterface extends GeneratorInterface<Oscillator> {
  SelectElement shapeSelect;

  @override
  void domInit(Oscillator osc) {
    shapeSelect = query('select')
      ..onInput.listen((e) {
        print('INPUT: ' + shapeSelect.selectedIndex.toString());
        osc.setType(shapeSelect.selectedIndex);
      });
    Oscillator.shapeTypes.forEach((type) {
      shapeSelect.append(OptionElement(data: type));
    });
  }

  @override
  String get htmlPath => 'oscillator/layout.html';
  @override
  String get styleId => 'oscillator';
  @override
  String get cssPath => 'oscillator/style.css';
}
