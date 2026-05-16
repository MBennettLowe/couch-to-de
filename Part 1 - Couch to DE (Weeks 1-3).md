# Couch to Data Engineering

A 67-day, ~20-minutes-a-day roadmap to go from zero to working data pipelines. Each day tells you exactly what to do, what to type, and what success looks like.

## Setup before Day 1

You need a GitHub account and a GitHub Codespace. If you don't have one, sign up at [github.com](https://github.com) (free). Then create a new empty repository called `couch-to-de` and click the green **Code** button → **Codespaces** → **Create codespace on main**. That gives you a Linux machine in the browser with VS Code pre-installed. Everything in this roadmap runs there.

When you open your Codespace, you'll get a terminal at the bottom of VS Code. That's where you'll type commands. To save your work between sessions, run at the end of each day: `git add -A && git commit -m "day N progress" && git push`. Codespaces stop after 30 minutes idle and get deleted after 30 days unused, so committing is how you protect your work.

---

## Week 1 — SQL Foundations

You cannot do data engineering without fluent SQL. This week is unglamorous but non-negotiable.

### Day 1 — Install PostgreSQL and load the Pagila sample database

**What is this?** PostgreSQL ("Postgres") is the world's most popular open source relational database. Pagila is a free sample database that simulates a DVD rental store — it has tables for films, actors, customers, rentals, and payments. It's the standard practice dataset for learning SQL.

**Do this:**

1. In your Codespace terminal, install Postgres and start it:
   ```bash
   sudo apt update && sudo apt install -y postgresql postgresql-contrib
   sudo service postgresql start
   ```
2. Create a database and load Pagila:
   ```bash
   sudo -u postgres createdb pagila
   curl -L https://raw.githubusercontent.com/devrimgunduz/pagila/master/pagila-schema.sql -o /tmp/schema.sql
   curl -L https://raw.githubusercontent.com/devrimgunduz/pagila/master/pagila-data.sql -o /tmp/data.sql
   sudo -u postgres psql pagila -f /tmp/schema.sql
   sudo -u postgres psql pagila -f /tmp/data.sql
   ```
3. Connect to it and run your first query:
   ```bash
   sudo -u postgres psql pagila
   ```
   At the `pagila=#` prompt, type:
   ```sql
   SELECT first_name, last_name FROM actor LIMIT 5;
   ```
   Press Enter. Type `\q` to exit.

**Outcome:** You should see five actor names printed. If you do, you have a working database with real data in it. Commit your work: `git add -A && git commit -m "day 1: pagila loaded" && git push`.

### Day 2 — WHERE, ORDER BY, LIMIT, DISTINCT

**What is this?** These four clauses filter and shape query results. `WHERE` keeps only rows matching a condition. `ORDER BY` sorts. `LIMIT` caps how many rows come back. `DISTINCT` removes duplicates.

**Do this:** Connect to Pagila with `sudo -u postgres psql pagila` and run each of these queries one at a time. Read each one before running it — predict what you'll see.

```sql
-- All actors whose first name is "Penelope"
SELECT * FROM actor WHERE first_name = 'Penelope';

-- The 10 longest films
SELECT title, length FROM film ORDER BY length DESC LIMIT 10;

-- All distinct film ratings (G, PG, R, etc.)
SELECT DISTINCT rating FROM film;

-- Films longer than 2 hours, sorted alphabetically
SELECT title, length FROM film WHERE length > 120 ORDER BY title LIMIT 20;
```

**Outcome:** You can read a SQL query and predict its shape (how many columns, roughly how many rows) before you run it. Now write one of your own: find all customers in the `customer` table whose `last_name` starts with the letter S. Hint: use `WHERE last_name LIKE 'S%'`.

### Day 3 — Aggregations: GROUP BY, HAVING, COUNT, SUM, AVG

**What is this?** Aggregations collapse many rows into summary numbers. `COUNT` counts rows, `SUM` adds, `AVG` averages. `GROUP BY` says "do this aggregation once per category." `HAVING` filters the groups (it's like `WHERE`, but for grouped rows).

**Do this:** Run each query and study the result.

```sql
-- How many films are there in total?
SELECT COUNT(*) FROM film;

-- How many films per rating?
SELECT rating, COUNT(*) FROM film GROUP BY rating;

-- Average rental rate per rating
SELECT rating, AVG(rental_rate) FROM film GROUP BY rating;

-- Only ratings with more than 200 films
SELECT rating, COUNT(*) FROM film GROUP BY rating HAVING COUNT(*) > 200;
```

Now write your own: find the total number of rentals per customer (use the `rental` table, group by `customer_id`, count rows). Then sort it so the customer with the most rentals is on top.

**Outcome:** You can answer "how many X per Y" questions in SQL. This is 80% of analytical work.

### Day 4 — Joins: INNER, LEFT, RIGHT, FULL OUTER

**What is this?** Joins combine rows from two tables based on a matching column. `INNER JOIN` keeps only rows that match in both tables. `LEFT JOIN` keeps everything from the left table even if there's no match on the right (the right side becomes NULL). `RIGHT` is the mirror. `FULL OUTER` keeps everything from both.

Real databases split data across many tables. To answer "which films has Penelope Guiness been in?" you need to join `actor`, `film_actor`, and `film`.

**Do this:**

```sql
-- All films that actor 1 (Penelope Guiness) appeared in
SELECT a.first_name, a.last_name, f.title
FROM actor a
INNER JOIN film_actor fa ON a.actor_id = fa.actor_id
INNER JOIN film f ON fa.film_id = f.film_id
WHERE a.actor_id = 1;

-- All customers and their rental counts (including customers with zero rentals)
SELECT c.first_name, c.last_name, COUNT(r.rental_id) AS rental_count
FROM customer c
LEFT JOIN rental r ON c.customer_id = r.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY rental_count DESC
LIMIT 10;
```

**Outcome:** You understand that an `INNER JOIN` would have dropped customers with zero rentals from the second query. Draw the four join types as Venn diagrams on paper if that helps — it does for most people.

### Day 5 — Subqueries and CTEs (WITH clauses)

**What is this?** Sometimes you need the result of one query to feed into another. A subquery is a query inside parentheses inside another query. A CTE (Common Table Expression) is the same idea but named and at the top — much more readable. CTEs use the `WITH` keyword.

**Do this:**

```sql
-- Subquery: films longer than the average film length
SELECT title, length
FROM film
WHERE length > (SELECT AVG(length) FROM film);

-- Same query as a CTE — easier to read
WITH avg_length AS (
  SELECT AVG(length) AS avg_len FROM film
)
SELECT f.title, f.length
FROM film f, avg_length a
WHERE f.length > a.avg_len;

-- A more useful CTE: top 10 customers by rental count, then their total payments
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
```

**Outcome:** You can break a complex question into named steps using CTEs. This is the single biggest readability upgrade in SQL.

### Day 6 — Window functions

**What is this?** Window functions compute a value across a "window" of related rows without collapsing them like `GROUP BY` does. Use them for rankings, running totals, and comparisons to neighboring rows. Key ones: `ROW_NUMBER()` (assigns 1, 2, 3...), `RANK()` (assigns 1, 2, 2, 4 for ties), `LAG()` (gets the previous row's value), `SUM() OVER (...)` (running total).

**Do this:**

```sql
-- Rank films within each rating by length
SELECT
  rating,
  title,
  length,
  ROW_NUMBER() OVER (PARTITION BY rating ORDER BY length DESC) AS rank_in_rating
FROM film
ORDER BY rating, rank_in_rating
LIMIT 20;

-- Running total of payment amounts over time
SELECT
  payment_date,
  amount,
  SUM(amount) OVER (ORDER BY payment_date) AS running_total
FROM payment
ORDER BY payment_date
LIMIT 20;
```

**Outcome:** `OVER (...)` clicks for you. The `PARTITION BY` is the equivalent of `GROUP BY` for windows.

### Day 7 — Mini-project: Five business questions in SQL

**What is this?** Today you write queries from scratch — no copy-paste. This is the test that you've actually internalized the week.

**Do this:** In your Codespace, create a folder `week1/` with a file `business_questions.sql`. Write a SQL query answering each of these about the Pagila database:

1. Which 5 films generated the most revenue (sum of payment amount for that film's rentals)?
2. Which actor has appeared in the most films?
3. What's the average rental duration per film category? (Tables: `film`, `film_category`, `category`.)
4. Which customers have rented every film in the "Sci-Fi" category? (Hard — try anyway.)
5. For each month in the data, what's the total revenue, and how does it compare to the previous month? (Use a window function.)

**Outcome:** A `.sql` file with five working queries. Commit it: `git add -A && git commit -m "day 7: week 1 capstone" && git push`. If you got stuck on question 4, that's normal — come back to it after Day 14.

---

## Week 2 — Data Modeling and Warehousing Concepts

You can query. Now learn how data should be *shaped* so it's easy to query.

### Day 8 — OLTP vs OLAP

**What is this?** OLTP (Online Transaction Processing) databases handle the day-to-day operations of an app — single-row reads and writes, lots of concurrent users. Postgres in transactional mode is OLTP. OLAP (Online Analytical Processing) databases are for analysis — scanning millions of rows, complex aggregations, few concurrent users. BigQuery and DuckDB are OLAP. They're built differently because the workloads are different.

**Do this:** Read [this short article](https://www.ibm.com/think/topics/oltp-vs-olap) (10 min). Then in your Codespace, create `week2/notes.md` and write 3-4 sentences answering: why would running an analytical query (e.g., "total revenue per category over the last year") on an OLTP database slow down the application?

**Outcome:** Your answer should mention table locks, indexes optimized for point reads, and row-based storage being slow for column scans. This is *why* data engineering exists as a field — moving data from OLTP systems into OLAP systems for analysis.

### Day 9 — Normalization (1NF, 2NF, 3NF)

**What is this?** Normalization is the process of organizing data to eliminate redundancy. 1NF: each cell has one value (no comma-separated lists). 2NF: every non-key column depends on the whole primary key. 3NF: no column depends on another non-key column. OLTP databases are usually heavily normalized.

**Do this:** Read [this guide](https://www.guru99.com/database-normalization.html). Then look at the Pagila schema by running `\d film` in psql — this shows the `film` table structure. Notice that `language_id` is a foreign key to a `language` table, not the language name itself. That's 3NF — the language name doesn't repeat in every film row.

**Outcome:** You can recognize a normalized schema when you see one, and you understand it's designed for write efficiency, not read efficiency.

### Day 10 — Dimensional modeling: facts vs dimensions

**What is this?** In analytical (OLAP) databases, we *denormalize* on purpose to make queries fast. The pattern is dimensional modeling: a central **fact table** (events: rentals, orders, clicks — usually numeric, lots of rows) surrounded by **dimension tables** (descriptive context: customer, product, date, store — fewer rows, lots of columns).

**Do this:** Read the first chapter of [Kimball Group's free intro](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/). Then sketch on paper: for the Pagila DVD rental business, what would the fact table be (hint: rentals or payments) and what dimensions would surround it (customer, film, store, date)?

**Outcome:** You can look at a business and identify "what's the event we measure" vs "what's the context that describes the event."

### Day 11 — Star vs snowflake schema

**What is this?** A **star schema** has the fact table in the middle with dimensions directly attached — each dimension is a single denormalized table. A **snowflake schema** further normalizes the dimensions into sub-tables (e.g., film → category, film → language as separate tables). Star is more common in modern warehouses because joins are cheap and storage is cheaper than developer time.

**Do this:** On paper, draw a star schema for an e-commerce business. Fact table: `fct_orders` with columns order_id, customer_id, product_id, date_id, quantity, revenue. Dimensions: `dim_customer`, `dim_product`, `dim_date`. List 4-5 columns for each dimension.

**Outcome:** You can sketch a star schema for any business when asked. This is a common interview question.

### Day 12 — Slowly Changing Dimensions (SCD Types 1, 2, 3)

**What is this?** Dimension data changes — a customer moves, a product gets renamed. How do you handle that? **Type 1**: overwrite the old value (you lose history). **Type 2**: insert a new row with a new "valid from / valid to" date and an `is_current` flag (you keep history; this is the most common). **Type 3**: add a "previous value" column (limited history).

**Do this:** Read [this guide](https://www.sqlservertutorial.net/sql-server-basics/sql-server-slowly-changing-dimension/). Then in `week2/notes.md`, answer: if a customer's address changes, and last year's sales report needs to show the *old* address as it was at the time of sale, which SCD type do you need?

**Outcome:** The answer is Type 2. You'll see SCD Type 2 in every dbt project you ever work on.

### Day 13 — Install DuckDB

**What is this?** DuckDB is an analytical database that runs as a single binary, no server, no setup. It reads CSV and Parquet directly. Think of it as "SQLite, but for analytics." You'll use it constantly.

**Do this:**

```bash
curl https://install.duckdb.org | sh
export PATH="$HOME/.duckdb/cli/latest:$PATH"
duckdb
```

At the `D` prompt, run:
```sql
SELECT 'hello duckdb' AS greeting;
CREATE TABLE numbers AS SELECT * FROM range(1, 11) AS t(n);
SELECT SUM(n) FROM numbers;
```

Type `.quit` to exit. Add the export line to your `~/.bashrc` so DuckDB is always available: `echo 'export PATH="$HOME/.duckdb/cli/latest:$PATH"' >> ~/.bashrc`.

**Outcome:** You should see `hello duckdb` and `55`. DuckDB is now installed.

### Day 14 — Mini-project: CSV to DuckDB star schema

**What is this?** Apply Week 2 by modeling a real dataset.

**Do this:** Download the [NYC Yellow Taxi 2023-01 Parquet file](https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2023-01.parquet):
```bash
mkdir -p week2/data && cd week2
curl -L https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2023-01.parquet -o data/taxi.parquet
duckdb taxi.db
```

In DuckDB, build a star schema:
```sql
-- Fact table: one row per trip
CREATE TABLE fct_trips AS
SELECT
  tpep_pickup_datetime AS pickup_ts,
  tpep_dropoff_datetime AS dropoff_ts,
  PULocationID AS pickup_location_id,
  DOLocationID AS dropoff_location_id,
  passenger_count,
  trip_distance,
  fare_amount,
  tip_amount,
  total_amount
FROM 'data/taxi.parquet';

-- Dimension: dates derived from the pickup
CREATE TABLE dim_date AS
SELECT DISTINCT
  CAST(pickup_ts AS DATE) AS date_id,
  EXTRACT(year FROM pickup_ts) AS year,
  EXTRACT(month FROM pickup_ts) AS month,
  EXTRACT(dow FROM pickup_ts) AS day_of_week
FROM fct_trips;

-- Sanity check: total revenue per day of week
SELECT d.day_of_week, SUM(f.total_amount) AS revenue
FROM fct_trips f
JOIN dim_date d ON CAST(f.pickup_ts AS DATE) = d.date_id
GROUP BY d.day_of_week
ORDER BY d.day_of_week;
```

**Outcome:** You see revenue grouped by day of week. The `taxi.db` file is too big to commit — instead create a `week2/build.sql` file with the queries above and commit that.

---

## Week 3 — Python for Data Engineering

Python is the glue language. This week makes you dangerous with it.

### Day 15 — Set up a Python project properly

**What is this?** A reproducible Python project needs a virtual environment (isolated dependencies) and a way to declare what packages it uses. `uv` is the modern fast tool for this.

**Do this:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env
mkdir -p week3 && cd week3
uv init --name week3
uv add polars pandas httpx "psycopg[binary]"
```

This creates a `pyproject.toml`, a `.venv/` folder, and installs the packages you'll need this week. Verify with: `uv run python -c "import polars; print(polars.__version__)"`.

**Outcome:** A version number is printed. You have an isolated Python environment.

### Day 16 — pandas basics

**What is this?** pandas is *the* Python data manipulation library. Slower than its alternatives, but it's everywhere. Today you learn the four operations that cover 80% of usage: read, filter, group, write.

**Do this:** Create `week3/pandas_basics.py`:
```python
import pandas as pd

# Read the taxi file from Week 2
df = pd.read_parquet("../week2/data/taxi.parquet")
print(f"Loaded {len(df):,} rows")
print(df.head())
print(df.dtypes)

# Filter: trips longer than 5 miles
long_trips = df[df["trip_distance"] > 5]
print(f"\n{len(long_trips):,} long trips")

# Group: average fare by passenger count
by_pax = df.groupby("passenger_count")["fare_amount"].mean()
print("\nAverage fare by passenger count:")
print(by_pax)

# Write
by_pax.to_csv("avg_fare_by_pax.csv")
```

Run it: `uv run python pandas_basics.py`.

**Outcome:** You see row counts, a head, and an average fare per passenger count. The CSV file appears in your folder.

### Day 17 — Polars basics

**What is this?** Polars is a faster, more modern DataFrame library. Same operations, different (better) API. It uses **lazy evaluation** — you build up a query plan, and it only runs when you call `.collect()`. This is how analytical engines work.

**Do this:** Create `week3/polars_basics.py`:
```python
import polars as pl

# Lazy: builds a plan, doesn't load data yet
plan = (
    pl.scan_parquet("../week2/data/taxi.parquet")
    .filter(pl.col("trip_distance") > 5)
    .group_by("passenger_count")
    .agg(pl.col("fare_amount").mean().alias("avg_fare"))
    .sort("passenger_count")
)

# Now actually run it
result = plan.collect()
print(result)
```

Run it. Time it against yesterday's pandas version: `time uv run python polars_basics.py` and `time uv run python pandas_basics.py`.

**Outcome:** Polars is noticeably faster. You see the same average-fare-by-passenger-count result.

### Day 18 — Reading from APIs

**What is this?** Most real-world data comes from APIs over HTTP. `httpx` is a modern Python HTTP client. Today you'll pull weather data from an open API.

**Do this:** Create `week3/api_pull.py`:
```python
import httpx
import json

# Open-Meteo: free weather API, no key required
url = "https://api.open-meteo.com/v1/forecast"
params = {
    "latitude": 39.29,
    "longitude": -76.61,  # Baltimore
    "hourly": "temperature_2m",
    "forecast_days": 3,
}

response = httpx.get(url, params=params)
response.raise_for_status()
data = response.json()

print(f"Got {len(data['hourly']['time'])} hourly readings")
print(f"First reading: {data['hourly']['time'][0]} -> {data['hourly']['temperature_2m'][0]} C")

with open("weather_raw.json", "w") as f:
    json.dump(data, f, indent=2)
```

Run it. Open `weather_raw.json` in VS Code and look at the structure.

**Outcome:** You have raw JSON weather data on disk and you understand the request/response cycle.

### Day 19 — JSON and nested data

**What is this?** API responses are usually nested JSON. To analyze them, you flatten them into a tabular DataFrame.

**Do this:** Create `week3/flatten.py`:
```python
import json
import polars as pl

with open("weather_raw.json") as f:
    data = json.load(f)

# The hourly section has parallel arrays — flatten into rows
df = pl.DataFrame({
    "timestamp": data["hourly"]["time"],
    "temp_c": data["hourly"]["temperature_2m"],
})
df = df.with_columns(
    pl.col("timestamp").str.to_datetime(),
    (pl.col("temp_c") * 9/5 + 32).alias("temp_f"),
)

print(df.head(10))
df.write_csv("weather_flat.csv")
```

**Outcome:** A clean tabular CSV with timestamp, temp_c, temp_f. This pattern — pull JSON, flatten, write tabular — is most of ingestion engineering.

### Day 20 — Connect Python to PostgreSQL

**What is this?** You'll write a DataFrame into Postgres, then read it back. This is the foundational ETL move.

**Do this:** First make sure Postgres is running and create a database:
```bash
sudo service postgresql start
sudo -u postgres createdb de_practice
sudo -u postgres psql -c "CREATE USER me WITH PASSWORD 'me'; GRANT ALL ON DATABASE de_practice TO me;"
```

Then create `week3/db_io.py`:
```python
import polars as pl
import psycopg

CONN = "postgresql://me:me@localhost:5432/de_practice"

df = pl.read_csv("weather_flat.csv", try_parse_dates=True)

with psycopg.connect(CONN) as conn:
    with conn.cursor() as cur:
        cur.execute("""
            DROP TABLE IF EXISTS weather;
            CREATE TABLE weather (
                timestamp TIMESTAMP PRIMARY KEY,
                temp_c DOUBLE PRECISION,
                temp_f DOUBLE PRECISION
            );
        """)
        rows = list(df.iter_rows())
        cur.executemany(
            "INSERT INTO weather (timestamp, temp_c, temp_f) VALUES (%s, %s, %s)",
            rows,
        )
    conn.commit()

with psycopg.connect(CONN) as conn:
    result = conn.execute("SELECT COUNT(*), MIN(temp_c), MAX(temp_c) FROM weather").fetchone()
    print(f"Rows: {result[0]}, min: {result[1]:.1f} C, max: {result[2]:.1f} C")
```

**Outcome:** A row count and temperature range printed. Verify in Postgres: `psql postgresql://me:me@localhost:5432/de_practice -c "SELECT * FROM weather LIMIT 5;"`.

### Day 21 — Mini-project: Your first ETL pipeline

**What is this?** Combine Days 18-20 into one script that goes API → transform → database.

**Do this:** Create `week3/etl.py` that:

1. Pulls 7 days of forecast for three cities (Baltimore: 39.29/-76.61, Tokyo: 35.68/139.69, London: 51.51/-0.13) from Open-Meteo.
2. Flattens each into a Polars DataFrame with columns: `city`, `timestamp`, `temp_c`, `temp_f`.
3. Concatenates all three with `pl.concat([df1, df2, df3])`.
4. Writes to a `weather_forecast` table in Postgres (drop and recreate each run).
5. Prints total rows and average temp per city.

You have all the pieces from Days 18-20. The only new bit is looping over cities and concatenating.

**Outcome:** A working end-to-end pipeline. Commit it. This is your first real piece of data engineering code — keep it; you'll come back to it in Week 6 when you add orchestration.

---

## A note on the rest

Weeks 4-9 (Days 22-67) follow this same format and will be added next. To keep this file from getting unwieldy, I'm sending it in two parts. Each remaining day will have:

- **What is this?** — the concept and why it matters
- **Do this:** — exact commands and code, copy-paste-runnable
- **Outcome:** — what you should see, plus the success check

When you've worked through Day 21, ask for "Week 4" (or all remaining weeks at once) and I'll send the next file with Days 22 onward.
