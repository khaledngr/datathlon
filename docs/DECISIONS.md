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

### D-028 · Repository layout (step 1)
- **Date:** 2026-11-02 · **Status:** Proposed, for the group to review
- **What:** one folder per part of the pipeline, matching the diagram and the build plan: `sources/` (simulated systems), `ingestion/` (Python jobs), `snowflake/` (setup, stages, tasks SQL), `dbt/`, `terraform/`, `gcp/` (manual steps), `dashboard/`, plus `docs/`, `architecture/`, `brand/`. Each folder has a README saying what goes in it, which step fills it and which TD it comes from.
- **Settings:** `.env.example` lists every setting; team-wide values filled in, personal ones empty; secrets are never in it, only paths to key files. `docs/SETUP.md` explains tools, accounts and the key-pair setup.
- **Why this layout:** the jury reads the repo (README, launch documented, C3); one folder per diagram box makes "where is the code for this arrow?" easy to answer, and each owner has a clear area.
- **Reused from:** TD 4.2 `redgrave-platform` (`.gitignore`, `.env.example`, `*.example` pattern).

### D-029 · Cost guard: Snowflake credit cap + Google Cloud budget alert (step 2)
- **Date:** 2026-11-02 · **Status:** Done (asked by the group: "be extra sure we're not paying anything extra")
- **Snowflake:** resource monitor `DATATHLON_ACCOUNT_MONITOR` on the whole account, script [snowflake/setup/01_resource_monitor.sql](../snowflake/setup/01_resource_monitor.sql). Quota **20 credits a month** (the trial has about 100; an XSMALL warehouse uses 1 credit per hour, the pipeline needs minutes a day). 50 % and 80 % → email; 100 % → warehouses suspended (running queries finish); 110 % → suspended immediately. Checked with `SHOW RESOURCE MONITORS`: quota 20, used 0, level ACCOUNT.
  - Emails go to `ROBINCCR` and `KHALED`. The first run had Robin only (Snowflake refuses users whose email is not verified); Khaled verified his email and was added the same day (`notify_users` = ROBINCCR, KHALED).
  - Limit: a resource monitor does not cover serverless features (serverless tasks, Snowpipe). So our Tasks will run on a warehouse (`WAREHOUSE = ...`), not serverless; this ties into D-022.
- **Google Cloud:** budget `datathlon-cost-guard` on Robin's billing account `014D04-0E9313-35FE88`, project `datathlon-513514`, all services, monthly. Amount **€10**. Email to billing admins (Robin) at 50 %, 90 %, 100 % of actual cost and at 100 % of forecast cost.
  - The budget counts cost **before credits** ("Programmes de remises" and "Autres remises" unticked, checked after saving), so it warns us even while the trial credits pay: €10 of real usage is far more than a bucket of a few MB should cost.
  - Type "Alertes uniquement", not "Plafond de dépenses": a spending cap only covers some services and could pause our bucket during the demo. The free trial is already a hard stop: Google does not charge the card until someone clicks **Changer** (upgrade to a paid account). **Rule: nobody clicks "Changer" / upgrade.**
  - Trial status seen on 2 Nov: 90 days and €269.43 of credit left.
- **Why both:** each cloud bills separately; a guard on one does not see the other (graded in C7, cost awareness).
- **Rejected:** a lower Snowflake quota (5 credits) could stop the pipeline during the live demo; Pub/Sub automation to disable billing (too much setup for a free trial that cannot charge anyway).
- **Later (step 3):** Terraform imports the resource monitor (pack `09-iac/snowflake`), so it is declared as code. The GCP budget stays manual: it belongs to Robin's billing account, which Terraform's service account cannot reach.

### D-030 · Commits credit the whole team (co-authors)
- **Date:** 2026-11-03 · **Status:** Decided (Khaled, for the group)
- **What:** the team works together on Khaled's laptop, so every commit ends with `Co-authored-by` lines for Robin and Rudy (and Claude). GitHub then shows all three on each commit and in the contributors' activity.
- **Emails used:** GitHub's private "noreply" addresses, which GitHub links to the right accounts without showing anyone's real email: `234458087+rcacarie-png@users.noreply.github.com` (Robin), `235127277+rcausel-a11y@users.noreply.github.com` (Rudy). Khaled is the author (`khaledngr@users.noreply.github.com`).
- **If one person did a step alone**, we drop the others' lines for that commit, so the history stays honest about who did what.
- **Not changed:** the commits before 3 Nov stay as they are (rewriting `main` would need a force push, which the branch protection blocks, D-027).

### D-031 · Terraform design for step 3
- **Date:** 2026-11-03 · **Status:** Decided (group said go)
- **One Terraform folder for both clouds** (`terraform/`): one `apply` creates the Snowflake storage integration and gives its Google service account read access on the landing bucket; no copy-paste between two projects.
- **Two warehouses** from the pack's warehouse module: `DATATHLON_WH` (pipeline, dbt) and `DATATHLON_BI_WH` (Streamlit), XSMALL, auto-suspend 60 s. Credits split by use (C7).
- **Roles:** SYSADMIN for objects, SECURITYADMIN for roles and grants (same as the pack), ACCOUNTADMIN only for the storage integration and the resource monitor import (Snowflake allows nothing lower).
- **Later, not in step 3:** the service user `DATATHLON_PIPELINE` (with ingestion, steps 5-6); removing SYSADMIN from people once the new roles work.
- **Sign-in for Terraform:** key pair on `KHALED` (no password, no MFA prompt). Script [snowflake/setup/gen_key.py](../snowflake/setup/gen_key.py), adapted from TD 2: the private key goes to `~/.snowflake/datathlon/`, outside the repo.
- **State:** remote, in the bucket `datathlon-tfstate-513514` (Frankfurt, versioned, private), created once by hand (a manual step the teacher expects us to list). Locking is built in to the GCS backend.
- **The Google budget stays manual** (Robin's billing account, out of Terraform's reach).
- **Applied 3 Nov (3b):** `terraform apply`: 1 imported (resource monitor), 29 added (database `DATATHLON`, schemas BRONZE / SILVER / QUARANTINE / GOLD, warehouses `DATATHLON_WH` and `DATATHLON_BI_WH`, roles `DATATHLON_ENGINEER` and `DATATHLON_ANALYST`, grants). Second `terraform plan`: **No changes**. State: `gs://datathlon-tfstate-513514/platform/default.tfstate`.
  - The import first wanted to clear the monitor's start date: we wrote the real date (`start_timestamp`) in the code, so the import changed nothing.
  - **Access proven** ([snowflake/setup/02_access_test.sql](../snowflake/setup/02_access_test.sql)): analyst reads GOLD; denied on BRONZE, on INSERT and on the pipeline warehouse.
  - **Found while testing:** Snowflake users have `DEFAULT_SECONDARY_ROLES = ALL`, so all of a person's roles are active at once and a member who is ACCOUNTADMIN passes every check whatever role is selected. The demo must start with `USE SECONDARY ROLES NONE`, and the future service user `DATATHLON_PIPELINE` gets `DEFAULT_SECONDARY_ROLES = ()` so it only ever has its own role.
- **Applied 3 Nov (3c):** 5 added: landing bucket `datathlon-landing-513514` (europe-west3, private, uniform access, files deleted after 90 days, `force_destroy = false`); storage integration `DATATHLON_GCS_INT` (allowed location: this bucket only); Snowflake's Google service account `k8lg30000@gcpeuropewest3-1-d3ca.iam.gserviceaccount.com` gets read-only on the bucket (`legacyBucketReader` + `objectViewer`, the 3 permissions Snowflake's loading guide lists); `DATATHLON_ENGINEER` can use the integration. Second plan: **No changes**. Robin's access was not needed (Khaled's Editor role could set bucket permissions).
  - **Link proven:** a test CSV uploaded to the bucket was listed and read from Snowflake through a temporary stage as `DATATHLON_ENGINEER`; a stage pointing at another bucket was refused ("not allowed by integration"). Test file and stage removed.
  - Provider note: the GCS integration resource is stable in provider 2.22.1, no preview flag needed.
- **3d, 3 Nov (step 3 closed):** drift demo tested: warehouse `DATATHLON_BI_WH` changed by hand (auto-suspend 3600 s, size SMALL); `terraform plan` showed `3600 -> 60` and `SMALL -> XSMALL` (1 to change); `apply` restored it; next plan **No changes**. Script in [terraform/README.md](../terraform/README.md). The 12 manual steps, with the reason for each, are in [docs/MANUAL_STEPS.md](MANUAL_STEPS.md).

### D-032 · Web shop source (step 4)
- **Date:** 2026-11-03 · **Status:** Done (group: "move on")
- **Built on TD 2 and the resource pack, in the Datathlon repo** (the TD folders are not touched): schema and `updated_at` trigger from TD 2 `01_create_merch_db.sql`; Docker Compose from pack `04-source-databases` (Postgres 16.4 only); psycopg2 loading style from the pack. New: a small generator, because TD 2's 240 fixed August orders cannot feed a daily dashboard.
- **Shared catalogue** `sources/catalogue/`: 30 sports products in 6 categories (€, 2 discontinued for UC3) and 8 stores (FR, BE, ES) with coordinates for the weather API. Used by every source, so web and store sales and stock join on the same codes.
- **Database:** Docker `datathlon-postgres`, `localhost:5433` only (5432 is Khaled's TD Postgres), password random in each person's `.env`. Schema `datathlon`: `products`, `stores`, `orders` (fulfilment home delivery / click & collect with `store_id`, status paid / cancelled / refunded, `is_test`), `order_lines`. No personal data: customers are codes (GDPR, C7).
- **Generator** `generate_orders.py`, fixed seed per day: `--init` = 1 Oct to yesterday (1,502 orders, 2,956 lines, 62 refunds on 3 Nov); `--next-day` = one more day + ~2 refunds of orders 2-14 days old. Prints generator vs Postgres counts.
- **Two watermark bugs found and fixed while testing** (good material for the defense):
  1. `--next-day` for today wrote orders stamped up to 23:00, in the future. The step 5 watermark would have jumped past refunds stamped "now" and skipped them. Fix: live rows get `updated_at` = the real time they are written.
  2. The TD 2 trigger overwrote the historical refund dates of `--init` with "now", so step 5's first load would have shown 62 refunds "today". Fix: the trigger keeps an `updated_at` that the UPDATE sets itself; a normal update still stamps now (checked).
- **Python:** one project environment `.venv` from `requirements.txt` (pinned: psycopg2-binary 2.9.10, snowflake-connector-python 3.12.4, cryptography 44.0.0, python-dotenv 1.0.1).

### D-033 · Fake data is shaped for the dashboard story (holidays effect)
- **Date:** 2026-11-03 · **Status:** Decided (Khaled: "optimize it so that it is good to show what we want to show in our BI")
- **Rule for every generator** (web orders now; tills step 6, stock step 7 later): the synthetic data must contain the patterns the dashboard is meant to show, on the same dates as the real context data the pipeline loads.
- **Holiday calendar** `sources/catalogue/holidays.csv`, saved by `fetch_holidays.py` from the **OpenHolidays API** (free, no key): school holidays FR and BE, nationwide public holidays FR, BE, ES, Sep-Dec 2026. France mainland only; Belgium's two autumn breaks (French- and Dutch-speaking communities) count for half each; Spain has no national school calendar, so public holidays only.
- **Effects in the web orders:** orders get a `country` (FR 70 %, BE 15 %, ES 15 %; click & collect in a store of that country). School holidays +60 % × share, the week before +30 %, public holiday +40 %, back to school 1-14 Sep +30 %, weekends ×1.6 / ×1.3. Category mix: hiking, cycling, swimming up in holidays; team sports, swimming up at back to school. History now starts **1 Sep** for a normal baseline.
- **Measured** (France, paid orders/day): normal 28.7, back to school 37.9 (+32 %), week before 37.6 (+31 %), All Saints holidays 49.9 (+74 %); outdoor share of units 48 % → 62 %. Data: 3,479 orders / 6,665 lines up to 2 Nov, deterministic.
- **Proposed, not decided:** use the same OpenHolidays API in step 7b (it covers FR, BE and ES; data.gouv.fr in D-021 covers France only). And later, shape store sales on the **real** Open-Meteo weather of each store's city (rain → fewer store visits, more web orders), so a weather effect shows with real data.
- **Robin's commit credit:** his first commit used the laptop email `rob@MacBook-Pro-de-Robin.local`, which GitHub cannot link to him. Added `.mailmap` so git shows it under his name (`git log --format='%aN'`); GitHub's contribution graph ignores `.mailmap`, so that one commit stays uncounted there. Fix for the future: on his laptop, `git config --global user.email "234458087+rcacarie-png@users.noreply.github.com"`. Commits made on Khaled's laptop credit him via `Co-authored-by` (D-030).

### D-034 · Incremental load of the web shop (step 5)
- **Date:** 2026-11-03 · **Status:** Done (group: "let's continue")
- **Code:** [ingestion/incremental_orders/load_web_orders.py](../ingestion/incremental_orders/load_web_orders.py), adapted from TD 2 `incremental_orders.py`: watermark = `MAX(updated_at)` already in BRONZE, batch table + `MERGE`, run log.
- **Changes from TD 2:** loads the order **lines** too (UC1 needs categories); **5-minute look-back** on the watermark (a row committed in the same second as the last load is re-read, the `MERGE` drops the overlap: an update only applies if `updated_at` is newer); Postgres read in one `REPEATABLE READ` snapshot (orders and lines consistent); **reconciliation** at the end of every run (Postgres counts = BRONZE counts) stored in `BRONZE.LOAD_RUNS`; `QUERY_TAG` so the job's cost shows in query history.
- **Tables:** `DATATHLON.BRONZE.WEB_ORDERS`, `WEB_ORDER_LINES`, `LOAD_RUNS` (created by the job if missing).
- **Service user `DATATHLON_PIPELINE`** (Terraform, `roles.tf`): `TYPE = SERVICE` (key pair only, no password, no Snowsight), role `DATATHLON_ENGINEER`, default warehouse `DATATHLON_WH`, **secondary roles NONE** (checked: `CURRENT_SECONDARY_ROLES()` empty), statement timeout 15 min. Public key committed in `terraform/keys/datathlon_pipeline.pub` (public, safe); private key in `~/.snowflake/datathlon/` on Khaled's laptop only. Terraform: 2 added, then No changes.
- **Tested 3 Nov:** run 1 = 3,520 orders + 6,742 lines inserted; run 2 = 43 re-read (look-back), **0 merged**; `--next-day` then run 3 = **45 inserted, 2 updated (the refunds)**, 94 lines; run 4 = 0. All 4 runs reconciled; statuses identical in Postgres and BRONZE (paid 3,320 incl. 22 test, refunded 126, cancelled 119).
- **Not handled, on purpose:** deletes (the shop never deletes orders, it changes their status); a deleted row would need CDC (Openflow / Debezium), mentioned as a limit.

### D-035 · Store till feed, files → GCS → `COPY INTO` (step 6)
- **Date:** 2026-11-03 · **Status:** Done (group: "Start step 6")
- **Generator** [sources/tills/till_feed.py](../sources/tills/till_feed.py), adapted from TD 3.3 `kiosk_sales_generator.py`: NDJSON files (one JSON per line), one row = one product scanned at a till, the same 11 deliberate defects as TD 3.3 (duplicates, missing id, store name variants, bad quantity, price formats, date formats, future and late dates, unknown SKU, payment variants, schema drift). The TD 3.3 customer e-mail is replaced by an optional loyalty code (GDPR, C7).
- **Two modes:** `--history` writes one file per store per day from 1 Sep to yesterday (defects at a quarter of the live rate) and follows the shared demand rules (D-033): FR and BE stores closed on Sunday, so no file; Spanish stores open. `--live` drops a small batch every few seconds at the full TD 3.3 defect rate (the live incident demo).
- **A planted incident for the dashboard:** on 24 Oct the Lyon store's tills send prices in cents after a "software update" (median price 24.99 → 3,499 in BRONZE). dbt (step 8) must catch it.
- **Shared demand rules** moved to `sources/catalogue/demand.py`, used by the web orders and the tills (and stock in step 7). The web generator gives the same output as before (checked).
- **Landing:** files go to `gs://datathlon-landing-513514/tills/YYYY/MM/DD/` (copy in `data/landing/`, git-ignored), uploaded with `google-cloud-storage` under each person's own Google sign-in.
- **One shared stage** `DATATHLON.BRONZE.LANDING` over the whole bucket (folders `tills/`, `stock/`, `api/`), through the Terraform storage integration (no key in Snowflake), plus file format `NDJSON`. Robin's step 7b can load from `@LANDING/api/`.
- **Raw table** `BRONZE.TILL_SALES_RAW`: `raw VARIANT` (nothing cleaned in bronze) + lineage columns `_file` (`METADATA$FILENAME`), `_file_row`, `_file_modified`, `_loaded_at`. `COPY INTO` with `ON_ERROR = CONTINUE`; its load history (64 days) means a re-run never loads a file twice.
- **Shared code:** `ingestion/sf_connect.py` (one connection as `DATATHLON_PIPELINE`, used by the web loader and the SQL runner) and `snowflake/run_sql.py` (runs a .sql file, adapted from TD 3 `run_sql_file.py`).
- **Tested 3 Nov:** first COPY = 450 files, 46,600 rows, 0 errors; re-run = 0 files; `--live --batches 3` then COPY = only the 3 new files (27 rows); `_file` never null; Sunday 25 Oct has MAD-01 and BCN-01 only; defects visible (734 duplicate sale ids, 590 rows with `unitPrice`, 32 spellings of 8 store codes). Web loader re-run after the refactor: reconciled.
- **Later (step 10):** a Snowflake Task runs the same `COPY INTO` on a schedule, so the till load needs no Python at all.

### D-036 · API pull: real weather and holidays, files → GCS → `COPY INTO` (step 7b)
- **Date:** 2026-11-03 · **Status:** Done (Robin)
- **Holidays from OpenHolidays, not data.gouv.fr** (Robin, closes the proposal in D-033): it covers FR, BE and ES, and it is the API the sales generators already follow (`sources/catalogue/holidays.csv`), so the real holidays the pipeline loads line up with the fake sales. Replaces data.gouv.fr in D-021.
- **Code** [ingestion/api_pull/pull_apis.py](../ingestion/api_pull/pull_apis.py), adapted from the resource pack `05_api_to_snowflake.py`: the API answer is kept raw, inside an envelope (source, url, run date, fetch time, store or country). Weather: one Open-Meteo call per store (8), daily temperature max/min, rain, wind, from 1 Sep to run date + 7 days (measured past + forecast). Holidays: school + public holidays for FR, BE, ES, 1 Sep - 31 Dec 2026 (6 calls).
- **Landing:** one NDJSON file per source and run, `gs://datathlon-landing-513514/api/{weather,holidays}/YYYY/MM/DD/`, through the shared stage `LANDING` (D-035). Loaded by [snowflake/stages/04_api.sql](../snowflake/stages/04_api.sql) into `BRONZE.WEATHER_RAW` and `BRONZE.HOLIDAYS_RAW` (same lineage columns as the tills). `ON_ERROR = ABORT_STATEMENT`: an API file is all or nothing.
- **No duplicates on re-run:** a run whose files are already in the bucket stops before calling the APIs (`--force` replaces them); `COPY INTO` never loads the same file twice. Limit: after `--force`, the changed file is loaded again, so silver (step 8) keeps the latest run per store and day.
- **Fails loudly:** timeout on every call (30 s), 3 tries (pause 2 s, 4 s), 4xx errors not retried, then exit code 1. Every call must succeed before anything is uploaded, so a failed run leaves no half-written files.
- **Runs as ROBINCCR on Robin's laptop:** `DATATHLON_PIPELINE`'s private key stays on Khaled's laptop, so Robin's `.env` points `PIPELINE_USER` to his own key (role `DATATHLON_ENGINEER`). On Khaled's laptop and in step 10 the job runs as the service user.
- **Tested 3 Nov:** run 1 = 2 files (8 weather calls of 71 days, 6 holiday calls: FR 4 + 6, BE 4 + 3, ES 0 + 22 periods), `COPY` loaded 8 + 6 rows, 0 errors; re-run = "already in the bucket", `COPY` 0 new rows; `--timeout 0.001` = 3 timeouts, exit 1, nothing uploaded. Yesterday's weather readable by store from BRONZE (e.g. Lille 2.7 mm of rain).
- **For silver (step 8):** flatten `raw:response:daily` by day; holidays: drop regional public holidays and overseas-only French school holidays, Belgian autumn breaks count for half (same rules as `fetch_holidays.py`). OpenHolidays returns no national school calendar for Spain.
- **Reviewed and re-tested on Khaled's laptop as `DATATHLON_PIPELINE`** (PR #2, merged 3 Nov): same-day re-run skipped; timeout demo exit 1 with nothing uploaded; backfill 1 and 2 Nov loaded once, `COPY` re-run 0. **One fix before merging** (group: "Fix first, then merge"): a run whose second upload failed was skipped forever (one file already there was enough); now a re-run fetches and uploads only the missing file (tested by deleting the 1 Nov holidays file).
- **Limit to watch:** Open-Meteo's forecast endpoint may keep only about 3 months of past days; around December, a history starting 1 Sep may need the archive endpoint. Not an issue for the 6 Nov defense.

### D-037 · Warehouse stock, daily CSV → GCS → `COPY INTO` (step 7)
- **Date:** 2026-11-03 · **Status:** Done (group: "Start step 7")
- **Generator** [sources/stock/stock_export.py](../sources/stock/stock_export.py): the store stock system's night count, one CSV per day (store × product: `on_hand`, `received`, `emergency`, `counted_at`) **plus a control file** with the expected row count and units (classic batch control). Same pattern as TD 2 Part A (export → stage → `COPY INTO` → reconcile).
- **Stock follows the real sales** of the other sources, so UC3 agrees with UC1: units sold = till lines (same generator and seed, cleaned like silver will: duplicates once, bad quantities and unknown SKUs out) + paid click & collect web orders of that store (Postgres). Night count = yesterday − sold + received.
- **Replenishment (assumption, shaped for the dashboard, D-033):** deliveries Monday and Thursday up to 10 days of the store's 28-day average sales. The average lags behind a rush, so outdoor products run low in the holidays. A shelf that would go negative gets a same-day emergency transfer (count never negative). Discontinued products keep 6 units, never restocked. FR/BE stores closed on Sunday: no count, no rows.
- **Measured** (FR + BE shelves under 3 days of cover): 0.5 % on normal days, 5.5 % the week before All Saints, 8.1 % in the holidays (hiking 22 %, cycling 14 %, swimming 11 %); Spain flat (~1 %, no national school holidays). The weekly view from BRONZE peaks at 12 % in the week of 19 Oct.
- **Snowflake** [snowflake/stages/03_stock.sql](../snowflake/stages/03_stock.sql): file format `CSV_HEADER`, typed tables `BRONZE.STOCK_SNAPSHOTS` and `STOCK_CONTROL` with `METADATA$FILENAME`, `ON_ERROR = ABORT_STATEMENT` (half a snapshot = wrong stock), and a **two-way reconciliation** (each control file = its snapshot; no snapshot without a control file).
- **Bug found by testing, fixed:** a broken CSV line (4 columns instead of 7) **was loaded** with NULLs: when `COPY` uses `SELECT $1..$7`, Snowflake does not reject short lines. Fix: `NOT NULL` columns (Snowflake enforces them, so the load aborts: "NULL result in a non-nullable column") and the reconciliation now also flags a day with no control file. Tables dropped and reloaded (bronze only, the files stay in the bucket).
- **Re-run safe twice over:** the export skips days already in the bucket (a snapshot already loaded is never re-sent changed), and `COPY INTO` never loads a file twice.
- **Tested 3 Nov:** 63 days, 13,500 rows, 512,797 units; reconciliation 0 differences; re-run 0 files; broken file → load aborted, nothing loaded; till sales without a stock row: 0 (UC3 acceptance test).

### D-038 · Audit fixes before step 8: one date window for every source
- **Date:** 2026-11-03 · **Status:** Done (Khaled: "Apply fixes 1 to 4", after the audit in journal #123)
- **One window:** the history of every simulated source is **1 Sep → yesterday**; only the live demo writes today. The web orders had run to 4 Nov (two `--next-day` replays), the tills and stock stopped on 2 Nov, so 3–4 Nov would have shown web sales and no store sales. Reset: Postgres `--init`, BRONZE web tables emptied and reloaded (3,479 / 6,665, reconciled), the 3 live till test files of 3 Nov removed (bucket + 27 BRONZE rows), stock files and tables regenerated against the reset web orders (same 13,500 rows / 512,797 units, control files reconciled). `LOAD_RUNS` keeps its history.
- **Guard:** `generate_orders.py --next-day` refuses a day after today (tested: "never writes a day after today").
- **Cleanup procedure** for C7: [CLEANUP.md](CLEANUP.md) (stop, empty bucket, `terraform destroy`, then manual objects, then checks).
- **Robin's user:** default warehouse `COMPUTE_WH` (outside Terraform) → `DATATHLON_WH`; `COMPUTE_WH` auto-suspend 300 s → 60 s. Snowflake now reports MFA on for `ROBINCCR` (off during the audit).
- **Docs:** root README quick start gives the full run order (web → tills → APIs → stock → stage SQL); `snowflake/README` lists all setup files.
- **Left for later, noted in the audit:** business day in UTC vs Paris time and "complete days only" in gold (step 9); checks that fail the scheduled run, rejected till lines in the data quality table (step 10); masking policy on customer codes (to check on the trial); cost projection (step 12).

### D-039 · dbt silver + quarantine + seed (step 8)
- **Date:** 2026-11-03 · **Status:** Done (Khaled: "finish just 8 now")
- **Project** [dbt/](../dbt/), adapted from TD 3.1 `redgrave_dbt` and TD 3.3 `redgrave_kiosk_dbt` (parse → quarantine → silver, schema macro, run log). **dbt Core 1.9 on the laptop as `DATATHLON_PIPELINE`**, started by `dbt/dbt.sh` (loads `.env`); the SQL runs in Snowflake. Whether step 10 moves it to dbt Projects on Snowflake stays open (D-022 point 2, for Robin).
- **One catalogue:** the seeds (`products`, `stores`, `holidays`) are read from `sources/catalogue/`, the files the generators use. No copy that could drift.
- **Till cleaning (UC1 store channel):** store variants mapped to codes ("par-01 ", "PAR01", "Paris La Defense" → PAR-01), 3 date formats, SKU upper-case, quantity text → number, `unitPrice` drift, € and comma prices, payment variants. **Cents are fixed against the catalogue, not with TD 3.3's "≥ 100" rule** (Datathlon sells a €249 bike): a price ≈ 100 × the catalogue price is divided by 100 and flagged `price_fixed_from_cents` (745 lines, incl. 204 of Lyon's 24 Oct incident). Loyalty codes hashed (GDPR). Late events kept and flagged (466).
- **Quarantine:** first failed rule (`missing_sale_id`, `unknown_store`, `unparseable_timestamp`, `future_timestamp`, `unknown_product`, `invalid_quantity`, `invalid_price`, `price_not_in_catalogue`) or `duplicate` (a resent sale; the first copy stays in silver). Recording duplicates too means **every raw line is in exactly one place**: 46,600 raw = 44,365 silver + 2,235 quarantine (706 duplicates, 591 bad quantities, 373 missing ids, 337 unknown products, 227 future dates, 1 price in cents twice).
- **Other sources:** web orders and lines (clean source, test orders flagged for gold), stock (adds category and `is_discontinued`), weather (latest run per store and day, `is_forecast`), holidays (latest run, same filters as `fetch_holidays.py`: equal to the generator calendar, 16 / 16, checked by a test).
- **Tests:** 55 pass (build green). Freshness 26 h warn / 50 h error, all pass. **Failure shown:** one extra raw row without a rebuild → `assert_till_rows_accounted_for` FAIL 1; row removed → PASS.
- **Versions:** dbt pulled `snowflake-connector-python` 3.18.1 and `python-dotenv` 1.2.4; `requirements.txt` updated, loaders re-tested (reconciled, 0 new files).
- **Known small gap:** the stock export (step 7) counts a quantity sent as text ("1 ") as invalid, silver accepts it as 1: a few units of difference between stock movements and silver sales. Not visible at UC3's grain; to align if the stock is regenerated.

### D-040 · dbt gold: UC1 sales, UC3 stock cover, data quality (step 9)
- **Date:** 2026-11-03 · **Status:** Done (Robin: "Go étape 9")
- **Two rules (assumptions, state them on the slides):** **business day = the UTC date** (every source stamps UTC; a sale at 23:30 Paris time in summer counts on that UTC day). **Gold shows complete days only:** macro [`last_complete_day`](../dbt/macros/last_complete_day.sql) = the earliest of the last web order day, last till file day and last night stock count, so a late source never shows a half day (e.g. web sales without store sales). Data today: 1 Sep → 2 Nov for all three.
- **`gold_sales_daily` (UC1)**, day × channel × country × category: units, revenue `SUM(qty × unit_price)` in EUR, orders or tickets, lines. Web = paid and not test orders (cancelled, refunded and 21 test orders out); click & collect counts as web (ordered online). Store = `silver_till_sales` (quarantined lines out, cents fixed). Late till events count on the day of the sale (466 lines, a few before 1 Sep). Total: 71,306 units, €2,978,000.82 (store €2,653,297.07, web €324,703.75).
- **`gold_stock_cover_daily` (UC3)**, day × store × product: days of cover = night count (end of that day) ÷ (units sold over the 7 calendar days up to that day ÷ 7); alert under 3 days. Units sold = till units + paid click & collect units of that store. Discontinued products out; a closed store has no count, so no row (FR/BE Sundays); a closed Sunday counts as 0 sales in the average. Starts on 7 Sep (first full 7-day window). Days of cover null = nothing sold in 7 days, no alert. **Measured:** alerts FR 7.6 % in the All Saints holidays vs 2.1 % on other days, BE 5.5 % vs 1.7 %, ES 1.1 % (no national school break).
- **`gold_data_quality_daily`**, file day × store (`UNKNOWN` when the store cannot be recognised): raw, silver and quarantined lines, quarantine % and one column per reason, prices fixed from cents. 46,600 = 44,365 + 2,235; 745 prices fixed. Lyon 24 Oct: 223 lines, 205 prices fixed from cents, 18 quarantined (8.1 %).
- **Tests added (15):** `assert_gold_sales_match_silver` (TD 3.1, revenue **and** units); `assert_gold_hand_checked_day` (Belgium, 24 Oct, Cycling, counted by hand from BRONZE, journal #135); `assert_stock_alerts_rise_in_all_saints` (FR/BE holiday share ≥ 5 % and ≥ 2 × the normal share); `assert_gold_quality_lines_add_up`; unique / not null keys and accepted values on the 3 models. `dbt build` 73 / 73. Failure shown: hand-checked value + €0.01 → FAIL 1, then put back.
- **Access:** the 3 tables are in GOLD, so `DATATHLON_ANALYST` reads them through the Terraform future grant (to check in step 11 with `USE SECONDARY ROLES NONE`). Holidays for the dashboard shading stay in SILVER for now: copy to gold in step 11 if the analyst needs them.
- **Cost:** 0.80 of 20 Snowflake credits over the last 30 days.
