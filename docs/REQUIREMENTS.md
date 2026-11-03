# Project requirements

Collected on 2 Nov 2026 from: Granola notes of the course sessions (9, 21, 22, 26, 27, 28, 29 Oct and 2 Nov), the Notion pages "Group project · Group 8 final deliverable" and "Oral defense", and the Drive folder `Data Engineering & Cloud Infrastructure/Oral defense`.

## Rules (latest update: 30 Oct)

| Requirement | What it means |
| --- | --- |
| Ownership | Every member owns a part of the pipeline and can answer questions on it |
| Sources | At least 3 (Postgres, MySQL, others). 5 or more for one use case is good |
| Ingestion | Several methods (batch, streaming…), written in code, no drag and drop. Each one is its own line in the Excalidraw diagram |
| Cloud | One provider only, nothing on-prem. Mixing clouds will be challenged |
| dbt | Mandatory, with tests and at least one seed |
| Use cases | 1 to 3, with the right tool for each |
| Documentation | dbt docs, Terraform, README, .gitignore, clean folders. Every tool, transformation and arrow of the architecture explained, plus a DAG |
| Incidents | Show live a corrupted row entering the pipeline and how the pipeline reacts |
| Demo | It must run live on the laptop: local Postgres → transformation → dashboard |
| Upload (4 Nov) | Slides, architecture diagram, Git link, ~30 s screen recording (not graded, needed for school audits) |

## Grading matrix (Drive: `Oral defense/Grading_matrix.png`)

| ID | Criterion | Points | Evidence expected |
| --- | --- | --- | --- |
| C1 | Convincing fictional company | 10 | Revenue model and customers (3); credible operations, size, stakeholders (3); problem and numerical constraints with explicit assumptions (4) |
| C2 | Use cases and business value | 10 | Decision and user identified (3); metric defined with grain, formula, exclusions (3); justified frequency and acceptance test (4) |
| C3 | Working end-to-end pipeline | 20 | Real ingestion from at least two sources (4); correct transformations and model (5); output checked against known data (5); documented launch, reproducible code, containerised job (6) |
| C4 | Tools fit the requirements | 10 | Justified ingestion, storage, transformation choices (4); a credible alternative and its trade-offs (3); no decorative components (3) |
| C5 | Real, controlled cloud use | 10 | A cloud storage/data service the pipeline goes through (3); processing run in the cloud, with proof (3); documented configuration and at least one resource in Terraform with protected state (4) |
| C6 | Reliability, quality, operations | 10 | Key, business-rule and freshness checks with a failure shown (3); replay without double counting (3); scheduling, logs, two incident scenarios, one tested (4) |
| C7 | Security and costs | 5 | Least-privilege access with an allowed and a denied check (1); protected secrets and sensitive data (1); prototype cost and projection (2); budget alert and cleanup procedure (1) |
| C8 | Slides and presentation | 5 | Clear storyline and architecture (2); claims backed by evidence, limitations stated (2); timing and coordination (1) |

## What the jury will push on

- Latency: do you really need real time, or is a daily batch enough?
- Scaling: what changes if the data grows 10x?
- Ownership: who owns each part, who troubleshoots it?
- Integrity: how do you know no row is lost or duplicated between steps?
- Security: masking at rest and in transit
- Cost: show compute usage and what it costs

## Found in the teacher's material on 2 Nov 2026 (second pass)

| Source | What it says | Impact on us |
| --- | --- | --- |
| Resource pack `Framework.pdf` step 02 | At least **5 real sources** (up to 15) | Conflicts with Notion's "at least 3": see D-021 |
| `Framework.pdf` step 03 | Mix batch, streaming or **direct API** ingestion; schema validation, error handling, structured landing storage | GCS landing zone, quarantine; an API source would add a method |
| `Framework.pdf` step 04 | Paid tiers give no extra credit; justify on architecture quality | Free tiers are fine |
| `Framework.pdf` step 06 | Run the pipeline live **while verifying governance, lineage and documentation**; at least 2 incidents | Show dbt docs lineage graph and `METADATA$FILENAME` during the demo |
| Slides 1.2, grading C5 | "Cloud-executed processing with run evidence" | dbt runs its SQL in Snowflake (cloud); keep query IDs / run IDs as proof |
| Slides 1.2, grading C7 | Allowed **and denied** access check; prototype cost **and a projection** with assumptions; documented budget alert | Show the analyst role denied on BRONZE; a cost slide |
| Slides 1.2, deliverables | Optional execution evidence: run IDs, dates, versions, checks, replay test, screenshots | Collect them in step 12 |
| Slides 3 (cloud project) | "A budget alert is the first thing to create" | Build plan step 2 comes before anything that costs money |
| Slides 4.2 | Orchestration can use Snowflake Tasks instead of an external tool | Chosen: Snowflake Tasks, no Airflow (D-022): one tool less to run, secure and pay for |
| Notion task "Snowflake resource monitor" | Last year students burned their free credits before the defense | Same as step 2 |
