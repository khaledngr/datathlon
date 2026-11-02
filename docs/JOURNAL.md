# Journal

Every action, in order. Who did it, what, and where the result is. Decisions themselves are in [DECISIONS.md](DECISIONS.md).

## 2026-11-02 (Mon)

| # | Who | Action | Result |
| --- | --- | --- | --- |
| 1 | Claude (for Khaled) | Read the course material: Granola notes of the 9 data engineering sessions, Notion pages (course page, "Group 8 final deliverable", "Oral defense"), Drive course folder (grading matrix, slots, timeline, slides) | Requirements summarised in [REQUIREMENTS.md](REQUIREMENTS.md) |
| 2 | Group | Chose the industry: sports retail, Decathlon style | D-004 |
| 3 | Group | Chose GCP as cloud provider (rejected Snowflake on AWS) | D-007 |
| 4 | Claude | Proposed parody names; group chose **Datathlon** | D-005 |
| 5 | Claude | Built `brand/brand-sheet.html`: name shortlist, colors, fonts, first logo (orbit ring) | Group kept colors and fonts, rejected the logo |
| 6 | Claude | Scanned the professor's slides (2_Ingestion, 3.2_Warehousing, 4.2_Orchestration_Terraform, Kafka) for trending tools and proposed a "trendy" free-credit stack | Parked by the group in favour of the TD stack (D-008) |
| 7 | Claude | Drew 7 new logo concepts in the brand sheet | Group chose **Speed D** (D-006) |
| 8 | Claude | Exported the logo with a Python + Pillow script: 6 variants (main, dark, light, transparent, symbol, transparent symbol) in PNG (2000 px) and SVG (font embedded). Downloaded the font Barlow Condensed ExtraBold Italic from Google Fonts (open licence) | [brand/](../brand/) |
| 9 | Claude | Created the Drive folder `Datathlon · Group 8 project/Brand` and copied the brand files into it (via Google Drive for desktop) | Khaled shares it with Robin and Rudy (D-012) |
| 10 | Claude | Created this project folder `datathlon/` with README, REQUIREMENTS, DECISIONS, JOURNAL, TD_INVENTORY, USE_CASES. Moved `brand/` inside it | This folder |
| 11 | Claude | Listed what each TD built and which files we can adapt | [TD_INVENTORY.md](TD_INVENTORY.md) |
| 12 | Claude | Drafted three use cases, each mapped to TD pieces | [USE_CASES.md](USE_CASES.md), waiting for the group vote (D-013) |
| 13 | Claude | Copied `README.md` and `docs/` to the Drive folder `Datathlon · Group 8 project/` so Robin and Rudy can read them | Drive copy; the local `datathlon/` folder stays the master until the Git repo exists |
| 14 | Group | Voted on the use cases: kept UC1 (daily omnichannel sales) and UC3 (stock cover alert), dropped UC2 | D-013 decided; [USE_CASES.md](USE_CASES.md) updated (UC2 struck through, UC3 no longer optional, rules table redone) |
| 15 | Claude | Checked the rules against the new scope: dropping UC2 removes the live corrupted-row demo, one ingestion method and one source. Wrote two options to cover them | D-014 proposed, waiting for the group |
| 16 | Claude | Re-copied `docs/` to the Drive folder | Drive copy in sync |
| 17 | Group | Chose option A for the incident demo: store sales of UC1 come from the TD 3.3 till feed | D-014 decided |
| 18 | Group | Decided the final presentation will be an HTML page simulating the pipeline (details later) | D-015 |
| 19 | Claude | Searched the course material for Streamlit: not in the course PDFs, but the teacher's **oral defense resource pack** (Drive `Oral defense/Oral-defense-resource-pack.zip`) has `08-visualisation/` with a Streamlit app and a dashboard tool comparison | D-016 proposed; pack added to [TD_INVENTORY.md](TD_INVENTORY.md) |
| 20 | Claude | Drew the architecture diagram v1 with a Python script that writes an Excalidraw file and an SVG preview. Checked the preview in the browser; the `.excalidraw` file follows Excalidraw's export format but was not yet opened in excalidraw.com | [architecture/](../architecture/), D-018 |
| 21 | Group + Claude | Discussed the team split: group proposed one person per use case + one on data quality; Claude added owners for the shared platform | D-017 proposed |
| 22 | Claude | Re-copied `docs/` and `architecture/` to the Drive folder | Drive copy in sync |
| 23 | Group | New way of working: build step by step with feedback after each step; Claude asks before applying its recommendations | D-020; memory updated |
| 24 | Claude | Re-read all course PDFs (7 lecture decks, 6 TD sheets, Kafka), the resource pack framework and Notion for project-relevant points. Notion unchanged since the morning | Findings in [REQUIREMENTS.md](REQUIREMENTS.md) "second pass"; sources conflict logged as D-021 |
| 25 | Claude | Downloaded 12 tool logos from Simple Icons 13.21.0 (jsDelivr CDN) into `architecture/logos/`, added them to the diagram, widened the columns, shortened the costs box. Checked the SVG preview in the browser | D-019, [architecture/](../architecture/) |
| 26 | Claude | Wrote the step-by-step build plan (steps 0–12) | [BUILD_PLAN.md](BUILD_PLAN.md), D-020 |
| 27 | Claude | Re-copied `docs/` and `architecture/` to the Drive folder | Drive copy in sync |
| 28 | Group | Asked for diagram changes; agreed on 5 sources; replaced Airflow by Snowflake Tasks | D-021 decided, D-022, D-023 |
| 29 | Claude | Read the teacher's Snowflake Tasks example (resource pack `06-orchestration-and-docker/snowflake-tasks/daily_pipeline_tasks.sql`) before redrawing | Pattern used in D-022 |
| 30 | Claude | Redrew the diagram v2: 5 sources + seed, 4 ingestion methods, Tasks bar, labels without parentheses, Excel logo (Simple Icons 10.0.0), faded dashed HTML box. Removed the Airflow logo file. Checked the preview in the browser | [architecture/](../architecture/) |
| 31 | Claude | Updated UC1 (how Postgres data arrives) and the build plan (API step 7b, Tasks in step 10) | [USE_CASES.md](USE_CASES.md), [BUILD_PLAN.md](BUILD_PLAN.md) |
| 32 | Claude | Step 0: checked the laptop. Installed: git, GitHub CLI (logged in as khaledngr), Terraform 1.17, Docker 29, psql 16, Python 3.13, Snowflake connector. Missing: Google Cloud CLI (`gcloud`) | Step 0 in progress |
| 33 | Claude | Step 0: queried the TD Snowflake account with its existing key login (no secret printed): region `AWS_EU_WEST_3` | D-024: new trial on GCP needed |
| 34 | Group | Discussed GCP vs AWS after the region check; chose to switch the whole project to AWS and keep the existing Snowflake account | D-025 (replaces D-007, D-024) |
| 35 | Claude | Read the teacher's AWS Terraform example (resource pack `09-iac/aws/main.tf`, `09-iac/README.md`) | Reused in build plan step 3 |
| 36 | Claude | Diagram v3: GCS → S3, Google logos → AWS and S3 logos (Simple Icons 13.21.0), AWS budget alert, label logos moved inside their boxes. Checked the preview | [architecture/](../architecture/) |
| 37 | Claude | Replaced GCP by AWS in the build plan, requirements and TD inventory | Docs consistent with D-025 |
| 38 | Claude | Re-copied `docs/` and `architecture/` to the Drive folder (removed the Google logo files there) | Drive copy in sync |
| 39 | Group | Reconsidered AWS after Claude explained the options (all Google / all AWS / mixed); went back to GCP | D-026 |
| 40 | Robin | Created the new Snowflake trial on GCP, region Frankfurt (`europe-west3`), user ROBINCCR | Account `NVTLKDO-RP44213` |
| 41 | Claude | In the browser pane, opened a SQL file in the new account and ran one read-only query (`CURRENT_REGION`, identifier, user, role) | Confirmed `GCP_EUROPE_WEST3` |
| 42 | Claude | Diagram v4 back on Google Cloud (GCS, Google logos, Frankfurt label, "SNOWFLAKE" label without hosting text); docs switched back from AWS | [architecture/](../architecture/), docs consistent with D-026 |
| 43 | Claude | Wrote the team access plan (Snowflake users and roles, GCP members, GitHub collaborators) | D-027 proposed |
| 44 | Claude | Re-copied `docs/` and `architecture/` to the Drive folder (Google logos back, AWS logos removed) | Drive copy in sync |
| 45 | Group | Approved the access plan and the repo name `datathlon`; gave GitHub usernames `rcacarie-png` (Robin), `rcausel-a11y` (Rudy) | D-027 decided |
| 46 | Claude | Added `.gitignore` (secrets, Terraform state, dbt/Python outputs), `git init`, first commit `b0bcd22` | Local repo |
| 47 | Claude | Created private GitHub repo `khaledngr/datathlon`; SSH push failed (port 22 blocked on this network), pushed over HTTPS with the GitHub CLI login | https://github.com/khaledngr/datathlon |
| 48 | Claude | Invited Robin and Rudy as collaborators (write); protected `main` (pull request required, no force push, no deletion) | Invitations pending acceptance |
| 49 | Claude | Tried to create the Snowflake users in the browser pane; blocked by the safety check (granting ACCOUNTADMIN). Wrote the SQL as a script for an admin to run | [snowflake/setup/00_team_users.sql](../snowflake/setup/00_team_users.sql) |
| 50 | Group | Gave the GCP project: `datathlon-513514`, on Robin's account | D-027 updated |
| 51 | Claude | Wrote the GCP access steps for Robin (IAM roles for Khaled and Rudy, budget, checks) | [gcp/setup/00_team_access.md](../gcp/setup/00_team_access.md) |
| 52 | Claude | Installed the Google Cloud CLI with Homebrew (`brew install --cask google-cloud-sdk`), after the group's OK: Google Cloud SDK 591.0.0. No account signed in yet | `gcloud` ready; Khaled signs in himself |
| 53 | Khaled | Signed in to Google Cloud on the laptop (`gcloud auth login`), project `datathlon-513514` selected | `gcloud` working |
| 54 | Robin + Claude | IAM fixed in 4 checks: first Robin picked "IAM Admin" + "IAM Editor" (only manage service accounts and permissions, no buckets); Claude tested the permissions each time and explained the right roles | Now: Khaled = Editor + Project IAM Admin, Rudy = Editor, Robin = Owner |
| 55 | Robin | Created a billing account (type "Particulier") and linked it to the project | Linked (`014D04-0E9313-35FE88`) but `billingEnabled = False` at last check: account not active yet |
