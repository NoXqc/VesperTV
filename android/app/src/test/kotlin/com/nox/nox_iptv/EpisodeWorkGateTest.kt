package com.nox.nox_iptv

import org.junit.Assert.*
import org.junit.Test

class EpisodeWorkGateTest {
    @Test fun foregroundCannotAcquireWorkerLease() {
        val gate = EpisodeWorkGate()
        gate.setVisible(true)
        assertNull(gate.acquire())
        gate.setVisible(false)
        assertNotNull(gate.acquire())
    }
    @Test fun openingThenClosingAppStillInvalidatesOldWorker() {
        val gate = EpisodeWorkGate()
        val old = gate.acquire()
        assertTrue(gate.allowed(old))
        gate.setVisible(true)
        assertFalse(gate.allowed(old))
        gate.setVisible(false)
        assertFalse(gate.allowed(old))
        assertNull(gate.acquire())
        gate.release(old)
        assertTrue(gate.allowed(gate.acquire()))
    }
    @Test fun onlyTheLeaseOwnerCanReleaseAndOldLeaseCannotCommit() {
        val gate = EpisodeWorkGate()
        val first = gate.acquire()
        assertNull(gate.acquire())
        gate.release(-1)
        assertTrue(gate.allowed(first))
        gate.release(first)
        val second = gate.acquire()
        gate.release(first)
        assertTrue(gate.allowed(second))
        assertFalse(gate.allowed(first))
        assertFalse(gate.allowed(null))
    }
}
