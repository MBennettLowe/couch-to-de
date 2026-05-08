#!/bin/bash
# Day 1 setup — run this on a fresh Codespace to get Pagila loaded

# Start Postgres in Docker on port 5433 (5432 is taken by apt-installed Postgres)
docker run -d \
  --name pg \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=pagila \
  -p 5433:5432 \
  postgres:16

# Wait for Postgres to be ready
sleep 10

# Download Pagila
curl -L https://raw.githubusercontent.com/devrimgunduz/pagila/master/pagila-schema.sql -o /tmp/schema.sql
curl -L https://raw.githubusercontent.com/devrimgunduz/pagila/master/pagila-data.sql -o /tmp/data.sql

# Load it
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d pagila -f /tmp/schema.sql
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d pagila -f /tmp/data.sql

# Verify
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d pagila -c "SELECT COUNT(*) FROM actor;"