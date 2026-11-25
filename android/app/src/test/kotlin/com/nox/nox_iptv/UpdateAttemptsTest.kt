package com.nox.nox_iptv

import org.junit.Assert.*
import org.junit.Test

/** GitHub #22: an update handed to the installer that never arrived. */
class UpdateAttemptsTest {
    @Test fun stillTheOldVersionIsAFailure() {
        assertTrue(UpdateAttempts.outcome(targetCode = 1013, installedCode = 980))
    }

    @Test fun theNewVersionIsNot() {
        assertFalse(UpdateAttempts.outcome(targetCode = 1013, installedCode = 1013))
        assertFalse(UpdateAttempts.outcome(targetCode = 1013, installedCode = 1020))
    }

    @Test fun unknownVersionsSayNothing() {
        assertFalse(UpdateAttempts.outcome(targetCode = -1, installedCode = 980))
        assertFalse(UpdateAttempts.outcome(targetCode = 1013, installedCode = -1))
    }
}
