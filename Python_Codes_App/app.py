"""
Olist Brazilian E-Commerce: analytics dashboard and review-satisfaction predictor (Streamlit).
Run locally:  streamlit run app.py
Login: set APP_USER and APP_PASSWORD (environment variables or .streamlit/secrets.toml).
Local defaults for testing only: olist / olist@2026  (change before deploying)
Data: reads the summary tables in outputs/ (made by 02_analysis.py) and model/ (made by 03_predictive_model.py).
"""
import hmac, json, os
import joblib, pandas as pd, plotly.express as px, streamlit as st

st.set_page_config(page_title="Olist Insights", page_icon="🛒", layout="wide")
BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BASE, "outputs")
TEAL, ORANGE = "#348E90", "#E8833A"


# ---------------- Login ----------------
def credentials():
    """Read credentials from Streamlit secrets, then environment variables, then local defaults."""
    try:
        return st.secrets["APP_USER"], st.secrets["APP_PASSWORD"]
    except Exception:
        return os.getenv("APP_USER", "olist"), os.getenv("APP_PASSWORD", "olist@2026")


def login():
    if st.session_state.get("auth"):
        return True
    st.title("🛒 Olist Insights")
    st.caption("Sign in to continue")
    u = st.text_input("User ID")
    p = st.text_input("Password", type="password")
    if st.button("Sign in"):
        user, pwd = credentials()
        if hmac.compare_digest(u, user) and hmac.compare_digest(p, pwd):   # constant-time compare
            st.session_state["auth"] = True
            st.rerun()
        else:
            st.error("Wrong user ID or password")
    return False


# ---------------- Data helpers ----------------
@st.cache_data
def load(name):
    return pd.read_csv(os.path.join(OUT, name))


@st.cache_data
def load_json(name):
    return json.load(open(os.path.join(OUT, name)))


@st.cache_resource
def load_model():
    return joblib.load(os.path.join(BASE, "model", "satisfaction_logreg.joblib"))


def kpi_row(items):
    for col, (label, val) in zip(st.columns(len(items)), items):
        col.metric(label, val)


def show(fig):
    fig.update_layout(margin=dict(l=10, r=10, t=50, b=10), title_font_size=16)
    st.plotly_chart(fig, width="stretch")


# ---------------- Pages ----------------
def page_overview():
    k = load_json("kpis.json")
    st.header("Executive overview: sales performance")
    kpi_row([("Orders", f"{k['orders']:,.0f}"), ("Unique customers", f"{k['unique_customers']:,.0f}"),
             ("GMV (R$ M)", f"{k['gmv']/1e6:.2f}"), ("Product revenue (R$ M)", f"{k['product_revenue']/1e6:.2f}")])
    kpi_row([("Avg order value (R$)", f"{k['avg_order_value']:.2f}"), ("Avg review (1 to 5)", f"{k['avg_review']:.2f}"),
             ("Late deliveries", f"{k['late_pct']:.2f}%"), ("Repeat customers", f"{k['repeat_pct']:.2f}%")])
    m = load("monthly.csv")
    show(px.line(m, x="purchase_month", y="revenue", markers=True, title="Monthly product revenue (R$)", color_discrete_sequence=[TEAL]))
    st.caption("Jan 2017 to Aug 2018 is shown. 2016 and the months after Aug 2018 are incomplete in the source data.")
    with st.expander("Key insights (finding, number, action)"):
        st.text(open(os.path.join(OUT, "insights.txt"), encoding="utf-8").read())


def page_sales():
    st.header("Sales and products")
    c = load("category.csv")
    n = st.slider("Top categories", 5, 25, 10)
    t = c.head(n).iloc[::-1]
    show(px.bar(t, x="revenue", y="category", orientation="h", title="Product revenue by category (R$)", color_discrete_sequence=[TEAL]))
    n80 = int((c.cum_share_pct - c.share_pct < 80).sum())
    st.caption(f"{n80} of {len(c)} categories generate 80% of revenue. Profitable here means highest revenue, because the data has no cost or margin.")
    s = load("state.csv").sort_values("revenue", ascending=False).head(10)
    show(px.bar(s, x="customer_state", y="revenue_share_pct", title="Share of product revenue by state (%)", color_discrete_sequence=[TEAL]))
    p = load("payments.csv")
    p = p[p.payment_type != "not_defined"]
    show(px.bar(p.sort_values("value_share_pct"), x="value_share_pct", y="payment_type", orientation="h",
                title="Share of payment value by method (%)", color_discrete_sequence=[TEAL]))


def page_delivery():
    st.header("Delivery and customer experience")
    k = load_json("kpis.json")
    kpi_row([("Late deliveries", f"{k['late_pct']:.2f}%"), ("Avg delivery days", f"{k['avg_delivery_days']:.2f}"),
             ("Avg review", f"{k['avg_review']:.2f}"), ("Low reviews (2.5 or less)", f"{k['low_review_pct']:.2f}%")])
    d = load("delay_vs_review.csv")
    fig = px.bar(d, x="delay_band", y="avg_review", text=d.avg_review.round(2), title="Average review score by delivery delay", color_discrete_sequence=[TEAL])
    fig.update_yaxes(range=[0, 5]); show(fig)
    s = load("state.csv")
    s = s[s.delivered_orders >= 300]
    metric = st.selectbox("State metric", ["late_pct", "avg_delivery_days", "avg_review"])
    asc = metric == "avg_review"
    show(px.bar(s.sort_values(metric, ascending=asc).head(10), x="customer_state", y=metric, title=f"Top 10 states by {metric} (300+ delivered orders)", color_discrete_sequence=[ORANGE]))
    st.dataframe(s.round(2), width="stretch", hide_index=True)
    st.caption("Review scores fall sharply once an order is late. This is an association, not proof of cause.")


def page_customers():
    st.header("Customers")
    r = load("rfm.csv")
    show(px.bar(r.sort_values("total_spend"), x="total_spend", y="segment", orientation="h", title="Total spend by RFM segment (R$)", color_discrete_sequence=[TEAL]))
    st.dataframe(r.round(1), width="stretch", hide_index=True)
    l = load("loyalty.csv")
    fig = px.bar(l, x="first_order", y="repeat_pct", text=l.repeat_pct.round(1), title="Customers who ordered again (%), by first-order delivery",
                 color="first_order", color_discrete_map={"Delivered on time": TEAL, "Delivered late": ORANGE})
    fig.update_layout(showlegend=False); show(fig)
    st.caption("Customers with at least 6 months to return. A late first delivery goes with fewer repeat orders (association, not proof).")


def page_sellers():
    st.header("Sellers")
    k = load_json("kpis.json")
    kpi_row([("Active sellers", f"{k['active_sellers']:,.0f}")])
    s = load("sellers.csv")
    mo = st.slider("Minimum delivered orders", 1, 200, 30)
    t = s[s.orders >= mo]
    st.dataframe(t.head(25).round(2), width="stretch", hide_index=True)
    show(px.scatter(t, x="late_pct", y="avg_review", size="revenue", hover_name="seller_id", title="Seller lateness vs review score (bubble = revenue)", color_discrete_sequence=[TEAL]))


def page_predict():
    st.header("Will the customer be satisfied?")
    st.write("Logistic regression estimates the chance of a 4 or 5 star review for a delivered order. Use it to prioritise proactive support, not to decide alone.")
    mdl, met = load_model(), load_json("model_metrics.json")
    kpi_row([("AUC", f"{met['auc']:.2f}"), ("Accuracy", f"{met['accuracy']:.0%}"),
             ("Unhappy orders caught", f"{met['recall_unsatisfied']:.0%}"), ("Precision (unhappy)", f"{met['precision_unsatisfied']:.0%}")])
    st.caption(f"Always guessing 'satisfied' would score {met['baseline_accuracy']:.0%} accuracy, so the value is in catching unhappy orders, not accuracy.")
    cats = mdl.named_steps["pre"].named_transformers_["c"].categories_
    c1, c2, c3 = st.columns(3)
    deliv = c1.number_input("Days from purchase to delivery", 1.0, 120.0, 12.0)
    est = c1.number_input("Days promised at purchase", 1.0, 120.0, 23.0)
    inst = c1.number_input("Instalments", 1, 24, 1)
    item = c2.number_input("Item total (R$)", 1.0, 7000.0, 120.0)
    frt = c2.number_input("Freight total (R$)", 0.0, 500.0, 20.0)
    ptype = c2.selectbox("Payment type", list(cats[0]))
    n_items = c3.number_input("Items in order", 1, 20, 1)
    n_sell = c3.number_input("Sellers in order", 1, 10, 1)
    state = c3.selectbox("Customer state", list(cats[1]))
    dow = c1.selectbox("Purchase weekday (0 = Monday)", list(range(7)))
    hour = c2.slider("Purchase hour", 0, 23, 14)
    if st.button("Predict"):
        delay = deliv - est
        row = pd.DataFrame([dict(delivery_days=deliv, estimated_days=est, days_late=max(delay, 0), days_early=max(-delay, 0),
                                 is_late=float(delay > 0), item_total=item, freight_total=frt, freight_ratio=frt / item,
                                 n_items=n_items, n_sellers=n_sell, installments=inst, purchase_dow=dow, purchase_hour=hour,
                                 main_payment_type=ptype, state_group=state)])
        p = float(mdl.predict_proba(row)[0, 1])
        st.metric("Probability of a 4 or 5 star review", f"{p:.0%}")
        st.progress(p)
        if p >= 0.5:
            st.success("Likely satisfied")
        else:
            st.warning("At risk of a low score: consider proactive support")
    with st.expander("What drives the prediction?"):
        co = load("model_coefficients.csv").head(10).iloc[::-1].copy()
        co["feature"] = co.feature.str.replace("_", " ")
        show(px.bar(co, x="coef", y="feature", orientation="h", title="Strongest drivers (negative lowers satisfaction)", color_discrete_sequence=[TEAL]))


PAGES = {"Overview": page_overview, "Sales and products": page_sales, "Delivery and experience": page_delivery,
         "Customers": page_customers, "Sellers": page_sellers, "Satisfaction predictor": page_predict}

if login():
    st.sidebar.title("🛒 Olist Insights")
    choice = st.sidebar.radio("Go to", list(PAGES))
    if st.sidebar.button("Sign out"):
        st.session_state["auth"] = False
        st.rerun()
    PAGES[choice]()
