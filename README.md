# Citus with pg_partman and pg_cron Docker Image

This repository provides a Docker image that integrates [Citus](https://github.com/citusdata/citus), [pg_partman](https://github.com/pgpartman/pg_partman), and [pg_cron](https://github.com/citusdata/pg_cron) on PostgreSQL 16 using Alpine Linux. This image is optimized for distributed workloads and partition management.

## Table of Contents

- [Features](#features)
- [Getting Started](#getting-started)
  - [Build the Image](#build-the-image)
  - [Run the Container](#run-the-container)
- [Environment Variables](#environment-variables)
- [Docker Compose](#docker-compose)
- [Health Check](#health-check)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features

- **Citus**: Enables distributed SQL queries on PostgreSQL for horizontal scaling.
- **pg_partman**: Manages time-based and serial-based table partitioning.
- **pg_cron**: Provides the ability to run scheduled jobs using SQL functions.

## Getting Started

### Prerequisites

- Docker installed on your system
- Optionally, `docker-compose` for orchestrating containers

### Build the Image

Clone the repository and build the Docker image:

```bash
git clone <repository-url>
cd cituswithpgpartmandocker
docker build -t cituswithpgpartmandocker:latest .
```

### Run the Container

To start the container with the default configuration:

```bash
docker run --name citus_standalone -p 5432:5432 -e POSTGRES_PASSWORD=password cituswithpgpartmandocker:latest
```

To start with multiple workers, use `docker-compose` (example provided below).

## Environment Variables

Customize the following environment variables as needed:

- **`POSTGRES_PASSWORD`**: Password for the `postgres` user (required).
- **`CITUS_WORKERS`**: Number of worker nodes (default is 2).

## Docker Compose

An example `docker-compose.yml` file is provided for configuring a Citus cluster with a master and two worker nodes.

```yaml
version: '3'
services:
  citus_master:
    image: cituswithpgpartmandocker:latest
    environment:
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - citus_master_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_healthcheck"]
      interval: 4s
      start_period: 6s

  citus_worker:
    image: cituswithpgpartmandocker:latest
    environment:
      POSTGRES_PASSWORD: password
    deploy:
      replicas: 2
    volumes:
      - citus_worker_data:/var/lib/postgresql/data

volumes:
  citus_master_data:
  citus_worker_data:
```

To start the Citus cluster:

```bash
docker-compose up
```

## Health Check

The container includes a `pg_healthcheck` script for monitoring service health. It runs every 4 seconds with a start delay of 6 seconds.

## Troubleshooting

### Common Issues

- **Library Not Found**: If you encounter `could not load library` errors, ensure that both `pg_partman.so` and `citus.so` are present in the correct directories:
  - `/usr/local/lib/postgresql`
  - `/usr/local/share/postgresql/extension`
  
- **Extension Not Found**: Connect to the database and check for available extensions:
  ```sql
  SELECT * FROM pg_extension;
  ```

- **Rebuilding the Image**: If you encounter issues, you may need to clean and rebuild the image:
  ```bash
  docker build --no-cache -t cituswithpgpartmandocker:latest .
  ```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.
