"""Datathlon · the GOLD dashboard (step 11, D-016), adapted from the resource pack 08-visualisation/streamlit.

  .venv/bin/streamlit run dashboard/streamlit_app.py      # on the laptop: http://localhost:8501

Reads GOLD only, as the read-only role DATATHLON_ANALYST on the warehouse DATATHLON_BI_WH (snowflake_session.py).
Same rules as the pack's README: each title is the use case's question, freshness and source table shown, queries
cached 10 minutes so the dashboard does not burn credits. Inside Snowflake (Streamlit in Snowflake) the same file uses
the session Snowflake gives it.
Inside Snowflake: app DATATHLON.APPS.DATATHLON_DASHBOARD, deployed by dashboard/deploy_to_snowflake.py (D-046).

Each tab opens on a one-line answer (green / orange / red box) computed from the data, then the charts behind it.
Week-on-week deltas: managers decide promotions weekly (UC1), so the trend matters more than the total.
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
ALERT_DAYS = 3  # the UC2 rule: is_alert in gold = less than 3 days of cover
INCIDENT_SHARE = 0.10  # a store sending more than 10 % of its day's prices in cents: an incident, not noise
CENTS_LEVELS = {"none": "#F1F2F8",                                   # level -> colour of the store x day grid
                "up to 10 % (usual noise, stray lines)": "#CDD2F2",  # pale on purpose: only red should catch the eye
                "over 10 % (incident: the store's tills send cents)": "#C0392B"}
# UC1 has two metrics. The chosen one drives the daily lines, the holiday uplift, the last-7-days table and the titles.
# (No "average basket": a till line is one product, so gold has no store ticket to divide by.)
METRICS = {"Revenue €": ("revenue_eur", "revenue (€)", "€{:,.0f}", ",.0f"),
           "Units": ("units", "units", "{:,.0f}", ",.0f")}


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


# ---------- helpers ----------
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


def week_windows(start, end):
    """(last 7 days, the 7 days before) as (first, last) pairs, end included; the second is None when the selected
    dates do not hold 14 days, so a half-empty week is never compared with a full one."""
    current = (end - timedelta(days=6), end)
    previous = (end - timedelta(days=13), end - timedelta(days=7))
    return current, previous if previous[0] >= start else None


def delta(current, previous):
    """Relative change, None when there is nothing to compare with."""
    if previous is None or pd.isna(previous) or previous == 0 or pd.isna(current):
        return None
    return current / previous - 1


def legend_filter(field):
    """Click a legend entry to keep that series in colour and fade the others (shift-click adds more)."""
    sel = alt.selection_point(fields=[field], bind="legend")
    return sel, alt.condition(sel, alt.value(1), alt.value(0.15))


def incidents_of(quality):
    # 1 or 2 lines a day in cents is the feed's usual noise; a store sending most of its day in cents is an incident
    return quality[quality.price_fixed_from_cents > INCIDENT_SHARE * quality.raw_lines].sort_values("file_date")


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
# cover_exact: the same formula as is_alert in gold, before days_of_cover is rounded to 0.1 (2.96 shows 3.0 but is an
# alert), so a threshold of 3 days gives exactly gold's alerts
stock = load(f"""SELECT snapshot_date, store_id, store_city, country, sku, product_name, category, on_hand, received,
                        emergency, avg_daily_units_7d, days_of_cover, is_alert,
                        on_hand / NULLIF(units_sold_7d / 7, 0) AS cover_exact
                 FROM {GOLD}.GOLD_STOCK_COVER_DAILY""")
quality = load(f"SELECT * FROM {GOLD}.GOLD_DATA_QUALITY_DAILY")
# converted in SQL: the laptop connector and Snowpark return time zones differently
built = load("""SELECT CONVERT_TIMEZONE('Europe/Paris', MAX(last_altered))::TIMESTAMP_NTZ AS built
                FROM DATATHLON.INFORMATION_SCHEMA.TABLES
                WHERE table_schema = 'GOLD' AND table_name LIKE 'GOLD_%'""")
for df, cols in ((sales, ["sales_date"]), (holidays_all, ["start_date", "end_date"]), (stock, ["snapshot_date"]),
                 (quality, ["file_date"])):
    for c in cols:
        df[c] = pd.to_datetime(df[c]).dt.date

first_day, last_day = sales.sales_date.min(), sales.sales_date.max()  # gold holds complete days only (D-040)

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

# What the stores and the data team look at first at 06:00, visible from every tab: the latest night count with the
# UC2 rule, and the latest till file. Not tied to the date slider: it is always "this morning".
with st.sidebar:
    st.subheader("This morning")
    latest = stock[stock.country.isin(countries)]
    if not latest.empty:
        latest = latest[latest.snapshot_date == latest.snapshot_date.max()]
        alerts_now = latest[latest.is_alert]
        if alerts_now.empty:
            st.success(f"Night count {latest.snapshot_date.iloc[0]:%a %d %b}: no shelf under {ALERT_DAYS} days.")
        else:
            st.warning(f"Night count {latest.snapshot_date.iloc[0]:%a %d %b}: **{len(alerts_now)} restock alerts** "
                       f"in {alerts_now.store_id.nunique()} stores (under {ALERT_DAYS} days of cover).")
    if not quality.empty:
        last_file = quality[quality.file_date == quality.file_date.max()]
        bad = incidents_of(last_file)
        if bad.empty:
            st.success(f"Till feed {last_file.file_date.iloc[0]:%d %b}: no price incident.")
        else:
            st.error(f"Till feed {last_file.file_date.iloc[0]:%d %b}: price incident in "
                     f"{', '.join(bad.store_id)}. See *Data quality*.")

st.title("Datathlon · daily sales and stock")
built_at = pd.Timestamp(built.built.iloc[0])
st.caption(f"Data up to **{last_day:%a %d %b %Y}** (complete days only) · gold tables built "
           f"{built_at:%d %b %H:%M} Paris · read-only role `DATATHLON_ANALYST`, warehouse `DATATHLON_BI_WH`")

tab_sales, tab_stock, tab_quality = st.tabs(["UC1 · Sales", "UC2 · Stock alerts", "Data quality"])
current_w, previous_w = week_windows(start, end)
WEEK_HELP = ("Delta: last 7 days of the selection vs the 7 days before." if previous_w else
             "No delta: pick at least 14 days to compare two weeks.")

# ---------- UC1 ----------
with tab_sales:
    st.header("Which categories and channels should next week's promotions push?")
    view = sales[sales.country.isin(countries) & sales.sales_date.between(start, end)].copy()
    choice = st.segmented_control("Show", list(METRICS), default="Revenue €", key="metric") or "Revenue €"
    col, label, fmt, axis_fmt = METRICS[choice]

    # a day x country is a "holiday day" when the country is on school holidays (Belgium: one community out of two)
    def on_holiday(row):
        h = holidays[(holidays.country == row.country) & (holidays.start_date <= row.sales_date)
                     & (holidays.end_date >= row.sales_date)]
        return not h.empty
    view["period"] = view.apply(on_holiday, axis=1).map({True: "school holidays", False: "other days"})
    cur = view[view.sales_date.between(*current_w)]
    prev = view[view.sales_date.between(*previous_w)] if previous_w else view.iloc[0:0]

    def web_share(df):
        total = df.revenue_eur.sum()
        return df[df.channel == "web"].revenue_eur.sum() / total if total else None

    def pct(d):
        return f"{d:+.0%} vs prev. week" if d is not None else None

    revenue, units = view.revenue_eur.sum(), view.units.sum()
    ws, ws_cur, ws_prev = web_share(view), web_share(cur), web_share(prev)
    per_day = view.groupby(["period", "sales_date"])[col].sum().groupby("period").mean()
    uplift = per_day.get("school holidays", 0) / per_day.get("other days", 1) - 1 if "other days" in per_day else 0
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Paid revenue", f"€{revenue:,.0f}", pct(delta(cur.revenue_eur.sum(), prev.revenue_eur.sum())),
              help=WEEK_HELP)
    c2.metric("Units sold", f"{units:,.0f}", pct(delta(cur.units.sum(), prev.units.sum())), help=WEEK_HELP)
    c3.metric("Web share of revenue", f"{ws or 0:.0%}",
              f"{(ws_cur - ws_prev) * 100:+.1f} pts vs prev. week" if ws_cur is not None and ws_prev is not None
              else None, delta_color="off", help=WEEK_HELP + " A channel mix, neither good nor bad: grey.")
    c4.metric("School-holiday uplift", f"{uplift:+.0%}",
              help=f"{label.capitalize()} per day in school holidays vs other days, same countries and dates")

    # the answer first: what grew and what fell last week, per category x channel, and the next holidays to plan for
    if previous_w:
        moves = (cur.groupby(["category", "channel"])[col].sum().to_frame("now")
                 .join(prev.groupby(["category", "channel"])[col].sum().to_frame("before"), how="outer").fillna(0))
        moves = moves[moves.before > 0].assign(change=lambda d: d.now / d.before - 1).sort_values("change")
        def names(rows):
            return ", ".join(f"**{c} · {ch}** {r.change:+.0%}" for (c, ch), r in rows.iterrows())
        up, down = moves[moves.change > 0].tail(3).iloc[::-1], moves[moves.change < 0].head(3)
        a, b = st.columns(2)
        if up.empty:
            a.info("No category x channel grew last week.")
        else:
            a.success(f"Push (rising {label}, last 7 days vs the 7 before): {names(up)}")
        if down.empty:
            b.info("No category x channel fell last week.")
        else:
            b.warning(f"Watch (falling {label}): {names(down)}")
    else:
        st.info("Pick at least 14 days to see what rose and fell last week.")
    upcoming = holidays[holidays.end_date > last_day].sort_values("start_date").groupby("country").head(1)
    if upcoming.empty:
        st.info("No school holidays ahead in the calendar we load (OpenHolidays, up to 31 Dec).")
    else:
        st.info("Next school holidays, to plan the promotions: " + " · ".join(
            f"**{r.country}** {r.holiday_name} "
            + (f"until {r.end_date:%a %d %b}" if r.start_date <= last_day else f"from {r.start_date:%a %d %b}")
            + (" (part of the country)" if r.share and r.share < 1 else "")
            for r in upcoming.sort_values("country").itertuples())
            + ". The chart *Which categories sell more in the school holidays?* shows what they usually lift.")

    daily = view.groupby(["sales_date", "channel"], as_index=False)[col].sum()
    daily["sales_date"] = pd.to_datetime(daily.sales_date)
    st.subheader(f"{label.split(' ')[0].title()} per day, store and web")
    # one chart per channel, each with its own scale: stores sell ~9x the web, one scale would flatten the web line
    for column, channel in zip(st.columns(2), ["store", "web"]):
        line = alt.Chart(daily[daily.channel == channel]).mark_line(strokeWidth=2.5, color=CHANNEL_COLORS.range[
            CHANNEL_COLORS.domain.index(channel)]).encode(
            x=alt.X("sales_date:T", title=None), y=alt.Y(f"{col}:Q", title=f"{channel.title()} {label}"),
            tooltip=[alt.Tooltip("sales_date:T", title="Day"),
                     alt.Tooltip(f"{col}:Q", title=label.capitalize(), format=axis_fmt)])
        column.altair_chart(holiday_layer(holidays, start, end) + line, use_container_width=True)

    st.subheader("Which categories sell more in the school holidays?")
    cat = (view.groupby(["category", "period", "sales_date"])[col].sum()
               .groupby(["category", "period"]).mean().unstack("period").fillna(0))
    if {"school holidays", "other days"} <= set(cat.columns):
        cat["uplift"] = cat["school holidays"] / cat["other days"] - 1
        cat = cat.reset_index().sort_values("uplift", ascending=False)
        st.altair_chart(alt.Chart(cat).mark_bar(color=BLUE).encode(
            x=alt.X("uplift:Q", title=f"{label.capitalize()} per day in school holidays vs other days",
                    axis=alt.Axis(format="+%")),
            y=alt.Y("category:N", sort="-x", title=None),
            color=alt.condition("datum.uplift > 0", alt.value(BLUE), alt.value(MUTED)),
            tooltip=["category:N", alt.Tooltip("uplift:Q", format="+.0%"),
                     alt.Tooltip("school holidays:Q", title=f"{label.capitalize()}/day in holidays", format=axis_fmt),
                     alt.Tooltip("other days:Q", title=f"{label.capitalize()}/day otherwise", format=axis_fmt)]),
            use_container_width=True)
    else:
        st.info("Pick dates that include school holidays and other days to compare.")

    st.subheader(f"Last 7 days ({max(start, current_w[0]):%d %b} → {end:%d %b}), {label} by category and channel")
    table = cur.pivot_table(index="category", columns="channel", values=col, aggfunc="sum", fill_value=0)
    table["total"] = table.sum(axis=1)
    formats = {c: fmt for c in table.columns}
    if previous_w:
        table["vs prev. week"] = table.total / prev.groupby("category")[col].sum().reindex(table.index).replace(
            0, float("nan")) - 1
        formats["vs prev. week"] = lambda v: "–" if pd.isna(v) else f"{v:+.0%}"
    styled = table.sort_values("total", ascending=False).style.format(formats)
    if previous_w:  # colour by hand: Styler.background_gradient needs matplotlib, not in environment.yml
        styled = styled.map(lambda v: "" if pd.isna(v) else f"color: {BLUE if v >= 0 else '#C0392B'}; font-weight: 600",
                            subset=["vs prev. week"])
    st.dataframe(styled, width="stretch")
    source("GOLD_SALES_DAILY", "GOLD_HOLIDAYS")

# ---------- UC2 ----------
with tab_stock:
    st.header("What should we restock, in which store, before it runs out?")
    sview = stock[stock.country.isin(countries) & stock.snapshot_date.between(start, end)].copy()
    no_count = sview.empty
    if no_count:
        st.info("No stock count in these dates (the 7-day cover starts on the 7th day of data).")
    else:
        # controls of this tab only: each store acts on its own list, and the right threshold depends on lead time
        k1, k2 = st.columns([1, 2])
        threshold = k1.slider("Alert below (days of cover)", 1, 7, ALERT_DAYS,
                              help=f"{ALERT_DAYS} days = the UC2 rule (`is_alert` in gold). Try more days if the "
                                   "next delivery is further away.")
        cities = sorted(sview.store_city.unique())
        picked = k2.multiselect("Stores", cities, default=cities)
        sview = sview[sview.store_city.isin(picked)]
        sview["alert"] = sview.cover_exact < threshold  # nothing sold in 7 days: no cover, no alert (as in gold)
        if threshold != ALERT_DAYS:
            st.caption(f"Threshold **{threshold} days** instead of the UC2 rule ({ALERT_DAYS} days): a what-if, the "
                       "sidebar and gold keep the rule.")

    if sview.empty:
        if not no_count:
            st.info("Pick at least one store.")
    else:
        per_day = sview.groupby("snapshot_date").alert.sum().sort_index(ascending=False)
        day = st.selectbox("Night count", per_day.index, format_func=lambda d: f"{d:%a %d %b} · {per_day[d]} alerts",
                           help="Latest count first: that is the list the stores act on this morning")
        today = sview[sview.snapshot_date == day]
        alerts = today[today.alert].sort_values("cover_exact")
        # the previous count, on the same stores: on Sunday only the Spanish stores count, all stores would not compare
        before = [d for d in per_day.index if d < day]
        prev_count = (sview[(sview.snapshot_date == before[0]) & sview.store_id.isin(today.store_id)]
                      if before else None)
        vs = f" vs {before[0]:%a %d %b}" if before else ""

        def change(now, then, unit=""):
            return f"{now - then:+,.0f}{unit}{vs}" if prev_count is not None and not prev_count.empty else None
        share_now = len(alerts) / len(today)
        share_then = prev_count.alert.mean() if prev_count is not None and not prev_count.empty else 0
        c1, c2, c3, c4 = st.columns(4)
        c1.metric(f"Alerts on {day:%d %b}", f"{len(alerts)}",
                  change(len(alerts), prev_count.alert.sum() if prev_count is not None else 0),
                  delta_color="inverse", help=f"store x product with less than {threshold} days of cover; delta vs "
                                              "the previous night count, same stores")
        c2.metric("Share of shelves in alert", f"{share_now:.0%}", change(share_now * 100, share_then * 100, " pts"),
                  delta_color="inverse")
        c3.metric("Emergency transfers (units)", f"{today.emergency.sum():,.0f}",
                  change(today.emergency.sum(), prev_count.emergency.sum() if prev_count is not None else 0),
                  delta_color="inverse", help="Units sent the same day from another store because the shelf would "
                                              "have gone empty: the stockouts the alerts did not prevent")
        c4.metric("Stores counted", f"{today.store_id.nunique()}", help="FR and BE stores are closed on Sunday")

        st.subheader(f"Restock list, night count of {day:%a %d %b}")
        if alerts.empty:
            st.success(f"No product under {threshold} days of cover.")
        else:
            worst = alerts.groupby("store_city").size().sort_values(ascending=False)
            st.warning(f"**{len(alerts)} products to restock** in {len(worst)} stores, most in "
                       + ", ".join(f"{city} ({n})" for city, n in worst.head(3).items()) + ".")
            st.dataframe(alerts[["store_city", "product_name", "category", "on_hand", "avg_daily_units_7d",
                                 "days_of_cover"]].rename(columns={
                             "store_city": "Store", "product_name": "Product", "category": "Category",
                             "on_hand": "On hand", "avg_daily_units_7d": "Sold per day (7 d)",
                             "days_of_cover": "Days of cover"}),
                         width="stretch", hide_index=True)

        # counts, not shares: on Sunday only the Spanish stores count, a share would jump for nothing.
        # Deliveries come on Monday and Thursday (dashed lines), so alerts build up towards Wednesday and Saturday.
        st.subheader("Alerts per night count, per category")
        trend = sview[sview.alert].groupby(["snapshot_date", "category"], as_index=False).size()
        trend["snapshot_date"] = pd.to_datetime(trend.snapshot_date)
        deliveries = sview[sview.received > 0].groupby("snapshot_date", as_index=False).received.sum()
        deliveries["snapshot_date"] = pd.to_datetime(deliveries.snapshot_date)
        pick, faded = legend_filter("category")
        bars = alt.Chart(trend).mark_bar().encode(
            x=alt.X("yearmonthdate(snapshot_date):T", title=None),
            y=alt.Y("size:Q", title=f"Store x product under {threshold} days of cover"),
            color=alt.Color("category:N", title="Category (click to filter)", scale=alt.Scale(scheme="tableau10")),
            opacity=faded,
            tooltip=[alt.Tooltip("snapshot_date:T", title="Day"), "category:N",
                     alt.Tooltip("size:Q", title="Alerts")]).add_params(pick)
        rules = alt.Chart(deliveries).mark_rule(color=NAVY, strokeDash=[4, 3], opacity=0.6).encode(
            x="yearmonthdate(snapshot_date):T",
            tooltip=[alt.Tooltip("snapshot_date:T", title="Delivery"),
                     alt.Tooltip("received:Q", title="Units received", format=",.0f")])
        st.altair_chart(holiday_layer(holidays, start, end) + bars + rules, use_container_width=True)
        st.caption("Dashed lines: warehouse deliveries (units received in the night count).")
    source("GOLD_STOCK_COVER_DAILY", "GOLD_HOLIDAYS")

# ---------- data quality ----------
with tab_quality:
    st.header("Can we trust the store sales figures?")
    qview = quality[quality.file_date.between(start, end)]
    st.caption("All stores: the till feed is checked before any country filter.")
    incidents = incidents_of(qview)
    if incidents.empty:
        st.success("Till feed clean over the period: no store sent more than 10 % of its day in cents.")
    else:
        st.error(f"**{len(incidents)} incident(s) in the period**, prices fixed by dbt before they reach the figures: "
                 + ", ".join(f"{r.store_id} {r.file_date:%d %b} ({r.price_fixed_from_cents:,.0f} of "
                             f"{r.raw_lines:,.0f} prices in cents)" for r in incidents.itertuples()))

    def quarantine_pct(df):
        return df.quarantine_lines.sum() / df.raw_lines.sum() if df.raw_lines.sum() else None
    q_cur = quarantine_pct(qview[qview.file_date.between(*current_w)])
    q_prev = quarantine_pct(qview[qview.file_date.between(*previous_w)]) if previous_w else None
    raw, quarantined = qview.raw_lines.sum(), qview.quarantine_lines.sum()
    c1, c2, c3 = st.columns(3)
    c1.metric("Till lines received", f"{raw:,}")
    c2.metric("Quarantined (kept out of the figures)", f"{quarantined / raw:.1%}" if raw else "–",
              f"{(q_cur - q_prev) * 100:+.1f} pts vs prev. week" if q_cur is not None and q_prev is not None else None,
              delta_color="inverse", help=f"{quarantined:,} lines. {WEEK_HELP}")
    c3.metric("Prices fixed (sent in cents)", f"{qview.price_fixed_from_cents.sum():,}")

    st.subheader("Quarantined lines per day, by reason")
    reasons = [c for c in qview.columns if c.startswith("q_")]
    by_reason = qview.groupby("file_date", as_index=False)[reasons].sum().melt(
        "file_date", var_name="reason", value_name="lines")
    by_reason = by_reason[by_reason.lines > 0]
    by_reason["reason"] = by_reason.reason.str[2:].str.replace("_", " ")
    by_reason["file_date"] = pd.to_datetime(by_reason.file_date)
    pick, faded = legend_filter("reason")
    st.altair_chart(alt.Chart(by_reason).mark_bar().encode(
        x=alt.X("file_date:T", title=None), y=alt.Y("lines:Q", title="Quarantined lines"),
        color=alt.Color("reason:N", title="Reason (click to filter)", scale=alt.Scale(scheme="tableau10")),
        opacity=faded,
        tooltip=[alt.Tooltip("file_date:T", title="Day"), "reason:N", "lines:Q"]).add_params(pick),
        use_container_width=True)

    # A count per day hid the story: 1 or 2 stray lines a day next to one whole store-day, on one axis. As a share of
    # each store's day on a store x day grid, the usual noise stays pale and an incident is one red cell.
    st.subheader("Which store sent its prices in cents, and when?")
    grid = qview.copy()
    grid["cents_share"] = grid.price_fixed_from_cents / grid.raw_lines
    grid["level"] = pd.cut(grid.cents_share, [-1, 0, INCIDENT_SHARE, 1], labels=list(CENTS_LEVELS)).astype(str)
    grid["file_date"] = pd.to_datetime(grid.file_date)
    st.altair_chart(alt.Chart(grid).mark_rect(stroke="white", strokeWidth=1).encode(
        x=alt.X("yearmonthdate(file_date):O", title=None, axis=alt.Axis(format="%d %b", labelAngle=-90,
                                                                         labelOverlap=True)),
        y=alt.Y("store_id:N", title=None),
        color=alt.Color("level:N", title="Prices sent in cents, share of the store's day",
                        scale=alt.Scale(domain=list(CENTS_LEVELS), range=list(CENTS_LEVELS.values())),
                        legend=alt.Legend(orient="top", labelLimit=400, titleLimit=400)),
        tooltip=[alt.Tooltip("file_date:T", title="Day"), alt.Tooltip("store_id:N", title="Store"),
                 alt.Tooltip("price_fixed_from_cents:Q", title="Prices in cents (fixed by dbt)"),
                 alt.Tooltip("raw_lines:Q", title="Lines received"),
                 alt.Tooltip("cents_share:Q", title="Share of the day", format=".0%")]).properties(
        height=34 * max(grid.store_id.nunique(), 1) + 110), use_container_width=True)  # + legend and date axis
    st.caption("Blank: store closed (Sunday in France and Belgium). dbt converts every price sent in cents back to "
               "euros, so neither the noise nor an incident changes the revenue; the red cells say which store's "
               "till software to check.")

    st.subheader("Incidents: a store sent more than 10 % of its day in cents")
    st.dataframe(incidents[["file_date", "store_id", "raw_lines", "price_fixed_from_cents", "quarantine_pct"]].rename(
        columns={"file_date": "Day", "store_id": "Store", "raw_lines": "Lines received",
                 "price_fixed_from_cents": "Prices fixed by dbt", "quarantine_pct": "% quarantined"}),
        width="stretch", hide_index=True)
    source("GOLD_DATA_QUALITY_DAILY")
