package com.hyner.hyner

internal object PdfFilename {
    fun sanitize(input: String): String? {
        if (input.isBlank() || input.length > 160 || !input.endsWith(".pdf", ignoreCase = true)) return null
        val stem = input.dropLast(4)
            .replace(Regex("[^\\p{L}\\p{M}\\p{N} ._-]"), "_")
            .replace(Regex("\\s+"), " ")
            .replace(Regex("_+"), "_")
            .replace(Regex("\\.{2,}"), ".")
            .trim(' ', '.', '_', '-')
        if (stem.isBlank() || stem.length > 116) return null
        return "$stem.pdf"
    }
}
