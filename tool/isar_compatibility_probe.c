/* Synthetic Android fixture probe for the unchanged Isar 3.3.0-dev.2 FFI.
 * Run each phase in a NEW process: old create, new upgrade, new crash, old read.
 * Supply a dedicated empty fixture directory, never an application data path.
 * This does not load a wallet, sign transactions, or communicate with a node.
 */
#include <dlfcn.h>
#include <inttypes.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define API(ret, name, args) static ret (*name) args
API(const char *, isar_version, (void));
API(const char *, isar_mdbx_version, (void));
API(int64_t, isar_instance_create, (void **, const char *, const char *, const char *, int64_t, bool, uint32_t, uint32_t, double));
API(bool, isar_instance_close, (void *));
API(int64_t, isar_instance_get_collection, (void *, void **, uint64_t));
API(int64_t, isar_instance_verify, (void *, void *));
API(int64_t, isar_txn_begin, (void *, void **, bool, bool, bool, int64_t));
API(int64_t, isar_txn_finish, (void *, bool));
API(int64_t, isar_json_import, (void *, void *, const char *, const uint8_t *, uint32_t));
API(int64_t, isar_count, (void *, void *, int64_t *));
API(int64_t, isar_delete, (void *, void *, int64_t, bool *));
API(void *, isar_qb_create, (void *));
API(void *, isar_qb_build, (void *));
API(void, isar_q_free, (void *));
API(int64_t, isar_q_export_json, (void *, void *, void *, const char *, uint8_t **, uint32_t *));
API(void, isar_free_json, (uint8_t *, uint32_t));
API(void, isar_key_create, (void **));
API(void, isar_key_add_string, (void *, const char *, bool));
API(int64_t, isar_qb_add_index_where_clause, (void *, uint64_t, void *, void *, bool, bool));
API(int64_t, isar_link, (void *, void *, uint64_t, int64_t, int64_t));
API(int64_t, isar_link_verify, (void *, void *, uint64_t, const int64_t *, uint32_t));
API(char *, isar_get_error, (int64_t));
API(void, isar_free_string, (char *));
#define LOAD(name) do { name = (__typeof__(name)) dlsym(handle, #name); if (!name) { fprintf(stderr, "Missing FFI: %s\n", #name); return 2; } } while (0)

static void check(int64_t code) {
    if (!code) return;
    char *message = isar_get_error(code);
    fprintf(stderr, "Fixture error: %s\n", message ? message : "unknown");
    if (message) isar_free_string(message);
    exit(3);
}
static void require(bool condition, const char *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message); exit(4); }
}
static void import(void *collection, void *txn, const char *json) {
    check(isar_json_import(collection, txn, "id", (const uint8_t *)json, (uint32_t)strlen(json)));
}

/* IDs follow upstream XXH3(name) and XXH3(link, seed=XXH3(collection)). */
static const uint64_t COLLECTION_ID = UINT64_C(4498922139804015684);
static const uint64_t INDEX_ID = UINT64_C(6902807635198700142);
static const uint64_t LINK_ID = UINT64_C(12214119538405479569);
static const char *SCHEMA = "[{\"name\":\"HardeningFixture\",\"version\":2,\"properties\":["
    "{\"name\":\"label\",\"type\":\"String\"},{\"name\":\"amount\",\"type\":\"Long\"},"
    "{\"name\":\"enabled\",\"type\":\"Bool\"},{\"name\":\"bytes\",\"type\":\"ByteList\"},"
    "{\"name\":\"tags\",\"type\":\"StringList\"}],\"indexes\":[{\"name\":\"label\","
    "\"unique\":true,\"properties\":[{\"name\":\"label\",\"type\":\"Value\",\"caseSensitive\":true}]}],"
    "\"links\":[{\"name\":\"friend\",\"target\":\"HardeningFixture\"}]}]";
static const char *INITIAL = "[{\"id\":1,\"label\":\"alpha\",\"amount\":9876543210,\"enabled\":true,\"bytes\":[0,1,255],\"tags\":[\"SCASH\",\"中文\"]},"
    "{\"id\":2,\"label\":\"beta\",\"amount\":-12,\"enabled\":false,\"bytes\":[],\"tags\":[]}]";
static const char *ADDED = "[{\"id\":3,\"label\":\"gamma\",\"amount\":42,\"enabled\":true,\"bytes\":[128],\"tags\":[\"SHIC\"]}]";

static void verify(void *instance, void *collection, int64_t expected) {
    void *txn = NULL;
    check(isar_txn_begin(instance, &txn, true, false, false, 0));
    int64_t count = 0;
    check(isar_count(collection, txn, &count));
    require(count == expected, "record count retained");
    check(isar_instance_verify(instance, txn));
    const int64_t links[] = {1, 2};
    check(isar_link_verify(collection, txn, LINK_ID, links, 2));
    void *query = isar_qb_build(isar_qb_create(collection));
    uint8_t *json = NULL; uint32_t length = 0;
    check(isar_q_export_json(query, collection, txn, "id", &json, &length));
    printf("DATA_JSON=%.*s\n", (int)length, json);
    isar_free_json(json, length); isar_q_free(query);
    void *lower = NULL, *upper = NULL;
    isar_key_create(&lower); isar_key_create(&upper);
    isar_key_add_string(lower, "alpha", true); isar_key_add_string(upper, "alpha", true);
    void *builder = isar_qb_create(collection);
    check(isar_qb_add_index_where_clause(builder, INDEX_ID, lower, upper, true, false));
    query = isar_qb_build(builder);
    check(isar_q_export_json(query, collection, txn, "id", &json, &length));
    printf("INDEX_JSON=%.*s\n", (int)length, json);
    isar_free_json(json, length); isar_q_free(query);
    check(isar_txn_finish(txn, false));
    puts("schema/data/count/index/link/integrity: PASS");
}

int main(int argc, char **argv) {
    if (argc != 4) { fprintf(stderr, "Usage: probe LIB FIXTURE_DIRECTORY create|upgrade|stress|crash|read\n"); return 1; }
    require(strstr(argv[2], "/data/local/tmp/gowallet-isar-") == argv[2], "dedicated fixture directory required");
    void *handle = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!handle) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
    LOAD(isar_version); LOAD(isar_mdbx_version); LOAD(isar_instance_create); LOAD(isar_instance_close);
    LOAD(isar_instance_get_collection); LOAD(isar_instance_verify); LOAD(isar_txn_begin); LOAD(isar_txn_finish);
    LOAD(isar_json_import); LOAD(isar_count); LOAD(isar_delete); LOAD(isar_qb_create); LOAD(isar_qb_build); LOAD(isar_q_free);
    LOAD(isar_q_export_json); LOAD(isar_free_json); LOAD(isar_key_create); LOAD(isar_key_add_string);
    LOAD(isar_qb_add_index_where_clause); LOAD(isar_link); LOAD(isar_link_verify); LOAD(isar_get_error); LOAD(isar_free_string);
    require(strcmp(isar_version(), "3.3.0-dev.2") == 0, "Isar version unchanged");
    require(strcmp(isar_mdbx_version(), "v0.13.8") == 0, "libmdbx version unchanged");
    printf("Isar=%s libmdbx=%s phase=%s\n", isar_version(), isar_mdbx_version(), argv[3]);
    void *instance = NULL, *collection = NULL, *txn = NULL;
    check(isar_instance_create(&instance, "compat", argv[2], SCHEMA, 64, false, 0, 0, NAN));
    check(isar_instance_get_collection(instance, &collection, COLLECTION_ID));
    if (strcmp(argv[3], "create") == 0) {
        check(isar_txn_begin(instance, &txn, true, true, false, 0));
        int64_t count = -1; check(isar_count(collection, txn, &count)); require(count == 0, "empty fixture required");
        import(collection, txn, INITIAL); check(isar_link(collection, txn, LINK_ID, 1, 2));
        check(isar_txn_finish(txn, true)); verify(instance, collection, 2);
    } else if (strcmp(argv[3], "upgrade") == 0) {
        verify(instance, collection, 2);
        check(isar_txn_begin(instance, &txn, true, true, false, 0));
        import(collection, txn, ADDED); check(isar_txn_finish(txn, true));
        check(isar_txn_begin(instance, &txn, true, true, false, 0));
        const char *duplicate = "[{\"id\":9,\"label\":\"alpha\"}]";
        require(isar_json_import(collection, txn, "id", (const uint8_t *)duplicate, (uint32_t)strlen(duplicate)) != 0, "unique constraint enforced");
        check(isar_txn_finish(txn, false));
        check(isar_txn_begin(instance, &txn, true, true, false, 0));
        import(collection, txn, "[{\"id\":99,\"label\":\"rollback\"}]");
        check(isar_txn_finish(txn, false)); verify(instance, collection, 3);
        puts("unique constraint/explicit transaction rollback: PASS");
    } else if (strcmp(argv[3], "stress") == 0) {
        verify(instance, collection, 3);
        check(isar_txn_begin(instance, &txn, true, true, false, 0));
        char payload[12288], long_value[10001];
        memset(long_value, 'x', sizeof(long_value)-1); long_value[sizeof(long_value)-1] = 0;
        for (int i = 0; i < 1040; ++i) {
            int size = snprintf(payload, sizeof(payload),
                "[{\"id\":%d,\"label\":\"load-%04d\",\"amount\":9876543210,\"tags\":[\"%s\"]}]",
                1000+i, i, i < 1024 ? "page-split" : long_value);
            require(size > 0 && size < (int)sizeof(payload), "bounded stress fixture");
            import(collection, txn, payload);
        }
        check(isar_txn_finish(txn, true));
        check(isar_txn_begin(instance, &txn, true, false, false, 0));
        int64_t count = 0; check(isar_count(collection, txn, &count));
        require(count == 1043, "batch insert and overflow records retained");
        check(isar_instance_verify(instance, txn)); check(isar_txn_finish(txn, false));
        check(isar_txn_begin(instance, &txn, true, true, false, 0));
        for (int i = 0; i < 1040; ++i) {
            bool deleted = false; check(isar_delete(collection, txn, 1000+i, &deleted));
            require(deleted, "each stress fixture deleted");
        }
        check(isar_txn_finish(txn, true)); verify(instance, collection, 3);
        puts("1040 batch writes/deletes, including 16 large values, page/index integrity: PASS");
    } else if (strcmp(argv[3], "crash") == 0) {
        verify(instance, collection, 3);
        check(isar_txn_begin(instance, &txn, true, true, false, 0));
        import(collection, txn, "[{\"id\":99,\"label\":\"uncommitted\"}]");
        puts("Exit without committing synthetic write transaction"); fflush(stdout); _exit(0);
    } else { require(strcmp(argv[3], "read") == 0, "known phase required"); verify(instance, collection, 3); }
    require(isar_instance_close(instance), "clean close");
    puts("PASS"); return 0;
}
