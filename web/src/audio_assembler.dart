import 'dart:typed_data';
import 'dart:web_audio';

import 'instruments.dart';
import 'patterns.dart';
import 'simplemusic.dart';

class Specs {
  final int sampleRate = 44100;
}

class AudioAssembler {
  Specs specs = Specs();
  var ctx = AudioContext();
  AudioBufferSourceNode source;

  AudioAssembler();

  void doSomething() {
    source = ctx.createBufferSource();
    source.channelCount = 1;

    var osc = ctx.createOscillator();
    osc.frequency.value = 110;
    source.connectNode(ctx.destination);
    //osc.start2();

    var drums = PresetDrums.basicKit();
    var notes = <Note>[];
    for (var i = 0; i < 16; i++) {
      notes.add(Note(tone: Note.C, octave: 5, start: RhythmUnit(i, 4)));
    }

    var streams = drums.createStream(NotePacket(
        notes: notes, bpm: 150, time: RhythmUnit(0, 4), specs: Specs()));
    var allInAll = Float32List(800000);
    streams.forEach((s) {
      allInAll.setRange(s.start, s.start + s.length, s.request());
    });

    source.buffer = ctx.createBuffer(1, 400000, specs.sampleRate)
      ..copyToChannel(allInAll, 0);
  }

  void run() async {
    source.start2();
    print(await ctx.resume());
    print(ctx.state);
    print('yeah boi');
  }
}
