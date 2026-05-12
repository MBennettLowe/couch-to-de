# Week 1 Notes

## Day 1 — Setup gotchas

- This Codespace doesn't allow passwordless sudo for the codespace user (unusual).
  Worked around by running Postgres in Docker instead of via apt.
- The apt-installed Postgres is still listening on port 5432; Docker Postgres uses 5433.
- Connection string: postgresql://postgres:postgres@localhost:5433/pagila
- After Codespace resume, run `docker start pg` to bring Postgres back up.

## First query result

SELECT first_name, last_name FROM actor LIMIT 5;
→ Penelope Guiness, Nick Wahlberg, Ed Chase, Jennifer Davis, Johnny Lollobrigida

## Day 2 — WHERE, ORDER BY, LIMIT, DISTINCT

### Setup gotchas

- After restarting the Codespace, the `pg` container exists but isn't running.
  `docker ps` shows nothing because it only lists running containers.
  Fix: `docker start pg` (or `docker ps -a` to see stopped containers too).
- Made setup.sh idempotent — it now checks for an existing `pg` container and
  starts it instead of failing on the `docker run` conflict.
- Inside psql, `\dt` output pages through `less`. Press `q` to exit the pager,
  not Enter. To disable pagination for the session: `\pset pager off`.

### Concepts that clicked

- psql is a client; SQL is the language. The slash commands (`\dt`, `\d`, `\l`)
  are psql-specific meta-commands for inspecting the database, not SQL.
  SELECT/INSERT/UPDATE/DELETE are SQL — they work in any Postgres client.
- ORDER BY takes a comma-separated list of columns for tie-breaking.
  `ORDER BY length DESC, title ASC` sorts by length first, then alphabetizes
  within ties. ASC is the default and can be omitted.
- LIMIT silently drops tied rows past the limit. If 12 films share the longest
  length and LIMIT is 10, two get cut. `FETCH FIRST 10 ROWS WITH TIES` keeps
  all ties.

### Queries I ran

Longest 10 films, alphabetized within ties:

    SELECT title, length
    FROM film
    ORDER BY length DESC, title ASC
    LIMIT 10;

Distinct film ratings:

    SELECT DISTINCT rating FROM film;
    -- Result: G, PG, PG-13, R, NC-17

Films longer than 2 hours:

    SELECT title, length
    FROM film
    WHERE length > 120
    ORDER BY title
    LIMIT 20;

### My own query (Day 2 exercise)

Customers whose last name starts with 'S':

    SELECT first_name, last_name
    FROM customer
    WHERE last_name LIKE 'S%'
    ORDER BY last_name;