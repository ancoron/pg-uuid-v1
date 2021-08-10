# 1. create a dedicated stage for compiling the extension
FROM postgres:13-buster AS builder

# 1.1 define environment variable for the build
ARG EXT_NAME=uuid_v1
ARG EXT_REPO_NAME=pg-uuid-v1
ARG EXT_VERSION=0.1

# 1.2 build in a dedicated directory
WORKDIR /srv/build

# 1.3 install build-time dependencies
RUN apt-get update \
    && apt-get install -q -y coreutils wget build-essential llvm postgresql-server-dev-${PG_MAJOR} \

# 1.4 download the configured release (see EXT_VERSION variable)
RUN wget -q -O ${EXT_REPO_NAME}.tar.gz "https://github.com/ancoron/${EXT_REPO_NAME}/archive/refs/tags/v${EXT_VERSION}.tar.gz" \
    && tar xzf ${EXT_REPO_NAME}.tar.gz \
    && rm -f ${EXT_REPO_NAME}.tar.gz

# 1.5 switch to code directory
WORKDIR /srv/build/${EXT_REPO_NAME}-${EXT_VERSION}

# 1.6 compile and install the extension
RUN make \
    && mkdir -p dist/lib/postgresql/${PG_MAJOR}/lib/bitcode/${EXT_NAME} \
    && mkdir -p dist/share/postgresql/${PG_MAJOR}/extension \
    && install -m 644 ${EXT_NAME}.so dist/lib/postgresql/${PG_MAJOR}/lib/ \
    && install -m 644 ${EXT_NAME}.control dist/share/postgresql/${PG_MAJOR}/extension/ \
    && install -m 644 ${EXT_NAME}--*.sql dist/share/postgresql/${PG_MAJOR}/extension/ \
    && install -m 644 ${EXT_NAME}.bc dist/lib/postgresql/${PG_MAJOR}/lib/bitcode/${EXT_NAME}/

# 1.7 invoke llvm LTO linker on bitcode file(s)
WORKDIR /srv/build/${EXT_REPO_NAME}-${EXT_VERSION}/dist/lib/postgresql/${PG_MAJOR}/lib/bitcode
RUN llvm-lto -thinlto -thinlto-action=thinlink -o ${EXT_NAME}.index.bc ${EXT_NAME}/${EXT_NAME}.bc

# 2. create the final runtime stage
FROM postgres:13-buster

# 2.1 copy all binaries and other files into the standard location
COPY --from=builder /srv/build/${EXT_REPO_NAME}-${EXT_VERSION}/dist/ /usr/
