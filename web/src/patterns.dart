import 'notes.dart';
import 'beat_fraction.dart';

abstract class PatternDataComponent {
  BeatFraction length();
}

class PatternNotesComponent extends PatternDataComponent {
  List<Note> notes;

  PatternNotesComponent(this.notes);

  @override
  BeatFraction length() {
    return notes.fold(
        BeatFraction.washy(0), (v, n) => n.end.beats > v.beats ? n.end : v);
  }
}

class PatternData {
  Map<int, PatternNotesComponent> instrumentNotes;

  BeatFraction length() {
    return const BeatFraction(4, 4);
  }
}

class PatternInstance {
  BeatFraction start;
  BeatFraction length;
  int track;
  PatternData data;

  BeatFraction get end => start + length;

  PatternInstance(
    this.data, {
    this.start = const BeatFraction(0, 1),
    this.length,
    this.track = 0,
  }) {
    length = length ?? data.length();
  }
}
