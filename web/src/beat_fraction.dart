class BeatFraction {
  final int numerator;
  final int denominator;
  final double beats;
  bool get isWashy => numerator < 0 || denominator < 0;

  const BeatFraction(this.numerator, this.denominator)
      : beats = 4 * numerator / denominator;

  const BeatFraction.washy(this.beats)
      : numerator = -1,
        denominator = -1;

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

  BeatFraction operator *(num m) {
    if (isWashy) {
      return BeatFraction.washy(beats * m);
    }
    return BeatFraction(numerator * m, denominator);
  }

  BeatFraction ceilToBeat() {
    // 5/8 ||| (4*5/8)^ * 8/4 ---> (2.5)^ * 2 ---> 3*2 ---> 6
    return BeatFraction(
        ((4 * numerator / denominator).ceil() * denominator / 4).ceil(),
        denominator);
  }

  bool equals(BeatFraction other) =>
      numerator == other.numerator && denominator == other.denominator;

  int compare(BeatFraction other) =>
      equals(other) ? 0 : (beats > other.beats ? 1 : -1);
}
