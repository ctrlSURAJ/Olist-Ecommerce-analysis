"""
STEP 4: Python analysis of the Olist data (reads the clean SQL views).
Run in VS Code: open the file and click "Run Cell" on each "# %%" block, or run the whole file.
Install once:  pip install pyodbc pandas matplotlib
Outputs: summary tables in outputs/ (used by the web app) and charts in charts/ (used in the presentation).
"""
# %% 1. SETTINGS AND DATA LOAD
import os, json, warnings
import pandas as pd, numpy as np, pyodbc
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
warnings.filterwarnings("ignore", message=".*pandas only supports SQLAlchemy.*")

HERE = os.path.dirname(os.path.abspath(__file__))
OUT, CH = os.path.join(HERE, "outputs"), os.path.join(HERE, "charts")
os.makedirs(OUT, exist_ok=True); os.makedirs(CH, exist_ok=True)

SERVER = os.getenv("SQL_SERVER", r"LAPTOP-QPM4MO6V\SQLEXPRESS01")   # change here or set SQL_SERVER
conn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={SERVER};DATABASE=BrazilianECommerce;"
                      "Trusted_Connection=yes;TrustServerCertificate=yes;", timeout=10)
df_orders = pd.read_sql("SELECT * FROM dbo.vw_order_master", conn)      # one row per order
df_items  = pd.read_sql("SELECT * FROM dbo.vw_item_detail", conn)       # one row per order item
df_rfm    = pd.read_sql("SELECT * FROM dbo.vw_rfm_customer", conn)      # one row per customer
df_pay    = pd.read_sql("SELECT order_id, payment_type, payment_installments, payment_value FROM dbo.order_payments", conn)
conn.close()

# %% 2. TYPE CLEANUP (SQL decimals arrive as Decimal objects, dates as date objects)
num = {"df_orders": ["delivery_days", "delay_days", "is_late", "review_score", "payment_total", "installments", "item_total", "freight_total"],
       "df_items": ["price", "freight_value", "review_score", "is_late", "delivery_days"],
       "df_rfm": ["recency_days", "frequency", "monetary"], "df_pay": ["payment_installments", "payment_value"]}
for name, cols in num.items():
    d = globals()[name]
    for c in cols: d[c] = pd.to_numeric(d[c], errors="coerce").astype(float)
for d in (df_orders, df_items): d["purchase_month"] = pd.to_datetime(d["purchase_month"])
print({n: len(globals()[n]) for n in num})          # expect 99441, 112650, 96096 (approx), 103886

# %% 3. HEADLINE KPIs  (same definitions as the SQL analysis)
deliv = df_orders[df_orders.order_status == "delivered"]
deliv_dated = deliv[deliv.order_delivered_customer_date.notna()]
valid_items = df_items[df_items.order_status != "canceled"]
per_person = df_orders.groupby("customer_unique_id").size()
kpi = {
    "orders": len(df_orders), "unique_customers": int(df_orders.customer_unique_id.nunique()),
    "gmv": df_orders.loc[df_orders.order_status != "canceled", "payment_total"].sum(),
    "product_revenue": valid_items.price.sum(), "freight_revenue": valid_items.freight_value.sum(),
    "avg_order_value": deliv.payment_total.mean(), "avg_review": deliv.review_score.mean(),
    "low_review_pct": (deliv.review_score <= 2.5).sum() / deliv.review_score.notna().sum() * 100,
    "late_pct": deliv_dated.is_late.mean() * 100, "avg_delivery_days": deliv_dated.delivery_days.mean(),
    "cancel_pct": (df_orders.order_status == "canceled").mean() * 100,
    "repeat_pct": (per_person > 1).mean() * 100, "active_sellers": int(valid_items.seller_id.nunique()),
}
kpi = {k: float(v) for k, v in kpi.items()}
json.dump(kpi, open(os.path.join(OUT, "kpis.json"), "w"), indent=1)
for k, v in kpi.items(): print(f"{k:20s} {v:,.2f}")

# %% 4. SALES TREND (complete months only: Jan 2017 to Aug 2018)
m = valid_items.groupby("purchase_month").agg(revenue=("price", "sum"), orders=("order_id", "nunique")).reset_index()
m = m[(m.purchase_month >= "2017-01-01") & (m.purchase_month <= "2018-08-01")].copy()
m["mom_growth_pct"] = m.revenue.pct_change() * 100
m.to_csv(os.path.join(OUT, "monthly.csv"), index=False)

# %% 5. CATEGORIES
cat = valid_items.groupby("category").agg(revenue=("price", "sum"), orders=("order_id", "nunique")).reset_index().sort_values("revenue", ascending=False)
cat["share_pct"] = cat.revenue / cat.revenue.sum() * 100
cat["cum_share_pct"] = cat.share_pct.cumsum()
n80 = int((cat.cum_share_pct - cat.share_pct < 80).sum())
cat.to_csv(os.path.join(OUT, "category.csv"), index=False)

# %% 6. STATES (sales vs delivery vs satisfaction)
rev = valid_items.groupby("customer_state").price.sum().rename("revenue")
ops = deliv_dated.groupby("customer_state").agg(delivered_orders=("order_id", "size"), avg_delivery_days=("delivery_days", "mean"),
                                               late_pct=("is_late", "mean"), avg_review=("review_score", "mean"))
ops["late_pct"] *= 100
state = pd.concat([rev, ops], axis=1).reset_index().rename(columns={"index": "customer_state"}).sort_values("revenue", ascending=False)
state["revenue_share_pct"] = state.revenue / state.revenue.sum() * 100
state.to_csv(os.path.join(OUT, "state.csv"), index=False)

# %% 7. DELIVERY DELAY VS REVIEW SCORE
d = deliv_dated.dropna(subset=["delay_days", "review_score"]).copy()
labels = ["On time or early", "1-3 days late", "4-7 days late", "8-14 days late", "15+ days late"]
d["delay_band"] = pd.cut(d.delay_days, [-1e9, 0, 3, 7, 14, 1e9], labels=labels)
band = d.groupby("delay_band", observed=True).review_score.agg(avg_review="mean", orders="size").reset_index()
band.to_csv(os.path.join(OUT, "delay_vs_review.csv"), index=False)

# %% 8. PAYMENTS
pay = df_pay.groupby("payment_type").agg(orders=("order_id", "nunique"), value=("payment_value", "sum"),
                                         avg_installments=("payment_installments", "mean")).reset_index()
pay["value_share_pct"] = pay.value / pay.value.sum() * 100
pay = pay.sort_values("value", ascending=False)
pay.to_csv(os.path.join(OUT, "payments.csv"), index=False)

# %% 9. SELLERS
sel_all = valid_items.groupby("seller_id").price.sum().sort_values(ascending=False)
top10_share = sel_all.head(int(round(len(sel_all) * 0.1))).sum() / sel_all.sum() * 100
dsel = df_items[df_items.order_status == "delivered"].groupby(["seller_id", "seller_state"]).agg(
    orders=("order_id", "nunique"), revenue=("price", "sum"), avg_review=("review_score", "mean"), late_pct=("is_late", "mean")).reset_index()
dsel["late_pct"] *= 100
dsel = dsel.sort_values("revenue", ascending=False)
dsel.to_csv(os.path.join(OUT, "sellers.csv"), index=False)
big = dsel[dsel.orders >= 30]

# %% 10. CUSTOMER SEGMENTS (RFM)
rfm = df_rfm.groupby("segment").agg(customers=("monetary", "size"), avg_spend=("monetary", "mean"), total_spend=("monetary", "sum")).reset_index().sort_values("total_spend", ascending=False)
rfm.to_csv(os.path.join(OUT, "rfm.csv"), index=False)

# %% 10b. ORIGINAL INSIGHT: DOES A LATE FIRST ORDER HURT LOYALTY?
# For each customer take the first non-canceled order. Keep customers whose first order was delivered and
# is at least 180 days older than the newest order, so they had time to come back. Association, not proof.
for c in ["order_purchase_timestamp", "order_delivered_customer_date"]: df_orders[c] = pd.to_datetime(df_orders[c])
ords = df_orders[df_orders.order_status != "canceled"].sort_values(["order_purchase_timestamp", "order_id"])
n_orders = ords.groupby("customer_unique_id").size()
first = ords.groupby("customer_unique_id").head(1).copy()
first["repeat"] = first.customer_unique_id.map(n_orders) > 1
cutoff = ords.order_purchase_timestamp.max() - pd.Timedelta(days=180)
f = first[(first.order_status == "delivered") & first.order_delivered_customer_date.notna() & (first.order_purchase_timestamp < cutoff)]
loy = f.groupby("is_late").agg(customers=("repeat", "size"), repeat_pct=("repeat", "mean")).reset_index()
loy["repeat_pct"] *= 100
loy["first_order"] = loy.is_late.map({0.0: "Delivered on time", 1.0: "Delivered late"})
loy.to_csv(os.path.join(OUT, "loyalty.csv"), index=False)
print(loy)

# %% 11. CHARTS (one message per chart, saved as PNG)
TEAL, ORANGE, GREY = "#348E90", "#E8833A", "#595959"
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 11, "axes.spines.top": False, "axes.spines.right": False})
def save(fig, name): fig.tight_layout(); fig.savefig(os.path.join(CH, name), dpi=160); plt.close(fig)

fig, ax = plt.subplots(figsize=(9, 4.5))
ax.plot(m.purchase_month, m.revenue / 1e3, color=TEAL, marker="o", lw=2.2)
pk = m.loc[m.revenue.idxmax()]; ax.annotate(f"Peak {pk.purchase_month:%b %Y}\nR${pk.revenue/1e3:,.0f}K", (pk.purchase_month, pk.revenue / 1e3), xytext=(-110, -4), textcoords="offset points", color=ORANGE, arrowprops=dict(arrowstyle="->", color=ORANGE))
ax.set_title("Monthly revenue grew sevenfold in 20 months, then plateaued", loc="left", fontweight="bold"); ax.set_ylabel("Product revenue (R$ thousand)"); ax.grid(axis="y", alpha=.3)
import matplotlib.dates as mdates; ax.xaxis.set_major_formatter(mdates.DateFormatter("%b %y")); ax.xaxis.set_major_locator(mdates.MonthLocator(interval=2))
save(fig, "01_monthly_revenue.png")

t = cat.head(10).iloc[::-1]
fig, ax = plt.subplots(figsize=(9, 4.8)); ax.barh(t.category.str.replace("_", " "), t.revenue / 1e3, color=TEAL)
ax.set_title(f"{n80} of {len(cat)} categories earn 80% of revenue", loc="left", fontweight="bold"); ax.set_xlabel("Product revenue (R$ thousand)")
for i, v in enumerate(t.revenue / 1e3): ax.text(v, i, f" {v:,.0f}", va="center", fontsize=10)
save(fig, "02_top_categories.png")

t = state.head(8)
fig, ax = plt.subplots(figsize=(9, 4.5)); ax.bar(t.customer_state, t.revenue_share_pct, color=[ORANGE] + [TEAL] * 7)
ax.set_title(f"SP, RJ and MG bring {state.head(3).revenue_share_pct.sum():.0f}% of revenue", loc="left", fontweight="bold"); ax.set_ylabel("Share of product revenue (%)")
for i, v in enumerate(t.revenue_share_pct): ax.text(i, v, f"{v:.1f}%", ha="center", va="bottom", fontsize=10)
save(fig, "03_state_revenue_share.png")

t = state[state.delivered_orders >= 300].sort_values("late_pct", ascending=False).head(10)
fig, ax = plt.subplots(figsize=(9, 4.8)); ax.barh(t.customer_state[::-1], t.late_pct[::-1], color=[ORANGE if s == "RJ" else TEAL for s in t.customer_state[::-1]])
ax.set_title("Late deliveries concentrate in the North-East and Rio", loc="left", fontweight="bold"); ax.set_xlabel("Late deliveries (%)")
for i, v in enumerate(t.late_pct[::-1]): ax.text(v, i, f" {v:.1f}%", va="center", fontsize=10)
save(fig, "04_late_by_state.png")

fig, ax = plt.subplots(figsize=(9, 4.5)); ax.bar(band.delay_band.astype(str), band.avg_review, color=[TEAL, TEAL] + [ORANGE] * 3)
ax.set_ylim(0, 5); ax.set_title("Late deliveries cut review scores sharply", loc="left", fontweight="bold"); ax.set_ylabel("Average review (1 to 5)")
for i, v in enumerate(band.avg_review): ax.text(i, v, f"{v:.2f}", ha="center", va="bottom")
save(fig, "05_delay_vs_review.png")

p = pay[pay.payment_type != "not_defined"].sort_values("value_share_pct")
fig, ax = plt.subplots(figsize=(9, 4)); ax.barh(p.payment_type.str.replace("_", " "), p.value_share_pct, color=[ORANGE if x == "credit_card" else TEAL for x in p.payment_type])
ax.set_title("Credit cards dominate payments", loc="left", fontweight="bold"); ax.set_xlabel("Share of payment value (%)")
for i, v in enumerate(p.value_share_pct): ax.text(v, i, f" {v:.1f}%", va="center", fontsize=10)
save(fig, "06_payment_mix.png")

r = rfm.sort_values("total_spend")
fig, ax = plt.subplots(figsize=(9, 4.2)); ax.barh(r.segment, r.total_spend / 1e6, color=[ORANGE if s == "At risk high value" else TEAL for s in r.segment])
ax.set_title("High-value customers at risk hold the most spend", loc="left", fontweight="bold"); ax.set_xlabel("Total spend (R$ million)")
for i, v in enumerate(r.total_spend / 1e6): ax.text(v, i, f" {v:.1f}M", va="center", fontsize=10)
save(fig, "07_rfm_segments.png")

fig, ax = plt.subplots(figsize=(7, 4.5)); ax.bar(loy.first_order, loy.repeat_pct, color=[TEAL, ORANGE], width=.55)
ax.set_title("A late first delivery lowers the chance of a second order", loc="left", fontweight="bold", fontsize=12); ax.set_ylabel("Customers who ordered again (%)"); ax.set_ylim(0, loy.repeat_pct.max() * 1.3)
for i, (v, n) in enumerate(zip(loy.repeat_pct, loy.customers)): ax.text(i, v, f"{v:.1f}%\n({n:,} customers)", ha="center", va="bottom", fontsize=10)
save(fig, "10_late_first_order_loyalty.png")

# %% 12. INSIGHTS (finding, number, action)
rj, sp, al = [state[state.customer_state == s].iloc[0] for s in ("RJ", "SP", "AL")]
risk = rfm[rfm.segment == "At risk high value"].iloc[0]
l_on, l_late = loy[loy.is_late == 0].iloc[0], loy[loy.is_late == 1].iloc[0]
late_gap = band.avg_review.iloc[0] - band.avg_review.iloc[2]
lines = [
 f"1. Growth: revenue rose from R${m.revenue.iloc[0]/1e3:,.0f}K (Jan 2017) to R${m.revenue.iloc[-1]/1e3:,.0f}K (Aug 2018); peak {pk.purchase_month:%b %Y} at R${pk.revenue/1e6:.2f}M. Action: plan stock and marketing for November.",
 f"2. Categories: {n80} of {len(cat)} categories earn 80% of revenue; top 3 are {', '.join(cat.head(3).category)}. Action: focus assortment and promotions on the core categories.",
 f"3. Geography: SP is {state.revenue_share_pct.iloc[0]:.1f}% of revenue; SP, RJ and MG together {state.head(3).revenue_share_pct.sum():.1f}%.",
 f"4. Delivery: {kpi['late_pct']:.2f}% of orders arrive late. Late rate is {al.late_pct:.1f}% in AL and {rj.late_pct:.1f}% in RJ versus {sp.late_pct:.1f}% in SP. Action: fix carriers and delivery promises in RJ first (second-largest market).",
 f"5. Satisfaction: on-time orders score {band.avg_review.iloc[0]:.2f}; orders 4 to 7 days late score {band.avg_review.iloc[2]:.2f} (gap {late_gap:.2f}). Action: late-risk alerts and honest delivery dates.",
 f"6. Sellers: top 10% of sellers earn {top10_share:.1f}% of revenue; among sellers with 30+ orders, late rate runs from {big.late_pct.min():.0f}% to {big.late_pct.max():.0f}%. Action: seller scorecard.",
 f"7. Payments: credit cards are {pay.loc[pay.payment_type=='credit_card','value_share_pct'].iloc[0]:.1f}% of payment value, boleto {pay.loc[pay.payment_type=='boleto','value_share_pct'].iloc[0]:.1f}%.",
 f"9. Loyalty: customers whose first order arrived late ordered again {l_late.repeat_pct:.1f}% of the time vs {l_on.repeat_pct:.1f}% when it arrived on time ({(1 - l_late.repeat_pct / l_on.repeat_pct) * 100:.0f}% lower; customers with 6+ months to return; association, not proof). Action: protect the first delivery for new customers.",
 f"8. Retention: only {kpi['repeat_pct']:.2f}% of customers ordered more than once; {int(risk.customers):,} high-value customers are drifting (R${risk.total_spend/1e6:.1f}M past spend). Action: win-back campaign.",
]
lines.sort()   # keep insights numbered 1 to 9 in order
open(os.path.join(OUT, "insights.txt"), "w", encoding="utf-8").write("\n".join(lines))
print("\n".join(lines)); print("\nSaved tables to", OUT, "and charts to", CH)