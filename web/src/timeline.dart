import 'beat_grid.dart';
import 'instruments.dart';
import 'patterns.dart';

class Timeline {
  double get lengthInBeats => 4;

  List<Instrument> instruments;
  List<Note> notes; // TODO this is, of course, massively simplified...

  Timeline();

  void fromBeatGrid(BeatGrid grid) {
    instruments = [grid.drums];
    notes = grid.getNotes();
  }
}
