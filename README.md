# Couch to Data Engineering

My 67-day journey from zero to working data pipelines.
Full roadmap is in the "Part 1/2/3 - Couch to DE" files.

## First-time setup (fresh Codespace)

Run the setup script — it installs and loads everything from scratch:

    bash week1/setup.sh

## Daily routine (resuming an existing Codespace)

The `pg` container and Pagila data persist between sessions. You only
need to restart the container, not rebuild it.

1. Start the Postgres container:

       docker start pg

2. Verify you have access to the Pagila database:

       psql pagila -c "SELECT COUNT(*) FROM actor;"

   Expected output: 200

3. (Optional) Open Pagila interactively to run queries:

       psql pagila

## Connection details

- Database server: PostgreSQL 16 (in Docker container `pg`)
- Port: 5433 (not the default 5432 — that's taken by the apt-installed Postgres)
- User: postgres / Password: postgres
- Connection string: postgresql://postgres:postgres@localhost:5433/pagila

## End-of-session

    git status
    git add <specific files>
    git commit -m "day N notes"
    git push
    # Then: F1 -> "Stop Current Codespace"