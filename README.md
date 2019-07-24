
# PostgreSQL data type for version 1 UUID's

This extension for PostgreSQL provides a new data type `uuid_v1` for
[RFC 4122][1] version 1 UUID values that is more efficient than the standard
[UUID][2] data type in many scenarios.

The tested scenarios where this data type is more efficient than the standard
UUID are described shortly in the following section.


## Performance compared to standard UUID

As this data type is tailored to version 1 UUID's we can optimize the internal
behavior much better than as it is the case for the standard [UUID][2] data type
in PostgreSQL.


## INSERT / COPY ... FROM

First, the parsing of a UUID string input value has been optimized to execute
~33% faster than the standard UUID parser does.

In addition - and this is most important when having an index at a UUID type
column - the internal structure is completely different but still needs 16 bytes
of value storage. However, the internal structure is now optimized for the
time-series nature of version 1 UUID's (which usually is created using the
current time). To reflect this fact, the default sort order is no longer tied
to the byte values of the UUID but to the 60-bit parsed UUID timestamp. This
has lead to a speed-up of factor 6-7 for internal B-Tree comparison logic.

Another good side effect is that the UUID values can now benefit from the
PostgreSQL B-Tree "fastpath", which optimizes for ever-inceasing index values
by basically caching the right-most index page. This means that most of the
time, an INSERT into an indexed talbe column will not need to search for the
relevant index page and we're getting a nice fastpath hit-rate. The standard
UUID spends ~50% of the time during INSERT's in this index page searching,
while this should be less than 1% for the data type `uuid_v1`


## SELECT / COPY ... TO

When larger numbers of UUID's need to be converted into a string representation
the performance of the conversion method plays a significant role.

Tests (using COPY) has revealed that the implementation for the `uuid_v1` data
type is ~5 times faster compared to the standard UUID output. However, the
resulting overall performance benefit (e.g. using `COPY` with format `text`) is
limited to a speedup factor of ~ 1.5 due to unrelated processing in PostgreSQL.


## Time-series queries

The `uuid_v1` data type also comes with additional comparison operators. One set
of operators can be used to efficiently compare `uuid_v1` values to
[`timestamp with time zone`][3] values, which means that time-series queries
are actually possible directly against these UUID's, e.g.:

```sql
SELECT *
FROM my_log
WHERE id >=~ '2019-03-01' AND id <~ '2019-04-01'
ORDER BY id;
```

...giving you an execution plan such as the following:

```
                                                                 QUERY PLAN                                                                 
--------------------------------------------------------------------------------------------------------------------------------------------
 Index Only Scan using my_log_pkey on my_log
   Index Cond: ((id >=~ '2019-03-01 00:00:00+09'::timestamp with time zone) AND (id <~ '2019-04-01 00:00:00+09'::timestamp with time zone))
(2 rows)
```


...and with aggregation:

```sql
WITH pre_sort AS (
    SELECT uuid_v1_get_timestamp(id) AS ts
    FROM my_log
    WHERE id >=~ '2019-03-01' AND id <~ '2019-04-01'
    ORDER BY id DESC
)
SELECT date(ts), count(*)
FROM pre_sort
GROUP BY 1
ORDER BY 1 DESC
```

...execution plan:

```
                                                                     QUERY PLAN                                                                     
----------------------------------------------------------------------------------------------------------------------------------------------------
 Sort
   Sort Key: (date(pre_sort.ts)) DESC
   CTE pre_sort
     ->  Index Only Scan Backward using t_uuid_v1_pkey on t_uuid_v1
           Index Cond: ((id >=~ '2019-03-01 00:00:00+09'::timestamp with time zone) AND (id <~ '2019-04-01 00:00:00+09'::timestamp with time zone))
   ->  HashAggregate
         Group Key: date(pre_sort.ts)
         ->  CTE Scan on pre_sort
(8 rows)
```


## Support functions

To provide additional features when using the `uuid_v1` data type, the following
functions are provided.


### uuid_v1_get_timestamp

The function `uuid_v1_get_timestamp(uuid_v1)` extracts the timestamp into an
instance of the PostgreSQL type [`timestamp with time zone`][3], e.g.:

```sql
SET timezone TO 'Asia/Tokyo';
SELECT uuid_v1_get_timestamp('b647e96b-862d-11e9-ae2b-db6f0f573554');
     uuid_v1_get_timestamp     
-------------------------------
 2019-06-04 03:30:50.132721+09
(1 row)
```

## uuid_v1_get_clockseq

The function `uuid_v1_get_clockseq(uuid_v1)` provides direct access to the
clock sequence value and returns a [`smallint`][6] value, e.g.:

```sql
SELECT uuid_v1_get_clockseq('4938f30e-8449-11e9-ae2b-e03f49467033');
 uuid_v1_get_clockseq 
----------------------
                11819
(1 row)
```

Please also note that the bits of the variant are not part of the clock
sequence value in compliance with the standard.


## uuid_v1_get_node

The function `uuid_v1_get_node(uuid_v1)` returns the node value (where it was
generated initially) as [bytea][5],
e.g.:

```sql
SELECT uuid_v1_get_node('b647e96b-862d-11e9-ae2b-db6f0f573554');
 uuid_v1_get_node
------------------
 \xdb6f0f573554
(1 row)
```


# Build

Straight forward but please ensure that you have the necessary PostgreSQL
development headers in-place as well as [PGXS][4] (which should be made
available with installing the development package).

```
make
```

# Executing Tests

Some basic tests are included by making use of `pg_regress` which can be run with:

```
make installcheck
```

You might need to create a role with super-user privileges with the same name as
your local user or you re-use an existing one, e.g.:

```
sudo -u postgres make installcheck
```

If your _default_ PostgreSQL installation doesn't listen on standard port 5432,
you can adapt it by specifying `REGRESS_PORT` variable, e.g.:

```
sudo -u postgres make REGRESS_PORT=5433 installcheck
```


# Installation

This also requires [PGXS][4] as it figures out where to find the installation:

```
sudo make install
```

If you want to install it into a non-default PostgreSQL installation, just
specify the path to the respective `pg_config` binary, e.g.:

```
sudo make PG_CONFIG=/usr/lib/postgresql/10/bin/pg_config install
```


[1]: https://tools.ietf.org/html/rfc4122
[2]: https://www.postgresql.org/docs/current/datatype-uuid.html
[3]: https://www.postgresql.org/docs/current/datatype-datetime.html
[4]: https://www.postgresql.org/docs/current/extend-pgxs.html
[5]: https://www.postgresql.org/docs/current/datatype-binary.html
[6]: https://www.postgresql.org/docs/current/datatype-numeric.html
