"""Datathlon · API pull (step 7b): real weather (Open-Meteo) and real holidays (OpenHolidays) -> GCS -> BRONZE.
Adapted from the resource pack 05-ingestion-methods/snowflake/05_api_to_snowflake.py: the API answer is kept as it
is (raw JSON), only an envelope is added (source, url, store or country, fetch time). Cleaning is dbt's job (step 8).

  python ingestion/api_pull/pull_apis.py                   # today's run: weather + holidays
  python ingestion/api_pull/pull_apis.py --date 2026-11-02 # the run of another day (backfill)
  python ingestion/api_pull/pull_apis.py --timeout 0.001   # incident demo: the API is too slow -> loud failure

Weather: one call per store (sources/catalogue/stores.csv), daily max/min temperature, rain and wind, from 1 Sep 2026
(the first day of the fake sales) to 7 days after the run: past days are measured, the next 7 days are the forecast.
Holidays: school + public holidays of FR, BE, ES, 1 Sep - 31 Dec 2026, the same API and dates as
sources/catalogue/holidays.csv, which the sales generators follow (D-033).

Files: gs://<GCS_LANDING_BUCKET>/api/{weather,holidays}/YYYY/MM/DD/<name>.json, one JSON line per API call
(a copy stays in data/landing/, git-ignored). Then snowflake/stages/04_api.sql loads them with COPY INTO.
Re-running the same day adds no duplicates: a run whose files are already in the bucket stops before calling the
APIs (--force replaces them), and COPY INTO never loads the same file twice.
Fails loudly: timeout on every call, 3 tries with a growing pause, then the job exits with an error and uploads nothing.
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from dotenv import load_dotenv

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "sources" / "catalogue"))
from demand import read_csv  # noqa: E402  shared catalogue reader

load_dotenv(REPO / ".env")

FIRST_DAY = date(2026, 9, 1)      # first day of the fake sales: the weather history starts here
FORECAST_DAYS = 7
HOLIDAYS_TO = date(2026, 12, 31)  # same window as sources/catalogue/holidays.csv
COUNTRIES = ("FR", "BE", "ES")
WEATHER_API = "https://api.open-meteo.com/v1/forecast"
HOLIDAYS_API = "https://openholidaysapi.org/{kind}"
TRIES = 3
LOCAL_DIR = REPO / "data" / "landing"


def get_json(url, params, timeout):
    """GET with a timeout and 3 tries (pause 2 s, then 4 s). Errors that will not go away (4xx) fail at once."""
    full_url = f"{url}?{urllib.parse.urlencode(params)}"
    for attempt in range(1, TRIES + 1):
        try:
            with urllib.request.urlopen(full_url, timeout=timeout) as r:
                return full_url, json.load(r)
        except urllib.error.HTTPError as e:
            if e.code < 500 and e.code != 429:
                raise SystemExit(f"FAILED {full_url}: HTTP {e.code}, not retried")
            error = f"HTTP {e.code}"
        except (urllib.error.URLError, TimeoutError) as e:
            error = str(getattr(e, "reason", e))
        print(f"  try {attempt}/{TRIES} failed ({error}): {full_url}")
        if attempt < TRIES:
            time.sleep(2 * attempt)
    raise SystemExit(f"FAILED after {TRIES} tries: {full_url}")


def envelope(source, url, run_date, response, **keys):
    return {"source": source, "url": url, "run_date": run_date.isoformat(),
            "fetched_at": datetime.now(timezone.utc).isoformat(timespec="seconds"), **keys, "response": response}


def weather(run_date, timeout):
    lines = []
    for s in read_csv("stores.csv"):
        url, resp = get_json(WEATHER_API, {
            "latitude": s["latitude"], "longitude": s["longitude"],
            "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max",
            "timezone": "Europe/Paris" if s["country"] != "ES" else "Europe/Madrid",
            "start_date": FIRST_DAY.isoformat(), "end_date": (run_date + timedelta(FORECAST_DAYS)).isoformat(),
        }, timeout)
        lines.append(envelope("open-meteo", url, run_date, resp, store_id=s["store_id"], city=s["city"]))
        print(f"  weather {s['store_id']}: {len(resp['daily']['time'])} days")
    return {"weather/stores": lines}


def holidays(run_date, timeout):
    lines = []
    for country in COUNTRIES:
        for kind in ("SchoolHolidays", "PublicHolidays"):
            url, resp = get_json(HOLIDAYS_API.format(kind=kind), {
                "countryIsoCode": country, "languageIsoCode": "EN",
                "validFrom": FIRST_DAY.isoformat(), "validTo": HOLIDAYS_TO.isoformat(),
            }, timeout)
            lines.append(envelope("openholidays", url, run_date, resp, country=country, kind=kind))
            print(f"  holidays {country} {kind}: {len(resp)} periods")
    return {"holidays/calendar": lines}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--date", type=date.fromisoformat, default=date.today(), help="run date (default: today)")
    ap.add_argument("--timeout", type=float, default=30, help="seconds per API call")
    ap.add_argument("--force", action="store_true", help="replace the files of this run if they exist")
    a = ap.parse_args()

    from google.cloud import storage  # Google sign-in: gcloud auth application-default login
    gcs = storage.Client(project=os.environ["GCP_PROJECT_ID"]).bucket(os.environ["GCS_LANDING_BUCKET"])
    names = {k: f"api/{k.split('/')[0]}/{a.date:%Y/%m/%d}/{k.split('/')[1]}_{a.date:%Y%m%d}.json"
             for k in ("weather/stores", "holidays/calendar")}
    todo = [k for k, n in names.items() if a.force or not gcs.blob(n).exists()]  # a half-done run only redoes what is missing
    if not todo:
        print(f"Run {a.date} already in the bucket ({len(names)} files): nothing to do. --force replaces them.")
        return

    print(f"API pull, run {a.date}" + ("" if len(todo) == len(names) else f", only {', '.join(todo)} (the rest is already in the bucket)"))
    pulls = {"weather/stores": weather, "holidays/calendar": holidays}
    files = {}
    for key in todo:  # every call succeeds before any upload
        files.update(pulls[key](a.date, a.timeout))
    for key, lines in files.items():
        path = LOCAL_DIR / names[key]
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("".join(json.dumps(line, ensure_ascii=False) + "\n" for line in lines), encoding="utf-8")
        gcs.blob(names[key]).upload_from_filename(str(path), content_type="application/x-ndjson")
        print(f"Uploaded gs://{gcs.name}/{names[key]} ({len(lines)} lines)")


if __name__ == "__main__":
    main()
