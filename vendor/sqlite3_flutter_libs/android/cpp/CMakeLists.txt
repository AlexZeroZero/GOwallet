cmake_minimum_required(VERSION 3.14)
project(gowallet_sqlite3 LANGUAGES C)
include(FetchContent)
FetchContent_Declare(sqlite3
    URL https://sqlite.org/2024/sqlite-autoconf-3460100.tar.gz
    URL_HASH SHA256=67d3fe6d268e6eaddcae3727fce58fcc8e9c53869bdd07a0c61e38ddf2965071
)
FetchContent_MakeAvailable(sqlite3)
add_library(sqlite3 SHARED "${sqlite3_SOURCE_DIR}/sqlite3.c")
target_include_directories(sqlite3 PRIVATE ${sqlite3_SOURCE_DIR})
# Preserve NDK flags; upstream's set(CMAKE_C_FLAGS "-O3") discarded them.
target_compile_options(sqlite3 PRIVATE -O3 -fstack-protector-strong)
target_compile_definitions(sqlite3 PRIVATE _FORTIFY_SOURCE=2)
target_link_options(sqlite3 PRIVATE -Wl,-z,relro,-z,now,-z,noexecstack)
# Exact feature options from simolus3/sqlite-native-libraries d32ebbed8d8a50ec24bef6e2cae18a48db8cd8c0.
target_compile_definitions(sqlite3 PUBLIC
    SQLITE_ENABLE_DBSTAT_VTAB SQLITE_ENABLE_FTS5 SQLITE_ENABLE_RTREE
    SQLITE_DQS=0 SQLITE_DEFAULT_MEMSTATUS=0 SQLITE_TEMP_STORE=2 SQLITE_MAX_EXPR_DEPTH=0
    SQLITE_STRICT_SUBTYPE=1 SQLITE_OMIT_AUTHORIZATION SQLITE_OMIT_DECLTYPE
    SQLITE_OMIT_DEPRECATED SQLITE_OMIT_PROGRESS_CALLBACK SQLITE_OMIT_SHARED_CACHE
    SQLITE_OMIT_TCL_VARIABLE SQLITE_OMIT_TRACE SQLITE_USE_ALLOCA SQLITE_UNTESTABLE
    SQLITE_HAVE_ISNAN SQLITE_HAVE_LOCALTIME_R SQLITE_HAVE_LOCALTIME_S
    SQLITE_HAVE_MALLOC_USABLE_SIZE SQLITE_HAVE_STRCHRNUL
)
