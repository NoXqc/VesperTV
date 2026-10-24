package io.flutter.plugins.videoplayer;

import android.graphics.Bitmap;
import android.graphics.Color;

/** One recent, private playback snapshot. Never persisted or exported. Main-thread ownership. */
final class ZapFrameCache {
  private Bitmap picture;
  private long capturedAt;

  void put(Bitmap next, long now) {
    clear();
    picture = next;
    capturedAt = now;
  }

  Bitmap take(long now) {
    if (picture == null) return null;
    if (now < capturedAt || now - capturedAt > 2500) {
      clear();
      return null;
    }
    Bitmap result = picture;
    picture = null;
    return result;
  }

  void clear() {
    if (picture != null) picture.recycle();
    picture = null;
  }

  /** Sample only 144 pixels, off the UI thread. Reject blank/vendor-green copies. */
  static boolean usable(Bitmap picture) {
    int opaque = 0, green = 0, dark = 0;
    int minGreen = 255, maxGreen = 0;
    for (int y = 0; y < 9; y++) {
      for (int x = 0; x < 16; x++) {
        int pixel = picture.getPixel((2 * x + 1) * picture.getWidth() / 32,
            (2 * y + 1) * picture.getHeight() / 18);
        int r = Color.red(pixel), g = Color.green(pixel), b = Color.blue(pixel);
        if (Color.alpha(pixel) >= 250) opaque++;
        if (r <= 8 && g <= 8 && b <= 8) dark++;
        // Zeroed YUV buffers can convert to dark green (~0,135,0), not #00ff00.
        if (g >= 48 && g - r >= 40 && g - b >= 40 && r <= 80 && b <= 80) {
          green++;
          minGreen = Math.min(minGreen, g);
          maxGreen = Math.max(maxGreen, g);
        }
      }
    }
    return opaque >= 137 && dark < 137 && !(green >= 137 && maxGreen - minGreen <= 24);
  }
}
