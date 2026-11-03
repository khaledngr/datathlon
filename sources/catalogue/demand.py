"""Datathlon · shared demand rules for every generator (web orders, store tills, stock), D-033.

One place for the story the dashboard must show, so all sources follow the same calendar:
school holidays +60 % (x share of the country), the week before +30 %, public holiday +40 % (web) / -30 % (stores,
many close), back to school 1-14 Sep +30 %; outdoor categories up in holidays, team sports and swimming at back to
school. Weekends differ by channel: French and Belgian stores are closed on Sunday, so people buy online instead.
"""
import csv
from datetime import date, timedelta
from pathlib import Path

CATALOGUE = Path(__file__).resolve().parent

HOLIDAY_CATEGORIES = {"Hiking": 2.5, "Cycling": 2.0, "Swimming": 2.0}   # outdoor and family trips
BACK_TO_SCHOOL_CATEGORIES = {"Team sports": 2.5, "Swimming": 2.0}      # club sign-ups in September
BASE_CATEGORY_WEIGHT = {"Running": 3, "Hiking": 3, "Fitness": 2}        # others 1

WEEKDAY_FACTOR = {  # Monday = 0 ... Sunday = 6
    "web": {5: 1.6, 6: 1.3},
    "store": {5: 1.8, 6: 0.0},             # Sunday closed (France, Belgium)
    "store_ES": {5: 1.8, 6: 1.2},          # Spanish stores open on Sunday
}
SUNDAY_CLOSED = {"FR", "BE"}


def read_csv(name):
    with open(CATALOGUE / name, newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def load_holidays():
    return [{**h, "start": date.fromisoformat(h["start_date"]), "end": date.fromisoformat(h["end_date"]),
             "share": float(h["share"])} for h in read_csv("holidays.csv")]


def demand(day, country, holidays, channel="web"):
    """How busy one channel is in one country on one day (factor x normal weekday), and which categories gain."""
    weekdays = WEEKDAY_FACTOR["store_ES" if channel == "store" and country not in SUNDAY_CLOSED else channel]
    factor = weekdays.get(day.weekday(), 1.0)
    category_boost = {}
    for h in (h for h in holidays if h["country"] == country):
        if h["type"] == "school" and h["start"] <= day <= h["end"]:
            factor *= 1 + 0.6 * h["share"]
            category_boost = HOLIDAY_CATEGORIES
        elif h["type"] == "school" and h["start"] - timedelta(days=7) <= day < h["start"]:
            factor *= 1 + 0.3 * h["share"]
            category_boost = HOLIDAY_CATEGORIES
        elif h["type"] == "public" and day == h["start"]:
            factor *= 1.4 if channel == "web" else 0.7
    if date(day.year, 9, 1) <= day <= date(day.year, 9, 14):
        factor *= 1.3
        category_boost = BACK_TO_SCHOOL_CATEGORIES
    return factor, category_boost


def product_weights(products, category_boost):
    """Relative chance of each product being bought, given the day's category boost."""
    return [BASE_CATEGORY_WEIGHT.get(p["category"], 1) * category_boost.get(p["category"], 1) for p in products]
