

# Stage 1: Build dependencies and compile Citus, pg_partman, and pg_cron
FROM postgres:16-alpine AS builder
ARG VERSION=12.1.0
ENV CITUS_VERSION=${VERSION} PG_PARTMAN_VERSION=v5.1.0 PG_CRON_VERSION=v1.6.0

# Install build dependencies and runtime dependencies
RUN set -ex \
    && apk add --no-cache --virtual .build-deps \
    autoconf \
    automake \
    g++ \
    clang15 \
    llvm15 \
    libtool \
    libxml2-dev \
    lz4-dev \
    krb5-dev \
    icu-dev \
    libxslt-dev \
    make \
    curl-dev \
    flex \
    && apk add --no-cache curl 

# Install pg_partman
RUN wget -O pg_partman.tar.gz "https://github.com/pgpartman/pg_partman/archive/refs/tags/$PG_PARTMAN_VERSION.tar.gz" \
    && mkdir -p /usr/src/pg_partman \
    && tar --extract --file pg_partman.tar.gz --directory /usr/src/pg_partman --strip-components=1 \
    && rm pg_partman.tar.gz \
    && cd /usr/src/pg_partman \
    && make clean \
    && make \
    && make install

# Install pg_cron
RUN wget -O pg_cron.tar.gz "https://github.com/citusdata/pg_cron/archive/refs/tags/$PG_CRON_VERSION.tar.gz" \
    && mkdir -p /usr/src/pg_cron \
    && tar --extract --file pg_cron.tar.gz --directory /usr/src/pg_cron --strip-components=1 \
    && rm pg_cron.tar.gz \
    && cd /usr/src/pg_cron \
    && make \
    && make install 

# Install Citus
RUN wget -O citus.tar.gz "https://github.com/citusdata/citus/archive/refs/tags/v${CITUS_VERSION}.tar.gz" \
    && mkdir -p /usr/src/citus \
    && tar --extract --file citus.tar.gz --directory /usr/src/citus --strip-components=1 \
    && rm citus.tar.gz \
    && cd /usr/src/citus \
    && ./configure || (cat config.log && exit 1) \
    && make \
    && make install \
    && apk del .build-deps

# Stage 2: Create the final image with only runtime dependencies
FROM postgres:16-alpine
ARG VERSION=11.2.0
LABEL maintainer="Citus Data https://citusdata.com" \
    org.label-schema.name="Citus" \
    org.label-schema.description="Scalable PostgreSQL for multi-tenant and real-time workloads" \
    org.label-schema.url="https://www.citusdata.com" \
    org.label-schema.vcs-url="https://github.com/citusdata/citus" \
    org.label-schema.vendor="Citus Data, Inc." \
    org.label-schema.version=${VERSION}-alpine \
    org.label-schema.schema-version="1.0"

# Install runtime dependencies
RUN apk add --no-cache libcurl lz4 krb5 icu libxml2 libxslt

# Copy compiled binaries and extensions from the builder stage
COPY --from=builder /usr/local/lib/postgresql /usr/local/lib/postgresql
COPY --from=builder /usr/local/share/postgresql/extension /usr/local/share/postgresql/extension
COPY --from=builder /usr/local/lib/postgresql/pg_partman*.so /usr/local/lib/postgresql/
COPY --from=builder /usr/local/share/postgresql/extension/pg_partman* /usr/local/share/postgresql/extension/

# Add citus, pg_cron, and pg_partman to PostgreSQL shared libraries
RUN echo "shared_preload_libraries='citus,pg_cron,pg_partman_bgw'" >> /usr/local/share/postgresql/postgresql.conf.sample

# Add scripts to run after initdb
COPY 000-configure-stats.sh 001-create-citus-extension.sql /docker-entrypoint-initdb.d/

# Add health check script
COPY pg_healthcheck wait-for-manager.sh /
RUN chmod +x /wait-for-manager.sh /docker-entrypoint-initdb.d/000-configure-stats.sh /docker-entrypoint-initdb.d/001-create-citus-extension.sql

# Modify entry point as needed
RUN sed "/unset PGPASSWORD/d" -i /usr/local/bin/docker-entrypoint.sh

# Set up health check
HEALTHCHECK --interval=4s --start-period=6s CMD ./pg_healthcheck
