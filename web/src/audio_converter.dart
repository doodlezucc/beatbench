import 'dart:html';
import 'dart:math';
import 'dart:typed_data';
import 'dart:web_audio';

import 'audio_assembler.dart';

class AudioConverter {
  final AudioBuffer abuffer;
  final Specs specs;
  final int len;

  AudioConverter(this.abuffer, this.specs, this.len);

  // Based on a JavaScript implementation by Russell Good
  // https://www.russellgood.com/how-to-convert-audiobuffer-to-audio-file/
  //
  // Convert an AudioBuffer to a Blob using WAVE representation
  Blob convertToWav() {
    var numOfChan = abuffer.numberOfChannels,
        length = len * numOfChan * 2 + 44,
        view = ByteData(length),
        channels = <Float32List>[],
        i,
        sample,
        offset = 0,
        pos = 0;

    void setUint16(data) {
      view.setUint16(pos, data, Endian.little);
      pos += 2;
    }

    void setUint32(data) {
      view.setUint32(pos, data, Endian.little);
      pos += 4;
    }

    // write WAVE header
    setUint32(0x46464952); // "RIFF"
    setUint32(length - 8); // file length - 8
    setUint32(0x45564157); // "WAVE"

    setUint32(0x20746d66); // "fmt " chunk
    setUint32(16); // length = 16
    setUint16(1); // PCM (uncompressed)
    setUint16(numOfChan);
    setUint32(abuffer.sampleRate);
    setUint32(abuffer.sampleRate * 2 * numOfChan); // avg. bytes/sec
    setUint16(numOfChan * 2); // block-align
    setUint16(16); // 16-bit (hardcoded in this demo)

    setUint32(0x61746164); // "data" - chunk
    setUint32(length - pos - 4); // chunk length

    // write interleaved data
    for (i = 0; i < abuffer.numberOfChannels; i++) {
      channels.add(abuffer.getChannelData(i));
    }

    while (pos < length) {
      for (i = 0; i < numOfChan; i++) {
        // interleave channels
        sample = max(-1, min(1, channels[i][offset])); // clamp
        sample = (0.5 + sample < 0 ? sample * 32768 : sample * 32767) |
            0; // scale to 16-bit signed int
        view.setInt16(pos, sample, Endian.little); // write 16-bit sample
        pos += 2;
      }
      offset++; // next source sample
      if (offset % 10000 == 0) {
        print((100 * pos / length).toStringAsFixed(1) + '%');
      }
    }

    // create Blob
    return Blob([view.buffer], 'audio/wav');
  }
}
