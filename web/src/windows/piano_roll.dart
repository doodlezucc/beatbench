import 'dart:async';
import 'dart:html';

import '../bar_fraction.dart';
import '../ctx.dart';
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
      _buildKey(common.description, common.whiteKey, parent, i,
          common.mod == 0 || common.mod == 5);
    }
  }

  void _buildKey(String description, bool white, HtmlElement parent, int pitch,
      [bool splitBottom = false]) {
    DivElement keyEl;
    parent.append(keyEl = DivElement()
      ..className =
          (white ? 'white' : 'black') + (splitBottom ? ' split-bottom' : '')
      ..text = description
      ..onMouseDown.listen((e) => _keyOn(pitch, e, keyEl))
      ..onMouseEnter.listen((e) {
        if (e.buttons > 0) {
          _keyOn(pitch, e, keyEl);
        }
      }));
  }

  DivElement _keyElemAtPitch(int pitch) =>
      query('.piano-keys').children[pitchMax - pitch];

  void setKeyVisuallyPlaying(int pitch, bool v) {
    _keyElemAtPitch(pitch).classes.toggle('playing', v);
  }

  void _keyOn(int pitch, MouseEvent e, DivElement keyEl) {
    StreamSubscription subUp;
    StreamSubscription subOut;
    sendNoteOn(NoteInfo(pitch, 1));
    subUp = keyEl.onMouseUp.listen((e) {
      subUp.cancel();
      _keyOff(pitch);
    });
    subOut = keyEl.onMouseOut.listen((e) {
      subOut.cancel();
      _keyOff(pitch);
    });
  }

  void _keyOff(int pitch) {
    sendNoteOff(pitch);
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
  BarFraction get renderedLength => bw.length + BarFraction(4, 1);

  @override
  PlaybackBoxWindow get bw => Project.instance.patternView;

  @override
  BarFraction get gridSize => BarFraction(1, 4);

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
  void addItem(BarFraction start, int y) {
    component.addNote(
        start: start, length: BarFraction(1, 4), pitch: toPitch(y));
  }

  static int toVisual(int pitch) => PianoRoll.pitchMax - pitch;
  static int toPitch(int visual) => PianoRoll.pitchMax - visual;

  void sendNoteOn(NoteInfo info) {
    component.generator.noteStart(info, ctx.currentTime, false);
  }

  void sendNoteOff(int pitch) {
    component.generator.noteEnd(pitch, ctx.currentTime);
  }
}

class PianoRollNote extends RollOrTimelineItem<Transform> {
  PianoRoll get pianoRoll => this.window;

  static final DragSystem<Transform> _dragSystem = DragSystem();
  SpanElement span;
  final Note note;
  StreamSubscription _docUpSub;

  PianoRollNote(PianoRoll window, this.note)
      : super(window.query('#notes').append(DivElement()..className = 'note'),
            window) {
    el
      ..append(span = SpanElement())
      ..append(stretchElem(false, _dragSystem))
      ..append(stretchElem(true, _dragSystem))
      ..onMouseDown.listen((e) {
        sendNoteOn();
        _docUpSub = document.onMouseUp.listen((e) {
          _docUpSub.cancel();
          sendNoteOff(note.y);
        });
      });

    _dragSystem.register(draggable);

    itemPosition();
  }

  void sendNoteOn() {
    if (Project.instance.audioAssembler.isRunning) return;

    pianoRoll.sendNoteOn(note.createInfo());
  }

  void sendNoteOff(int pitch) {
    if (Project.instance.audioAssembler.isRunning) return;

    pianoRoll.sendNoteOff(pitch);
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
  void onNewY(int a, int b) {
    sendNoteOff(a);
    sendNoteOn();
  }

  @override
  Transformable<Transform> get tr => note;
}
