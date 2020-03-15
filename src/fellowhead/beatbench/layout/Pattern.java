package fellowhead.beatbench.layout;

import fellowhead.beatbench.*;

public class Pattern {
    private PatternData data;
    private RhythmUnit start;
    private RhythmUnit length;

    public Pattern(PatternData data, RhythmUnit start, RhythmUnit length) {
        this.data = data;
        this.start = start;
        this.length = length;
    }

    public PatternData getData() {
        return data;
    }

    public RhythmUnit getStart() {
        return start;
    }

    public RhythmUnit getLength() {
        return length;
    }
}