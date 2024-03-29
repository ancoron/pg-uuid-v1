#
# Makefile for extension 'uuid_v1'
#
# See: https://www.postgresql.org/docs/current/extend-extensions.html

MODULE_big = uuid_v1
OBJS = uuid_v1.o

# Define name of the extension
EXTENSION = uuid_v1

# Which SQL to execution at "CREATE EXTENSION ..."
DATA = $(EXTENSION)--0.1.sql

# pg_regress settings
REGRESS_PORT := 5432
REGRESS_OPTS = --load-extension=$(EXTENSION) --port=$(REGRESS_PORT)

REGRESS = \
	010_parse \
	020_convert \
	030_compare \
	040_extract \
	050_operators \
	060_plans \
	070_index

# Use PGXS for installation
# See: https://www.postgresql.org/docs/current/extend-pgxs.html
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
