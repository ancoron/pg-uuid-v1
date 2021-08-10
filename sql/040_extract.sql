SET timezone TO 'Africa/Nairobi';

-- extract timestamp
WITH test_data (uuid, ts) AS (
    SELECT t.uuid::uuid_v1, uuid_v1_get_timestamp(t.uuid::uuid_v1)
    FROM (
        VALUES
            ('edb4d8f0-1a80-11e8-98d9-e03f49f7f8f3'),
            ('4938f30e-8449-11e9-ae2b-e03f49467033')
    ) AS t (uuid)
)
SELECT
    to_char(ts, 'IYYY-MM-DD"T"HH24:MI:SS.USOF') AS "iso_timestamp",
    extract(epoch from ts) AS "epoch",
    ts AS "timestamp"
FROM test_data;

-- extract clock sequence
WITH test_data (uuid, clock_seq) AS (
    SELECT t.uuid::uuid_v1, uuid_v1_get_clockseq(t.uuid::uuid_v1)
    FROM (
        VALUES
            ('edb4d8f0-1a80-11e8-98d9-e03f49f7f8f3'),
            ('4938f30e-8449-11e9-ae2b-e03f49467033'),
            ('e856f430-f950-11eb-adf0-e03f49f7f8f3'),
            ('e856f430-f950-11eb-bfff-e03f49f7f8f3'),
            ('e856f430-f950-11eb-8000-e03f49f7f8f3')
    ) AS t (uuid)
)
SELECT uuid, to_hex(clock_seq::integer) AS "hex", clock_seq
FROM test_data;

-- extract node
WITH test_data (uuid, node) AS (
    SELECT t.uuid::uuid_v1, uuid_v1_get_node(t.uuid::uuid_v1)
    FROM (
        VALUES
            ('edb4d8f0-1a80-11e8-98d9-e03f49f7f8f3'),
            ('4938f30e-8449-11e9-ae2b-e03f49467033'),
            ('e856f430-f950-11eb-adf0-652aab8c3fac'),
            ('e856f430-f950-11eb-adf0-dc399a95ccb0'),
            ('e856f430-f950-11eb-adf0-8992b529b4ab')
    ) AS t (uuid)
)
SELECT uuid, pg_typeof(node) AS "data type", encode(node, 'hex') AS "node (hex)"
FROM test_data;
