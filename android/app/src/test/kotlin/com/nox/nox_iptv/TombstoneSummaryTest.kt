package com.nox.nox_iptv

import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayOutputStream

/** Tombstones built by hand in Android's layout (system/core/debuggerd/proto/tombstone.proto). */
class TombstoneSummaryTest {
    private class Proto {
        val out = ByteArrayOutputStream()
        private fun varint(v: Long) {
            var x = v
            while (true) {
                if (x and 0x7fL.inv() == 0L) { out.write(x.toInt()); return }
                out.write(((x and 0x7f) or 0x80).toInt())
                x = x ushr 7
            }
        }
        fun num(field: Int, v: Long) = apply { varint((field shl 3).toLong()); varint(v) }
        fun bytes(field: Int, b: ByteArray) = apply {
            varint(((field shl 3) or 2).toLong()); varint(b.size.toLong()); out.write(b)
        }
        fun text(field: Int, s: String) = bytes(field, s.toByteArray())
        fun msg(field: Int, m: Proto) = bytes(field, m.out.toByteArray())
        fun fixed64(field: Int) = apply { varint(((field shl 3) or 1).toLong()); out.write(ByteArray(8)) }
        fun build(): ByteArray = out.toByteArray()
    }

    private fun frame(pc: Long, file: String, fn: String = "", off: Long = 0) =
        Proto().num(1, pc).num(2, pc + 0x7000).text(4, fn).num(5, off).text(6, file)

    private fun thread(id: Int, name: String, vararg frames: Proto) = Proto().apply {
        num(1, id.toLong()).text(2, name)
        for (f in frames) msg(4, f)
    }

    private fun tombstone(): ByteArray {
        val signal = Proto().num(1, 11).text(2, "SIGSEGV").num(3, 1).text(4, "SEGV_MAPERR")
            .num(8, 1).num(9, 0x10)
        val crashed = thread(
            4321, "RenderThread",
            frame(0x1234, "/vendor/lib64/egl/libGLES_mali.so", "", 0),
            frame(0x5678, "/system/lib64/libhwui.so", "android::uirenderer::renderthread::DrawFrameTask::run()", 52),
        )
        val other = thread(4300, "main", frame(0x9, "/apex/com.android.runtime/lib64/bionic/libc.so", "__epoll_pwait", 8))
        val log = Proto().text(1, "2026-11-25 14:09:16.950").num(2, 4300).num(3, 4321).num(4, 6)
            .text(5, "VesperNativeSurface").text(6, "surface A destroyed")
        return Proto()
            .num(1, 1).text(2, "google/kirkwood/kirkwood:14").fixed64(23)
            .num(5, 4300).num(6, 4321)
            .msg(10, signal)
            .text(14, "")
            .msg(15, Proto().text(1, "null pointer dereference"))
            .msg(16, Proto().num(1, 4300).msg(2, other))
            .msg(16, Proto().num(1, 4321).msg(2, crashed))
            .msg(18, Proto().text(1, "main").msg(2, log))
            .build()
    }

    @Test fun crashingThreadAndSignal() {
        val lines = TombstoneSummary.summarize(tombstone())
        assertEquals("  SIGSEGV (SEGV_MAPERR) fault 0x10", lines[0])
        assertEquals("  cause: null pointer dereference", lines[1])
        assertEquals("  thread RenderThread (4321), 2 threads", lines[2])
        assertEquals("  #00 pc 1234 libGLES_mali.so", lines[3])
        assertEquals(
            "  #01 pc 5678 libhwui.so (android::uirenderer::renderthread::DrawFrameTask::run()+52)",
            lines[4],
        )
        assertTrue(lines.last(), lines.last().endsWith("VesperNativeSurface: surface A destroyed"))
        assertTrue(lines.none { it.contains("epoll") }) // other threads are left out
    }

    @Test fun abortMessageIsShown() {
        val data = Proto().num(6, 7).msg(10, Proto().text(2, "SIGABRT"))
            .text(14, "Check failed: frame != nullptr")
            .msg(16, Proto().num(1, 7).msg(2, thread(7, "1.raster", frame(0x1, "/data/app/x/lib/arm64/libflutter.so"))))
            .build()
        val lines = TombstoneSummary.summarize(data)
        assertEquals("  SIGABRT", lines[0])
        assertEquals("  abort: Check failed: frame != nullptr", lines[1])
        assertEquals("  #00 pc 1 libflutter.so", lines[3])
    }

    @Test fun framesAreCapped() {
        val frames = (0 until 40).map { frame(it.toLong(), "/system/lib64/libc.so") }.toTypedArray()
        val data = Proto().num(6, 1).msg(16, Proto().num(1, 1).msg(2, thread(1, "t", *frames))).build()
        val count = TombstoneSummary.summarize(data).count { it.startsWith("  #") }
        assertEquals(TombstoneSummary.MAX_FRAMES, count)
    }

    @Test fun garbageFallsBackToLibraryStrings() {
        val data = byteArrayOf(0x0f, 0x7f, 0x00) + "\u0001/system/lib64/libhwui.so\u0000junk".toByteArray()
        val lines = TombstoneSummary.summarize(data)
        assertEquals(listOf("  ~ /system/lib64/libhwui.so"), lines)
    }

    @Test fun emptyReportSaysNothing() {
        assertTrue(TombstoneSummary.summarize(ByteArray(0)).isEmpty())
    }
}
