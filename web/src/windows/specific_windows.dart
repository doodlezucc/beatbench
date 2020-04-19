import 'dart:html';
import 'dart:math';

import 'package:meta/meta.dart';

import '../audio_assembler.dart';
import '../beat_fraction.dart';
import '../drag.dart';
import '../utils.dart';
import 'windows.dart';
import '../history.dart';

mixin PlaybackBoxWindow on Window {
  PlaybackBox get box;

  BeatFraction get length => _length;
  BeatFraction _length = BeatFraction(4, 4);
  set length(BeatFraction l) {
    var min = BeatFraction(4, 4);
    if (l < min) l = min;
    _length = l;
    box.length = timeAt(l);
    drawOrientation();
    box.thereAreChanges();
    if (headPosition > length) {
      headPosition = BeatFraction.washy(headPosition.beats % length.beats);
    }
  }

  BeatFraction _headPosition = BeatFraction(0, 1);
  BeatFraction get headPosition => _headPosition;
  set headPosition(BeatFraction headPosition) {
    if (headPosition > length) {
      headPosition = length;
    } else if (headPosition.numerator < 0) {
      headPosition = BeatFraction(0, 4);
    }
    if (headPosition != _headPosition) {
      _headPosition = headPosition;
      onHeadSet(headPosition);
      drawForeground(headPosition.beats);
      box.position = timeAt(headPosition);
    }
  }

  void onHeadSet(BeatFraction head);
  void drawForeground(double ghost);
  void drawOrientation();

  double timeAt(BeatFraction songLength);
  double beatsAt(double time);

  void onNewTempo() {
    box.handleNewTempo(timeAt(length));
  }
}

abstract class RollOrTimelineWindow<I extends RollOrTimelineItem>
    extends Window {
  CssPxVar get cellHeight;
  static final CssPxVar railHeight = CssPxVar('rail-height');

  BeatFraction get renderedLength;

  CanvasElement canvasFg;
  CanvasElement canvasBg;

  HtmlElement get scrollArea => query('.right');

  final List<I> items = [];
  Iterable<I> get selectedItems => items.where((p) => p.selected);

  RollOrTimelineWindow(HtmlElement element, String title)
      : super(element, title) {
    canvasBg = query('#background')
      ..onMouseDown.listen((e) {
        if (!(e.shiftKey || e.ctrlKey)) {
          if (selectedItems.isNotEmpty) {
            selectedItems.forEach((i) => i.selected = false);
          } else {
            addItem(BeatFraction.floor(e.offset.x / beatWidth.value, gridSize),
                ((e.offset.y - railHeight.value) / cellHeight.value).floor());
          }
        }
      });
    canvasFg = query('#foreground');
    drawBg();

    scrollArea.onScroll.listen((ev) => _onScroll());
    _onScroll();

    var handle = query('#head .handle');
    query('.rail').onMouseDown.listen((e) {
      handle.classes.toggle('dragged', true);
      _playheadFromPixels(e);
      var sub = document.onMouseMove.listen(_playheadFromPixels);
      var sub2;
      sub2 = document.onMouseUp.listen((e) {
        handle.classes.toggle('dragged', false);
        sub.cancel();
        sub2.cancel();
      });
    });
  }

  void addItem(BeatFraction start, int y);

  void _onScroll() {
    //e.style.top = (-query('#right').scrollTop).toString() + 'px';
    query('#head').parent.style.left =
        (-scrollArea.scrollLeft).toString() + 'px';
    query('.left').style.top = (-scrollArea.scrollTop).toString() + 'px';
  }

  PlaybackBoxWindow get bw;

  void _playheadFromPixels(MouseEvent e) {
    bw.headPosition = BeatFraction.round(
        (e.page.x - query('.rail').documentOffset.x) / beatWidth.value,
        gridSize);
  }

  T extremeItem<T>(dynamic Function(Transform tr) variable,
      {@required bool max, bool onlyDragged = true, T ifNone}) {
    var list = onlyDragged ? selectedItems : items;
    return extreme<I, T>(
        list, (item) => variable(_getTransform(item, onlyDragged)),
        max: max, ifNone: ifNone);
  }

  Transform _getTransform(I item, bool dragged) =>
      dragged ? item.draggable.savedVar : item.transform;

  void drawFg(double head, double ghost) {
    var l = renderedLength;
    canvasFg.width = (l.beats * beatWidth.value).round();
    canvasFg.height = canvasHeight + railHeight.value.round();

    var ctx = canvasFg.context2D;
    ctx.clearRect(0, 0, canvasFg.width, canvasFg.height);

    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.5;
    var x = head * beatWidth.value;
    ctx.moveTo(x, 0);
    ctx.lineTo(x, canvasFg.height);

    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.5;
    x = ghost * beatWidth.value;
    ctx.moveTo(x, 0);
    ctx.lineTo(x, canvasFg.height);

    ctx.stroke();
  }

  BeatFraction get gridSize;
  CssPxVar get beatWidth;

  void drawBg() {
    canvasBg.width = (renderedLength.beats * beatWidth.value).round();
    canvasBg.height = canvasHeight + railHeight.value.round();

    var ctx = canvasBg.context2D;
    ctx.clearRect(0, 0, canvasBg.width, canvasBg.height);

    drawPreOrientation(ctx);

    ctx.strokeStyle = '#fff4';
    for (var b = 0.0; b <= renderedLength.beats; b += gridSize.beats) {
      var x = (b * beatWidth.value).round() - 0.5;
      ctx.moveTo(x, 0);
      ctx.lineTo(x, canvasBg.height);
    }
    ctx.stroke();

    ctx.fillStyle = '#0008';
    ctx.fillRect(bw.length.beats * beatWidth.value, 0,
        (renderedLength - bw.length).beats * beatWidth.value, canvasBg.height);
  }

  void drawPreOrientation(CanvasRenderingContext2D ctx) {}

  int get canvasHeight;

  void windowHeadSet(BeatFraction head) {
    query('#head').style.left = cssCalc(head.beats, beatWidth);
  }
}

abstract class RollOrTimelineItem<T extends Transform> {
  final RollOrTimelineWindow window;
  final HtmlElement el;

  BeatFraction _start;
  BeatFraction get start => _start;
  set start(BeatFraction start) {
    if (silentStart(start)) onUpdate();
  }

  bool silentStart(BeatFraction start) {
    var oldStart = _start;
    _start = start.beats >= 0 ? start : BeatFraction(0, 1);
    el.style.left = cssCalc(_start.beats, window.beatWidth);
    return _start != oldStart;
  }

  void onUpdate();

  BeatFraction _length;
  BeatFraction get length => _length;
  set length(BeatFraction length) {
    if (silentLength(length)) {
      onUpdate();
    }
  }

  bool silentLength(BeatFraction length) {
    var oldLength = _length;
    _length = length.beats >= 1 ? length : BeatFraction(1, 4);
    el.style.width = cssCalc(_length.beats, window.beatWidth);
    if (_length != oldLength) {
      onWidthSet();
      return true;
    }
    return false;
  }

  void onWidthSet() {}

  int _y;
  int get y => _y;
  set y(int y) {
    if (_y != y) {
      _y = y;
      onYSet();
      onUpdate();
    }
  }

  void onYSet() {}

  BeatFraction get end => start + length;

  bool _selected = false;
  bool get selected => _selected;
  set selected(bool v) {
    _selected = v;
    el.classes.toggle('selected', v);
  }

  Draggable<T> draggable;
  T get transform => Transform(start, length, y) as T;
  void applyTransform(T transform) {
    start = transform.start;
    length = transform.length;
    y = transform.y;
  }

  RollOrTimelineItem(this.el, this.window) {
    el.onMouseDown.listen((e) {
      if (!selected) {
        if (!e.shiftKey) {
          window.selectedItems.forEach((p) => p.selected = false);
        }
        selected = true;
      }
    });
    draggable = Draggable<T>(el, () => transform, (tr, pixelOff, ev) {
      var xDiff = BeatFraction.round(
          pixelOff.x / window.beatWidth.value, window.gridSize);
      var minXDiff = window.extremeItem((tr) => tr.start, max: false) * -1;
      if (xDiff < minXDiff) {
        xDiff = minXDiff;
      }
      var minYDiff = -window.extremeItem<num>((tr) => tr.y, max: false);
      var yDiff =
          max(minYDiff, (pixelOff.y / window.cellHeight.value + 0.5).floor());

      window.selectedItems.forEach((p) {
        p.start = p.draggable.savedVar.start + xDiff;
        p.y = p.draggable.savedVar.y + yDiff;
      });

      if (ev.detail == 1) {
        if (tr != transform) {
          History.registerDoneAction(TransformAction(
              window.selectedItems.toList(growable: false), transform - tr));
        } else if (pixelOff.x == 0 && pixelOff.y == 0) {
          if (!ev.shiftKey) {
            window.selectedItems.forEach((p) => p.selected = false);
          }
          selected = true;
        }
      }
    });
  }

  DivElement stretchElem(bool right, DragSystem<T> dragSystem) {
    var out = DivElement()..className = 'stretch ${right ? 'right' : 'left'}';
    dragSystem.register(Draggable<T>(
      out,
      () => transform,
      (tr, off, ev) {
        var diff =
            BeatFraction.round(off.x / window.beatWidth.value, window.gridSize);
        // diff maximum: lengthOld - 1
        var maxDiff =
            window.extremeItem((i) => i.length, max: false) - window.gridSize;
        if (right) {
          if (diff < maxDiff * -1) diff = maxDiff * -1;
          window.selectedItems.forEach((p) {
            p.length = p.draggable.savedVar.length + diff;
          });
        } else {
          if (diff > maxDiff) diff = maxDiff;
          diff = leftStretch(diff);
        }
        if (diff.numerator == 0) return;
        if (ev.detail == 1) {
          // register reversible action
          History.registerDoneAction(TransformAction(
              window.selectedItems.toList(growable: false), transform - tr));
        }
      },
    ));
    return out;
  }

  BeatFraction leftStretch(BeatFraction diff) {
    var minDiff = window.extremeItem((i) => i.start, max: false) * -1;
    if (diff < minDiff) diff = minDiff;

    window.selectedItems.forEach((p) {
      if (p.silentLength(p.draggable.savedVar.length - diff)) {
        p.start = p.draggable.savedVar.start + diff;
      }
    });

    return diff;
  }
}

class Transform {
  final BeatFraction start;
  final BeatFraction length;
  final int y;

  Transform(this.start, this.length, this.y);

  @override
  bool operator ==(dynamic other) => other is Transform
      ? start == other.start && length == other.length && y == other.y
      : false;

  Transform operator +(Transform o) => Transform(
        start + o.start,
        length + o.length,
        y + o.y,
      );

  Transform operator -(Transform o) => Transform(
        start - o.start,
        length - o.length,
        y - o.y,
      );
}

class PatternTransform extends Transform {
  final BeatFraction contentShift;

  PatternTransform(
      BeatFraction start, BeatFraction length, this.contentShift, int track)
      : super(start, length, track);

  @override
  bool operator ==(dynamic other) => other is PatternTransform
      ? start == other.start &&
          length == other.length &&
          contentShift == other.contentShift &&
          y == other.y
      : false;

  @override
  PatternTransform operator +(dynamic o) => PatternTransform(
        start + o.start,
        length + o.length,
        contentShift + o.contentShift,
        y + o.y,
      );

  @override
  PatternTransform operator -(dynamic o) => PatternTransform(
        start - o.start,
        length - o.length,
        contentShift - o.contentShift,
        y - o.y,
      );
}

class TransformAction<T extends RollOrTimelineItem> extends MultipleAction<T> {
  final dynamic diff;

  TransformAction(Iterable<T> items, this.diff) : super(items);

  @override
  void doSingle(T object) {
    object.applyTransform(object.transform + diff);
  }

  @override
  void undoSingle(T object) {
    object.applyTransform(object.transform - diff);
  }
}
