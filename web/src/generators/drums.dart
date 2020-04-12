import 'dart:html';
import 'dart:typed_data';
import 'dart:web_audio';

import 'package:meta/meta.dart';

import '../notes.dart';
import 'base.dart';

class Drums extends Generator {
  Map<int, DrumSample> drumSamples;

  Drums(this.drumSamples, {@required AudioContext ctx}) : super(ctx, null) {
    node.gain.value = 0.5;
  }

  @override
  void noteEvent(NoteInfo note, double when, NoteSignal signal) {
    if (signal == NoteSignal.NOTE_START) {
      if (drumSamples.containsKey(note.coarsePitch)) {
        node.context.createBufferSource()
          ..connectNode(node)
          ..buffer = drumSamples[note.coarsePitch].buffer
          ..start(when);
      }
    }
  }

  @override
  String get name => 'Fragile Drums';
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
      }, ctx: ctx);

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
