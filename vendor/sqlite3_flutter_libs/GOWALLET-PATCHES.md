# GOwallet Android SQLite hardening

Based on sqlite3_flutter_libs 0.5.25 (upstream MIT license retained).
Android uses the same SQLite 3.46.1 source and feature definitions as the previous
`eu.simonbinder:sqlite3-native-library:3.46.1+1` artifact.

Reference build: https://github.com/simolus3/sqlite-native-libraries/tree/d32ebbed8d8a50ec24bef6e2cae18a48db8cd8c0

The source download is pinned by SHA-256 in android/cpp/CMakeLists.txt. SQLite
itself is public-domain software: https://sqlite.org/copyright.html .

Instead of resetting CMAKE_C_FLAGS to -O3, preserve Android NDK defaults and add
target-specific optimization, stack protection, FORTIFY, immediate binding,
RELRO and non-executable stack flags. No schema, Dart API or SQL feature option
is changed. Android builds use NDK 28.0.13004108 and minimum API 24, consistent
with GOwallet's application requirements. Other platforms retain upstream files.

This is compiler hardening, not a SQLite version upgrade or a claim that all
SQLite vulnerabilities have been audited or fixed.
