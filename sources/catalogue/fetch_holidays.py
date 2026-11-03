"""Datathlon · save the holiday calendar the generators follow (FR, BE, ES, 1 Sep - 31 Dec 2026).

Source: OpenHolidays API (openholidaysapi.org, free, no key): school holidays + public holidays.
The fake orders, till sales and stock are shaped around these dates, so that the real holiday data loaded by the
pipeline (step 7b) lines up with the sales in the dashboard: the effect of school holidays must be visible.

  python sources/catalogue/fetch_holidays.py     # writes sources/catalogue/holidays.csv

`share` = part of the country concerned. France: mainland zones only (overseas excluded). Belgium: the French- and
Dutch-speaking communities have different autumn breaks, so each counts for half. Spain: national holidays only.
"""
import csv
import json
import urllib.request
from pathlib import Path

API = "https://openholidaysapi.org/{kind}?countryIsoCode={country}&languageIsoCode=EN&validFrom=2026-09-01&validTo=2026-12-31"
OUT = Path(__file__).with_name("holidays.csv")
OVERSEAS_FR = {"RU", "GP", "MQ", "GF", "YT", "BL", "MF", "PM", "WF", "PF", "NC"}


def get(kind, country):
    with urllib.request.urlopen(API.format(kind=kind, country=country), timeout=30) as r:
        return json.load(r)


rows = {}
for country in ("FR", "BE", "ES"):
    for kind, label in (("SchoolHolidays", "school"), ("PublicHolidays", "public")):
        for h in get(kind, country):
            subs = {s["shortName"] for s in h.get("subdivisions", [])}
            if label == "public" and not h.get("nationwide"):
                continue  # regional public holidays (Alsace, Spanish regions...) are left out
            if label == "school" and (country == "ES" or (country == "FR" and subs <= OVERSEAS_FR)):
                continue  # Spain: regional calendars only; France: overseas-only breaks
            share = 0.5 if country == "BE" and label == "school" and h["startDate"] < "2026-12-01" else 1.0
            key = (country, label, h["startDate"], h["endDate"])
            rows[key] = {"country": country, "type": label, "start_date": h["startDate"], "end_date": h["endDate"],
                         "name": h["name"][0]["text"], "share": share}

with open(OUT, "w", newline="", encoding="utf-8") as fh:
    w = csv.DictWriter(fh, fieldnames=["country", "type", "start_date", "end_date", "name", "share"])
    w.writeheader()
    w.writerows(sorted(rows.values(), key=lambda r: (r["country"], r["start_date"], r["type"])))
print(f"{len(rows)} holidays written to {OUT}")
