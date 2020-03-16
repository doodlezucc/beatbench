package fellowhead.beatbench;

public class Beat {
    private double bpm;

    public Beat(double bpm) {
        this.bpm = bpm;
    }

    public double getBpm() {
        return bpm;
    }

    public void setBpm(double bpm) {
        this.bpm = bpm;
    }
}