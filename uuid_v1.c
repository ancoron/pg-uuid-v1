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
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include <math.h>

#include "postgres.h"

#include "access/hash.h"
#include "datatype/timestamp.h"
#include "lib/stringinfo.h"
#include "lib/hyperloglog.h"
#include "libpq/pqformat.h"
#include "port/pg_bswap.h"
#include "utils/builtins.h"
#include "utils/guc.h"
#include "utils/sortsupport.h"
#include "utils/timestamp.h"
#include "utils/uuid.h"
#include "uuid_v1.h"

PG_MODULE_MAGIC;

#define PG_UUID_OFFSET_EPOCH INT64CONST(122192928000000000)

/*
 * The time offset between the UUID timestamp and the PostgreSQL epoch in
 * microsecond precision.
 *
 * This constant is the result of the following expression:
 * `PG_UUID_OFFSET_EPOCH / 10 + ((POSTGRES_EPOCH_JDATE - UNIX_EPOCH_JDATE) * SECS_PER_DAY * USECS_PER_SEC)`
 */
#define PG_UUID_OFFSET INT64CONST(13165977600000000)

/* sortsupport for uuid */
typedef struct
{
	int64 input_count; /* number of non-null values seen */
	bool estimating; /* true if estimating cardinality */

	hyperLogLogState abbr_card; /* cardinality estimator */
} uuid_v1_sortsupport_state;

static void parse_uuid_v1(const char *source, pg_uuid_v1 *uuid);
static int64 to_uuid_timestamp(const TimestampTz ts);
static int uuid_v1_cmp0(const pg_uuid_v1 *a, const pg_uuid_v1 *b);
static int uuid_v1_cmp_ts0(const pg_uuid_v1 *a, const TimestampTz b);

static int uuid_v1_cmp_abbrev(Datum x, Datum y, SortSupport ssup);
static bool uuid_v1_abbrev_abort(int memtupcount, SortSupport ssup);
static Datum uuid_v1_abbrev_convert(Datum original, SortSupport ssup);
static int uuid_v1_sort_cmp(Datum x, Datum y, SortSupport ssup);

static int64 uuid_timestamp_int(const pg_uuid_t *uuid);
static int16 uuid_clockseq(const pg_uuid_t *uuid);
static const unsigned char* uuid_node(const pg_uuid_t *uuid);

static float8 uuid_v1_epoch_internal(const pg_uuid_v1 *uuid);

PG_FUNCTION_INFO_V1(uuid_v1_in);
PG_FUNCTION_INFO_V1(uuid_v1_out);
PG_FUNCTION_INFO_V1(uuid_v1_recv);
PG_FUNCTION_INFO_V1(uuid_v1_send);

PG_FUNCTION_INFO_V1(uuid_v1_epoch);
PG_FUNCTION_INFO_V1(uuid_v1_timestamp);
PG_FUNCTION_INFO_V1(uuid_v1_node);
PG_FUNCTION_INFO_V1(uuid_v1_clockseq);

PG_FUNCTION_INFO_V1(uuid_v1_conv_from_std);
PG_FUNCTION_INFO_V1(uuid_v1_conv_to_std);

PG_FUNCTION_INFO_V1(uuid_v1_sortsupport);

PG_FUNCTION_INFO_V1(uuid_v1_cmp);
PG_FUNCTION_INFO_V1(uuid_v1_eq);
PG_FUNCTION_INFO_V1(uuid_v1_ne);
PG_FUNCTION_INFO_V1(uuid_v1_lt);
PG_FUNCTION_INFO_V1(uuid_v1_le);
PG_FUNCTION_INFO_V1(uuid_v1_gt);
PG_FUNCTION_INFO_V1(uuid_v1_ge);

PG_FUNCTION_INFO_V1(uuid_v1_cmp_ts);
PG_FUNCTION_INFO_V1(uuid_v1_eq_ts);
PG_FUNCTION_INFO_V1(uuid_v1_ne_ts);
PG_FUNCTION_INFO_V1(uuid_v1_lt_ts);
PG_FUNCTION_INFO_V1(uuid_v1_le_ts);
PG_FUNCTION_INFO_V1(uuid_v1_gt_ts);
PG_FUNCTION_INFO_V1(uuid_v1_ge_ts);

Datum
uuid_v1_in(PG_FUNCTION_ARGS)
{
	char *uuid_str = PG_GETARG_CSTRING(0);
	pg_uuid_v1 *uuid;

	uuid = (pg_uuid_v1 *) palloc(UUID_LEN);
	parse_uuid_v1(uuid_str, uuid);
	PG_RETURN_UUID_P(uuid);
}

Datum
uuid_v1_out(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *uuid = PG_GETARG_UUIDV1_P(0);
	static const char hex_chars[] = "0123456789abcdef";
	char* str;
	int i, out;
	unsigned char* bytes;
	int64 timestamp;
	int16 clk;
	uint8 hi, lo;

	str = (char*) palloc(37);
	out = 0;

	/* must convert to network byte order */
	timestamp = pg_hton64(uuid->timestamp);

	bytes = (unsigned char*) &timestamp;

	/* write time_low */
	for (i = 4; i < 8; i++)
	{
		hi = bytes[i] >> 4;
		lo = bytes[i] & 0x0F;

		str[out++] = hex_chars[hi];
		str[out++] = hex_chars[lo];
	}

	str[out++] = '-';

	/* write time_mid */
	for (i = 2; i < 4; i++)
	{
		hi = bytes[i] >> 4;
		lo = bytes[i] & 0x0F;

		str[out++] = hex_chars[hi];
		str[out++] = hex_chars[lo];
	}

	str[out++] = '-';

	/* write version and time_high */
	for (i = 0; i < 2; i++)
	{
		if (i == 0)
			hi = 1;
		else
			hi = bytes[i] >> 4;

		lo = bytes[i] & 0x0F;

		str[out++] = hex_chars[hi];
		str[out++] = hex_chars[lo];
	}

	str[out++] = '-';

	/* write variant and clock sequence */
	clk = pg_hton16(uuid->clock_seq);
	bytes = (unsigned char*) &clk;
	for (i = 0; i < 2; i++)
	{
		if (i == 0)
			hi = bytes[i] >> 4 | 0x8;
		else
			hi = bytes[i] >> 4;

		lo = bytes[i] & 0x0F;

		str[out++] = hex_chars[hi];
		str[out++] = hex_chars[lo];
	}

	str[out++] = '-';

	for (i = 0; i < UUID_NODE_LEN; i++)
	{
		hi = uuid->node[i] >> 4;
		lo = uuid->node[i] & 0x0F;

		str[out++] = hex_chars[hi];
		str[out++] = hex_chars[lo];
	}

	str[36] = '\0';

	PG_RETURN_CSTRING(str);
}

static void
parse_uuid_v1(const char *source, pg_uuid_v1 *uuid)
{
	int64 timestamp;
	int16 clock_seq;
	unsigned char node[6];

	const char *src = source;
	uint8 val;
	int i;

	timestamp = 0;
	clock_seq = 0;

	for (i = 0; i < 16 && *src;)
	{
		val = *src++ -'0';

		if (val > 48)
			val -= 39;
		else if (val > 15)
			val -= 7;

		if (val < 0 || val > 15)
			continue;

		i++;
		timestamp = (timestamp << 4) | val;
	}

	/* no more input... */
	if (!(*src) || i < 16)
		goto syntax_error;

	/* version mismatch */
	if ((timestamp & 0xF000) != 0x1000)
		goto version_error;

	uuid->timestamp = (
			((timestamp << 48) & 0x0FFF000000000000) |
			((timestamp << 16) & 0x0000FFFF00000000) |
			((timestamp >> 32) & 0x00000000FFFFFFFF));

	if (uuid->timestamp < 0)
		goto syntax_error;

	for (i = 0; i < 4 && *src;)
	{
		val = *src++ -'0';

		if (val > 48)
			val -= 39;
		else if (val > 15)
			val -= 7;

		if (val < 0 || val > 15)
			continue;

		i++;
		clock_seq = (clock_seq << 4) | val;
	}

	/* no more input... */
	if (!(*src) || i < 4)
		goto syntax_error;

	/* variant mismatch */
	if ((clock_seq & 0xC000) != 0x8000)
		goto variant_error;

	uuid->clock_seq = clock_seq & 0x3FFF;

	for (i = 0; i < 12 && *src;)
	{
		val = *src++ -'0';

		if (val > 48)
			val -= 39;
		else if (val > 15)
			val -= 7;

		if (val < 0 || val > 15)
			continue;

		if (i % 2 == 0)
			node[i / 2] = (val << 4);
		else
			node[i / 2] |= val;

		i++;
	}

	/* not enough input... */
	if (i < 12)
		goto syntax_error;

	memcpy(uuid->node, node, 6);

	return;

syntax_error:
	ereport(ERROR,
			(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
			errmsg("invalid input syntax for type %s: \"%s\"",
			"uuid_v1", source)));

version_error:
	ereport(ERROR,
			(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
			errmsg("invalid version for type %s: \"%s\"",
			"uuid_v1", source)));

variant_error:
	ereport(ERROR,
			(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
			errmsg("invalid variant for type %s: \"%s\"",
			"uuid_v1", source)));
}

Datum
uuid_v1_recv(PG_FUNCTION_ARGS)
{
	StringInfo buffer = (StringInfo) PG_GETARG_POINTER(0);
	pg_uuid_v1 *uuid;

	uuid = (pg_uuid_v1 *) palloc(UUID_LEN);
	uuid->timestamp = pq_getmsgint64(buffer);
	uuid->clock_seq = pq_getmsgint(buffer, 2);
	memcpy(uuid->node, pq_getmsgbytes(buffer, UUID_NODE_LEN), UUID_NODE_LEN);
	PG_RETURN_POINTER(uuid);
}

Datum
uuid_v1_send(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *uuid = PG_GETARG_UUIDV1_P(0);
	StringInfoData buffer;

	pq_begintypsend(&buffer);
	pq_sendint64(&buffer, uuid->timestamp);
	pq_sendint16(&buffer, uuid->clock_seq);
	pq_sendbytes(&buffer, (char *) uuid->node, UUID_NODE_LEN);
	PG_RETURN_BYTEA_P(pq_endtypsend(&buffer));
}

Datum
uuid_v1_conv_from_std(PG_FUNCTION_ARGS)
{
	pg_uuid_t *input = PG_GETARG_UUID_P(0);
	pg_uuid_v1 *output;

	if (PG_ARGISNULL(0))
		PG_RETURN_NULL();

	output = uuid_std_to_v1(input);

	PG_RETURN_UUIDV1_P(output);
}

Datum
uuid_v1_conv_to_std(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *input = PG_GETARG_UUIDV1_P(0);
	pg_uuid_t *output;

	if (PG_ARGISNULL(0))
		PG_RETURN_NULL();

	output = uuid_v1_to_std(input);

	PG_RETURN_UUID_P(output);
}

/*
 * uuid_std_to_v1
 *	Convert a standard UUID into a V1 UUID, if possible.
 */
pg_uuid_v1*
uuid_std_to_v1(const pg_uuid_t *uuid)
{
	pg_uuid_v1 *uuid_v1;

	if (1 != ((uuid->data[6] >> 4) & 0x0F) || (0x80 != ((uuid->data[8]) & 0xC0)))
		return NULL;

	uuid_v1 = (pg_uuid_v1 *) palloc(UUID_LEN);
	uuid_v1->timestamp = uuid_timestamp_int(uuid);
	uuid_v1->clock_seq = uuid_clockseq(uuid);
	memcpy(uuid_v1->node, uuid_node(uuid), UUID_NODE_LEN);

	return uuid_v1;
}

pg_uuid_t*
uuid_v1_to_std(const pg_uuid_v1 *uuid)
{
	pg_uuid_t *std;
	uint8 offset = 0;
	uint8 size;
	uint32 i;
	uint16 s;

	std = (pg_uuid_t *) palloc(UUID_LEN);

	/* write time_low in network byte order */
	i = pg_hton32((uint32) (uuid->timestamp & 0x00000000FFFFFFFF));
	size = sizeof(uint32);
	memcpy(std->data, &i, size);
	offset += size;

	/* write time_mid in network byte order */
	s = pg_hton16((uint16) ((uuid->timestamp & 0x0000FFFF00000000) >> 32));
	size = sizeof(uint16);
	memcpy(std->data + offset, &s, size);
	offset += size;

	/* write version and time_high in network byte order */
	s = pg_hton16((uint16) (((uuid->timestamp & 0x0FFF000000000000) >> 48) | 0x1000));
	memcpy(std->data + offset, &s, size);
	offset += size;

	/* write variant and clock sequence in network byte order */
	s = pg_hton16((uint16) (uuid->clock_seq | 0x8000));
	memcpy(std->data + offset, &s, size);
	offset += size;

	/* write node value as is */
	memcpy(std->data + offset, uuid->node, UUID_NODE_LEN);

	return std;
}

int64
uuid_timestamp_int(const pg_uuid_t *uuid)
{
	/* UUID timestamp is encoded in network byte order */
	int64 timestamp = pg_ntoh64(*(int64 *) uuid->data);

	/* unshuffle the UUID timestamp */
	timestamp = (
			((timestamp << 48) & 0x0FFF000000000000) |
			((timestamp << 16) & 0x0000FFFF00000000) |
			((timestamp >> 32) & 0x00000000FFFFFFFF));

	return timestamp;
}

int16
uuid_clockseq(const pg_uuid_t *uuid)
{
	return ((uuid->data[8] << 8) + uuid->data[9]) & 0x3FFF;
}

const unsigned char*
uuid_node(const pg_uuid_t *uuid)
{
	const unsigned char *src;

	src = uuid->data;
	src += 10;

	return src;
}

float8
uuid_v1_epoch_internal(const pg_uuid_v1 *uuid)
{
	int64 timestamp = (uuid->timestamp - PG_UUID_OFFSET_EPOCH) / 10;
	return (float8) timestamp / 1000000.0;
}

Datum
uuid_v1_epoch(PG_FUNCTION_ARGS)
{
	float8 result;
	pg_uuid_v1 *uuid = PG_GETARG_UUIDV1_P(0);

	if (PG_ARGISNULL(0))
		PG_RETURN_NULL();

	result = uuid_v1_epoch_internal(uuid);

	/* Recheck in arithmetic produces something just out of range */
	if (result < 0.0)
		ereport(ERROR,
			(errcode(ERRCODE_DATETIME_VALUE_OUT_OF_RANGE),
			errmsg("timestamp out of range")));

	PG_RETURN_FLOAT8(result);
}

/*
 * uuid_v1_timestamptz
 *	Extract the timestamp from a version 1 UUID.
 */
TimestampTz
uuid_v1_timestamptz(const pg_uuid_v1 *uuid)
{
	/* from 100 ns precision to PostgreSQL epoch */
	TimestampTz timestamp = uuid->timestamp / 10 - PG_UUID_OFFSET;

	return timestamp;
}

/*
 * uuid_v1_timestamp
 *	extract the timestamp of a version 1 UUID
 *
 */
Datum
uuid_v1_timestamp(PG_FUNCTION_ARGS)
{
	TimestampTz timestamp = 0L;
	pg_uuid_v1 *uuid = PG_GETARG_UUIDV1_P(0);

	if (PG_ARGISNULL(0))
		PG_RETURN_NULL();

	timestamp = uuid_v1_timestamptz(uuid);

	/* Recheck in case roundoff produces something just out of range */
	if (!IS_VALID_TIMESTAMP(timestamp))
		ereport(ERROR,
			(errcode(ERRCODE_DATETIME_VALUE_OUT_OF_RANGE),
			errmsg("timestamp out of range")));

	PG_RETURN_TIMESTAMP(timestamp);
}

/*
 * uuid_v1_clockseq
 *	extract the clock sequence of a version 1 UUID
 *
 */
Datum
uuid_v1_clockseq(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *uuid = PG_GETARG_UUIDV1_P(0);

	if (PG_ARGISNULL(0))
		PG_RETURN_NULL();

	PG_RETURN_INT16(uuid->clock_seq);
}

/*
 * uuid_v1_node
 *	extract the node value of a version 1 UUID
 *
 */
Datum
uuid_v1_node(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *uuid = PG_GETARG_UUIDV1_P(0);
	bytea *bytes;

	if (PG_ARGISNULL(0))
		PG_RETURN_NULL();

	bytes = palloc(UUID_NODE_LEN + VARHDRSZ);
	SET_VARSIZE(bytes, UUID_NODE_LEN + VARHDRSZ);
	memcpy(VARDATA(bytes), uuid->node, UUID_NODE_LEN);

	PG_RETURN_BYTEA_P(bytes);
}

static int
uuid_v1_cmp0(const pg_uuid_v1 *a, const pg_uuid_v1 *b)
{
	int64 diff = a->timestamp - b->timestamp;
	if (diff < 0)
		return -1;
	else if (diff > 0)
		return 1;

	diff = a->clock_seq - b->clock_seq;
	if (diff < 0)
		return -1;
	else if (diff > 0)
		return 1;

	return memcmp(a->node, b->node, UUID_NODE_LEN);
}

Datum
uuid_v1_cmp(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	pg_uuid_v1 *b = PG_GETARG_UUIDV1_P(1);

	PG_RETURN_INT32(uuid_v1_cmp0(a, b));
}

Datum
uuid_v1_eq(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	pg_uuid_v1 *b = PG_GETARG_UUIDV1_P(1);

	PG_RETURN_BOOL(memcmp(a, b, UUID_LEN) == 0);
}

Datum
uuid_v1_ne(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	pg_uuid_v1 *b = PG_GETARG_UUIDV1_P(1);

	PG_RETURN_BOOL(memcmp(a, b, UUID_LEN) != 0);
}

Datum
uuid_v1_lt(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	pg_uuid_v1 *b = PG_GETARG_UUIDV1_P(1);

	PG_RETURN_BOOL(uuid_v1_cmp0(a, b) < 0);
}

Datum
uuid_v1_le(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	pg_uuid_v1 *b = PG_GETARG_UUIDV1_P(1);

	PG_RETURN_BOOL(uuid_v1_cmp0(a, b) <= 0);
}

Datum
uuid_v1_gt(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	pg_uuid_v1 *b = PG_GETARG_UUIDV1_P(1);

	PG_RETURN_BOOL(uuid_v1_cmp0(a, b) > 0);
}

Datum
uuid_v1_ge(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	pg_uuid_v1 *b = PG_GETARG_UUIDV1_P(1);

	PG_RETURN_BOOL(uuid_v1_cmp0(a, b) >= 0);
}

/*
 * to_uuid_timestamp
 *	Convert a given timestamp into a UUID timestamp value.
 *
 */
static int64
to_uuid_timestamp(const TimestampTz ts)
{
	return (((int64) ts) + PG_UUID_OFFSET) * 10;
}

static int
uuid_v1_cmp_ts0(const pg_uuid_v1 *a, const TimestampTz b)
{
	int64 diff = a->timestamp - to_uuid_timestamp(b);
	if (diff < 0)
		return -1;
	else if (diff > 0)
		return 1;

	return 0;
}

Datum
uuid_v1_cmp_ts(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	TimestampTz b = PG_GETARG_TIMESTAMPTZ(1);

	PG_RETURN_INT32(uuid_v1_cmp_ts0(a, b));
}

Datum
uuid_v1_eq_ts(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	TimestampTz b = PG_GETARG_TIMESTAMPTZ(1);

	PG_RETURN_BOOL(uuid_v1_cmp_ts0(a, b) == 0);
}

Datum
uuid_v1_ne_ts(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	TimestampTz b = PG_GETARG_TIMESTAMPTZ(1);

	PG_RETURN_BOOL(uuid_v1_cmp_ts0(a, b) != 0);
}

Datum
uuid_v1_lt_ts(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	TimestampTz b = PG_GETARG_TIMESTAMPTZ(1);

	PG_RETURN_BOOL(uuid_v1_cmp_ts0(a, b) < 0);
}

Datum
uuid_v1_le_ts(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	TimestampTz b = PG_GETARG_TIMESTAMPTZ(1);

	PG_RETURN_BOOL(uuid_v1_cmp_ts0(a, b) <= 0);
}

Datum
uuid_v1_gt_ts(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	TimestampTz b = PG_GETARG_TIMESTAMPTZ(1);

	PG_RETURN_BOOL(uuid_v1_cmp_ts0(a, b) > 0);
}

Datum
uuid_v1_ge_ts(PG_FUNCTION_ARGS)
{
	pg_uuid_v1 *a = PG_GETARG_UUIDV1_P(0);
	TimestampTz b = PG_GETARG_TIMESTAMPTZ(1);

	PG_RETURN_BOOL(uuid_v1_cmp_ts0(a, b) >= 0);
}


/*
 * Parts of below code have been shamelessly copied (and modified) from:
 *	  src/backend/utils/adt/uuid.c
 *
 * ...and are:
 * Copyright (c) 2007-2019, PostgreSQL Global Development Group
 */

/*
 * Sort support strategy routine
 */
Datum
uuid_v1_sortsupport(PG_FUNCTION_ARGS)
{
	SortSupport ssup = (SortSupport) PG_GETARG_POINTER(0);

	ssup->comparator = uuid_v1_sort_cmp;
	ssup->ssup_extra = NULL;

	if (ssup->abbreviate)
	{
		uuid_v1_sortsupport_state *uss;
		MemoryContext oldcontext;

		oldcontext = MemoryContextSwitchTo(ssup->ssup_cxt);

		uss = palloc(sizeof(uuid_v1_sortsupport_state));
		uss->input_count = 0;
		uss->estimating = true;
		initHyperLogLog(&uss->abbr_card, 10);

		ssup->ssup_extra = uss;

		ssup->comparator = uuid_v1_cmp_abbrev;
		ssup->abbrev_converter = uuid_v1_abbrev_convert;
		ssup->abbrev_abort = uuid_v1_abbrev_abort;
		ssup->abbrev_full_comparator = uuid_v1_sort_cmp;

		MemoryContextSwitchTo(oldcontext);
	}

	PG_RETURN_VOID();
}

/*
 * SortSupport comparison func
 */
static int
uuid_v1_sort_cmp(Datum x, Datum y, SortSupport ssup)
{
	pg_uuid_v1 *arg1 = DatumGetUUIDV1P(x);
	pg_uuid_v1 *arg2 = DatumGetUUIDV1P(y);

	return uuid_v1_cmp0(arg1, arg2);
}

/*
 * Conversion routine for sortsupport.
 *
 * Converts original uuid representation to abbreviated key representation.
 *
 * Our encoding strategy is simple: if the UUID is an RFC 4122 version 1 then
 * extract the 60-bit timestamp. Otherwise, pack the first `sizeof(Datum)`
 * bytes of uuid data into a Datum (on little-endian machines, the bytes are
 * stored in reverse order), and treat it as an unsigned integer.
 */
static Datum
uuid_v1_abbrev_convert(Datum original, SortSupport ssup)
{
	uuid_v1_sortsupport_state *uss = ssup->ssup_extra;
	pg_uuid_v1 *authoritative = DatumGetUUIDV1P(original);
	Datum res;
	int64 timestamp = authoritative->timestamp;

#if SIZEOF_DATUM == 8
	memcpy(&res, &timestamp, sizeof(Datum));
#else       /* SIZEOF_DATUM != 8 */
	/* use last 4 bytes of int64 as they are more significant */
	memcpy(&res, &timestamp + 4, sizeof(Datum));
#endif

	uss->input_count += 1;

	if (uss->estimating)
	{
		uint32 tmp;

#if SIZEOF_DATUM == 8
		tmp = (uint32) res ^ (uint32) ((uint64) res >> 32);
#else       /* SIZEOF_DATUM != 8 */
		tmp = (uint32) res;
#endif

		addHyperLogLog(&uss->abbr_card, DatumGetUInt32(hash_uint32(tmp)));
	}

	/*
	 * Byteswap on little-endian machines.
	 *
	 * This is needed so that uuid_ts_cmp_abbrev() (an unsigned integer 3-way
	 * comparator) works correctly on all platforms.  If we didn't do this,
	 * the comparator would have to call memcmp() with a pair of pointers to
	 * the first byte of each abbreviated key, which is slower.
	 */
	res = DatumBigEndianToNative(res);

	return res;
}

/*
 * Abbreviated key comparison func
 */
static int
uuid_v1_cmp_abbrev(Datum x, Datum y, SortSupport ssup)
{
	if (x > y)
		return 1;
	else if (x == y)
		return 0;
	else
		return -1;
}

/*
 * Callback for estimating effectiveness of abbreviated key optimization.
 *
 * We pay no attention to the cardinality of the non-abbreviated data, because
 * there is no equality fast-path within authoritative uuid comparator.
 */
static bool
uuid_v1_abbrev_abort(int memtupcount, SortSupport ssup)
{
	uuid_v1_sortsupport_state *uss = ssup->ssup_extra;
	double abbr_card;

	if (memtupcount < 10000 || uss->input_count < 10000 || !uss->estimating)
		return false;

	abbr_card = estimateHyperLogLog(&uss->abbr_card);

	/*
	 * If we have >100k distinct values, then even if we were sorting many
	 * billion rows we'd likely still break even, and the penalty of undoing
	 * that many rows of abbrevs would probably not be worth it.  Stop even
	 * counting at that point.
	 */
	if (abbr_card > 100000.0)
	{
#ifdef TRACE_SORT
		if (trace_sort)
			elog(LOG,
				"uuid_v1_abbrev: estimation ends at cardinality %f"
				" after " INT64_FORMAT " values (%d rows)",
				abbr_card, uss->input_count, memtupcount);
#endif
		uss->estimating = false;
		return false;
	}

	/*
	 * Target minimum cardinality is 1 per ~2k of non-null inputs.  0.5 row
	 * fudge factor allows us to abort earlier on genuinely pathological data
	 * where we've had exactly one abbreviated value in the first 2k
	 * (non-null) rows.
	 */
	if (abbr_card < uss->input_count / 2000.0 + 0.5)
	{
#ifdef TRACE_SORT
		if (trace_sort)
			elog(LOG,
				"uuid_v1_abbrev: aborting abbreviation at cardinality %f"
				" below threshold %f after " INT64_FORMAT " values (%d rows)",
				abbr_card, uss->input_count / 2000.0 + 0.5, uss->input_count,
				memtupcount);
#endif
		return true;
	}

#ifdef TRACE_SORT
	if (trace_sort)
		elog(LOG,
			"uuid_v1_abbrev: cardinality %f after " INT64_FORMAT
			" values (%d rows)", abbr_card, uss->input_count, memtupcount);
#endif

	return false;
}
