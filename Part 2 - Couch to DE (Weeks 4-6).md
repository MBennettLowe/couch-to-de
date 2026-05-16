# Couch to Data Engineering — Part 2 (Weeks 4-6)

Continuing from Day 21. Same format throughout: *What is this?*, *Do this:*, *Outcome:*.

---

## Week 4 — File Formats and Object Storage

Real pipelines don't move CSVs around. They move Parquet files on object storage. This week you learn why, and how.

### Day 22 — CSV vs JSON vs Parquet vs Avro

**What is this?** File formats for data fall into two camps: **row-based** (CSV, JSON, Avro) store one record at a time; **columnar** (Parquet, ORC) store all values for one column together. Columnar formats are dramatically faster for analytical queries because you only read the columns you need, and similar values compress better when stored together. Parquet is the de facto standard for analytics.

**Do this:** Read [this short comparison](https://www.upsolver.com/blog/the-file-format-fundamentals-of-big-data) (15 min). Then in `week4/notes.md`, answer in your own words: if a query selects 3 columns out of 50 and scans 100 million rows, why is Parquet faster than CSV?

**Outcome:** Your answer should mention that Parquet only reads the bytes for the 3 needed columns, while CSV must parse every row from start to finish to find any column. That's typically a 10-100x speedup.

### Day 23 — Convert CSV to Parquet

**What is this?** Today you measure the difference yourself.

**Do this:** Make sure you're in your project. Then:

```bash
mkdir -p week4 && cd week4
# Convert the taxi parquet to CSV first (so we can compare)
duckdb -c "COPY (SELECT * FROM '../week2/data/taxi.parquet') TO 'taxi.csv' (HEADER, DELIMITER ',');"
# Then back to parquet (with default snappy compression)
duckdb -c "COPY (SELECT * FROM 'taxi.csv') TO 'taxi.parquet' (FORMAT PARQUET);"

# Compare file sizes
ls -lh taxi.csv taxi.parquet

# Time a query against each
time duckdb -c "SELECT passenger_count, AVG(fare_amount) FROM 'taxi.csv' GROUP BY passenger_count;"
time duckdb -c "SELECT passenger_count, AVG(fare_amount) FROM 'taxi.parquet' GROUP BY passenger_count;"
```

**Outcome:** Parquet is roughly 5x smaller and 5-10x faster on this query. Note the numbers in `week4/notes.md`. You now have visceral evidence of why Parquet exists.

### Day 24 — Spin up MinIO

**What is this?** MinIO is an S3-compatible object store you can run locally. It speaks the same API as Amazon S3, so any tool that talks to S3 talks to MinIO. This is how you learn cloud storage patterns without a cloud bill.

**Do this:** First install Docker if it's not already in your Codespace (it usually is — check with `docker --version`). Then:

```bash
docker run -d --name minio \
  -p 9000:9000 -p 9001:9001 \
  -e "MINIO_ROOT_USER=admin" \
  -e "MINIO_ROOT_PASSWORD=password123" \
  quay.io/minio/minio server /data --console-address ":9001"
```

In your Codespace, click the **Ports** tab at the bottom of VS Code. Find port 9001, right-click, and "Open in Browser" (set to public if needed). Log in with `admin` / `password123`. Click "Create Bucket" and make one called `lake`.

**Outcome:** You can see the MinIO web console. The `lake` bucket exists and is empty.

### Day 25 — Upload to MinIO with boto3

**What is this?** `boto3` is the AWS Python SDK. Pointed at MinIO instead of AWS, it works identically. This is how Python code talks to object storage.

**Do this:** In `week4/`, run `uv add boto3` (or if you're not in a uv project, `pip install boto3`). Then create `s3_upload.py`:

```python
import boto3

s3 = boto3.client(
    "s3",
    endpoint_url="http://localhost:9000",
    aws_access_key_id="admin",
    aws_secret_access_key="password123",
)

# Upload yesterday's parquet
s3.upload_file("taxi.parquet", "lake", "raw/taxi/2023-01.parquet")
print("Uploaded.")

# List what's there
response = s3.list_objects_v2(Bucket="lake", Prefix="raw/")
for obj in response.get("Contents", []):
    size_mb = obj["Size"] / 1024 / 1024
    print(f"  {obj['Key']}  ({size_mb:.1f} MB)")
```

Run it. Refresh the MinIO console — you should see the file under `lake/raw/taxi/`.

**Outcome:** A Parquet file in object storage, uploaded by Python code. Every cloud data lake works exactly this way.

### Day 26 — Query Parquet in MinIO with DuckDB

**What is this?** DuckDB can query Parquet files directly from S3-compatible storage without downloading them. This is "data lake" mode — your storage and compute are separate.

**Do this:** Open DuckDB and run:

```sql
-- Configure DuckDB to talk to MinIO
INSTALL httpfs;
LOAD httpfs;
SET s3_endpoint = 'localhost:9000';
SET s3_access_key_id = 'admin';
SET s3_secret_access_key = 'password123';
SET s3_use_ssl = false;
SET s3_url_style = 'path';

-- Now query a file in MinIO directly
SELECT passenger_count, COUNT(*) AS trips, AVG(fare_amount) AS avg_fare
FROM 's3://lake/raw/taxi/2023-01.parquet'
GROUP BY passenger_count
ORDER BY passenger_count;
```

**Outcome:** Aggregation results come back without you ever downloading the file. This separation of storage from compute is the foundation of modern analytics.

### Day 27 — Read about table formats: Iceberg, Delta, Hudi

**What is this?** A bare Parquet file in object storage is just a file. **Table formats** add a metadata layer on top so a folder of Parquet files behaves like a database table — supporting updates, deletes, schema evolution, time travel, and concurrent writers. The three contenders are Apache Iceberg, Delta Lake, and Apache Hudi. Iceberg has won most of the open ecosystem mindshare in 2025-2026.

**Do this:** Read [the official Iceberg "What is" page](https://iceberg.apache.org/docs/latest/). In `week4/notes.md`, answer: why can't you just `UPDATE` or `DELETE` a row in a regular Parquet file in S3? What does Iceberg add that makes it possible?

**Outcome:** Your answer should mention that Parquet files are immutable, so updates require either rewriting the whole file or layering metadata that tracks "this row was deleted in version N." Iceberg's manifest files do exactly that.

### Day 28 — Your first Iceberg table with PyIceberg

**What is this?** PyIceberg is the Python library for creating and querying Iceberg tables. Today you create one in MinIO.

**Do this:** Install: `uv add "pyiceberg[s3fs,pyarrow]" pyarrow`. Then create `week4/iceberg_demo.py`:

```python
import pyarrow.parquet as pq
from pyiceberg.catalog.sql import SqlCatalog

# Use a local SQLite catalog backed by MinIO for storage
catalog = SqlCatalog(
    "default",
    **{
        "uri": "sqlite:///iceberg_catalog.db",
        "warehouse": "s3://lake/warehouse/",
        "s3.endpoint": "http://localhost:9000",
        "s3.access-key-id": "admin",
        "s3.secret-access-key": "password123",
    },
)

# Create a namespace and load source data
catalog.create_namespace_if_not_exists("trips")
table_data = pq.read_table("taxi.parquet")

# Create the iceberg table from the parquet schema
table = catalog.create_table_if_not_exists(
    "trips.yellow_taxi",
    schema=table_data.schema,
)

# Append the data
table.append(table_data)

# Query it back
result = table.scan().to_arrow()
print(f"Iceberg table now has {len(result):,} rows")
```

Run it. Look in the MinIO console — you'll see the `warehouse/trips.db/yellow_taxi/` folder structure with `data/` and `metadata/` subfolders.

**Outcome:** A working Iceberg table. Don't worry if it felt fiddly — it is. You just did something that took the industry years to standardize.

---

## Week 5 — Transformations with dbt

dbt is how modern teams transform data. Once raw data is in your warehouse, dbt turns it into clean, tested, documented analytical tables. dbt Core is open source.

### Day 29 — Install dbt Core

**What is this?** dbt Core is a Python package. You also need an "adapter" for the database you're targeting. We'll use `dbt-duckdb` because it's the simplest.

**Do this:**

```bash
mkdir -p week5 && cd week5
uv init --name week5
uv add dbt-core dbt-duckdb
uv run dbt init taxi_dbt
# When prompted for a database, choose duckdb
cd taxi_dbt
```

Edit `~/.dbt/profiles.yml` (create the folder if needed: `mkdir -p ~/.dbt`):

```yaml
taxi_dbt:
  outputs:
    dev:
      type: duckdb
      path: /workspaces/couch-to-de/week5/taxi_dbt/taxi.duckdb
      threads: 4
  target: dev
```

(Adjust the path to wherever your repo lives — run `pwd` in your Codespace to check.)

Test:
```bash
uv run dbt debug
```

**Outcome:** All checks pass. You see "All checks passed!"

### Day 30 — Your first dbt model

**What is this?** A dbt **model** is a SQL `SELECT` statement saved as a `.sql` file. dbt wraps it in `CREATE TABLE AS` (or `CREATE VIEW AS`) and runs it. The magic comes from `ref()` — referencing other models so dbt builds them in the right order.

**Do this:** First, get the taxi data into the DuckDB file:

```bash
cd /workspaces/couch-to-de/week5/taxi_dbt
duckdb taxi.duckdb -c "CREATE TABLE raw_trips AS SELECT * FROM '/workspaces/couch-to-de/week2/data/taxi.parquet';"
```

Now delete the example models dbt created for you:
```bash
rm -rf models/example
```

Create `models/staging/stg_trips.sql`:
```sql
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
FROM raw_trips
WHERE total_amount > 0
  AND trip_distance > 0
```

Create `models/marts/fct_daily_revenue.sql`:
```sql
SELECT
  CAST(pickup_ts AS DATE) AS trip_date,
  COUNT(*) AS trip_count,
  SUM(total_amount) AS revenue,
  AVG(trip_distance) AS avg_distance
FROM {{ ref('stg_trips') }}
GROUP BY 1
ORDER BY 1
```

Run it: `uv run dbt run`.

**Outcome:** dbt builds both models, in the right order (stg first, then fct). It tells you "2 of 2 OK." Verify: `duckdb taxi.duckdb -c "SELECT * FROM main.fct_daily_revenue LIMIT 5;"`.

### Day 31 — Sources and staging models

**What is this?** Until now, your staging model referenced `raw_trips` directly by name. That's fragile. dbt **sources** declare your raw tables explicitly, so you can reference them via `source()` and dbt knows where they came from.

**Do this:** Create `models/staging/_sources.yml`:

```yaml
version: 2
sources:
  - name: raw
    database: taxi
    schema: main
    tables:
      - name: raw_trips
        description: "Raw NYC yellow taxi trips, January 2023"
```

Update `models/staging/stg_trips.sql` to use the source:
```sql
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
FROM {{ source('raw', 'raw_trips') }}
WHERE total_amount > 0
  AND trip_distance > 0
```

Run `uv run dbt run` again. Then run `uv run dbt source freshness` (it'll skip since we haven't configured freshness, but the command works).

**Outcome:** Same models build, but now their lineage explicitly traces back to a declared source.

### Day 32 — Tests

**What is this?** dbt tests are SQL queries that should return zero rows. If they return any rows, the test fails. The four built-in tests cover most needs: `not_null`, `unique`, `accepted_values`, `relationships`.

**Do this:** Create `models/staging/_models.yml`:

```yaml
version: 2
models:
  - name: stg_trips
    columns:
      - name: pickup_ts
        tests:
          - not_null
      - name: passenger_count
        tests:
          - not_null
          - accepted_values:
              values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
      - name: total_amount
        tests:
          - not_null

  - name: fct_daily_revenue
    columns:
      - name: trip_date
        tests:
          - not_null
          - unique
```

Run `uv run dbt test`.

**Outcome:** Some tests pass. The `accepted_values` test on `passenger_count` may fail if the raw data has weird values — that's the point. Tests catch real data issues. If it fails, decide: do you fix the data (filter in stg) or change the test? Both are valid responses; document your choice in `notes.md`.

### Day 33 — Documentation

**What is this?** dbt can auto-generate a documentation site showing every model, every column, descriptions, and a clickable lineage graph.

**Do this:** Add descriptions to `_models.yml`:

```yaml
version: 2
models:
  - name: stg_trips
    description: "Cleaned individual taxi trips, with invalid trips filtered out"
    columns:
      - name: pickup_ts
        description: "Timestamp the trip started"
        tests:
          - not_null
      # ... rest as before

  - name: fct_daily_revenue
    description: "Daily revenue and trip counts. One row per day."
    columns:
      - name: trip_date
        description: "Calendar date of the trips"
        tests:
          - not_null
          - unique
```

Generate the docs:
```bash
uv run dbt docs generate
uv run dbt docs serve
```

In the Codespace **Ports** tab, find port 8080 and open it in your browser.

**Outcome:** A documentation site with descriptions, columns, and a lineage graph. Click the lineage graph button (lower right) to see your DAG visually.

### Day 34 — Macros and Jinja

**What is this?** dbt files are Jinja-templated SQL. **Macros** are reusable functions written in Jinja. They let you DRY up repeated SQL patterns.

**Do this:** Create `macros/cents_to_dollars.sql`:

```sql
{% macro cents_to_dollars(column_name) %}
    ROUND(({{ column_name }} / 100.0)::NUMERIC, 2)
{% endmacro %}
```

This macro is silly for our taxi data (amounts are already in dollars), but as a stand-in: create a model that uses it. `models/marts/agg_revenue_in_pennies.sql`:

```sql
SELECT
  trip_date,
  {{ cents_to_dollars('revenue * 100') }} AS revenue_dollars
FROM {{ ref('fct_daily_revenue') }}
```

Run `uv run dbt run -s agg_revenue_in_pennies`. Then run `uv run dbt compile` and look in `target/compiled/taxi_dbt/models/marts/agg_revenue_in_pennies.sql` to see the rendered SQL.

**Outcome:** You see your macro expanded into actual SQL in the compiled output. Real dbt projects use macros for things like generating date spines, masking PII, or testing data freshness.

### Day 35 — Mini-project: Full dbt project

**What is this?** Build a proper layered dbt project: staging → intermediate → marts, all tested, all documented.

**Do this:** Restructure your project:

```
models/
├── staging/
│   ├── _sources.yml
│   ├── _models.yml
│   └── stg_trips.sql
├── intermediate/
│   ├── _models.yml
│   └── int_trips_enriched.sql
└── marts/
    ├── _models.yml
    ├── fct_daily_revenue.sql
    └── dim_pickup_locations.sql
```

The challenge:
1. `int_trips_enriched.sql` should add columns `trip_duration_minutes` (derived from pickup/dropoff timestamps) and `tip_pct` (tip / fare ratio).
2. `dim_pickup_locations.sql` should be one row per `pickup_location_id` with the count of trips originating there.
3. `fct_daily_revenue.sql` should now reference `int_trips_enriched` instead of `stg_trips`, and add a `total_tips` column.
4. Every model needs descriptions and at least 2 tests.

Run `uv run dbt build` (which runs `seed`, `run`, and `test` in order). Everything should pass.

**Outcome:** A real dbt project with three layers, tests, and docs. Commit it. This is the kind of structure a hiring manager wants to see in a portfolio.

---

## Week 6 — Orchestration with Airflow

A pipeline that runs once is a script. A pipeline that runs every day, retries on failure, and tells you when something breaks — that's data engineering. Airflow is the most widely used scheduler.

### Day 36 — Spin up Airflow with Docker Compose

**What is this?** Airflow is several services (scheduler, webserver, workers, metadata DB). Docker Compose runs them all together with one command.

**Do this:**

```bash
mkdir -p week6 && cd week6
curl -LfO 'https://airflow.apache.org/docs/apache-airflow/stable/docker-compose.yaml'

# Required setup
mkdir -p ./dags ./logs ./plugins ./config
echo "AIRFLOW_UID=$(id -u)" > .env

# Start it (this takes 3-5 minutes the first time)
docker compose up airflow-init
docker compose up -d
```

Wait until `docker compose ps` shows all services `(healthy)`. Then in the Codespace **Ports** tab, open port 8080. Log in with `airflow` / `airflow`.

**Outcome:** The Airflow UI loads. You see a list of example DAGs. Browse around — the UI is your friend.

### Day 37 — Airflow concepts

**What is this?** A **DAG** (Directed Acyclic Graph) is your pipeline. Each node is a **task**. The **scheduler** decides when DAGs run. The **executor** runs the tasks. The **webserver** is the UI. The **metadata database** stores everything else (run history, task states).

**Do this:** Read the [Airflow Core Concepts page](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/index.html) — just the overview, not every linked page. Then in the Airflow UI, click on the `example_bash_operator` DAG. Look at: the **Graph** view (the DAG structure), the **Code** view (the Python that defines it), and the **Runs** view (history).

**Outcome:** You can identify a DAG, a task, and a run when you see them. The vocabulary clicks.

### Day 38 — Your first DAG

**What is this?** A DAG is a Python file in the `dags/` folder. Today you write one.

**Do this:** Create `week6/dags/hello_dag.py`:

```python
from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator

with DAG(
    dag_id="hello_world",
    start_date=datetime(2026, 1, 1),
    schedule="@daily",
    catchup=False,
    tags=["learning"],
) as dag:
    say_hello = BashOperator(
        task_id="say_hello",
        bash_command="echo 'Hello from Airflow at $(date)'",
    )

    list_files = BashOperator(
        task_id="list_files",
        bash_command="ls -la /opt/airflow/dags/",
    )

    say_goodbye = BashOperator(
        task_id="say_goodbye",
        bash_command="echo 'Goodbye!'",
    )

    say_hello >> list_files >> say_goodbye
```

Wait 30 seconds for Airflow to pick it up. In the UI, find `hello_world`, toggle it on (the button at the left of the DAG row), then click ▶ → "Trigger DAG."

**Outcome:** The DAG runs. Click into it, view the Graph, click each task and see its logs. You should see the echo output and the file listing.

### Day 39 — PythonOperator and TaskFlow API

**What is this?** Bash is fine for simple stuff, but most real tasks are Python functions. The **TaskFlow API** uses decorators (`@task`) to make Python functions into tasks naturally.

**Do this:** Create `week6/dags/python_dag.py`:

```python
from datetime import datetime
from airflow.decorators import dag, task

@dag(
    dag_id="taskflow_demo",
    start_date=datetime(2026, 1, 1),
    schedule="@daily",
    catchup=False,
    tags=["learning"],
)
def taskflow_demo():
    @task
    def extract():
        return [1, 2, 3, 4, 5]

    @task
    def transform(numbers: list[int]) -> int:
        return sum(numbers)

    @task
    def load(total: int):
        print(f"Final total: {total}")

    load(transform(extract()))

taskflow_demo()
```

Trigger it from the UI. Watch how data flows from `extract` → `transform` → `load` automatically (this is XComs under the hood — see tomorrow).

**Outcome:** You see "Final total: 15" in the load task's logs. The decorator syntax is what most modern Airflow code looks like.

### Day 40 — XComs

**What is this?** **XComs** ("cross-communication") are how tasks pass small bits of data to each other. The TaskFlow API uses them automatically. They're stored in Airflow's metadata database, so don't push large objects through them — just IDs, paths, or small values.

**Do this:** In the UI, after running yesterday's `taskflow_demo`, click the `transform` task → **XCom** tab. You'll see the value `15` stored, with a key of `return_value`. That's the XCom.

Now create `dags/xcom_explicit.py` to make it explicit:

```python
from datetime import datetime
from airflow.decorators import dag, task

@dag(dag_id="xcom_explicit", start_date=datetime(2026, 1, 1), schedule=None, catchup=False)
def xcom_explicit():
    @task
    def get_filepath() -> str:
        # In a real pipeline, this might decide which file to process based on date
        return "/tmp/data_2026_05_05.csv"

    @task
    def process(filepath: str):
        print(f"Would process file: {filepath}")
        # The path is small (a string), so XCom is appropriate.
        # Don't return the file's contents through XCom.

    process(get_filepath())

xcom_explicit()
```

**Outcome:** You understand XComs are for small metadata, not for moving actual data. Actual data should land in object storage (MinIO / S3) and tasks should pass paths.

### Day 41 — Connections, Variables, and Hooks

**What is this?** **Connections** store credentials (database URLs, API keys) so they're not hardcoded in DAGs. **Variables** store config values. **Hooks** are Python wrappers that use a connection (e.g., `PostgresHook` to query Postgres).

**Do this:** In the Airflow UI, go to **Admin → Connections → +**. Create a connection:
- **Connection Id:** `postgres_local`
- **Connection Type:** Postgres
- **Host:** `host.docker.internal` (or your Codespace's hostname — try this first)
- **Schema:** `de_practice`
- **Login:** `me`
- **Password:** `me`
- **Port:** `5432`

Click **Test**. If it fails, you may need to start Postgres with `sudo service postgresql start && sudo -u postgres psql -c "ALTER SYSTEM SET listen_addresses = '*';" && sudo service postgresql restart` and edit `/etc/postgresql/*/main/pg_hba.conf` to allow connections from Docker.

(For Week 6 simplicity, you can also just install Postgres *inside* the airflow Docker network — but the connection-config experience is the lesson here regardless.)

**Outcome:** A working connection in Airflow. In a real project, every external system Airflow talks to has a connection.

### Day 42 — Mini-project: Orchestrate the full pipeline

**What is this?** Combine Week 3's ETL script and Week 5's dbt project into one Airflow DAG.

**Do this:** The clean way is to put your code in the `dags/` folder (or mount a separate `code/` folder). For simplicity, copy your Week 3 `etl.py` into `week6/dags/etl_helpers.py` (rename so Airflow doesn't try to parse it as a DAG).

Create `week6/dags/weather_pipeline.py`:

```python
from datetime import datetime
from airflow.decorators import dag, task
from airflow.operators.bash import BashOperator

@dag(
    dag_id="weather_pipeline",
    start_date=datetime(2026, 1, 1),
    schedule="@daily",
    catchup=False,
    tags=["capstone"],
)
def weather_pipeline():
    @task
    def extract_and_load():
        # Import your ETL function from etl_helpers.py
        from etl_helpers import run_etl  # you'll need to wrap your week 3 script in a function
        run_etl()

    run_dbt = BashOperator(
        task_id="run_dbt",
        bash_command="cd /workspaces/couch-to-de/week5/taxi_dbt && dbt build",
    )

    extract_and_load() >> run_dbt

weather_pipeline()
```

Trigger it. Both tasks should succeed.

**Outcome:** A scheduled pipeline that pulls fresh weather data into Postgres every day, then transforms and tests it with dbt. This is the actual shape of production data engineering.

---

## End of Part 2

You now have through Day 42 fully spec'd. Part 3 covers Weeks 7-9 (Spark, streaming/quality/capstone, GCP). When you reach Day 42, ask for "Part 3."
