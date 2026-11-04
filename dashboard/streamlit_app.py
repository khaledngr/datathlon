"""Datathlon · the GOLD dashboard (step 11, D-016), adapted from the resource pack 08-visualisation/streamlit.

  .venv/bin/streamlit run dashboard/streamlit_app.py      # on the laptop: http://localhost:8501

Reads GOLD only, as the read-only role DATATHLON_ANALYST on the warehouse DATATHLON_BI_WH (snowflake_session.py).
Same rules as the pack's README: each title is the use case's question, freshness and source table shown, queries
cached 10 minutes so the dashboard does not burn credits. Inside Snowflake (Streamlit in Snowflake) the same file uses
the session Snowflake gives it.
Inside Snowflake: app DATATHLON.APPS.DATATHLON_DASHBOARD, deployed by dashboard/deploy_to_snowflake.py (D-044).
"""
from datetime import timedelta
from pathlib import Path

import altair as alt
import pandas as pd
import streamlit as st

HERE = Path(__file__).resolve().parent
GOLD = "DATATHLON.GOLD"
BLUE, NAVY, MINT, SKY, MUTED = "#3946C0", "#101A4E", "#8EF5B5", "#E8ECFF", "#5A6390"  # brand/brand-sheet.html
CHANNEL_COLORS = alt.Scale(domain=["store", "web"], range=[NAVY, BLUE])


# ---------- data ----------
@st.cache_resource
def session():
    try:
        from snowflake.snowpark.context import get_active_session  # running inside Snowflake
        return get_active_session()
    except Exception:
        from snowflake_session import connect                       # running on a laptop
        return connect()


@st.cache_data(ttl=600)  # re-query at most every 10 minutes
def load(sql):
    s = session()
    if hasattr(s, "sql"):
        df = s.sql(sql).to_pandas()
    else:
        with s.cursor() as cur:
            cur.execute(sql)
            df = pd.DataFrame(cur.fetchall(), columns=[d[0] for d in cur.description])
    df.columns = [c.lower() for c in df.columns]
    for c in df.columns:  # Snowflake NUMBER arrives as Decimal: charts need floats
        if df[c].dtype == object and len(df) and type(df[c].dropna().iloc[0]).__name__ == "Decimal":
            df[c] = df[c].astype(float)
    return df


def holiday_layer(holidays, start, end):
    """Shaded holiday periods (mint), drawn behind a time chart."""
    h = holidays[(holidays.end_date >= start) & (holidays.start_date <= end)].copy()
    h["from"] = pd.to_datetime(h.start_date.clip(lower=start))
    h["to"] = pd.to_datetime(h.end_date.clip(upper=end) + timedelta(days=1))  # end day included
    return alt.Chart(h).mark_rect(color=MINT, opacity=0.35).encode(
        x="from:T", x2="to:T",
        tooltip=[alt.Tooltip("country:N", title="Country"), alt.Tooltip("holiday_name:N", title="Holiday"),
                 alt.Tooltip("start_date:T", title="From"), alt.Tooltip("end_date:T", title="To")])


def source(*tables):
    st.caption("Source: " + " · ".join(f"`{GOLD}.{t}`" for t in tables) + " (gold layer, rebuilt every day at 06:00)")


# ---------- page ----------
st.set_page_config(page_title="Datathlon · sales and stock", page_icon=str(HERE / "assets" / "datathlon-mark.png"),
                   layout="wide")
st.markdown("""<style>
@import url('https://fonts.googleapis.com/css2?family=Barlow+Condensed:ital,wght@1,800&family=Inter:wght@400;600&display=swap');
html, body, [class*="css"] { font-family: Inter, sans-serif; }
h1, h2, h3 { font-family: "Barlow Condensed", sans-serif !important; font-style: italic; text-transform: uppercase; }
</style>""", unsafe_allow_html=True)

sales = load(f"SELECT sales_date, channel, country, category, units, revenue_eur FROM {GOLD}.GOLD_SALES_DAILY")
holidays_all = load(f"SELECT country, holiday_type, start_date, end_date, holiday_name, share FROM {GOLD}.GOLD_HOLIDAYS")
# converted in SQL: the laptop connector and Snowpark return time zones differently
built = load("""SELECT CONVERT_TIMEZONE('Europe/Paris', MAX(last_altered))::TIMESTAMP_NTZ AS built
                FROM DATATHLON.INFORMATION_SCHEMA.TABLES
                WHERE table_schema = 'GOLD' AND table_name LIKE 'GOLD_%'""")
for df, cols in ((sales, ["sales_date"]), (holidays_all, ["start_date", "end_date"])):
    for c in cols:
        df[c] = pd.to_datetime(df[c]).dt.date

# both channels from the first web order: a few late till events (is_late_event) are dated 30-31 Aug, kept in gold
first_day = sales[sales.channel == "web"].sales_date.min()
last_day = sales.sales_date.max()

with st.sidebar:
    st.image(str(HERE / "assets" / "datathlon-logo.png"), width="stretch")
    countries = st.multiselect("Countries", ["FR", "BE", "ES"], default=["FR", "BE", "ES"])
    start, end = st.slider("Days", min_value=first_day, max_value=last_day, value=(first_day, last_day),
                           format="DD MMM")
    st.caption("Shaded in mint: school holidays of the selected countries (OpenHolidays API).")

if not countries:
    st.warning("Pick at least one country.")
    st.stop()

holidays = holidays_all[holidays_all.country.isin(countries) & (holidays_all.holiday_type == "school")]
st.title("Datathlon · daily sales and stock")
built_at = pd.Timestamp(built.built.iloc[0])
st.caption(f"Data up to **{last_day:%a %d %b %Y}** (complete days only) · gold tables built "
           f"{built_at:%d %b %H:%M} Paris · read-only role `DATATHLON_ANALYST`, warehouse `DATATHLON_BI_WH`")

tab_sales, tab_stock, tab_quality = st.tabs(["UC1 · Sales", "UC2 · Stock alerts", "Data quality"])

# ---------- UC1 ----------
with tab_sales:
    st.header("Which categories and channels should next week's promotions push?")
    view = sales[sales.country.isin(countries) & sales.sales_date.between(start, end)].copy()

    # a day x country is a "holiday day" when the country is on school holidays (Belgium: one community out of two)
    def on_holiday(row):
        h = holidays[(holidays.country == row.country) & (holidays.start_date <= row.sales_date)
                     & (holidays.end_date >= row.sales_date)]
        return not h.empty
    view["period"] = view.apply(on_holiday, axis=1).map({True: "school holidays", False: "other days"})

    revenue, units = view.revenue_eur.sum(), view.units.sum()
    web_share = view[view.channel == "web"].revenue_eur.sum() / revenue if revenue else 0
    per_day = view.groupby(["period", "sales_date"]).revenue_eur.sum().groupby("period").mean()
    uplift = per_day.get("school holidays", 0) / per_day.get("other days", 1) - 1 if "other days" in per_day else 0
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Paid revenue", f"€{revenue:,.0f}")
    c2.metric("Units sold", f"{units:,.0f}")
    c3.metric("Web share of revenue", f"{web_share:.0%}")
    c4.metric("Revenue per day in school holidays", f"{uplift:+.0%}", help="vs other days, same countries and dates")

    daily = view.groupby(["sales_date", "channel"], as_index=False).revenue_eur.sum()
    daily["sales_date"] = pd.to_datetime(daily.sales_date)
    st.subheader("Revenue per day, store and web")
    # one chart per channel, each with its own scale: stores sell ~9x the web, one scale would flatten the web line
    for col, channel in zip(st.columns(2), ["store", "web"]):
        line = alt.Chart(daily[daily.channel == channel]).mark_line(strokeWidth=2.5, color=CHANNEL_COLORS.range[
            CHANNEL_COLORS.domain.index(channel)]).encode(
            x=alt.X("sales_date:T", title=None), y=alt.Y("revenue_eur:Q", title=f"{channel.title()} revenue (€)"),
            tooltip=[alt.Tooltip("sales_date:T", title="Day"),
                     alt.Tooltip("revenue_eur:Q", title="Revenue €", format=",.0f")])
        col.altair_chart(holiday_layer(holidays, start, end) + line, use_container_width=True)

    st.subheader("Which categories sell more in the school holidays?")
    cat = (view.groupby(["category", "period", "sales_date"]).units.sum()
               .groupby(["category", "period"]).mean().unstack("period").fillna(0))
    if {"school holidays", "other days"} <= set(cat.columns):
        cat["uplift"] = cat["school holidays"] / cat["other days"] - 1
        cat = cat.reset_index().sort_values("uplift", ascending=False)
        st.altair_chart(alt.Chart(cat).mark_bar(color=BLUE).encode(
            x=alt.X("uplift:Q", title="Units per day in school holidays vs other days", axis=alt.Axis(format="+%")),
            y=alt.Y("category:N", sort="-x", title=None),
            color=alt.condition("datum.uplift > 0", alt.value(BLUE), alt.value(MUTED)),
            tooltip=["category:N", alt.Tooltip("uplift:Q", format="+.0%"),
                     alt.Tooltip("school holidays:Q", title="Units/day in holidays", format=".0f"),
                     alt.Tooltip("other days:Q", title="Units/day otherwise", format=".0f")]),
            use_container_width=True)
    else:
        st.info("Pick dates that include school holidays and other days to compare.")

    st.subheader(f"Last 7 days ({max(start, end - timedelta(days=6)):%d %b} → {end:%d %b}) by category and channel")
    week = view[view.sales_date > end - timedelta(days=7)]
    table = week.pivot_table(index="category", columns="channel", values="revenue_eur", aggfunc="sum", fill_value=0)
    table["total"] = table.sum(axis=1)
    st.dataframe(table.sort_values("total", ascending=False).style.format("€{:,.0f}"), width="stretch")
    source("GOLD_SALES_DAILY", "GOLD_HOLIDAYS")

# ---------- UC2 ----------
with tab_stock:
    st.header("What should we restock, in which store, before it runs out?")
    stock = load(f"""SELECT snapshot_date, store_id, store_city, country, sku, product_name, category, on_hand,
                            avg_daily_units_7d, days_of_cover, is_alert
                     FROM {GOLD}.GOLD_STOCK_COVER_DAILY""")
    stock["snapshot_date"] = pd.to_datetime(stock.snapshot_date).dt.date
    sview = stock[stock.country.isin(countries) & stock.snapshot_date.between(start, end)]
    if sview.empty:
        st.info("No stock count in these dates (the 7-day cover starts on the 7th day of data).")
    else:
        per_day = sview.groupby("snapshot_date").is_alert.sum().sort_index(ascending=False)
        day = st.selectbox("Night count", per_day.index, format_func=lambda d: f"{d:%a %d %b} · {per_day[d]} alerts",
                           help="Latest count first: that is the list the stores act on this morning")
        today = sview[sview.snapshot_date == day]
        alerts = today[today.is_alert].sort_values("days_of_cover")
        c1, c2, c3 = st.columns(3)
        c1.metric(f"Alerts on {day:%d %b}", f"{len(alerts)}", help="store x product with less than 3 days of cover")
        c2.metric("Share of shelves in alert", f"{len(alerts) / len(today):.0%}")
        c3.metric("Stores counted", f"{today.store_id.nunique()}", help="FR and BE stores are closed on Sunday")

        st.subheader(f"Restock list, night count of {day:%a %d %b}")
        if alerts.empty:
            st.success("No product under 3 days of cover.")
        else:
            st.dataframe(alerts[["store_city", "product_name", "category", "on_hand", "avg_daily_units_7d",
                                 "days_of_cover"]].rename(columns={
                             "store_city": "Store", "product_name": "Product", "category": "Category",
                             "on_hand": "On hand", "avg_daily_units_7d": "Sold per day (7 d)",
                             "days_of_cover": "Days of cover"}),
                         width="stretch", hide_index=True)

        # counts, not shares: on Sunday only the Spanish stores count, a share would jump for nothing.
        # Deliveries come on Monday and Thursday, so alerts build up towards Wednesday and Saturday.
        st.subheader("Alerts per night count, per category")
        trend = sview[sview.is_alert].groupby(["snapshot_date", "category"], as_index=False).size()
        trend["snapshot_date"] = pd.to_datetime(trend.snapshot_date)
        st.altair_chart(holiday_layer(holidays, start, end) + alt.Chart(trend).mark_bar().encode(
            x=alt.X("yearmonthdate(snapshot_date):T", title=None),
            y=alt.Y("size:Q", title="Store x product under 3 days of cover"),
            color=alt.Color("category:N", title="Category", scale=alt.Scale(scheme="tableau10")),
            tooltip=[alt.Tooltip("snapshot_date:T", title="Day"), "category:N", alt.Tooltip("size:Q", title="Alerts")]),
            use_container_width=True)
    source("GOLD_STOCK_COVER_DAILY", "GOLD_HOLIDAYS")

# ---------- data quality ----------
with tab_quality:
    st.header("Can we trust the store sales figures?")
    quality = load(f"SELECT * FROM {GOLD}.GOLD_DATA_QUALITY_DAILY")
    quality["file_date"] = pd.to_datetime(quality.file_date).dt.date
    qview = quality[quality.file_date.between(start, end)]
    st.caption("All stores: the till feed is checked before any country filter.")
    raw, quarantined = qview.raw_lines.sum(), qview.quarantine_lines.sum()
    c1, c2, c3 = st.columns(3)
    c1.metric("Till lines received", f"{raw:,}")
    c2.metric("Quarantined (kept out of the figures)", f"{quarantined / raw:.1%}" if raw else "–",
              help=f"{quarantined:,} lines")
    c3.metric("Prices fixed (sent in cents)", f"{qview.price_fixed_from_cents.sum():,}")

    st.subheader("Quarantined lines per day, by reason")
    reasons = [c for c in qview.columns if c.startswith("q_")]
    by_reason = qview.groupby("file_date", as_index=False)[reasons].sum().melt(
        "file_date", var_name="reason", value_name="lines")
    by_reason = by_reason[by_reason.lines > 0]
    by_reason["reason"] = by_reason.reason.str[2:].str.replace("_", " ")
    by_reason["file_date"] = pd.to_datetime(by_reason.file_date)
    st.altair_chart(alt.Chart(by_reason).mark_bar().encode(
        x=alt.X("file_date:T", title=None), y=alt.Y("lines:Q", title="Quarantined lines"),
        color=alt.Color("reason:N", title="Reason", scale=alt.Scale(scheme="tableau10")),
        tooltip=[alt.Tooltip("file_date:T", title="Day"), "reason:N", "lines:Q"]), use_container_width=True)

    st.subheader("Prices sent in cents, fixed by dbt, per day and store")
    cents = qview[qview.price_fixed_from_cents > 0].copy()
    cents["file_date"] = pd.to_datetime(cents.file_date)
    st.altair_chart(alt.Chart(cents).mark_bar().encode(
        x=alt.X("yearmonthdate(file_date):T", title=None), y=alt.Y("price_fixed_from_cents:Q", title="Prices fixed"),
        color=alt.Color("store_id:N", title="Store", scale=alt.Scale(scheme="tableau10")),
        tooltip=[alt.Tooltip("file_date:T", title="Day"), alt.Tooltip("store_id:N", title="Store"),
                 alt.Tooltip("price_fixed_from_cents:Q", title="Prices fixed"),
                 alt.Tooltip("raw_lines:Q", title="Lines received")]), use_container_width=True)

    # 1 or 2 lines a day in cents is the feed's usual noise; a store sending most of its day in cents is an incident
    incidents = qview[qview.price_fixed_from_cents > 0.1 * qview.raw_lines].sort_values("file_date")
    st.subheader("Incidents: a store sent more than 10 % of its day in cents")
    st.dataframe(incidents[["file_date", "store_id", "raw_lines", "price_fixed_from_cents", "quarantine_pct"]].rename(
        columns={"file_date": "Day", "store_id": "Store", "raw_lines": "Lines received",
                 "price_fixed_from_cents": "Prices fixed by dbt", "quarantine_pct": "% quarantined"}),
        width="stretch", hide_index=True)
    source("GOLD_DATA_QUALITY_DAILY")
