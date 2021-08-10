/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

-- complain if script is sourced in psql, rather than via ALTER EXTENSION
\echo Use "CREATE EXTENSION uuid_v1" to load this file. \quit


-- create new data type "uuid_v1"
CREATE FUNCTION uuid_v1_in(cstring)
RETURNS uuid_v1
AS 'MODULE_PATHNAME', 'uuid_v1_in'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

CREATE FUNCTION uuid_v1_out(uuid_v1)
RETURNS cstring
AS 'MODULE_PATHNAME', 'uuid_v1_out'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

CREATE FUNCTION uuid_v1_recv(internal)
RETURNS uuid_v1
AS 'MODULE_PATHNAME', 'uuid_v1_recv'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

CREATE FUNCTION uuid_v1_send(uuid_v1)
RETURNS bytea
AS 'MODULE_PATHNAME', 'uuid_v1_send'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

CREATE TYPE uuid_v1 (
    INTERNALLENGTH = 16,
    INPUT = uuid_v1_in,
    OUTPUT = uuid_v1_out,
    RECEIVE = uuid_v1_recv,
    SEND = uuid_v1_send,
    STORAGE = plain,
    ALIGNMENT = double
);

-- type conversion helper functions
CREATE FUNCTION uuid_v1_convert(uuid_v1) RETURNS uuid
AS 'MODULE_PATHNAME', 'uuid_v1_conv_to_std'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

CREATE FUNCTION uuid_v1_convert(uuid) RETURNS uuid_v1
AS 'MODULE_PATHNAME', 'uuid_v1_conv_from_std'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;


-- helper functions to extract encoded information
CREATE FUNCTION uuid_v1_get_timestamp(uuid_v1) RETURNS timestamp with time zone
AS 'MODULE_PATHNAME', 'uuid_v1_timestamp'
LANGUAGE C STABLE LEAKPROOF STRICT PARALLEL SAFE;

CREATE FUNCTION uuid_v1_get_clockseq(uuid_v1) RETURNS smallint
AS 'MODULE_PATHNAME', 'uuid_v1_clockseq'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

CREATE FUNCTION uuid_v1_get_node(uuid_v1) RETURNS bytea
AS 'MODULE_PATHNAME', 'uuid_v1_node'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

CREATE FUNCTION uuid_v1_get_epoch(uuid_v1) RETURNS float8
AS 'MODULE_PATHNAME', 'uuid_v1_epoch'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;


-- equal
CREATE FUNCTION uuid_v1_eq(uuid_v1, uuid_v1)
RETURNS bool
AS 'MODULE_PATHNAME', 'uuid_v1_eq'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_eq(uuid_v1, uuid_v1) IS 'equal to';

CREATE OPERATOR = (
    LEFTARG = uuid_v1,
    RIGHTARG = uuid_v1,
    PROCEDURE = uuid_v1_eq,
    COMMUTATOR = '=',
    NEGATOR = '<>',
    RESTRICT = eqsel,
    JOIN = eqjoinsel,
    MERGES
);

CREATE FUNCTION uuid_v1_eq_ts(uuid_v1, timestamp with time zone)
RETURNS bool
AS 'MODULE_PATHNAME', 'uuid_v1_eq_ts'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_eq_ts(uuid_v1, timestamp with time zone) IS 'equal to';

CREATE OPERATOR =~ (
    LEFTARG = uuid_v1,
    RIGHTARG = timestamp with time zone,
    PROCEDURE = uuid_v1_eq_ts,
    COMMUTATOR = '=~',
    NEGATOR = '<>~',
    RESTRICT = eqsel,
    JOIN = eqjoinsel,
    MERGES
);

-- not equal
CREATE FUNCTION uuid_v1_ne(uuid_v1, uuid_v1)
RETURNS bool
AS 'MODULE_PATHNAME', 'uuid_v1_ne'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_ne(uuid_v1, uuid_v1) IS 'not equal to';

CREATE OPERATOR <> (
	LEFTARG = uuid_v1,
    RIGHTARG = uuid_v1,
    PROCEDURE = uuid_v1_ne,
    COMMUTATOR = '<>',
    NEGATOR = '=',
    RESTRICT = neqsel,
    JOIN = neqjoinsel
);

CREATE FUNCTION uuid_v1_ne_ts(uuid_v1, timestamp with time zone)
RETURNS bool
AS 'MODULE_PATHNAME', 'uuid_v1_ne_ts'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_ne_ts(uuid_v1, timestamp with time zone) IS 'not equal to';

CREATE OPERATOR <>~ (
	LEFTARG = uuid_v1,
    RIGHTARG = timestamp with time zone,
    PROCEDURE = uuid_v1_ne_ts,
    COMMUTATOR = '<>~',
    NEGATOR = '=~',
    RESTRICT = neqsel,
    JOIN = neqjoinsel
);

-- lower than
CREATE FUNCTION uuid_v1_lt(uuid_v1, uuid_v1)
RETURNS bool
AS 'MODULE_PATHNAME', 'uuid_v1_lt'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_lt(uuid_v1, uuid_v1) IS 'lower than';

CREATE OPERATOR < (
	LEFTARG = uuid_v1,
    RIGHTARG = uuid_v1,
    PROCEDURE = uuid_v1_lt,
	COMMUTATOR = '>',
    NEGATOR = '>=',
	RESTRICT = scalarltsel,
    JOIN = scalarltjoinsel
);

CREATE FUNCTION uuid_v1_lt_ts(uuid_v1, timestamp with time zone)
RETURNS bool
AS 'MODULE_PATHNAME', 'uuid_v1_lt_ts'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_lt_ts(uuid_v1, timestamp with time zone) IS 'lower than';

CREATE OPERATOR <~ (
	LEFTARG = uuid_v1,
    RIGHTARG = timestamp with time zone,
    PROCEDURE = uuid_v1_lt_ts,
	COMMUTATOR = '>~',
    NEGATOR = '>=~',
	RESTRICT = scalarltsel,
    JOIN = scalarltjoinsel
);

-- greater than
CREATE FUNCTION uuid_v1_gt(uuid_v1, uuid_v1)
RETURNS bool
AS 'MODULE_PATHNAME', 'uuid_v1_gt'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_gt(uuid_v1, uuid_v1) IS 'greater than';

CREATE OPERATOR > (
	LEFTARG = uuid_v1,
    RIGHTARG = uuid_v1,
    PROCEDURE = uuid_v1_gt,
	COMMUTATOR = '<',
    NEGATOR = '<=',
	RESTRICT = scalargtsel,
    JOIN = scalargtjoinsel
);

CREATE FUNCTION uuid_v1_gt_ts(uuid_v1, timestamp with time zone)
RETURNS bool
AS 'MODULE_PATHNAME', 'uuid_v1_gt_ts'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_gt_ts(uuid_v1, timestamp with time zone) IS 'greater than';

CREATE OPERATOR >~ (
	LEFTARG = uuid_v1,
    RIGHTARG = timestamp with time zone,
    PROCEDURE = uuid_v1_gt_ts,
	COMMUTATOR = '<~',
    NEGATOR = '<=~',
	RESTRICT = scalargtsel,
    JOIN = scalargtjoinsel
);

-- lower than or equal
CREATE FUNCTION uuid_v1_le(uuid_v1, uuid_v1)
RETURNS bool
AS 'MODULE_PATHNAME', 'uuid_v1_le'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_le(uuid_v1, uuid_v1) IS 'lower than or equal to';

CREATE OPERATOR <= (
	LEFTARG = uuid_v1,
    RIGHTARG = uuid_v1,
    PROCEDURE = uuid_v1_le,
	COMMUTATOR = '>=',
    NEGATOR = '>',
	RESTRICT = scalarltsel,
    JOIN = scalarltjoinsel
);

CREATE FUNCTION uuid_v1_le_ts(uuid_v1, timestamp with time zone)
RETURNS bool
AS 'MODULE_PATHNAME', 'uuid_v1_le_ts'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_le_ts(uuid_v1, timestamp with time zone) IS 'lower than or equal to';

CREATE OPERATOR <=~ (
	LEFTARG = uuid_v1,
    RIGHTARG = timestamp with time zone,
    PROCEDURE = uuid_v1_le_ts,
	COMMUTATOR = '>=~',
    NEGATOR = '>~',
	RESTRICT = scalarltsel,
    JOIN = scalarltjoinsel
);

-- greater than or equal
CREATE FUNCTION uuid_v1_ge(uuid_v1, uuid_v1)
RETURNS bool
AS 'MODULE_PATHNAME', 'uuid_v1_ge'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_ge(uuid_v1, uuid_v1) IS 'greater than or equal to';

CREATE OPERATOR >= (
	LEFTARG = uuid_v1,
    RIGHTARG = uuid_v1,
    PROCEDURE = uuid_v1_ge,
	COMMUTATOR = '<=',
    NEGATOR = '<',
	RESTRICT = scalargtsel,
    JOIN = scalargtjoinsel
);

CREATE FUNCTION uuid_v1_ge_ts(uuid_v1, timestamp with time zone)
RETURNS bool
AS 'MODULE_PATHNAME', 'uuid_v1_ge_ts'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_ge_ts(uuid_v1, timestamp with time zone) IS 'greater than or equal to';

CREATE OPERATOR >=~ (
	LEFTARG = uuid_v1,
    RIGHTARG = timestamp with time zone,
    PROCEDURE = uuid_v1_ge_ts,
	COMMUTATOR = '<=~',
    NEGATOR = '<~',
	RESTRICT = scalargtsel,
    JOIN = scalargtjoinsel
);

-- generic comparison function
CREATE FUNCTION uuid_v1_cmp(uuid_v1, uuid_v1)
RETURNS int4
AS 'MODULE_PATHNAME', 'uuid_v1_cmp'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_cmp(uuid_v1, uuid_v1) IS 'UUID v1 comparison function';

CREATE FUNCTION uuid_v1_cmp_ts(uuid_v1, timestamp with time zone)
RETURNS int4
AS 'MODULE_PATHNAME', 'uuid_v1_cmp_ts'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_cmp_ts(uuid_v1, timestamp with time zone) IS 'UUID v1 comparison function for timestamps';

-- sort support function
CREATE FUNCTION uuid_v1_sortsupport(internal)
RETURNS void
AS 'MODULE_PATHNAME', 'uuid_v1_sortsupport'
LANGUAGE C IMMUTABLE LEAKPROOF STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuid_v1_sortsupport(internal) IS 'btree sort support function';


-- create operator class
CREATE OPERATOR CLASS uuid_v1_ops DEFAULT FOR TYPE uuid_v1
    USING btree AS
        OPERATOR        1       <,
        OPERATOR        1       <~ (uuid_v1, timestamp with time zone),
        OPERATOR        2       <=,
        OPERATOR        2       <=~ (uuid_v1, timestamp with time zone),
        OPERATOR        3       =,
        OPERATOR        3       =~ (uuid_v1, timestamp with time zone),
        OPERATOR        4       >=,
        OPERATOR        4       >=~ (uuid_v1, timestamp with time zone),
        OPERATOR        5       >,
        OPERATOR        5       >~ (uuid_v1, timestamp with time zone),
        FUNCTION        1       uuid_v1_cmp(uuid_v1, uuid_v1),
        FUNCTION        1       uuid_v1_cmp_ts(uuid_v1, timestamp with time zone),
        FUNCTION        2       uuid_v1_sortsupport(internal)
;
