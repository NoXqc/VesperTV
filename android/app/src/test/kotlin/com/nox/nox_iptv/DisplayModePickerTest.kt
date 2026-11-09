package com.nox.nox_iptv

import org.junit.Assert.*
import org.junit.Test

class DisplayModePickerTest {
    private val modes = listOf(
        DisplayModePicker.Mode(1, 1280, 720, 59.94),
        DisplayModePicker.Mode(2, 1280, 720, 50.0),
        DisplayModePicker.Mode(3, 1920, 1080, 59.94),
        DisplayModePicker.Mode(4, 1920, 1080, 50.0),
        DisplayModePicker.Mode(5, 3840, 2160, 59.94),
        DisplayModePicker.Mode(6, 3840, 2160, 50.0),
    )
    private val tv4k = modes[4]

    private fun pick(fps: Double, w: Int, h: Int, rate: Boolean = true, resolution: Boolean = true) =
        DisplayModePicker.pick(modes, tv4k, fps, w, h, rate, false, resolution)

    @Test fun a720pChannelStaysAt1080pNot720p() {
        // LOG-RJQ6N6 (onn 4K Pro): 720p output scaled the interface and video differently.
        assertEquals(3, pick(59.94, 1280, 720))
        assertEquals(4, pick(50.0, 1280, 720))
        assertEquals(3, pick(29.97, 720, 480))
    }

    @Test fun fullHdAnd4kStillMatch() {
        assertEquals(3, pick(59.94, 1920, 1080))
        assertEquals(6, pick(50.0, 3840, 2160))
        assertEquals(3, pick(59.94, 1920, 804))
    }

    @Test fun rateOnlyKeepsTheCurrentSize() {
        assertEquals(6, pick(50.0, 1280, 720, resolution = false))
    }

    @Test fun aTvWithOnly720pKeepsItsMode() {
        val small = listOf(DisplayModePicker.Mode(1, 1280, 720, 60.0), DisplayModePicker.Mode(2, 1280, 720, 50.0))
        assertEquals(2, DisplayModePicker.pick(small, small[0], 50.0, 1280, 720, true, false, true))
    }
}
