"""
STEP 5: Predictive model. Will a delivered order get a satisfied review (score 4 or 5)?
Business use: flag orders at risk of a bad review so support can reach out proactively.
Model: Logistic Regression (simple, explainable). Baseline: always predict "satisfied".
Run in VS Code like 02_analysis.py. Install once: pip install pyodbc pandas matplotlib scikit-learn joblib
Outputs: model/satisfaction_logreg.joblib, outputs/model_metrics.json, outputs/model_coefficients.csv, charts/08 and 09.
"""
# %% 1. LOAD DATA (clean SQL view, one row per order)
import os, json, warnings
import numpy as np, pandas as pd, pyodbc, joblib
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score, roc_curve, confusion_matrix
warnings.filterwarnings("ignore", message=".*pandas only supports SQLAlchemy.*")

HERE = os.path.dirname(os.path.abspath(__file__))
OUT, CH, MD = (os.path.join(HERE, d) for d in ("outputs", "charts", "model"))
for d in (OUT, CH, MD): os.makedirs(d, exist_ok=True)

SERVER = os.getenv("SQL_SERVER", r"LAPTOP-QPM4MO6V\SQLEXPRESS01")
conn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={SERVER};DATABASE=BrazilianECommerce;"
                      "Trusted_Connection=yes;TrustServerCertificate=yes;", timeout=10)
df_orders = pd.read_sql("SELECT * FROM dbo.vw_order_master", conn)
conn.close()

# %% 2. PREPARE: delivered orders that have a review and a delivery date
for c in ["delivery_days", "delay_days", "is_late", "review_score", "payment_total", "installments", "item_total", "freight_total", "n_items", "n_sellers"]:
    df_orders[c] = pd.to_numeric(df_orders[c], errors="coerce").astype(float)
for c in ["order_purchase_timestamp", "order_estimated_delivery_date"]:
    df_orders[c] = pd.to_datetime(df_orders[c])

d = df_orders[(df_orders.order_status == "delivered") & df_orders.order_delivered_customer_date.notna()].copy()
d = d.dropna(subset=["review_score", "delivery_days", "delay_days", "item_total", "freight_total", "installments", "main_payment_type"])
print("orders used for the model:", len(d))          # expect about 95,800

# %% 3. FEATURES (all known once the order is delivered)
d["estimated_days"] = (d.order_estimated_delivery_date - d.order_purchase_timestamp).dt.total_seconds() / 86400
d["days_late"] = d.delay_days.clip(lower=0)                       # only lateness hurts
d["days_early"] = (-d.delay_days).clip(lower=0)
d["freight_ratio"] = (d.freight_total / d.item_total.replace(0, np.nan)).fillna(0).clip(upper=d.freight_total.div(d.item_total.replace(0, np.nan)).quantile(.99))
d["purchase_dow"] = d.order_purchase_timestamp.dt.day_of_week
d["purchase_hour"] = d.order_purchase_timestamp.dt.hour
top_states = d.customer_state.value_counts().head(10).index                    # keep the form simple
d["state_group"] = np.where(d.customer_state.isin(top_states), d.customer_state, "Other")
d["target"] = (d.review_score >= 4).astype(int)                                # 1 = satisfied

num = ["delivery_days", "estimated_days", "days_late", "days_early", "is_late", "item_total", "freight_total",
       "freight_ratio", "n_items", "n_sellers", "installments", "purchase_dow", "purchase_hour"]
cat = ["main_payment_type", "state_group"]
X, y = d[num + cat], d.target
Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

# %% 4. TRAIN
pre = ColumnTransformer([("n", StandardScaler(), num), ("c", OneHotEncoder(handle_unknown="ignore"), cat)])
model = Pipeline([("pre", pre), ("m", LogisticRegression(max_iter=1000, class_weight="balanced"))]).fit(Xtr, ytr)

# %% 5. EVALUATE (on the 20% the model never saw)
p = model.predict_proba(Xte)[:, 1]; pred = (p >= 0.5).astype(int)
tn, fp, fn, tp = confusion_matrix(yte, pred).ravel()
met = {
    "orders_used": int(len(d)), "train_rows": int(len(Xtr)), "test_rows": int(len(Xte)),
    "satisfied_rate": float(y.mean()),
    "baseline_accuracy": float(max(y.mean(), 1 - y.mean())),      # always guessing "satisfied"
    "accuracy": float(accuracy_score(yte, pred)), "auc": float(roc_auc_score(yte, p)),
    "precision_satisfied": float(precision_score(yte, pred)), "recall_satisfied": float(recall_score(yte, pred)),
    "f1_satisfied": float(f1_score(yte, pred)),
    "recall_unsatisfied": float(tn / (tn + fp)),                  # share of unhappy orders we catch
    "precision_unsatisfied": float(tn / (tn + fn)),
    "confusion_matrix": [[int(tn), int(fp)], [int(fn), int(tp)]],
    "top_states": list(top_states),
}
json.dump(met, open(os.path.join(OUT, "model_metrics.json"), "w"), indent=1)
for k, v in met.items(): print(f"{k:24s} {v}")

# %% 6. DRIVERS (standardised coefficients: negative = lowers satisfaction)
names = [n.split("__", 1)[1] for n in model.named_steps["pre"].get_feature_names_out()]
coef = pd.DataFrame({"feature": names, "coef": model.named_steps["m"].coef_[0]})
coef["abs"] = coef.coef.abs(); coef = coef.sort_values("abs", ascending=False)
coef.to_csv(os.path.join(OUT, "model_coefficients.csv"), index=False)
joblib.dump(model, os.path.join(MD, "satisfaction_logreg.joblib"))

# %% 7. CHARTS
TEAL, ORANGE = "#348E90", "#E8833A"
plt.rcParams.update({"font.size": 11, "axes.spines.top": False, "axes.spines.right": False})
fpr, tpr, _ = roc_curve(yte, p)
fig, ax = plt.subplots(figsize=(5.5, 4.5)); ax.plot(fpr, tpr, color=TEAL, lw=2.5, label=f"Model (AUC {met['auc']:.2f})")
ax.plot([0, 1], [0, 1], "--", color="grey", label="Random guess"); ax.set_xlabel("False positive rate"); ax.set_ylabel("True positive rate")
ax.set_title("The model beats random guessing", loc="left", fontweight="bold"); ax.legend(); fig.tight_layout(); fig.savefig(os.path.join(CH, "08_model_roc.png"), dpi=160); plt.close(fig)

t = coef.head(8).iloc[::-1]
fig, ax = plt.subplots(figsize=(8, 4.5)); ax.barh(t.feature.str.replace("_", " "), t.coef, color=[ORANGE if v < 0 else TEAL for v in t.coef])
ax.axvline(0, color="grey", lw=.8); ax.set_title("What drives satisfaction (orange lowers it, teal raises it)", loc="left", fontweight="bold"); ax.set_xlabel("Coefficient (standardised)")
fig.tight_layout(); fig.savefig(os.path.join(CH, "09_model_drivers.png"), dpi=160); plt.close(fig)
print("\nSaved model, metrics, coefficients and charts.")
