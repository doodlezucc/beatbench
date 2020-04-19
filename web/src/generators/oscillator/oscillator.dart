import 'dart:html';
import 'dart:math';
import 'dart:web_audio';

import '../../notes.dart';
import '../base.dart';

class Oscillator extends Generator<_OscNoteNode> {
  final GainNode gain;
  static const shapeTypes = ['sine', 'square', 'sawtooth', 'triangle'];

  @override
  _OscillatorInterface get visible => super.visible;

  String _type = shapeTypes[0];
  String get type => _type;
  void setType(int typeIndex, [bool isUserInteraction = false]) {
    _type = shapeTypes[typeIndex];
    playingNodes.forEach((node) {
      node.oscNode.type = _type;
    });
    if (!isUserInteraction) {
      visible?.shapeSelect?.selectedIndex = typeIndex;
    }
  }

  Oscillator(BaseAudioContext ctx)
      : gain = ctx.createGain(),
        super(ctx, _OscillatorInterface()) {
    gain.gain.value = 0.1;
  }

  @override
  String get name => 'My Little Cheap Oscillator';

  @override
  List<AudioNode> get chain => [gain];

  @override
  _OscNoteNode createNode(NoteInfo note, bool resume) =>
      _OscNoteNode(this, note, ctx);
}

class _OscNoteNode extends NoteNodeChain {
  final OscillatorNode oscNode;

  _OscNoteNode(Oscillator osc, NoteInfo info, BaseAudioContext ctx)
      : oscNode = ctx.createOscillator(),
        super(info, ctx) {
    var freq = 440 * pow(2, (info.coarsePitch - 69) / 12);
    oscNode
      ..type = osc.type
      ..frequency.value = freq;
  }

  @override
  List<AudioNode> get chain => [oscNode];

  @override
  void start(double when) {
    oscNode.start2(when);
  }

  @override
  void stop(double when) {
    oscNode.stop(when);
  }
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
