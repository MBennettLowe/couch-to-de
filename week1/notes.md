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