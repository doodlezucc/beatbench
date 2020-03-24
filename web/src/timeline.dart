import 'beat_grid.dart';
import 'instruments.dart';
import 'notes.dart';
import 'beat_fraction.dart';
import 'patterns.dart';
import 'utils.dart';

class Timeline {
  // UI stuff
  static final pixelsPerBeat = CssPxVar('timeline-ppb', 20);
  static final pixelsPerTrack = CssPxVar('timeline-ppt', 70);

  BeatFraction songLength = BeatFraction(4, 4);
  double get lengthInBeats => songLength.beats;

  List<Instrument> instruments;
  List<PatternInstance> patterns;
  List<List<NoteShift>> _noteShiftBuffer;

  Timeline();

  double beatsAt(double seconds, double bps) {
    return wrappedBeats(seconds * bps);
  }

  double wrappedBeats(double beats) {
    return beats % lengthInBeats;
  }

  void updateNoteShiftBuffer() {
    _noteShiftBuffer =
        List<List<NoteShift>>.filled(instruments.length, <NoteShift>[]);
    patterns.forEach((pat) {
      var notes = pat.data.instrumentNotes;
      for (var i = 0; i < _noteShiftBuffer.length; i++) {
        _noteShiftBuffer[i]
            .addAll(notes[i].notes.map((note) => NoteShift(note, pat.start)));
      }
    });
  }

  // WARNING: doesn't do more than one wrap!
  Iterable<Iterable<NoteShift>> getNotes(
      double startInBeats, double lengthInBeats) {
    var endInBeats = startInBeats + lengthInBeats;
    var loopCount = (startInBeats / this.lengthInBeats).floor();
    var shiftBeats = songLength.beats * loopCount;

    return _noteShiftBuffer.map((patShiftedNotesOfAnInstr) =>
        patShiftedNotesOfAnInstr
            .where((n) {
              var shiftedStart =
                  n.note.start.beats + n.shift.beats + shiftBeats;
              return shiftedStart >= startInBeats && shiftedStart < endInBeats;
            })
            .map((n) => NoteShift(n.note, n.shift + songLength * loopCount))
            // wrapping
            .followedBy(patShiftedNotesOfAnInstr
                .where((n) =>
                    n.note.start.beats + n.shift.beats + shiftBeats <
                    endInBeats - this.lengthInBeats)
                .map((n) => NoteShift(
                    n.note, n.shift + songLength * (loopCount + 1)))));
  }

  void updateSongLength() {
    songLength = patterns.fold(BeatFraction.washy(0),
        (v, pat) => pat.end.beats > v.beats ? pat.end.ceilToBeat() : v);
  }

  void fromBeatGrid(BeatGrid grid) {
    instruments = [grid.drums];
    var gridPatternData = PatternData(
      'My awesome beat',
      {0: PatternNotesComponent(grid.getNotes())},
    );
    var crashPatternData = PatternData(
      'Crash!',
      {
        0: PatternNotesComponent([
          Note(tone: Note.D + 1, octave: 5),
        ])
      },
    );
    patterns = [
      PatternInstance(gridPatternData),
      PatternInstance(gridPatternData, start: const BeatFraction(1, 1)),
      PatternInstance(gridPatternData, start: const BeatFraction(2, 1)),
      PatternInstance(gridPatternData, start: const BeatFraction(3, 1)),
      // open hihat only on the first of 4 bars -> proof-of-concept: timeline & patterns
      PatternInstance(crashPatternData, track: 1)
    ];
    updateSongLength();
    updateNoteShiftBuffer();
  }
}

class NoteShift {
  final Note note;
  final BeatFraction shift;

  const NoteShift(this.note, this.shift);
}
