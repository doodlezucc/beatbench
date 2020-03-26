class BeatFraction {
  final int numerator;
  final int denominator;
  final double beats;
  bool get isWashy => denominator == 0;

  const BeatFraction(this.numerator, this.denominator)
      : beats = 4 * numerator / denominator;

  const BeatFraction.washy(this.beats)
      : numerator = 0,
        denominator = 0;

  BeatFraction operator +(BeatFraction other) {
    if (isWashy || other.isWashy) {
      return BeatFraction.washy(beats + other.beats);
    }
    if (denominator == other.denominator) {
      return BeatFraction(numerator + other.numerator, denominator);
    }
    return BeatFraction(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator);
    // 1/2 + 1/8 = (8+2)/(16) = 10/16 = 5/8 !!!
  }

  BeatFraction operator -(BeatFraction other) {
    return this + other * -1;
  }

  BeatFraction operator *(num m) {
    if (isWashy) {
      return BeatFraction.washy(beats * m);
    }
    return BeatFraction(numerator * m, denominator);
  }

  BeatFraction ceilTo(int denom) {
    return BeatFraction(
        ((denom * numerator / denominator).ceil() * denominator / denom).ceil(),
        denominator);
  }

  @override
  bool operator ==(dynamic other) =>
      (other is BeatFraction) ? beats == other.beats : false;

  bool operator >(BeatFraction other) {
    return beats > other.beats;
  }

  bool operator >=(BeatFraction other) {
    return beats >= other.beats;
  }

  bool operator <(BeatFraction other) {
    return beats < other.beats;
  }

  bool operator <=(BeatFraction other) {
    return beats <= other.beats;
  }

  @override
  String toString() => '$numerator/$denominator';
}
