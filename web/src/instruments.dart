import 'dart:html';
import 'dart:typed_data';
import 'dart:web_audio';

import 'package:meta/meta.dart';

import 'audio_assembler.dart';
import 'patterns.dart';
import 'simplemusic.dart';

class NotePacket {
  final List<Note> notes;
  final double bpm;
  final RhythmUnit time;
  final Specs specs;

  NotePacket(
      {@required this.notes,
      @required this.bpm,
      @required this.time,
      @required this.specs});
}

abstract class Instrument {
  final GainNode node;

  Instrument(AudioContext ctx)
      : node = ctx.createGain()..connectNode(ctx.destination);

  void playNote(Note note, double when);
}

class Drums extends Instrument {
  Map<int, DrumSample> drumSamples;

  Drums(this.drumSamples, {@required AudioContext ctx}) : super(ctx);

  @override
  void playNote(Note note, double when) {
    if (drumSamples.containsKey(note.coarsePitch)) {
      node.context.createBufferSource()
        ..connectNode(node)
        ..buffer = drumSamples[note.coarsePitch].buffer
        ..start(when);
    }
  }
}

class DrumSample {
  String name;
  AudioBuffer buffer;

  DrumSample(this.name, this.buffer);
}

class PresetDrums {
  static Future<Drums> cymaticsLofiKit(AudioContext ctx) async => Drums({
        Note.getPitch(Note.C, 5):
            await load(name: 'Kick', path: 'lofiC.wav', ctx: ctx),
        Note.getPitch(Note.C + 1, 5):
            await load(name: 'Snare', path: 'lofiC#.wav', ctx: ctx),
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
    ByteBuffer response = request.response;

    var buffer = await ctx.decodeAudioData(response);
    print('Loaded some stuff yay');
    return buffer;
  }
}
