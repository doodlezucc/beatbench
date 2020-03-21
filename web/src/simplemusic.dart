class RhythmUnit {
  final int numerator;
  final int denominator;
  final double beats;

  const RhythmUnit(this.numerator, this.denominator)
      : beats = 4 * numerator / denominator;

  const RhythmUnit.washy(this.beats)
      : numerator = -1,
        denominator = -1;

  bool equals(RhythmUnit other) =>
      numerator == other.numerator && denominator == other.denominator;

  int compare(RhythmUnit other) =>
      equals(other) ? 0 : (beats > other.beats ? 1 : -1);

  static int beatsInSamples(double beats, double bpm, int sampleRate) =>
      (sampleRate * beats / (bpm / 60)).round();

  int inSamples(double bpm, int sampleRate) =>
      beatsInSamples(beats, bpm, sampleRate);
}
