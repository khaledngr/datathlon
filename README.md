# Datathlon · Group 8 data pipeline

Group project for **Data Engineering & Cloud Infrastructure** (Albert School, Laura Belmond).
We play the data engineering team of **Datathlon**, a fictional omnichannel sports retailer (an obvious Decathlon parody), and present its data pipeline to the CDO.

- **Team:** Khaled Elnagar, Robin, Rudy
- **Upload deadline:** Wed 4 Nov 2026 (slides, architecture, Git link, ~30 s pipeline video)
- **Oral defense:** Fri 6 Nov 2026, 11:30, 15 min

## Where things are

| Folder / file | What it holds |
| --- | --- |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Every decision: what we chose, why, what we rejected |
| [docs/JOURNAL.md](docs/JOURNAL.md) | Every action, in order, with the date |
| [docs/USE_CASES.md](docs/USE_CASES.md) | The use cases (decided first, tools follow) |
| [docs/BUILD_PLAN.md](docs/BUILD_PLAN.md) | The build, step by step, with owners and checks |
| [architecture/](architecture/) | Architecture diagram (Excalidraw + SVG preview) and the script that draws it |
| [docs/TD_INVENTORY.md](docs/TD_INVENTORY.md) | What each TD already built and how we reuse it |
| [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | Project rules and the grading matrix |
| [brand/](brand/) | Logo files, colors, fonts ([brand-sheet.html](brand/brand-sheet.html)) |

Code folders (ingestion, dbt, Airflow, Terraform) will be added as we build them.

## Working rules

1. **Use cases first, tools second.** The stack follows the use cases and will change as they do.
2. **TD stack first.** We reuse and adapt what we built in the TDs, because we understand it and can defend it. A new tool needs a reason in `DECISIONS.md`.
3. **Document as we go.** Every choice goes in `DECISIONS.md`, every action in `JOURNAL.md`, at the moment it happens.
