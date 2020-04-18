import 'notes.dart';

class MidiTyping {
  static final Map<String, NoteInfo> _infos = {};

  static NoteInfo generateNoteInfo(String key, bool qwertz) {
    if (_infos.containsKey(key)) {
      return null;
    }
    var pitch = _getPitch(key, qwertz);
    if (pitch != null) {
      var info = NoteInfo(Note.octave(pitch, 4), 1);
      _infos[key] = info;
      return info;
    }
    return null;
  }

  static NoteInfo getExistingNoteInfo(String key) {
    var info = _infos[key];
    _infos.remove(key);
    return info;
  }

  static int _getPitch(String key, bool qwertz) {
    switch (key) {
      case 'z':
        return qwertz ? Note.A + 12 : Note.C;
      case 's':
        return Note.C + 1;
      case 'x':
        return Note.D;
      case 'd':
        return Note.D + 1;
      case 'c':
        return Note.E;
      case 'v':
        return Note.F;
      case 'g':
        return Note.F + 1;
      case 'b':
        return Note.G;
      case 'h':
        return Note.G + 1;
      case 'n':
        return Note.A;
      case 'j':
        return Note.A + 1;
      case 'm':
        return Note.B;

      case ',':
        return Note.C + 12;
      case 'l':
        return Note.C + 13;
      case '.':
        return Note.D + 12;

      case 'q':
        return Note.C + 12;
      case '2':
        return Note.C + 13;
      case 'w':
        return Note.D + 12;
      case '3':
        return Note.D + 13;
      case 'e':
        return Note.E + 12;
      case 'r':
        return Note.F + 12;
      case '5':
        return Note.F + 13;
      case 't':
        return Note.G + 12;
      case '6':
        return Note.G + 13;
      case 'y':
        return qwertz ? Note.C : Note.A + 12;
      case '7':
        return Note.A + 13;
      case 'u':
        return Note.B + 12;

      case 'i':
        return Note.C + 24;
      case '9':
        return Note.C + 25;
      case 'o':
        return Note.D + 24;
      case '0':
        return Note.D + 25;
      case 'p':
        return Note.E + 24;
    }
    return null;
  }
}
