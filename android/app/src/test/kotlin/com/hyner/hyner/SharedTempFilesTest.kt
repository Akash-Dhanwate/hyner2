package com.hyner.hyner

import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files

class SharedTempFilesTest {
    @Test fun onlyOldGeneratedInactiveRegularFilesAreRemoved() {
        val folder = Files.createTempDirectory("hyner-share-cleanup").toFile()
        val outside = Files.createTempFile("hyner-user-export", ".pdf").toFile()
        try {
            val now = System.currentTimeMillis()
            val old = now - SharedTempFiles.RETENTION_MILLIS - 1000
            fun file(name: String, modified: Long) = folder.resolve(name).apply {
                writeText("%PDF-1.7\nfixture"); assertTrue(setLastModified(modified))
            }
            val obsolete = file("bill-old-123.pdf", old)
            val fresh = file("bill-recent-123.pdf", now)
            val currentHandoff = file("bill-session-123.pdf", old)
            val userNamed = file("important-bill.pdf", old)
            val directory = folder.resolve("bill-directory-123.pdf").apply { mkdir(); setLastModified(old) }
            val symlink = folder.toPath().resolve("bill-link-123.pdf")
            Files.createSymbolicLink(symlink, outside.toPath())
            assertEquals(1, SharedTempFiles.clean(folder, "bill-session-", now))
            assertFalse(obsolete.exists())
            assertTrue(fresh.exists()); assertTrue(currentHandoff.exists()); assertTrue(userNamed.exists())
            assertTrue(directory.exists()); assertTrue(Files.isSymbolicLink(symlink)); assertTrue(outside.exists())
            assertEquals(0, SharedTempFiles.clean(folder, "bill-session-", now))
        } finally { folder.deleteRecursively(); outside.delete() }
    }
}
