class BarFraction {
  final int numerator;
  final int denominator;
  final double beats;
  bool get isWashy => denominator == 0;

  const BarFraction(this.numerator, this.denominator)
      : beats = 4 * numerator / denominator;

  const BarFraction.washy(this.beats)
      : numerator = 0,
        denominator = 0;

  // round 0.5 : (1/3) => (3/12)
  BarFraction.round(double beats, BarFraction gridSize)
      : this((beats * gridSize.numerator * gridSize.denominator / 4).round(),
            gridSize.denominator);

  BarFraction.floor(double beats, BarFraction gridSize)
      : this((beats * gridSize.numerator * gridSize.denominator / 4).floor(),
            gridSize.denominator);

  BarFraction operator +(BarFraction other) {
    if (isWashy || other.isWashy) {
      return BarFraction.washy(beats + other.beats);
    }
    if (denominator == other.denominator) {
      return BarFraction(numerator + other.numerator, denominator);
    }
    return BarFraction(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator);
    // 1/2 + 1/8 = (8+2)/(16) = 10/16 = 5/8 !!!
  }

  BarFraction operator -(BarFraction other) {
    return this + other * -1;
  }

  BarFraction operator *(num m) {
    if (isWashy) {
      return BarFraction.washy(beats * m);
    }
    return BarFraction(numerator * m, denominator);
  }

  BarFraction ceilTo(int denom) {
    return BarFraction(
        ((denom * numerator / denominator).ceil() * denominator / denom).ceil(),
        denominator);
  }

  BarFraction swingify(double amount) {
    if (amount > 0 && beats % 0.5 >= 0.25) {
      var source = beats % 0.25;
      var off = amount / 8 + source / (1 + amount);
      return BarFraction.washy(((beats * 4).floor() / 4) + off);
    }
    return this;
  }

  @override
  bool operator ==(dynamic other) =>
      (other is BarFraction) ? beats == other.beats : false;

  bool operator >(BarFraction other) {
    return beats > other.beats;
  }

  bool operator >=(BarFraction other) {
    return beats >= other.beats;
  }

  bool operator <(BarFraction other) {
    return beats < other.beats;
  }

  bool operator <=(BarFraction other) {
    return beats <= other.beats;
  }

  @override
  String toString() => '$numerator/$denominator';
}
