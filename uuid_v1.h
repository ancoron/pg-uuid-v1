/*-------------------------------------------------------------------------
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
 *
 * uuid_v1.h
 *	  Header file for the "uuid_v1" ADT. In C, we use the name pg_uuid_v1,
 *	  to avoid conflicts with any uuid_t type that might be defined by
 *	  the system headers.
 *
 * uuid_v1.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef UUID_V1_H
#define UUID_V1_H

#define UUID_NODE_LEN 6

typedef struct pg_uuid_v1
{
    int64           timestamp;
    int16           clock_seq;
    unsigned char   node[UUID_NODE_LEN];
} pg_uuid_v1;

/* fmgr interface macros */
#define UUIDV1PGetDatum(X)		PointerGetDatum(X)
#define PG_RETURN_UUIDV1_P(X)	return UUIDV1PGetDatum(X)
#define DatumGetUUIDV1P(X)		((pg_uuid_v1 *) DatumGetPointer(X))
#define PG_GETARG_UUIDV1_P(X)	DatumGetUUIDV1P(PG_GETARG_DATUM(X))

extern pg_uuid_v1* uuid_std_to_v1(const pg_uuid_t *uuid);
extern pg_uuid_t* uuid_v1_to_std(const pg_uuid_v1 *uuid);
extern TimestampTz uuid_v1_timestamptz(const pg_uuid_v1 *uuid);

#endif							/* UUID_V1_H */
