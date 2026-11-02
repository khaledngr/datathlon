# Decision log

One entry per decision. Status: **Decided**, **Proposed** (waiting for the group), **Superseded** (replaced by a later decision, kept for history).
Newest decisions at the bottom.

---

### D-001 · Project scope and constraints
- **Date:** 2026-11-02 · **Status:** Decided (set by the course)
- **What:** invent a company and build its data pipeline, presented to Laura as CDO. Upload on 4 Nov, defense on 6 Nov at 11:30. Rules and grading in [REQUIREMENTS.md](REQUIREMENTS.md).
- **Source:** Notion "Group 8 final deliverable", Granola course notes, Drive `Oral defense/Grading_matrix.png`.

### D-002 · Team
- **Date:** 2026-11-02 · **Status:** Decided
- **What:** Group 8 = Khaled Elnagar, Robin (rcacarie@albertschool.com), Rudy (rcausel@albertschool.com).

### D-003 · New project folder, separate from the TD repo
- **Date:** 2026-11-02 · **Status:** Decided
- **What:** the project lives in its own folder `datathlon/` (and its own Git repo later), not in the `redgrave-platform` TD repo.
- **Why:** the TD repo is individual lab work about a football club; the project is a group deliverable about a different company.
- **Note:** see D-011: we still reuse TD *code*, adapted.

### D-004 · Industry: sports retail
- **Date:** 2026-11-02 · **Status:** Decided
- **What:** an omnichannel sports retailer (stores + website, own brands), in the style of Decathlon.
- **Why:** strong data problems to show: seasonal demand, stockouts, promotions spikes (Black Friday), store vs online view. Easy for the jury to picture.
- **Rejected:** none discussed.

### D-005 · Company name: Datathlon
- **Date:** 2026-11-02 · **Status:** Decided
- **What:** "Datathlon", a deliberate parody of Decathlon: three syllables, "-athlon" ending, with the buzzword "data".
- **Alternatives shown:** Cloudathlon, Pipathlon, Bytathlon, Promptathlon, Tokathlon. Earlier non-parody ideas (Stridea, Sportéa, Altimo…) were dropped because the group wanted the joke.
- **Note:** the company stays fictional; we do not use Decathlon's name, logo or trademarks.

### D-006 · Brand: colors, fonts, logo "Speed D"
- **Date:** 2026-11-02 · **Status:** Decided
- **What:** colors Track Blue `#3946C0`, Night Pitch `#101A4E`, Sprint Mint `#8EF5B5`, Warm-up `#E8ECFF`. Fonts Barlow Condensed (titles, logo) and Inter (text). Logo: white bold italic "DATATHLON" on a blue block, with a sprinting "D" and three speed streaks (the middle one mint).
- **Why:** echoes Decathlon's blue-and-white look so the parody reads instantly, with our own symbol.
- **Alternatives shown:** a first "orbit ring" logo (rejected by the group as weak), then six concepts: Podium chart, Track lanes, Speed D, Pixel ball, Peak sparkline, Stopwatch database, plus a wordmark only. Group chose Speed D.
- **Files:** [brand/](../brand/), also in Drive `Data Engineering & Cloud Infrastructure/Datathlon · Group 8 project/Brand`.

### D-007 · Cloud provider: GCP
- **Date:** 2026-11-02 · **Status:** Decided again by D-026 (after a short switch to AWS, D-025)
- **What:** Google Cloud is our single cloud provider.
- **Why:** the team already works on GCP and the school gives access with credits.
- **Rejected:** Snowflake on AWS (my first proposal): the team prefers the cloud it knows.
- **Consequence:** Snowflake (D-008) must be an account hosted on a **GCP region**, otherwise the jury sees two clouds. To check: region of the TD account (see TD_INVENTORY.md "Open check").

### D-008 · Core stack = the TD stack
- **Date:** 2026-11-02 · **Status:** Decided (principle), tools per use case still Proposed
- **What:** we start from the tools used in the TDs: Postgres → Snowflake (batch + incremental), dbt Core, Python feed simulator, Docker, Airflow, Terraform, GitHub Actions. Airflow only if the use cases need orchestration beyond what Snowflake/dbt can do.
- **Why:** the team understands these and has already made them work; ownership is graded (every member must answer questions on their part).
- **Superseded proposal:** a "trendy" stack (Iceberg, Redpanda, Streamlit in Snowflake, Cortex, DuckDB). Parked: we only add a tool from it if a use case needs it, and we write the reason here.

### D-009 · Use cases before tools
- **Date:** 2026-11-02 · **Status:** Decided
- **What:** we fix the use cases first ([USE_CASES.md](USE_CASES.md)), then pick the tool for each. The stack will evolve.
- **Why:** the grading asks for tools that fit the requirements and no decorative components (C4); Laura said "the business case drives the data, never the other way around" (26 Oct session).

### D-010 · Document every choice and action
- **Date:** 2026-11-02 · **Status:** Decided
- **What:** decisions go in this file, actions in [JOURNAL.md](JOURNAL.md), written at the moment they happen.
- **Why:** documentation is graded (README, dbt docs, every tool and arrow explained) and every member must be able to explain every part.

### D-011 · Reuse and adapt TD code
- **Date:** 2026-11-02 · **Status:** Decided
- **What:** we copy the TD files listed in [TD_INVENTORY.md](TD_INVENTORY.md) into `datathlon/` and adapt them (Redgrave → Datathlon, football merch → sports retail). The journal records the source file of each copy.
- **Why:** faster than writing from scratch, and the team already understands this code.

### D-012 · Shared workspace in Google Drive
- **Date:** 2026-11-02 · **Status:** Decided
- **What:** the group folder is `Data Engineering & Cloud Infrastructure/Datathlon · Group 8 project` in Khaled's school Drive. Khaled shares it with Robin and Rudy himself.
- **Why:** one place for slides, diagram and video before the 4 Nov upload.

### D-013 · Use cases: UC1 + UC3
- **Date:** 2026-11-02 · **Status:** Decided (group vote)
- **What:** we keep **UC1 · Daily omnichannel sales and revenue** and **UC3 · Stock cover alert**. Details in [USE_CASES.md](USE_CASES.md).
- **Rejected:** UC2 · Live store-till sales with quality control, as a use case of its own. Claude had recommended UC1 + UC2 because UC2 was almost all TD code; the group preferred UC3's business value (stockouts are a real pain point: ~4 % of sales lost).
- **Consequence:** UC2 carried three things the rules require: the live corrupted-row demo, the micro-batch ingestion method and the till feed source. Without it, we must cover the incident demo another way: see D-014.

### D-014 · Where the live incident demo comes from: option A
- **Date:** 2026-11-02 · **Status:** Decided (group chose option A)
- **Problem:** the rules require a live demo where a corrupted row enters the pipeline and the pipeline reacts. It was planned in UC2, which was dropped (D-013).
- **Option A (Claude's recommendation): the store channel of UC1 comes from the till feed.** UC1 already splits revenue by channel (store / web). Web orders come from Postgres; store sales come from the TD 3.3 till feed generator (micro-batch files), which already sends corrupted rows that dbt sends to quarantine. It reuses TD 3.3 code as planned, and gives us a third source and a third ingestion method for free. UC1 stays one use case; the till feed is its store-side input, not a separate use case.
- **Option B: a corrupted stock row in UC3.** We inject a bad row into the daily stock snapshot (negative stock, unknown product, wrong store). A dbt test catches it and the row goes to quarantine. Simpler data flow, but we write the quarantine logic ourselves and the demo is a batch load, less visual.
- **Either way:** the product catalogue stays the dbt **seed** (used by both UC1 categories and UC3 products), and the second incident (Airflow task crash, retry without double counting, TD 4.2) stays in UC1.

### D-015 · Final presentation as an HTML page
- **Date:** 2026-11-02 · **Status:** Decided (principle); content to be specified by the group later
- **What:** the slides are an HTML page that tells the story and animates a simulated data flow.
- **Limit we accept:** a web page alone cannot run Python, dbt or Snowflake. The real pipeline runs in its own tools (terminal, Airflow UI, Snowflake). The page can show the live dashboard inside it (an `<iframe>` pointing at the Streamlit app running on the laptop) and link to the Airflow UI.
- **Why the real tools must still be visible:** "working pipeline" is the biggest criterion (C3, 20 pts) and the incident demo must be live. An animation in the page explains; it does not prove. We switch to Airflow / Snowflake during the demo.

### D-016 · Dashboard: Streamlit
- **Date:** 2026-11-02 · **Status:** Proposed (Claude's recommendation)
- **What:** a Streamlit app reading the GOLD tables only.
- **Why:** it is in the teacher's own oral defense resource pack (`08-visualisation/streamlit/streamlit_app.py`, with a README comparing tools), it is Python like the rest of our code, and the same file runs **inside Snowflake** (Streamlit in Snowflake, nothing to install) or **on the laptop** (`streamlit run`). The laptop version can be shown inside the HTML presentation; Streamlit in Snowflake needs a Snowflake login and may refuse to load inside another page.
- **Alternatives in the teacher's pack:** Power BI Desktop (Windows only), Looker Studio (made for BigQuery, weak with Snowflake), Metabase or Superset (one more Docker service to run), Evidence (reports as code), Snowsight dashboards (cannot be embedded).
- **Rules from the teacher's README we follow:** connect to GOLD, never bronze; each chart title is the use-case question; show data freshness and source table; a dedicated XSMALL warehouse with `AUTO_SUSPEND = 60` and a read-only role; cache queries (`ttl=600`) so the dashboard does not burn credits.

### D-017 · Team split by use case
- **Date:** 2026-11-02 · **Status:** Proposed by the group, Claude agrees with one addition
- **What:** one person per story: **UC1** daily sales (Postgres incremental load, dbt sales models, Airflow), **UC3** stock cover (stock file via GCS, days-of-cover model), **data quality** (till feed, quarantine, dbt tests, both live incidents).
- **Addition:** the shared platform also needs an owner, because the jury grades it on its own (C5 cloud + IaC, C7 security and cost). Proposal: UC3 owner also takes Terraform, GCS and costs (UC3 already uses the GCS bucket); data-quality owner also takes the Streamlit dashboard (it shows the % quarantined). UC1 is the heaviest part, so its owner takes nothing extra.
- **Earlier proposal (Claude), replaced:** split by layer (ingestion / dbt / cloud). The group's split tells the story better: each person defends one business question end to end.

### D-018 · Architecture diagram, draft v1
- **Date:** 2026-11-02 · **Status:** Draft, for the group to correct
- **What:** [architecture/datathlon-architecture.excalidraw](../architecture/datathlon-architecture.excalidraw) (open on excalidraw.com), preview [.svg](../architecture/datathlon-architecture.svg), generated by [make_diagram.py](../architecture/make_diagram.py).
- **Shows:** 4 sources (3 OLTP + seed) → 3 ingestion methods → Snowflake on GCP (bronze → silver → gold, quarantine) → Streamlit → HTML presentation; Airflow on top; Terraform, GitHub Actions, GCS, costs and security at the bottom inside GCP.
- **New choice in it (to confirm):** till and stock files land in a **GCS bucket** before `COPY INTO`, so GCP is really used (C5) and not only as Snowflake's host. TD 2 and TD 3.3 loaded files from the laptop instead.

### D-019 · Tool logos on the architecture diagram
- **Date:** 2026-11-02 · **Status:** Decided (group asked for it)
- **What:** each box shows its tool's logo (Postgres, Python, dbt, GCS, Airflow, Docker, Snowflake, Google Cloud, Streamlit, HTML5, Terraform, GitHub Actions). Columns widened so text and logos fit.
- **Source of the logos:** Simple Icons 13.21.0 (CC0 licence, free to reuse), saved in `architecture/logos/`, coloured with each brand's colour. Logos are used only to name the tools, which is allowed.

### D-020 · Build step by step
- **Date:** 2026-11-02 · **Status:** Decided (way of working); the step list is Proposed
- **What:** we build in small steps ([BUILD_PLAN.md](BUILD_PLAN.md)). After each step Claude reports what was done and how it was checked; the group reviews and decides before the next step. Claude asks before acting on any of its own recommendations.

### D-021 · Five sources: add weather and holidays
- **Date:** 2026-11-02 · **Status:** Decided (group agreed: 5 sources needed)
- **Conflict found:** Notion "Group 8 final deliverable" says **at least 3 sources**, but the teacher's framework (resource pack `01-start-here/Framework.pdf`, step 02) says **at least 5 real sources, up to 15**, and "real-world datasets". Our plan has 3 sources plus the seed, all simulated.
- **Decision:** add 2 real public sources, which also gives a 4th ingestion method (API, listed in the framework step 03): Open-Meteo weather per store city (from the teacher's `FREE-APIS.md`, no key) and French school and public holidays (data.gouv.fr). Both explain sales and stock levels of a sports retailer.
- **Sources now:** web orders (Postgres), store tills (feed), warehouse stock (CSV), weather (Open-Meteo API, real), holidays (data.gouv.fr API, real), plus the product catalogue seed.
- **Still a risk:** 3 of the 5 are simulated, and the framework says "real". We say so openly on the slides; the simulated ones play the company's internal systems, which a fictional company cannot have for real.

### D-022 · Snowflake Tasks instead of Airflow
- **Date:** 2026-11-02 · **Status:** Decided (group)
- **What:** the daily schedule runs inside Snowflake with Tasks: root task at 06:00 → COPY INTO → MERGE → dbt build → gold, with automatic retries and a finalizer task that logs each run. Pattern from the teacher's resource pack (`06-orchestration-and-docker/snowflake-tasks/daily_pipeline_tasks.sql`) and TD 4.2 slides ("use internal DWH features like Tasks instead of external orchestrators").
- **Why:** nothing extra to install or keep running on a laptop, it runs in the cloud (helps C5 "cloud-executed processing"), and fewer moving parts (C4 "no decorative components").
- **Replaced:** Airflow 3 in Docker (TD 4.2), D-008.
- **Consequences, open questions (Claude will ask before choosing):**
  1. Tasks only run SQL and code *inside* Snowflake. Three jobs live outside: the Postgres incremental load, the two API pulls, and the till feed generator. Something must start them. Options: run them by hand or with cron on the laptop; a Docker job on GCP (Cloud Run job + Cloud Scheduler); for the APIs only, a Python procedure in Snowflake with an external access integration (to check: may not be allowed on trial accounts).
  2. Where dbt runs: inside Snowflake ("dbt Projects on Snowflake", started by a task), or dbt Core on the laptop. To check on our account.
  3. "Containerised job" (C3) used to come from Airflow's DockerOperator. It now comes from the Python ingestion job in Docker (TD 4.1, pack `docker/python-ingest-job`).
  4. Failure alerts: finalizer task + a Snowflake notification (email), instead of Airflow's alert callback.

### D-023 · Diagram v2
- **Date:** 2026-11-02 · **Status:** Done, for review
- **Changes asked by the group:** "account hosted on a GCP region" removed from the Snowflake label; no parentheses, TD references written "· TD2"; Excel logo on warehouse stock (taken from Simple Icons 10.0.0, removed from later versions); HTML presentation faded to 40 % and dashed because we may drop it from the diagram; 5 sources; Snowflake Tasks bar instead of Airflow.
- **Added by Claude to stay correct:** an "API pull" ingestion box for the two APIs; "schedule: to confirm" on the incremental load (see D-022 point 1); dbt box no longer says Docker (see D-022 point 2).

### D-024 · New Snowflake trial account on GCP
- **Date:** 2026-11-02 · **Status:** Superseded by D-025 (no new account needed)
- **Fact:** the TD Snowflake account (`RXTWCXB-MJ49606`) is in region `AWS_EU_WEST_3` (AWS Paris), checked with `SELECT CURRENT_REGION()` on 2 Nov 2026. Using it would put a second cloud in the project.
- **What:** a new 30-day Snowflake trial created on **Google Cloud**, Enterprise edition (free during the trial), in a European GCP region. The trial outlives the 6 Nov defense.
- **Region (Claude's proposal, to confirm):** `europe-west4` (Netherlands), and the GCS bucket in the same region, so Snowflake reads files without cross-region transfer costs (C7). Alternative: `europe-west3` (Frankfurt).
- **Who creates it:** a group member, in the browser; Claude does not create accounts or type passwords. Teammates then get their **own** Snowflake users and roles (never a shared password), see step 0.

### D-025 · Cloud provider: AWS (replaces GCP)
- **Date:** 2026-11-02 · **Status:** Superseded by D-026 (back to GCP)
- **What:** AWS is our single cloud. We keep the existing Snowflake account `RXTWCXB-MJ49606`, which already runs on AWS Paris (`AWS_EU_WEST_3`): $398 of credits left, trial ends around 21 Nov, after the 6 Nov defense. The S3 landing bucket goes in the same region (`eu-west-3`), so Snowflake reads it without cross-region transfer costs.
- **Why:** no new Snowflake account to create; the teacher's resource pack has a ready AWS example (`09-iac/aws`: S3 bucket + IAM role trusted by Snowflake's storage integration; `05-ingestion-methods/snowflake/02_copy_and_snowpipe_from_s3.sql`; `SNOWPIPE_TUTORIAL.md`).
- **Cost of the switch:** we need an **AWS account** (sign-up asks for a card; free tier covers a small S3 bucket); the AWS CLI is not installed yet; nobody in the team has used AWS before.
- **Replaced:** D-007 (GCP) and D-024 (new Snowflake trial on GCP).
- **Changed elsewhere:** diagram v3 (S3, AWS logos, AWS budget alert), build plan steps 0, 2, 3, 6, 7, 7b, TD inventory.
- **Note:** this Snowflake account also holds Khaled's TD objects. The project gets its own `DATATHLON` database, warehouses and roles, so nothing mixes.

### D-026 · Back to GCP, new Snowflake account in Frankfurt
- **Date:** 2026-11-02 · **Status:** Decided (group)
- **Why we came back:** staying on AWS meant opening an AWS account (credit card) and learning AWS; a mixed setup (Snowflake on AWS + files on Google) risks the jury counting two clouds and pays cross-cloud transfer. One 5-minute Snowflake sign-up on GCP was the least work. Claude recommended this.
- **The account (checked with a query on 2 Nov):** identifier `NVTLKDO-RP44213`, locator `GE20484`, region `GCP_EUROPE_WEST3` (Frankfurt), first admin user `ROBINCCR` (ACCOUNTADMIN). Sign-in: `https://app.snowflake.com/europe-west3.gcp/ge20484/`.
- **Region:** Frankfurt. Claude had suggested the Netherlands (slightly cheaper); Frankfurt works the same. Consequence: the GCS bucket must be in `europe-west3` too.
- **Seen in passing:** Snowsight Workspaces offers "dbt Project", so dbt can run inside Snowflake on this account (answers part of D-022 point 2, still to test).
- **Replaced:** D-024 (trial plan) and D-025 (AWS). Diagram v4 and the build plan, TD inventory and requirements are back on GCP.

### D-027 · Team access: one login per person, least privilege
- **Date:** 2026-11-02 · **Status:** Decided (group said go ahead); GitHub done; Snowflake script and GCP steps ready for Robin to run
- **Principle:** nobody shares a login or a password; each tool gives each person only what they need (graded in C7: "proportionate access with allowed/denied verification", "protected secrets").
- **Snowflake** (account `NVTLKDO-RP44213`, today only `ROBINCCR`):
  - One user per member. `ROBINCCR` stays Robin's; a second ACCOUNTADMIN (Khaled) so the team is not locked out if Robin is unavailable.
  - Roles, same pattern as TD 4.2 Terraform: `ACCOUNTADMIN` only for one-time setup (resource monitor, storage integration); `DATATHLON_ENGINEER` for the 3 members (builds in the `DATATHLON` database); `DATATHLON_ANALYST` reads GOLD only (dashboard, and the "denied on BRONZE" demo); a service user `DATATHLON_PIPELINE` with a key pair for scripts and Tasks.
  - People sign in to Snowsight with password + MFA; scripts use key pairs (TD 2 `gen_key.py`). Private keys and passwords never go in Git or chat.
  - The admin (Robin) types any temporary password himself, with `MUST_CHANGE_PASSWORD = TRUE`. Claude prepares the SQL and runs only what the group approves, never typing passwords.
- **Google Cloud:** one project with the school credits. Each member added with their own `@albertschool.com` Google account; Terraform runs with a dedicated service account; nobody gets Owner except the project owner.
- **GitHub:** one private repo, the 3 members as collaborators, `main` protected (changes through pull requests, where GitHub Actions runs `terraform plan`). Laura gets access (or the repo goes public) before the 4 Nov upload.
- **Done 2 Nov:** private repo `khaledngr/datathlon`; Robin (`rcacarie-png`) and Rudy (`rcausel-a11y`) invited with write access; `main` protected (pull request required, no force push, no deletion; Khaled as repo admin can still push directly, `enforce_admins` off).
- **Snowflake:** script [snowflake/setup/00_team_users.sql](../snowflake/setup/00_team_users.sql) creates `KHALED` (ACCOUNTADMIN + SYSADMIN) and `RUDY` (SYSADMIN, temporary until the Terraform roles exist). A first attempt by Claude was blocked by the safety check; after the group asked again, Claude ran it in the browser pane on 2 Nov (users created, passwords still to be set by an admin).
- **Google Cloud:** project `datathlon-513514`, owned by Robin (billing on his account). Robin adds Khaled (Editor + Project IAM Admin, for setup and Terraform) and Rudy (Editor) with their school Google accounts: steps in [gcp/setup/00_team_access.md](../gcp/setup/00_team_access.md). Budget alert needs Robin, or billing access for Khaled. **Checked 2 Nov:** roles correct (Khaled `roles/editor` + `roles/resourcemanager.projectIamAdmin`, Rudy `roles/editor`, Robin `roles/owner`); billing account linked but not active yet.
