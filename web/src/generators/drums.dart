import 'dart:html';
import 'dart:typed_data';
import 'dart:web_audio';

import 'package:meta/meta.dart';

import '../notes.dart';
import 'base.dart';

class Drums extends Generator {
  final GainNode gain;
  final Map<int, DrumSample> drumSamples;

  Drums(this.drumSamples, BaseAudioContext ctx)
      : gain = ctx.createGain()..gain.value = 0.5,
        super(ctx, null, 'fwd/drums');

  @override
  String get name => 'Fragile Drums';

  @override
  NoteNodeChain createNode(NoteInfo info, bool resume) {
    if (resume) {
      return null; // Don't play a sound when note is resumed
    }
    if (drumSamples.containsKey(info.coarsePitch)) {
      return _DrumPlayingNode(info, ctx, drumSamples[info.coarsePitch].buffer);
    }
    return null;
  }

  @override
  List<AudioNode> get chain => [gain];

  @override
  Generator<NoteNodeChain> cloneForRender(OfflineAudioContext ctx) {
    return Drums(drumSamples, ctx);
  }
}

class _DrumPlayingNode extends NoteNodeChain {
  final AudioBufferSourceNode source;

  _DrumPlayingNode(NoteInfo info, BaseAudioContext ctx, AudioBuffer buffer)
      : source = ctx.createBufferSource()..buffer = buffer,
        super(info, ctx);

  @override
  void start(double when) {
    source.start(when);
  }

  @override
  void stop(double when) {}

  @override
  List<AudioNode> get chain => [source];
}

class DrumSample {
  String name;
  AudioBuffer buffer;

  DrumSample(this.name, this.buffer);
}

class PresetDrums {
  static Future<Drums> cymaticsLofiKit(AudioContext ctx) async => Drums({
        Note.octave(Note.C, 5): await load(
            name: 'Kick', path: 'Cymatics - Lofi Kick 4 - D#.wav', ctx: ctx),
        Note.octave(Note.C + 1, 5): await load(
            name: 'Snare', path: 'Cymatics - Lofi Snare 10 - A.wav', ctx: ctx),
        Note.octave(Note.C + 2, 5): await load(
            name: 'Closed Hihat',
            path: 'Cymatics - Lofi Closed Hihat 1.wav',
            ctx: ctx),
        Note.octave(Note.C + 3, 5): await load(
            name: 'Open Hihat',
            path: 'Cymatics - Lofi Open Hihat 2.wav',
            ctx: ctx),
      }, ctx);

  static Future<DrumSample> load(
      {@required AudioContext ctx, String name, @required String path}) async {
    return DrumSample(name, await loadResource(ctx: ctx, path: path));
  }

  static Future<AudioBuffer> loadResource(
      {@required AudioContext ctx, @required String path}) async {
    var request = await HttpRequest.request(
      Uri.file('resources/$path').toString(),
      responseType: 'arraybuffer',
    );

    var buffer = await ctx.decodeAudioData(request.response as ByteBuffer);
    print('Loaded some stuff yay');
    return buffer;
  }
}
