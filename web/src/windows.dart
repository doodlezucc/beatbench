import 'dart:html';

import 'audio_assembler.dart';
import 'beat_fraction.dart';
import 'project.dart';
import 'timeline.dart';
import 'utils.dart';

abstract class Window {
  HtmlElement _element;
  HtmlElement get element => _element;
  final HtmlElement _frame;

  String get title => _frame.querySelector('.title').text;
  set title(String title) {
    _frame.querySelector('.title').text = title;
  }

  bool get isFocused => Project.instance.currentWindow == this;
  void focus() {
    var old = Project.instance.currentWindow;
    if (old != null) old._setFocus(false);
    Project.instance.currentWindow = this;
    visible = true;
    _setFocus(true);
  }

  void _setFocus(bool v) {
    _frame.classes.toggle('focused', v);
  }

  bool get visible => _frame.parent != null;

  set visible(bool v) {
    var parent = document.querySelector('#windows');
    v ? parent.append(_frame) : _frame.remove();
  }

  Point<num> get position => _frame.getBoundingClientRect().topLeft;
  set position(Point<num> position) {
    _frame.style.left = '${position.x}px';
    _frame.style.top = '${position.y}px';
  }

  static HtmlElement _createFrame(String title) {
    return DivElement()
      ..className = 'window'
      ..append(DivElement()
        ..className = 'topbar'
        ..append(SpanElement()
          ..className = 'title'
          ..text = title));
  }

  Window(HtmlElement element, String title) : _frame = _createFrame(title) {
    _element = _frame.append(element);
    visible = false;
  }

  bool handleKeyDown(KeyEvent event) => false;
  bool handleDelete() => false;
  bool handleSelectAll() => false;
  bool handleClone() => false;

  Element query(String selectors) => element.querySelector(selectors);
}

abstract class RollOrTimelineWindow extends Window {
  CssPxVar get beatWidth;

  BeatFraction _length = BeatFraction(4, 4);
  BeatFraction get length => _length;
  BeatFraction get renderLength => _length + BeatFraction(16, 1);
  set length(BeatFraction l) {
    var min = BeatFraction(4, 4);
    if (l < min) l = min;
    _length = l;
    box.length = timeAt(l);
    _drawOrientation();
    box.thereAreChanges();
    if (headPosition > renderLength) {
      headPosition =
          BeatFraction.washy(headPosition.beats % renderLength.beats);
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
      query('#head').style.left = cssCalc(headPosition.beats, beatWidth);
      drawForeground(headPosition.beats);
      box.position = timeAt(headPosition);
    }
  }

  CanvasElement _canvasFg;
  CanvasElement _canvasBg;

  PlaybackBox _box;
  PlaybackBox get box => _box;

  HtmlElement get _scrollArea => query('.right');

  RollOrTimelineWindow(HtmlElement element, String title)
      : super(element, title) {
    _canvasBg = query('#background')..onClick.listen(onBackgroundClick);
    _canvasFg = query('#foreground');
    _drawOrientation();
    _box = PlaybackBox(
      onUpdateVisuals: (time) {
        drawForeground(beatsAt(time));
      },
      onStop: () {
        drawForeground(headPosition.beats);
      },
      getNotes: notesCache,
    );

    _scrollArea.onScroll.listen((ev) => _onScroll());
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

  void _onScroll() {
    //e.style.top = (-query('#right').scrollTop).toString() + 'px';
    query('#head').parent.style.left =
        (-_scrollArea.scrollLeft).toString() + 'px';
    query('#tracks').style.top = (-_scrollArea.scrollTop).toString() + 'px';
  }

  void _playheadFromPixels(MouseEvent e) {
    headPosition = BeatFraction(
        ((e.client.x - query('.rail').documentOffset.x) / beatWidth.value)
            .floor(),
        4);
  }

  void onNewTempo() {
    box.handleNewTempo(timeAt(length));
  }

  void thereAreChanges() {
    box.thereAreChanges();
  }

  void _drawOrientation() {
    drawOrientation(length, renderLength, BeatFraction(1, 4), beatWidth.value);
  }

  void drawForeground(double ghost) {
    var l = renderLength;
    _canvasFg.width = (l.beats * beatWidth.value).round();
    _canvasFg.height = canvasHeight;

    var ctx = _canvasFg.context2D;
    ctx.clearRect(0, 0, _canvasFg.width, _canvasFg.height);

    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.5;
    var x = headPosition.beats * beatWidth.value;
    ctx.moveTo(x, 0);
    ctx.lineTo(x, _canvasFg.height);

    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.5;
    x = ghost * beatWidth.value;
    ctx.moveTo(x, 0);
    ctx.lineTo(x, _canvasFg.height);

    ctx.stroke();
  }

  void drawOrientation(
    BeatFraction activeLength,
    BeatFraction renderLength,
    BeatFraction drawSteps,
    double ppb,
  ) {
    _canvasBg.width = (renderLength.beats * ppb).round();
    _canvasBg.height = canvasHeight;

    var ctx = _canvasBg.context2D;
    ctx.clearRect(0, 0, _canvasBg.width, _canvasBg.height);

    ctx.strokeStyle = '#fff4';
    for (var b = 0.0; b <= renderLength.beats; b += drawSteps.beats) {
      var x = (b * ppb).round() - 0.5;
      ctx.moveTo(x, 0);
      ctx.lineTo(x, _canvasBg.height);
    }
    ctx.stroke();

    ctx.fillStyle = '#0008';
    ctx.fillRect(activeLength.beats * ppb, 0,
        (renderLength - activeLength).beats * ppb, _canvasBg.height);
  }

  void onBackgroundClick(MouseEvent e);
  int get canvasHeight;

  double timeAt(BeatFraction songLength);

  double beatsAt(double time);

  Iterable<PlaybackNote> notesCache();
}
