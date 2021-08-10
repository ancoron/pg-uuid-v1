CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
SET timezone TO 'Zulu';
SET enable_seqscan TO on;

CREATE TABLE uuid_v1_index_tests (id uuid_v1 PRIMARY KEY);

INSERT INTO uuid_v1_index_tests (id)
SELECT uuid_v1_convert(uuid_generate_v1()) FROM generate_series(1, 100000);

CREATE INDEX uuid_v1_index_tests_idx_epoch ON uuid_v1_index_tests (uuid_v1_get_epoch(id));
CREATE INDEX uuid_v1_index_tests_idx_clockseq ON uuid_v1_index_tests (uuid_v1_get_clockseq(id));
CREATE INDEX uuid_v1_index_tests_idx_node ON uuid_v1_index_tests (uuid_v1_get_node(id));

ANALYZE uuid_v1_index_tests;

INSERT INTO uuid_v1_index_tests (id)
SELECT uuid_v1_convert(uuid_generate_v1()) FROM generate_series(1, 100000);

-- ensure we have different clock sequences and nodes
UPDATE uuid_v1_index_tests
SET id = concat_ws(
    '-',
    split_part(id::text, '-', 1),
    split_part(id::text, '-', 2),
    split_part(id::text, '-', 3),
    concat(
        'a',
        (
            SELECT array_agg(to_hex(gen))
            FROM generate_series(1000, 1255) AS gen
        )[floor((random() * 255)::int) + 1]
    ),
    (
        ARRAY[
            'f98796f6f0b5',
            '65b2223f50e4',
            '9fa7849f3019',
            'ab4f70acdda4',
            '1572d280cdc7',
            '8992b529b4ab',
            '861510bbfbba',
            '03f60bc35a16'
        ]::TEXT[]
    )[floor((random() * 7)::int) + 1]
)::uuid_v1;

ANALYZE uuid_v1_index_tests;

\pset format unaligned
\pset tuples_only on

EXPLAIN (ANALYZE OFF, VERBOSE OFF, COSTS OFF, BUFFERS OFF, WAL OFF, TIMING OFF, SUMMARY OFF, FORMAT YAML)
SELECT id FROM uuid_v1_index_tests
ORDER BY uuid_v1_get_epoch(id) DESC
LIMIT 1 OFFSET 5432;

EXPLAIN (ANALYZE OFF, VERBOSE OFF, COSTS OFF, BUFFERS OFF, WAL OFF, TIMING OFF, SUMMARY OFF, FORMAT YAML)
SELECT count(*) FROM uuid_v1_index_tests
WHERE uuid_v1_get_clockseq(id) = 1123;

EXPLAIN (ANALYZE OFF, VERBOSE OFF, COSTS OFF, BUFFERS OFF, WAL OFF, TIMING OFF, SUMMARY OFF, FORMAT YAML)
SELECT count(*) FROM uuid_v1_index_tests
WHERE uuid_v1_get_node(id) = decode('9fa7849f3019', 'hex');

