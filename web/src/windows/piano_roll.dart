import 'dart:html';

import '../beat_fraction.dart';
import '../drag.dart';
import '../history.dart';
import '../notes.dart';
import '../patterns.dart';
import '../project.dart';
import '../transformable.dart';
import '../utils.dart';
import 'specific_windows.dart';

class PianoRoll extends RollOrTimelineWindow<PianoRollNote> {
  static final pixelsPerKey = CssPxVar('piano-roll-ppk');
  static final pixelsPerBeat = CssPxVar('piano-roll-ppb');

  static const int _octaveMin = 2;
  static const int _octaveMax = 8;
  static int get pitchMin => _octaveMin * 12;
  static int get pitchMax => _octaveMax * 12;

  PatternNotesComponent _comp;
  PatternNotesComponent get component => _comp;
  set component(PatternNotesComponent comp) {
    if (_comp != comp) {
      _comp = comp;
      reloadData();
    }
  }

  final _allRollNotes = <PianoRollNote>[];

  PianoRoll() : super(querySelector('#pianoRoll'), 'Piano Roll') {
    _buildPianoKeys();
    Future.microtask(() {
      scrollArea.scrollTop =
          (((_octaveMax - 7) * 12 + 5) * pixelsPerKey.value).round();
    });
  }

  void _buildPianoKeys() {
    var parent = query('.piano-keys');
    for (var i = pitchMax; i >= pitchMin; i--) {
      var common = CommonPitch(i);
      _buildKey(common.description, common.whiteKey, parent,
          common.mod == 0 || common.mod == 5);
    }
  }

  void _buildKey(String description, bool white, HtmlElement parent,
      [bool splitBottom = false]) {
    parent.append(DivElement()
      ..className =
          (white ? 'white' : 'black') + (splitBottom ? ' split-bottom' : '')
      ..text = description);
  }

  void reloadData() {
    items.forEach((n) => n._dispose());
    items.clear();
    items.addAll(_comp.notes.map((n) => PianoRollNote(this, n)));
  }

  @override
  CssPxVar get beatWidth => pixelsPerBeat;
  @override
  CssPxVar get cellHeight => pixelsPerKey;

  @override
  int get canvasHeight =>
      ((pitchMax - pitchMin + 1) * pixelsPerKey.value).round();

  @override
  void drawPreOrientation(CanvasRenderingContext2D ctx) {
    ctx.fillStyle = '#0005';
    ctx.strokeStyle = '#222';
    for (var o = 0; o < _octaveMax - _octaveMin; o++) {
      var i = o * 12 + 1;
      _drawLine(ctx, i);
      _drawKey(ctx, i + 1);
      _drawKey(ctx, i + 3);
      _drawKey(ctx, i + 5);
      _drawLine(ctx, i + 7);
      _drawKey(ctx, i + 8);
      _drawKey(ctx, i + 10);
    }
    ctx.stroke();
  }

  void _drawKey(CanvasRenderingContext2D ctx, int i) {
    var y = i * pixelsPerKey.value + RollOrTimelineWindow.railHeight.value;
    ctx.fillRect(0, y, canvasBg.width, pixelsPerKey.value);
  }

  void _drawLine(CanvasRenderingContext2D ctx, int i) {
    var y =
        i * pixelsPerKey.value + RollOrTimelineWindow.railHeight.value - 0.5;
    ctx.moveTo(0, y);
    ctx.lineTo(canvasBg.width, y);
  }

  @override
  BeatFraction get renderedLength => bw.length + BeatFraction(4, 1);

  @override
  PlaybackBoxWindow get bw => Project.instance.patternView;

  @override
  BeatFraction get gridSize => BeatFraction(1, 4);

  Iterable<Note> getNotes() {
    return items.map((i) => i.note);
  }

  void onNoteAction(Note note, bool create) {
    if (create) {
      var prn = _allRollNotes.firstWhere((pn) => pn.note == note,
          orElse: () => PianoRollNote(this, note));
      items.add(prn);
      prn.selected = true;
    } else {
      var prn = items.singleWhere((i) => i.note == note);
      prn._dispose();
      items.remove(prn);
      bw.box.thereAreChanges();
    }
  }

  @override
  bool handleDelete() {
    if (selectedItems.isNotEmpty) {
      History.perform(NotesComponentAction(component, false,
          selectedItems.map((pn) => pn.note).toList(growable: false)));
    }
    return true;
  }

  @override
  void addItem(BeatFraction start, int y) {
    History.perform(NotesComponentAction(component, true,
        [Note(pitch: toPitch(y), start: start, length: BeatFraction(1, 4))]));
  }

  static int toVisual(int pitch) => PianoRoll.pitchMax - pitch;
  static int toPitch(int visual) => PianoRoll.pitchMax - visual;
}

class PianoRollNote extends RollOrTimelineItem<Transform> {
  PianoRoll get pianoRoll => this.window;

  static final DragSystem<Transform> _dragSystem = DragSystem();
  SpanElement span;
  final Note note;

  PianoRollNote(PianoRoll window, this.note)
      : super(window.query('#notes').append(DivElement()..className = 'note'),
            window) {
    el
      ..append(span = SpanElement())
      ..append(stretchElem(false, _dragSystem))
      ..append(stretchElem(true, _dragSystem));

    _dragSystem.register(draggable);

    itemPosition();
  }

  void _dispose() {
    el.remove();
  }

  @override
  bool get invertVerticalDragging => true;

  int get pitch => note.y;

  void onUpdate() {
    itemPosition();

    if (note.end > pianoRoll.bw.length) {
      pianoRoll.bw.length = note.end;
    } else if (note.end < pianoRoll.bw.length) {
      Project.instance.patternView.calculateLength();
    } else {
      pianoRoll.bw.box.thereAreChanges();
    }
  }

  @override
  void onYSet() {
    el.style.top = cssCalc(PianoRoll.toVisual(pitch), PianoRoll.pixelsPerKey);
    span.text = CommonPitch(pitch).description;
  }

  @override
  Transformable<Transform> get tr => note;
}
