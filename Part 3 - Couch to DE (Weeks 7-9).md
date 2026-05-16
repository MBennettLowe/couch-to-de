# Couch to Data Engineering — Part 3 (Weeks 7-9)

The final stretch. Spark for big data, streaming and quality and capstone, then cloud deployment on GCP.

---

## Week 7 — Distributed Processing with Spark

When data outgrows a single machine, you need a distributed engine. Apache Spark is the most widely used. Even though we'll run it on one machine, the concepts transfer to a cluster of hundreds.

### Day 43 — Why distributed processing?

**What is this?** When a dataset is too big to fit in one machine's memory, you split it across many machines. Each machine processes its piece in parallel; the results are combined. This introduces concepts you don't have on one machine: **partitioning** (how data is split), **shuffles** (when data has to move between machines, e.g., for a join), and **driver/executor model** (one coordinator, many workers).

**Do this:** Read [this short overview](https://spark.apache.org/docs/latest/cluster-overview.html) (15 min). In `week7/notes.md`, answer: if you have a dataset partitioned by `customer_id` across 10 machines and you `GROUP BY customer_id`, why is that fast? What about `GROUP BY country_code` instead — what has to happen?

**Outcome:** Your answer should mention that the first case can aggregate locally on each machine without moving data. The second case requires a *shuffle* — all rows with the same country_code have to end up on the same machine before they can be grouped. Shuffles are expensive. This concept matters in every distributed system.

### Day 44 — Install PySpark

**What is this?** PySpark is the Python API for Spark. Installed locally, it runs in "local mode" — using your machine's cores as if they were a tiny cluster. The code you write is identical to what you'd run on a 1000-node cluster.

**Do this:** First make sure you have Java (Spark needs it):
```bash
sudo apt install -y default-jdk
java -version
```

Then in `week7/`:
```bash
mkdir -p week7 && cd week7
uv init --name week7
uv add pyspark
```

Verify with `week7/hello_spark.py`:
```python
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("hello").getOrCreate()
df = spark.range(0, 1_000_000)
print(f"Count: {df.count():,}")
print(f"Sum: {df.agg({'id': 'sum'}).collect()[0][0]:,}")
spark.stop()
```

Run with `uv run python hello_spark.py`. Ignore the stack of warnings that prints — that's normal for local Spark.

**Outcome:** You see `Count: 1,000,000` and `Sum: 499,999,500,000`. PySpark works.

### Day 45 — Spark DataFrames

**What is this?** Spark DataFrames look like pandas/Polars DataFrames but operate distributed. Same kinds of operations: read, filter, group, write.

**Do this:** Create `week7/spark_basics.py`:

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = (
    SparkSession.builder
    .appName("taxi_basics")
    .config("spark.sql.shuffle.partitions", "8")  # default is 200, way too many for local
    .getOrCreate()
)

df = spark.read.parquet("/workspaces/couch-to-de/week2/data/taxi.parquet")

print(f"Rows: {df.count():,}")
df.printSchema()

# Filter and aggregate
result = (
    df
    .filter(F.col("trip_distance") > 5)
    .groupBy("passenger_count")
    .agg(
        F.count("*").alias("trips"),
        F.avg("fare_amount").alias("avg_fare"),
    )
    .orderBy("passenger_count")
)

result.show()
spark.stop()
```

Run it. Compare to your Polars version from Day 17 — same result, more overhead, but it would scale to terabytes.

**Outcome:** Same results as Polars, but you've now used the API that runs on real clusters.

### Day 46 — Spark SQL

**What is this?** You can register a Spark DataFrame as a "temp view" and query it with SQL instead of the DataFrame API. Most teams write Spark SQL because it's familiar.

**Do this:** Create `week7/spark_sql.py`:

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("spark_sql").getOrCreate()

df = spark.read.parquet("/workspaces/couch-to-de/week2/data/taxi.parquet")
df.createOrReplaceTempView("trips")

result = spark.sql("""
    SELECT
        passenger_count,
        COUNT(*) AS trips,
        ROUND(AVG(fare_amount), 2) AS avg_fare,
        ROUND(AVG(tip_amount), 2) AS avg_tip
    FROM trips
    WHERE trip_distance > 5
    GROUP BY passenger_count
    ORDER BY passenger_count
""")

result.show()
spark.stop()
```

**Outcome:** Same results, written in SQL. Most production Spark code looks like this.

### Day 47 — The Spark UI

**What is this?** Spark has a web UI that shows what's actually happening: jobs, stages, tasks, shuffles, memory usage. Reading the Spark UI is half the job of debugging Spark jobs.

**Do this:** Create `week7/long_job.py`:

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
import time

spark = (
    SparkSession.builder
    .appName("long_job")
    .config("spark.ui.port", "4040")
    .getOrCreate()
)

df = spark.read.parquet("/workspaces/couch-to-de/week2/data/taxi.parquet")

# Force some shuffles by joining the dataset to itself
result = (
    df.alias("a")
    .join(df.alias("b"), F.col("a.PULocationID") == F.col("b.DOLocationID"))
    .groupBy(F.col("a.PULocationID"))
    .count()
)

print("Press Ctrl+C when you're done exploring the UI...")
print(f"Result: {result.count()}")
time.sleep(120)  # keep UI alive
spark.stop()
```

Run it. While it's running, open port 4040 from the Codespace **Ports** tab. Click on the running job, then a stage. Look at: **Tasks** (how many ran in parallel), **Shuffle Read/Write** (how much data moved), **Event Timeline**.

**Outcome:** You can navigate the Spark UI. You don't need to master it — just be able to find why a stage is slow when something breaks.

### Day 48 — Partitioning, broadcast joins, skew

**What is this?** Three concepts that come up constantly. **Partitioning** = how data is split (good partitioning makes queries fast). **Broadcast join** = when one side of a join is small, send a copy to every machine instead of shuffling the big side. **Skew** = when one partition has way more data than others, slowing the whole job (e.g., 90% of rows belong to one customer).

**Do this:** No coding today. Read [this article on Spark joins](https://www.databricks.com/blog/2020/05/29/adaptive-query-execution-speeding-up-spark-sql-at-runtime.html). In `week7/notes.md`, answer:
1. If you join a 1 TB fact table to a 50 MB dimension table, which side should be broadcast?
2. If 80% of your `orders` rows are from customer #1 and you `GROUP BY customer_id`, what's likely to happen and how would you fix it?

**Outcome:** Answers: (1) the 50 MB side; (2) one task gets 80% of the work and the rest finish quickly — fixes include "salting" the key (adding a random suffix) or filtering hot keys out and processing them separately.

### Day 49 — Mini-project: Process NYC Taxi at scale

**What is this?** Process multiple months of taxi data, write the result as partitioned Parquet.

**Do this:** Download three months:
```bash
cd /workspaces/couch-to-de/week2/data
for month in 02 03 04; do
  curl -L "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2023-${month}.parquet" -o "taxi_2023_${month}.parquet"
done
```

Create `week7/process_taxi.py`:

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = (
    SparkSession.builder
    .appName("taxi_processing")
    .config("spark.sql.shuffle.partitions", "8")
    .getOrCreate()
)

# Read all four months at once via glob
df = spark.read.parquet("/workspaces/couch-to-de/week2/data/taxi*.parquet")
print(f"Total rows: {df.count():,}")

# Clean and enrich
clean = (
    df
    .filter(F.col("total_amount") > 0)
    .filter(F.col("trip_distance") > 0)
    .withColumn("trip_date", F.to_date("tpep_pickup_datetime"))
    .withColumn("trip_month", F.date_format("trip_date", "yyyy-MM"))
    .withColumn("duration_min", (F.unix_timestamp("tpep_dropoff_datetime") - F.unix_timestamp("tpep_pickup_datetime")) / 60)
)

# Write partitioned by month
(
    clean
    .write
    .mode("overwrite")
    .partitionBy("trip_month")
    .parquet("/workspaces/couch-to-de/week7/output/clean_trips/")
)

# Sanity check: aggregations from the partitioned output
agg = (
    spark.read.parquet("/workspaces/couch-to-de/week7/output/clean_trips/")
    .groupBy("trip_month")
    .agg(
        F.count("*").alias("trips"),
        F.round(F.avg("duration_min"), 2).alias("avg_duration"),
        F.round(F.sum("total_amount"), 2).alias("total_revenue"),
    )
    .orderBy("trip_month")
)
agg.show()

spark.stop()
```

Run it. Watch the Spark UI as it runs.

**Outcome:** A `clean_trips/` folder organized by month (`trip_month=2023-01/`, `trip_month=2023-02/`, etc.). The aggregation prints monthly summaries. You've now done batch processing the way real DE jobs do.

---

## Week 8 — Streaming, Data Quality, and the Capstone

The last week before cloud. Streaming, quality testing, and pulling everything together into a portfolio piece.

### Day 50 — Batch vs streaming

**What is this?** **Batch** = process data in chunks (every hour, every day) on a schedule. **Streaming** = process each event as it arrives, latency in seconds or less. Streaming is more complex and more expensive. Most jobs that *feel* like they need streaming actually work fine as 5-minute batches.

**Do this:** Read [this Confluent piece on when streaming is appropriate](https://www.confluent.io/learn/batch-vs-real-time-data-processing/). In `week8/notes.md`, write down two examples of jobs that genuinely need streaming, and two that *seem* to but don't.

**Outcome:** Examples of "needs streaming": fraud detection, real-time bidding. Examples of "doesn't really need streaming": daily revenue dashboards, weekly cohort analysis. The bias should be toward batch unless you have a strong reason.

### Day 51 — Spin up Redpanda (Kafka, but lighter)

**What is this?** **Apache Kafka** is the dominant streaming platform. **Redpanda** is API-compatible with Kafka but written in C++ — much lighter on resources, perfect for Codespaces. Code that talks to Redpanda will work unchanged against real Kafka.

**Do this:** Create `week8/docker-compose.yml`:

```yaml
services:
  redpanda:
    image: redpandadata/redpanda:latest
    command:
      - redpanda
      - start
      - --smp=1
      - --memory=1G
      - --reserve-memory=0M
      - --overprovisioned
      - --node-id=0
      - --kafka-addr=PLAINTEXT://0.0.0.0:9092
      - --advertise-kafka-addr=PLAINTEXT://localhost:9092
    ports:
      - "9092:9092"
```

Start it: `cd week8 && docker compose up -d`. Check it's running: `docker compose ps`.

Create a topic and send a message:
```bash
docker exec -it $(docker compose ps -q redpanda) rpk topic create taxi_trips
docker exec -it $(docker compose ps -q redpanda) rpk topic produce taxi_trips
# type a message and press Enter, then Ctrl+D
```

**Outcome:** A running Redpanda broker with a `taxi_trips` topic that has at least one message in it.

### Day 52 — Producers and consumers in Python

**What is this?** Code that writes to a topic is a **producer**. Code that reads is a **consumer**. They're decoupled — the producer doesn't know who's reading.

**Do this:** Install: `uv add kafka-python`. Create `week8/producer.py`:

```python
from kafka import KafkaProducer
import json
import time
import random

producer = KafkaProducer(
    bootstrap_servers="localhost:9092",
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
)

for i in range(100):
    msg = {
        "trip_id": i,
        "fare": round(random.uniform(5, 50), 2),
        "passenger_count": random.choice([1, 1, 1, 2, 3, 4]),
    }
    producer.send("taxi_trips", value=msg)
    print(f"Sent: {msg}")
    time.sleep(0.5)

producer.flush()
print("Done.")
```

In a separate terminal, create `week8/consumer.py`:

```python
from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    "taxi_trips",
    bootstrap_servers="localhost:9092",
    auto_offset_reset="earliest",
    value_deserializer=lambda m: json.loads(m.decode("utf-8")),
    group_id="my_consumer_group",
)

print("Listening...")
for message in consumer:
    print(f"Got: {message.value}")
```

Run the consumer first, then the producer in the other terminal. Watch messages flow.

**Outcome:** Real-time messaging working end-to-end. You've now done the basic streaming pattern.

### Day 53 — Topics, partitions, consumer groups, offsets

**What is this?** A **topic** is split into **partitions** for parallelism. Each message in a partition has an **offset** (a number). A **consumer group** is a set of consumers that share work — each partition is read by exactly one consumer in the group. This is how Kafka scales.

**Do this:** Recreate the topic with multiple partitions:
```bash
docker exec -it $(docker compose ps -q redpanda) rpk topic delete taxi_trips
docker exec -it $(docker compose ps -q redpanda) rpk topic create taxi_trips --partitions 3
```

Re-run the producer. Then run *two* consumers (in two terminals) using the same `group_id`. You should see each consumer get a subset of the messages — they're sharing the work.

Now run a *third* consumer with a *different* `group_id`. It gets *all* messages — different groups read independently.

**Outcome:** You see partitions and consumer groups in action. Draw the picture in `notes.md`: 3 partitions, 2 consumers in group A (each reading 1-2 partitions), 1 consumer in group B (reading all 3).

### Day 54 — Kafka Connect and Debezium (CDC) — read only

**What is this?** **Kafka Connect** is a framework for plugging databases into Kafka without writing code. **Debezium** is a Kafka Connect plugin that reads database transaction logs and emits each insert/update/delete as a Kafka message — this is **Change Data Capture (CDC)**. It's how modern pipelines stream changes from Postgres into a data lake.

**Do this:** No coding today. Read [this Debezium intro](https://debezium.io/documentation/reference/stable/architecture.html). In `notes.md`, answer: why is CDC fundamentally better than running `SELECT * FROM orders WHERE updated_at > <last_run>` every 5 minutes?

**Outcome:** Your answer should mention: CDC catches deletes (the `updated_at` query won't), it gets every intermediate state (not just the latest), and it doesn't put query load on the source database.

### Day 55 — Data quality with Great Expectations or Soda Core

**What is this?** dbt tests are simple (not_null, unique, etc.). Real data quality needs more: distribution checks ("revenue today should be within 30% of the 7-day average"), schema drift, freshness. **Great Expectations** and **Soda Core** are the open source tools for this. Today you'll add Soda checks to your dbt project.

**Do this:** Install: `uv add soda-core soda-core-duckdb`. Create `week8/soda/checks_taxi.yml`:

```yaml
checks for fct_daily_revenue:
  - row_count > 0
  - missing_count(trip_date) = 0
  - duplicate_count(trip_date) = 0
  - avg(revenue) between 1000 and 1000000

checks for stg_trips:
  - row_count > 100000
  - missing_percent(passenger_count) < 1
  - min(fare_amount) >= 0
```

Create `week8/soda/configuration.yml`:

```yaml
data_source taxi:
  type: duckdb
  path: /workspaces/couch-to-de/week5/taxi_dbt/taxi.duckdb
```

Run: `uv run soda scan -d taxi -c week8/soda/configuration.yml week8/soda/checks_taxi.yml`.

**Outcome:** A scan report showing each check pass/fail. This catches data drift that dbt's basic tests miss.

### Day 56 — Observability: lineage, freshness, OpenLineage

**What is this?** **Lineage** = tracking what data flows where (table A is built from tables B and C). **Freshness** = how recently was this data updated. **OpenLineage** is an open standard for emitting lineage events; **Marquez** is an open source backend that displays them.

**Do this:** No installation today (Marquez is a beast). Just read [the OpenLineage overview](https://openlineage.io/docs/) and look at [the Marquez demo screenshots](https://marquezproject.ai/). In `notes.md`, answer: what's the difference between dbt's lineage graph (you saw on Day 33) and OpenLineage?

**Outcome:** Your answer should note: dbt only knows about dbt models. OpenLineage spans the whole stack — you can see "this dbt model depends on a table in Postgres which depends on a Kafka topic which depends on an upstream API." Cross-tool lineage is what makes incidents debuggable in real environments.

### Day 57 — Capstone scoping

**What is this?** Today you plan, not build. Production-grade pipelines start with a scoping document.

**Do this:** Create `capstone/README.md` with these sections, fill out each:

```markdown
# NYC Taxi Pipeline — Capstone

## Goal
One paragraph: what does this pipeline produce, and who is the (imaginary) consumer?

## Architecture
Diagram (use ASCII or mermaid): API → Lake (MinIO) → Warehouse (DuckDB) → Marts → BI

## Sources
List each data source: NYC Taxi Parquet (TLC website), weather data (Open-Meteo).

## Models
List each dbt model and its purpose:
- stg_trips: cleaned trip events
- stg_weather: cleaned hourly weather
- int_trips_with_weather: joined intermediate
- fct_daily_revenue: revenue per day
- fct_weather_impact: trip count + tip rate per weather condition

## Tests
Critical assertions: trip_date is unique in fct_daily_revenue, no negative revenue, etc.

## Schedule
Daily at 6am UTC.

## SLAs
"Daily revenue mart available by 8am UTC. Alert if not."

## Open questions
What you still haven't decided.
```

**Outcome:** A clear plan you can build against. Real engineers spend at least a day per project on this — bad scoping kills more pipelines than bad code does.

### Days 58-59 — Capstone build, parts 1 and 2

**What is this?** Two days to actually build it.

**Day 58 — Ingestion and storage:**
1. Write a Python script that downloads the latest taxi parquet to MinIO under `lake/raw/taxi/{year}/{month}.parquet`.
2. Write a second script that pulls the previous day's weather from Open-Meteo for NYC and writes it to MinIO under `lake/raw/weather/{year}/{month}/{day}.json`.
3. Both scripts should be idempotent (running them twice on the same data produces the same result).

**Day 59 — Transforms, tests, orchestration:**
1. Configure dbt-duckdb to read directly from MinIO (DuckDB's `httpfs` extension).
2. Build the staging, intermediate, and marts models from your Day 57 plan.
3. Add Soda checks for the marts.
4. Wire it all into an Airflow DAG: ingest → dbt build → soda scan.
5. Trigger it. Make sure everything passes.

**Outcome:** A working end-to-end pipeline. Don't move to Day 60 until everything green-passes.

### Day 60 — Capstone polish

**What is this?** A capstone that isn't documented isn't a portfolio piece.

**Do this:**
1. Update `README.md` with: what it does, how to run it, the architecture diagram, screenshot of the Airflow DAG and the dbt lineage graph.
2. Add a `requirements.md` listing every tool used and why.
3. Add a `decisions.md` explaining the choices you made: why DuckDB over Postgres for the warehouse, why dbt over hand-written SQL, why Airflow over cron, etc. ("Decision logs" are gold for interviews — they show you think.)
4. Push everything to a fresh GitHub repo with a good README.
5. Pin the repo to your GitHub profile.

**Outcome:** A clean, documented, runnable repo on GitHub. This is the artifact you'll show in interviews. Spend extra time on the README — recruiters skim, hiring managers read.

---

## Week 9 — GCP and BigQuery

The cloud week. You'll re-deploy the capstone on Google Cloud using BigQuery as the warehouse. GCP gives new accounts $300 in free credits over 90 days. BigQuery has a generous always-free tier (1 TB queries + 10 GB storage per month). You won't burn through this if you're careful.

### Day 61 — GCP account, gcloud CLI, billing alert

**What is this?** Set up the cloud account properly before doing anything else. The billing alert is non-negotiable — every horror story about a $40k cloud bill starts with not setting one.

**Do this:**
1. Go to [console.cloud.google.com](https://console.cloud.google.com), sign in, accept the free tier.
2. Create a new project: name it `couch-to-de`. Note the project ID (it'll have a suffix like `couch-to-de-123456`).
3. **Set a billing alert:** Billing → Budgets & alerts → Create Budget. Set it to $5/month with alerts at 50%, 90%, and 100%. Also set it to disable billing if it hits 100% (this is a kill switch).
4. Install gcloud in your Codespace:
   ```bash
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   gcloud init
   gcloud auth application-default login
   ```
   Follow the URL, log in, paste the code back.
5. Set your project: `gcloud config set project YOUR_PROJECT_ID`.

**Outcome:** `gcloud config list` shows your project. The billing alert exists. Take a screenshot of the alert and put it in `week9/notes.md`.

### Day 62 — BigQuery basics with public datasets

**What is this?** **BigQuery** is GCP's serverless analytical warehouse. You don't manage servers; you just run SQL. It charges per byte scanned (unless on the free tier or reserved capacity). Always look at the cost preview before running queries.

**Do this:** In the [BigQuery console](https://console.cloud.google.com/bigquery), open the Query Editor and run:

```sql
SELECT
  language.name AS language,
  COUNT(*) AS repos
FROM `bigquery-public-data.github_repos.languages`,
UNNEST(language) AS language
GROUP BY language
ORDER BY repos DESC
LIMIT 20;
```

Before clicking Run, look at the top right — it shows estimated bytes processed (probably 30-50 MB). That's your cost preview.

Now from the command line:
```bash
bq query --use_legacy_sql=false 'SELECT COUNT(*) FROM `bigquery-public-data.usa_names.usa_1910_current`'
```

**Outcome:** Query results from the BigQuery console and the CLI. You're now using a real cloud warehouse.

### Day 63 — BigQuery vs Postgres

**What is this?** BigQuery and Postgres look similar from the SQL surface but are wildly different underneath. BigQuery has **partitioning** (table physically split by date) and **clustering** (sorted within partition). It has *no indexes* — it scans columnar data fast enough that indexes aren't needed. It's billed by data scanned, so partitioning saves money directly.

**Do this:** In the BigQuery console, run these two queries on the same public dataset and compare the bytes processed shown in the cost preview:

```sql
-- Query 1: scan everything
SELECT COUNT(*)
FROM `bigquery-public-data.wikipedia.pageviews_2024`
WHERE DATE(datehour) = "2024-01-15";

-- Query 2: scan one partition (the table is partitioned by datehour)
SELECT COUNT(*)
FROM `bigquery-public-data.wikipedia.pageviews_2024`
WHERE datehour BETWEEN "2024-01-15 00:00:00" AND "2024-01-15 23:59:59";
```

The second query should scan vastly less data. **Don't run both** — just look at the cost preview.

**Outcome:** You understand that on partitioned tables, filtering by the partition column is free, and filtering by anything else costs you a full scan. This is the #1 BigQuery cost-control rule.

### Day 64 — Cloud Storage and external tables

**What is this?** **Google Cloud Storage (GCS)** is the GCP equivalent of S3 / MinIO. **External tables** in BigQuery let you query files in GCS without ingesting them — the same pattern you used with DuckDB+MinIO on Day 26.

**Do this:** Create a bucket and upload your taxi parquet:
```bash
gsutil mb -l us-central1 gs://couch-to-de-$YOUR_PROJECT_ID-lake/
gsutil cp /workspaces/couch-to-de/week2/data/taxi.parquet gs://couch-to-de-$YOUR_PROJECT_ID-lake/raw/taxi/2023-01.parquet
```

Create a dataset in BigQuery:
```bash
bq mk --location=us-central1 raw
```

Create the external table from the BigQuery console (Query Editor):
```sql
CREATE OR REPLACE EXTERNAL TABLE `YOUR_PROJECT_ID.raw.taxi_external`
OPTIONS (
  format = 'PARQUET',
  uris = ['gs://couch-to-de-YOUR_PROJECT_ID-lake/raw/taxi/*.parquet']
);

-- Query it
SELECT COUNT(*) FROM `YOUR_PROJECT_ID.raw.taxi_external`;
```

**Outcome:** You queried Parquet files in object storage from BigQuery, no ingestion. This is the modern lakehouse pattern.

### Day 65 — Re-point dbt to BigQuery

**What is this?** This is where dbt's cross-warehouse design pays off. You'll re-run your dbt project against BigQuery with minimal code changes — just a profile swap.

**Do this:** Install: `uv add dbt-bigquery`. Add a new profile to `~/.dbt/profiles.yml`:

```yaml
taxi_dbt:
  outputs:
    dev:
      type: duckdb
      path: /workspaces/couch-to-de/week5/taxi_dbt/taxi.duckdb
      threads: 4
    prod:
      type: bigquery
      method: oauth
      project: YOUR_PROJECT_ID
      dataset: dbt_dev
      threads: 4
      location: us-central1
  target: dev
```

Update your sources file (`models/staging/_sources.yml`) so it points at the BigQuery external table when running against `prod`. The simplest approach: just edit the `database` and `schema` to match your BQ project/dataset.

Run against BigQuery:
```bash
cd week5/taxi_dbt
dbt run --target prod
```

**Outcome:** The same dbt project, same models, now built in BigQuery. The portability is the win.

### Day 66 — Cloud Run Jobs and Cloud Scheduler

**What is this?** GCP's managed Airflow (Cloud Composer) is overkill and expensive (~$300/month minimum). For most pipelines, **Cloud Run Jobs** (containerized scripts that run to completion) triggered by **Cloud Scheduler** (cron in the cloud) is dramatically cheaper and simpler.

**Do this:** Create `week9/cloud_run/Dockerfile`:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
RUN pip install dbt-bigquery
COPY taxi_dbt/ ./taxi_dbt/
WORKDIR /app/taxi_dbt
CMD ["dbt", "build", "--target", "prod"]
```

Build and deploy:
```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
gcloud artifacts repositories create dbt-jobs --repository-format=docker --location=us-central1
docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT_ID/dbt-jobs/taxi-dbt:latest .
docker push us-central1-docker.pkg.dev/YOUR_PROJECT_ID/dbt-jobs/taxi-dbt:latest

gcloud run jobs create taxi-dbt \
  --image=us-central1-docker.pkg.dev/YOUR_PROJECT_ID/dbt-jobs/taxi-dbt:latest \
  --region=us-central1 \
  --task-timeout=10m
```

Schedule it:
```bash
gcloud scheduler jobs create http taxi-dbt-daily \
  --location=us-central1 \
  --schedule="0 6 * * *" \
  --uri="https://us-central1-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/YOUR_PROJECT_ID/jobs/taxi-dbt:run" \
  --http-method=POST \
  --oauth-service-account-email=YOUR_SA_EMAIL
```

(You may need to set up a service account first; the gcloud error messages will guide you.)

**Outcome:** A scheduled cloud-native job. Trigger it manually once: `gcloud run jobs execute taxi-dbt --region=us-central1`. Watch it succeed.

### Day 67 — Capstone on GCP

**What is this?** Final day. Re-deploy the Week 8 capstone on GCP and update your README so the project tells both stories: open-source-local and cloud-native.

**Do this:**
1. Adapt the ingestion scripts (Day 58) to write to GCS instead of MinIO.
2. Adapt the dbt project (Day 59) to read from BigQuery external tables.
3. Wrap each step (ingestion, dbt) as Cloud Run Jobs.
4. Use Cloud Scheduler to run them in sequence (or use a tiny Python orchestrator script as a third Cloud Run Job — Cloud Workflows is the alternative for this).
5. Update the capstone `README.md` with a new section: **"Cloud architecture (GCP)"** showing the same pipeline rebuilt with GCS, BigQuery, and Cloud Run.
6. **Tear down everything** when you're done verifying it works:
   ```bash
   gcloud run jobs delete taxi-dbt --region=us-central1
   gcloud scheduler jobs delete taxi-dbt-daily --location=us-central1
   gsutil -m rm -r gs://couch-to-de-YOUR_PROJECT_ID-lake/
   bq rm -r -f raw
   bq rm -r -f dbt_dev
   ```
   Resources you forget about become bills.

**Outcome:** A portfolio repo demonstrating the same pipeline two ways: open source + cloud. You've finished the program. You're a data engineer.

---

## After Day 67

Pick a direction:

- **Real-time / streaming**: Kafka in depth, then Apache Flink or Materialize
- **Lakehouse stack**: Iceberg + Trino + Spark in serious depth
- **dbt-first analytics engineering**: dbt at scale, semantic layers, dbt-cloud
- **ML platform engineering**: feature stores, training pipelines, model serving

Each is its own multi-month rabbit hole. You now have the foundation to navigate any of them.

## Books worth owning

- *The Data Warehouse Toolkit* by Kimball — the dimensional modeling bible
- *Designing Data-Intensive Applications* by Kleppmann — the systems-thinking book that separates DEs from script-runners
- *Fundamentals of Data Engineering* by Reis & Housley — the closest thing the field has to a current textbook
