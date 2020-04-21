import 'beat_fraction.dart';
import 'history.dart';

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

mixin Transformable<T extends Transform> {
  BeatFraction _start;
  BeatFraction _length;
  int _y;

  BeatFraction get start => _start;
  set start(BeatFraction start) {
    if (_start != start) {
      _start = start;
      onTransformed();
    }
  }

  BeatFraction get length => _length;
  set length(BeatFraction length) {
    if (_length != length) {
      _length = length;
      onTransformed();
    }
  }

  int get y => _y;
  set y(int y) {
    if (_y != y) {
      _y = y;
      onTransformed();
    }
  }

  BeatFraction get end => start + length;

  void applyTransform(T transform) {
    _start = transform.start;
    _length = transform.length;
    _y = transform.y;
    onTransformed();
  }

  T get transform => Transform(start, length, y) as T;

  void onTransformed();
}

class TransformAction<T extends Transformable> extends MultipleAction<T> {
  final Transform diff;

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
