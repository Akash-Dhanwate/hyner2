package com.hyner.hyner

import java.io.File

/** Only generated cache/share PDFs; never durable bill documents or user exports. */
internal object SharedTempFiles {
    const val RETENTION_MILLIS = 7L * 24 * 60 * 60 * 1000
    private val generatedName = Regex("^bill-[A-Za-z0-9-]+\\.pdf$")

    fun clean(directory: File, protectedPrefix: String, nowMillis: Long): Int {
        val root = directory.canonicalFile
        var removed = 0
        var inspected = 0
        directory.listFiles { _, name ->
            // Bound per-pass file I/O, including on old devices without NIO directory streams.
            inspected++ < 1000 && generatedName.matches(name) && !name.startsWith(protectedPrefix)
        }?.forEach { file ->
            try {
                val canonical = file.canonicalFile
                if (canonical.parentFile == root && canonical.name == file.name && file.isFile &&
                    file.lastModified() > 0 && file.lastModified() < nowMillis - RETENTION_MILLIS && file.delete()
                ) removed++
            } catch (_: Exception) {
                // Best effort: lack of permission must never prevent sharing.
            }
        }
        return removed
    }
}
