package com.hyner.hyner

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PdfFilenameTest {
    @Test fun preservesReadableUnicodeAndSpaces() {
        assertEquals("Rahul Patil_9876543210.pdf", PdfFilename.sanitize("Rahul Patil_9876543210.pdf"))
        assertEquals("शर्मा जी_1234567890.pdf", PdfFilename.sanitize("शर्मा जी_1234567890.pdf"))
    }

    @Test fun replacesPathSeparatorsAndRejectsUnsafeExtensions() {
        assertEquals("secret.pdf", PdfFilename.sanitize("../secret.pdf"))
        assertNull(PdfFilename.sanitize("invoice.apk"))
        assertNull(PdfFilename.sanitize("a".repeat(161) + ".pdf"))
    }
}
