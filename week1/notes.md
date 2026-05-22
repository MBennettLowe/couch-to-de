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


## Day 3 — Aggregations: GROUP BY, HAVING, COUNT, SUM, AVG

### Setup gotchas

- None today. Daily routine is muscle memory:
  `docker start pg` → `psql pagila` → quick count query to confirm connection.

### Concepts that clicked

- A GROUP BY query maps to three clauses with distinct jobs:
  - GROUP BY → what to group the rows by (the "piles")
  - SELECT   → what to display (the grouping column AND the aggregate)
  - ORDER BY → how to order the final result
  - First stumble: I grouped by customer_id but forgot to ADD it to SELECT,
    so the customer_id column didn't appear in the output.

- Column aliasing with AS: `COUNT(*) AS rental_count` renames the default
  `count` header. ORDER BY can reference the alias directly.

- COUNT(*) vs COUNT(column): COUNT(*) counts rows; COUNT(column) counts
  only rows where that column isn't NULL. Default to COUNT(*) for "how
  many rows are in this group."

- WHERE vs HAVING (the big one):
  - WHERE filters individual ROWS, before grouping.
  - HAVING filters GROUPS, after the aggregate runs.
  - Quick test: if the filter mentions an aggregate function (COUNT, SUM,
    AVG), it goes in HAVING. If it mentions a plain column value, WHERE.

- SQL clause ORDER of execution (worth memorizing — different from how
  you write it):
    Written:  SELECT → FROM → WHERE → GROUP BY → HAVING → ORDER BY → LIMIT
    Executed: FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT
  This is why ORDER BY can reference SELECT aliases but WHERE cannot —
  SELECT runs before ORDER BY, but after WHERE.

- Mental model for "for each X" questions: "for each X" → GROUP BY X.
  The aggregate function (AVG, SUM, COUNT) runs once per group.

### What I did when I got stuck

Aggregations didn't click on the first pass. Instead of pushing through,
I paused the roadmap and:
- Watched a couple of videos on GROUP BY / HAVING
- Started SQLBolt for structured interactive practice
- Looked up SQL order of execution as a reference

Came back to the drill and wrote the query without help.
Lesson: pausing to shore up a concept beats pushing past confusion.

### Queries I ran

Rentals per customer, top 10 most active (Day 3 exercise):

    SELECT COUNT(*) AS most_rentals, customer_id
    FROM rental
    GROUP BY customer_id
    ORDER BY most_rentals DESC
    LIMIT 10;

### Still need practice

- HAVING with combined filters (WHERE + HAVING in the same query).
- Writing aggregations against unfamiliar tables — building the habit of
  `\d tablename` first to see what columns exist before querying.