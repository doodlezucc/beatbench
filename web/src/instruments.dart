import 'dart:math';

import 'package:meta/meta.dart';

import 'audio_assembler.dart';
import 'patterns.dart';
import 'simplemusic.dart';

class AudioStream {
  final int start;
  final int length;
  final Iterable<double> Function(int offset, int length) request;

  AudioStream(
      {@required this.start, @required this.length, @required this.request});
}

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
  List<AudioStream> createStream(NotePacket packet);
}

class Drums extends Instrument {
  Map<int, DrumSample> drumSamples;

  Drums(this.drumSamples);

  @override
  List<AudioStream> createStream(NotePacket packet) {
    return packet.notes
        .where((note) =>
            drumSamples.containsKey(note.coarsePitch) &&
            note.start.compare(packet.time) >= 0)
        .map((note) => AudioStream(
              start: RhythmUnit.beatsInSamples(
                  note.start.beats - packet.time.beats,
                  packet.bpm,
                  packet.specs.sampleRate),
              request: (offset, length) => drumSamples.entries
                  .firstWhere((element) => element.key == note.coarsePitch)
                  .value
                  .request(),
              length: 10000,
            ))
        .toList(growable: false);
  }
}

class DrumSample {
  String name;
  final Iterable<double> Function(int length) _request;
  int length;

  Iterable<double> request() => _request(length);

  DrumSample(this.name, this._request, this.length);
}

class PresetDrums {
  static Drums basicKit() => Drums({Note.getPitch(Note.C, 5): kick()});

  static DrumSample kick() {
    return DrumSample('Kick', (length) {
      var frequency = 110;
      var sampleRate = 44100; // TODO make this prettier
      var samples = List<double>(length);

      for (var i = 0; i < length; i++) {
        samples[i] = 0.2 *
            (1 - i / (length - 1)) *
            sin(2 * pi * frequency * (i / sampleRate));
      }
      return samples;
    }, 10000);
  }
}

class SineOscillator {}
