import 'dart:collection';

import 'package:beatbench/audio_assembler.dart';
import 'package:beatbench/simplemusic.dart';
import 'package:flutter/material.dart';

import 'patterns.dart';

class AudioStream {
  Queue<double> _stream = Queue();
  Iterable<double> Function(int offset, int length) _request;

  void push(Iterable<double> add) {
    _stream.addAll(add);
  }

  AudioStream(start, this._request);
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
  @override
  List<AudioStream> createStream(NotePacket packet) {
    return packet.notes
        .where((note) => note.start.compare(packet.time) >= 0)
        .map((note) => AudioStream(
            RhythmUnit.beatsInSamples(note.start.beats - packet.time.beats,
                packet.bpm, packet.specs.sampleRate),
            (offset, length) {}))
        .toList(growable: false);
  }
}
