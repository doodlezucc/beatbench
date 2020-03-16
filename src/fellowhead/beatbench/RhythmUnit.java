package fellowhead.beatbench;

public class RhythmUnit {
    private final int numerator;
    private final int denominator;

    public RhythmUnit(int numerator, int denominator) {
        this.numerator = numerator;
        this.denominator = denominator;
    }

    public int getNumerator() {
        return numerator;
    }

    public int getDenominator() {
        return denominator;
    }
}