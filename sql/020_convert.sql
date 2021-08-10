SET timezone TO 'Zulu';
\x

-- conversion
SELECT pg_typeof(uuid_v1_convert('edb4d8f0-1a80-11e8-98d9-e03f49f7f8f3'::uuid)) AS from_std;
SELECT pg_typeof(uuid_v1_convert('edb4d8f0-1a80-11e8-98d9-e03f49f7f8f3'::uuid_v1)) AS to_std;
WITH data AS (
    SELECT
        uuid_v1_convert('607ad07c-f95a-11eb-adf0-9d8ba2d04971'::uuid) AS uuid_to_uuid_v1,
        '607ad07c-f95a-11eb-adf0-9d8ba2d04971'::uuid_v1 AS string_to_uuid_v1
)
SELECT
    uuid_to_uuid_v1,
    uuid_v1_get_timestamp(uuid_to_uuid_v1) AS conv_timestamp,
    uuid_v1_get_clockseq(uuid_to_uuid_v1) AS conv_clock_seq,
    string_to_uuid_v1,
    uuid_v1_get_timestamp(string_to_uuid_v1) AS string_timestamp,
    uuid_v1_get_clockseq(string_to_uuid_v1) AS string_clock_seq,
    (uuid_to_uuid_v1 = string_to_uuid_v1)::text AS equals_conversion_to_uuid_v1
FROM data
;
WITH data AS (
    SELECT
        uuid_v1_convert('7ca71896-f95a-11eb-adf0-9d8ba2d04971'::uuid_v1) AS uuid_v1_to_uuid,
        '7ca71896-f95a-11eb-adf0-9d8ba2d04971'::uuid AS string_to_uuid
)
SELECT
    uuid_v1_to_uuid,
    string_to_uuid,
    (uuid_v1_to_uuid = string_to_uuid)::text AS equals_conversion_to_uuid
FROM data
;
SELECT
    uuid_v1_convert(uuid_v1_convert('edb4d8f0-1a80-11e8-98d9-e03f49f7f8f3'::uuid_v1))
    AS double_convert
;
