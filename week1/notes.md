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

## Day 4 — Joins: INNER, LEFT, RIGHT, FULL OUTER

### Setup routine

- docker start pg          → start the Postgres container
- docker ps                → confirm the CONTAINER is up (not psql — psql
                             is the client, launched separately)
- psql pagila              → connect to the pagila database
- quick COUNT(*) query     → confirm I have access

### Concepts that clicked

Joins combine rows from two tables on a matching column. The key question
that separates the four types: which table's UNMATCHED rows do you keep?

- INNER JOIN — only rows that match in BOTH tables (the overlap).
  Keeps no unmatched rows.
- LEFT JOIN — ALL rows from the left table + matching rows from the right.
  Unmatched right side comes back as NULL.
- RIGHT JOIN — ALL rows from the right table + matching rows from the left.
  Unmatched left side comes back as NULL. Mirror image of LEFT. (Rarely
  written in practice — people flip table order and use LEFT instead.)
- FULL OUTER JOIN — ALL rows from BOTH tables. Matches combine; anything
  unmatched on either side is kept with NULLs filling the missing side.
  Nothing gets dropped.

Mental shortcut:
  INNER = overlap only
  LEFT  = all left + matches
  RIGHT = all right + matches
  FULL  = everything, both sides

### Still need practice

- Writing multi-table joins (e.g. actor → film_actor → film) where you
  chain joins across a linking table.
- Recognizing when a LEFT JOIN is needed to AVOID dropping rows (e.g.
  customers with zero rentals would vanish under an INNER JOIN).


## Day 5 — Subqueries and CTEs (WITH clauses)

### Setup gotchas

- Restarting today, I typed `docker start ps` instead of `docker start pg`.
  - `pg` is the NAME I gave my container with `docker run --name pg`.
  - `ps` is the Unix "process status" subcommand — `docker ps` lists
    running containers.
  - They look almost identical in a terminal. Read errors carefully.

- CLI tool structure: `<command> <subcommand> [arguments]`. Same pattern
  for docker, git, psql, dbt, gcloud, etc.

### Concepts that clicked

- Subqueries put a query inside another query (parentheses). Read
  inside-out. Anonymous and single-use.

- CTEs (Common Table Expressions, `WITH ... AS (...)`) name a query at
  the top, then reference it by name below. Read top-to-bottom.

- Both produce the same answer for the same logic. The choice is about
  readability and reuse.

### Subquery vs CTE — what I'd reach for now

My first instinct was to prefer subqueries because they match my habit
of "peek at a query, then use its result" — sticking a query inside
another query feels like that.

The experienced take is the opposite: prefer CTEs for anything beyond
trivial.
- CTEs read top-to-bottom like a story; subqueries read inside-out and
  get unreadable as logic grows.
- CTEs can be named meaningfully (`top_customers`); subqueries are
  anonymous and harder to remember six months later.
- CTEs can be reused multiple times in the same query; subqueries can't.
- Modern warehouses optimize both equally — the old "subqueries are
  faster" folklore is outdated.

Subqueries still earn their keep when you just need ONE scalar value
inline, like `WHERE length > (SELECT AVG(length) FROM film)`.

My "peek-first" habit still works with CTEs — better, actually. You
write WITH step1 AS (...) SELECT * FROM step1, verify the result, add
step2, verify, and so on. You get to peek BETWEEN every step.

### Queries I ran

WITH top_customers AS (
  SELECT customer_id, COUNT(*) AS rentals
  FROM rental
  GROUP BY customer_id
  ORDER BY rentals DESC
  LIMIT 10
)
SELECT t.customer_id, t.rentals, SUM(p.amount) AS total_paid
FROM top_customers t
JOIN payment p ON t.customer_id = p.customer_id
GROUP BY t.customer_id, t.rentals
ORDER BY t.rentals DESC;

### Still need practice

- Building up complex queries CTE-by-CTE, verifying each step before
  adding the next.
- Recognizing when ONE scalar subquery is the right tool vs when to
  reach for a CTE.

# Week 1 — Day 7: Capstone — Five Business Questions in SQL

## What Today Was

Day 7 is the Week 1 capstone. No new concepts — just five business questions to answer from scratch using everything covered in Days 1–6. The task was to write a SQL query for each question against the Pagila database and save them in `week1/business_questions.sql`.

---

## What Clicked

- **Starting Codespaces** — Getting the GitHub Codespace up and running is now muscle memory. Knowing where to go and how to get back into the environment quickly is a win.
- **Starting the Docker container** — Running `docker start pg` to bring the Postgres container back up (rather than recreating it) clicked this week. Understanding that `docker ps` only shows *running* containers, not stopped ones, was a key correction from earlier in the week.
- **SQLTools extension in VSCode** — Installing the SQLTools extension for Postgres was a productivity unlock. Being able to view tables, browse schema, and run queries in a side panel while writing SQL in the editor is proper EDA tooling — no more switching back and forth to the terminal for every `\dt` check.

---

## What Was Hard

All five capstone questions were challenging. Honest reflection below.

### Q1 — Which 5 films generated the most revenue?

The instinct to use `MAX` instead of `SUM` was the first hurdle. The question asks for total revenue per film across all its rentals, which means summing payment amounts — not finding a single maximum. The other challenge was the join chain: `payment → rental → inventory → film`. Payment doesn't link directly to a film; it links to a rental, which links to an inventory item (a physical copy), which finally links to the film title. Getting that 4-table chain right takes practice.

```sql
SELECT f.title, SUM(p.amount) AS total_revenue
FROM payment p
JOIN rental r ON p.rental_id = r.rental_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
GROUP BY f.title
ORDER BY total_revenue DESC
LIMIT 5;
```

### Q2 — Which actor has appeared in the most films?

Simpler chain (`actor → film_actor → film`) but the key lesson was grouping by `actor_id`, not just name, because two actors could share the same name. The `film_actor` bridge table has one row per actor-film combination — counting those rows per actor gives the answer.

```sql
SELECT a.first_name, a.last_name, COUNT(fa.film_id) AS film_count
FROM actor a
JOIN film_actor fa ON a.actor_id = fa.actor_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY film_count DESC
LIMIT 1;
```

### Q3 — Average rental duration per film category?

Introduced `AVG` and a 3-table join through the `film_category` bridge table. The key clarification: `rental_duration` is a column on the `film` table itself (the allowed days to keep a film), not something calculated from actual rental timestamps.

```sql
SELECT c.name AS category, ROUND(AVG(f.rental_duration), 2) AS avg_rental_duration
FROM category c
JOIN film_category fc ON c.category_id = fc.category_id
JOIN film f ON fc.film_id = f.film_id
GROUP BY c.category_id, c.name
ORDER BY avg_rental_duration DESC;
```

### Q4 — Which customers have rented every Sci-Fi film? (Hard)

This introduced **relational division** — a concept SQL has no native operator for. The approach that makes the most sense right now is the COUNT matching method: find each customer's count of distinct Sci-Fi films rented, then compare it to the total number of Sci-Fi films using a subquery in `HAVING`. The double-negative `NOT EXISTS` approach is more theoretically correct but harder to reason through at this stage.

```sql
SELECT cu.customer_id, cu.first_name, cu.last_name,
       COUNT(DISTINCT f.film_id) AS scifi_films_rented
FROM customer cu
JOIN rental r ON cu.customer_id = r.customer_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
WHERE c.name = 'Sci-Fi'
GROUP BY cu.customer_id, cu.first_name, cu.last_name
HAVING COUNT(DISTINCT f.film_id) = (
    SELECT COUNT(DISTINCT f2.film_id)
    FROM film f2
    JOIN film_category fc2 ON f2.film_id = fc2.film_id
    JOIN category c2 ON fc2.category_id = c2.category_id
    WHERE c2.name = 'Sci-Fi'
);
```

### Q5 — Monthly revenue with month-over-month comparison using a window function?

The payoff question. Two new tools introduced here: `DATE_TRUNC` to collapse dates into months, and `LAG()` to pull the previous row's value into the current row. The CTE (`WITH monthly_revenue AS`) is necessary because you can't apply a window function directly on top of a `GROUP BY` in a single query — you have to aggregate first, then window over the result.

```sql
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', payment_date) AS month,
        SUM(amount) AS total_revenue
    FROM payment
    GROUP BY DATE_TRUNC('month', payment_date)
)
SELECT
    month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(total_revenue - LAG(total_revenue) OVER (ORDER BY month), 2) AS revenue_change
FROM monthly_revenue
ORDER BY month;
```

---

## Key Takeaways

- Joins are the hardest part right now and need the most continued practice.
- The core analytical loop is always: **join tables → GROUP BY the category → aggregate the number → ORDER BY → LIMIT**.
- `SUM` = total across many rows. `MAX` = single biggest value. These are not interchangeable.
- CTEs make complex queries readable by breaking them into named steps.
- EDA before the final query — checking table shape, confirming columns exist, spotting duplicates — is the right habit to build now.

---

## Aggregate Summary Across All 5 Questions

| Q | Aggregate | Join depth | New concept |
|---|-----------|------------|-------------|
| 1 | `SUM` | 4 tables | Multi-table join chain |
| 2 | `COUNT` | 2 tables | Bridge/junction table |
| 3 | `AVG` | 3 tables | `film_category` bridge |
| 4 | `COUNT DISTINCT` | 6 tables | Relational division, subquery in `HAVING` |
| 5 | `SUM` + window | 1 table | `LAG`, `DATE_TRUNC`, CTE |

---

