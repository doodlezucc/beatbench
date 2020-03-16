package fellowhead.beatbench.layout;

import java.awt.*;

import fellowhead.beatbench.Beat;

public class Sequencer extends Component {
    private Beat beat;

    public Sequencer(Beat beat) {
        setBeat(beat);
    }

    public Beat getBeat() {
        return beat;
    }

    public void setBeat(Beat beat) {
        this.beat = beat;
    }
}