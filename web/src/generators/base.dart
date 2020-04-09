import 'dart:web_audio';

import '../notes.dart';

abstract class Generator {
  final GainNode node;

  Generator(AudioContext ctx)
      : node = ctx.createGain()..connectNode(ctx.destination);

  void noteEvent(NoteInfo note, double when, NoteSignal signal);
}

class NoteSignal {
  final bool noteOn;
  final bool isResumed;

  const NoteSignal(this.noteOn, this.isResumed);

  static const NoteSignal NOTE_START = NoteSignal(true, false);
  static const NoteSignal NOTE_RESUME = NoteSignal(true, true);
  static const NoteSignal NOTE_END = NoteSignal(false, false);
}
