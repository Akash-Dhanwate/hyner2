# SQLite source dependency

Unmodified SQLite 3.54.1 amalgamation, downloaded from:
https://sqlite.org/2026/sqlite-amalgamation-3540100.zip

The archive SHA3-256 was verified against https://sqlite.org/download.html:
`92281c86e2957f9b9305890f9ac04204caa7b677cc868dc326d942689df28e30`.

Only `sqlite3.c` and `sqlite3.h` are included. SQLite is in the public domain;
the upstream dedication is retained at the start of both source files.
See https://sqlite.org/copyright.html.

The sqlite3 Dart build hook compiles this source for each target. This avoids
runtime reliance on the host's SQLite and flaky external binary downloads.
The package's normal compile definitions are retained. To upgrade, download a
new official amalgamation, verify its published checksum, update both files
and this record, then rerun all migration tests and native builds.
