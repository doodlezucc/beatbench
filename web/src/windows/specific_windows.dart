import 'dart:html';
import 'dart:math';

import 'package:meta/meta.dart';

import '../audio_assembler.dart';
import '../bar_fraction.dart';
import '../drag.dart';
import '../transformable.dart';
import '../utils.dart';
import 'windows.dart';
import '../history.dart';

mixin PlaybackBoxWindow on Window {
  PlaybackBox get box;

  BarFraction get length => _length;
  BarFraction _length = BarFraction(4, 4);
  set length(BarFraction l) {
    var min = BarFraction(4, 4);
    if (l < min) l = min;
    _length = l;
    box.length = timeAt(l);
    drawOrientation();
    box.thereAreChanges();
    if (headPosition > length) {
      headPosition = BarFraction.washy(headPosition.beats % length.beats);
    }
  }

  BarFraction _headPosition = BarFraction(0, 1);
  BarFraction get headPosition => _headPosition;
  set headPosition(BarFraction headPosition) {
    if (headPosition > length) {
      headPosition = length;
    } else if (headPosition.numerator < 0) {
      headPosition = BarFraction(0, 4);
    }
    if (headPosition != _headPosition) {
      _headPosition = headPosition;
      onHeadSet(headPosition);
      drawForeground(headPosition.beats);
      box.position = timeAt(headPosition);
    }
  }

  void onHeadSet(BarFraction head);
  void drawForeground(double ghost);
  void drawOrientation();

  double timeAt(BarFraction songLength);
  double beatsAt(double time);

  void onNewTempo() {
    box.handleNewTempo(timeAt(length));
  }
}

abstract class RollOrTimelineWindow<I extends RollOrTimelineItem>
    extends Window {
  CssPxVar get cellHeight;
  static final CssPxVar railHeight = CssPxVar('rail-height');

  BarFraction get renderedLength;

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
            addItem(BarFraction.floor(e.offset.x / beatWidth.value, gridSize),
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

  void addItem(BarFraction start, int y);

  void _onScroll() {
    //e.style.top = (-query('#right').scrollTop).toString() + 'px';
    query('#head').parent.style.left =
        (-scrollArea.scrollLeft).toString() + 'px';
    query('.left').style.top = (-scrollArea.scrollTop).toString() + 'px';
  }

  PlaybackBoxWindow get bw;

  void _playheadFromPixels(MouseEvent e) {
    bw.headPosition = BarFraction.round(
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
      dragged ? item.draggable.savedVar : item.tr.transform;

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

  BarFraction get gridSize;
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

  void windowHeadSet(BarFraction head) {
    query('#head').style.left = cssCalc(head.beats, beatWidth);
  }
}

abstract class RollOrTimelineItem<T extends Transform> {
  final RollOrTimelineWindow window;
  final HtmlElement el;
  Transformable<T> get tr;

  void itemPosition() {
    el.style.left = cssCalc(tr.start.beats, window.beatWidth);
    el.style.width = cssCalc(tr.length.beats, window.beatWidth);
    onYSet();
  }

  void onYSet();

  bool _selected = false;
  bool get selected => _selected;
  set selected(bool v) {
    _selected = v;
    el.classes.toggle('selected', v);
  }

  Draggable<T> draggable;

  bool get invertVerticalDragging => false;

  RollOrTimelineItem(this.el, this.window) {
    el.onMouseDown.listen((e) {
      if (!selected) {
        if (!e.shiftKey) {
          window.selectedItems.forEach((p) => p.selected = false);
        }
        selected = true;
      }
    });
    draggable = Draggable<T>(el, () => tr.transform, (srcTr, pixelOff, ev) {
      var xDiff = BarFraction.round(
          pixelOff.x / window.beatWidth.value, window.gridSize);
      var minXDiff = window.extremeItem((tr) => tr.start, max: false) * -1;
      if (xDiff < minXDiff) {
        xDiff = minXDiff;
      }
      var minYDiff = -window.extremeItem<num>((tr) => tr.y, max: false);
      var yDiff = max(
          minYDiff,
          ((invertVerticalDragging ? -1 : 1) *
                      pixelOff.y /
                      window.cellHeight.value +
                  0.5)
              .floor());

      window.selectedItems.forEach((p) {
        p.tr.start = p.draggable.savedVar.start + xDiff;
        p.tr.y = p.draggable.savedVar.y + yDiff;
      });

      if (ev.detail == 1) {
        if (srcTr != tr.transform) {
          _registerTransformAction(tr.transform - srcTr);
        } else if (pixelOff.x == 0 && pixelOff.y == 0) {
          if (!ev.shiftKey) {
            window.selectedItems.forEach((p) => p.selected = false);
          }
          selected = true;
        }
      }
    });
  }

  void _registerTransformAction(Transform diff) {
    History.registerDoneAction(TransformAction(
        window.selectedItems.map((i) => i.tr).toList(growable: false), diff));
  }

  DivElement stretchElem(bool right, DragSystem<T> dragSystem) {
    var out = DivElement()..className = 'stretch ${right ? 'right' : 'left'}';
    dragSystem.register(Draggable<T>(
      out,
      () => tr.transform,
      (srcTr, off, ev) {
        var diff =
            BarFraction.round(off.x / window.beatWidth.value, window.gridSize);
        // diff maximum: lengthOld - 1
        var maxDiff =
            window.extremeItem((i) => i.length, max: false) - window.gridSize;
        if (right) {
          if (diff < maxDiff * -1) diff = maxDiff * -1;
          window.selectedItems.forEach((p) {
            p.tr.length = p.draggable.savedVar.length + diff;
          });
        } else {
          if (diff > maxDiff) diff = maxDiff;
          diff = leftStretch(diff);
        }
        if (diff.numerator == 0) return;
        if (ev.detail == 1) {
          // register reversible action
          _registerTransformAction(tr.transform - srcTr);
        }
      },
    ));
    return out;
  }

  BarFraction leftStretch(BarFraction diff) {
    var minDiff = window.extremeItem((i) => i.start, max: false) * -1;
    if (diff < minDiff) diff = minDiff;

    window.selectedItems.forEach((p) {
      p.tr.length = p.draggable.savedVar.length - diff;
      p.tr.start = p.draggable.savedVar.start + diff;
    });

    return diff;
  }
}
