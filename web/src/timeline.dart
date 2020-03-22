import 'beat_grid.dart';
import 'instruments.dart';
import 'patterns.dart';
import 'simplemusic.dart';

class Timeline {
  RhythmUnit songLength = RhythmUnit(4, 4);
  double get lengthInBeats => songLength.beats;

  List<Instrument> instruments;
  List<Note> notes; // TODO this is, of course, massively simplified...

  Timeline();

  double beatsAt(double seconds, double bps) {
    return wrappedBeats(seconds * bps);
  }

  double wrappedBeats(double beats) {
    return beats % lengthInBeats;
  }

  // WARNING: doesn't do more than one wrap!
  Iterable<NoteShift> getNotes(double startInBeats, double lengthInBeats) {
    var endInBeats = startInBeats + lengthInBeats;
    var loopCount = (startInBeats / this.lengthInBeats).floor();
    var shiftBeats = songLength.beats * loopCount;
    return notes
        .where((n) =>
            n.start.beats + shiftBeats >= startInBeats &&
            n.start.beats + shiftBeats < endInBeats)
        .map((n) => NoteShift(n, songLength * loopCount))
        .followedBy(notes // wrapping condition
            .where((n) =>
                n.start.beats + shiftBeats < endInBeats - this.lengthInBeats)
            .map((n) => NoteShift(n, songLength * (loopCount + 1))));
  }

  void fromBeatGrid(BeatGrid grid) {
    instruments = [grid.drums];
    notes = grid.getNotes();
  }
}

class NoteShift {
  final Note note;
  final RhythmUnit shift;

  const NoteShift(this.note, this.shift);
}
