package io.flutter.plugins.videoplayer;

import static org.junit.Assert.*;
import android.graphics.Bitmap;
import android.graphics.Color;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = {28, 30})
public class ZapFrameCacheTest {
  private Bitmap solid(int color) {
    Bitmap picture = Bitmap.createBitmap(160, 90, Bitmap.Config.ARGB_8888);
    picture.eraseColor(color);
    return picture;
  }

  @Test public void rejectsDarkYuvGreenAndBrightGreenButKeepsTexturedField() {
    for (int green : new int[] {64, 135, 180, 255}) {
      Bitmap picture = solid(Color.rgb(0, green, 0));
      assertFalse(ZapFrameCache.usable(picture));
      picture.recycle();
    }
    Bitmap field = solid(Color.GREEN);
    for (int y = 0; y < 90; y++) {
      for (int x = 0; x < 160; x++) field.setPixel(x, y, Color.rgb(20, 90 + x % 140, 10));
    }
    assertTrue(ZapFrameCache.usable(field));
    field.recycle();
  }

  @Test public void rejectsBlankOrTransparentCaptureAndAcceptsOrdinaryPicture() {
    for (int color : new int[] {Color.BLACK, Color.TRANSPARENT}) {
      Bitmap picture = solid(color);
      assertFalse(ZapFrameCache.usable(picture));
      picture.recycle();
    }
    Bitmap normal = solid(Color.BLUE);
    assertTrue(ZapFrameCache.usable(normal));
    normal.recycle();
    Bitmap tiny = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888);
    tiny.eraseColor(Color.GREEN);
    assertFalse(ZapFrameCache.usable(tiny));
    tiny.recycle();
  }

  @Test public void onlyKeepsOneFrameAndTransfersItsOwnershipOnce() {
    ZapFrameCache cache = new ZapFrameCache();
    Bitmap first = solid(Color.RED), second = solid(Color.BLUE);
    cache.put(first, 100);
    cache.put(second, 200);
    assertTrue(first.isRecycled());
    assertSame(second, cache.take(300));
    assertNull(cache.take(300));
    cache.clear();
    assertFalse(second.isRecycled()); // now owned by the visible cover, not the cache
    second.recycle();
  }

  @Test public void expiredAndClearedFramesCannotLeakAcrossChannels() {
    ZapFrameCache cache = new ZapFrameCache();
    Bitmap old = solid(Color.BLUE);
    cache.put(old, 100);
    assertNull(cache.take(2601));
    assertTrue(old.isRecycled());
    Bitmap current = solid(Color.RED);
    cache.put(current, 3000);
    cache.clear();
    assertTrue(current.isRecycled());
    assertNull(cache.take(3100));
  }
}
