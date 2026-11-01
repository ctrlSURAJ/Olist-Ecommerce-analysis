# Brazilian E-Commerce (Olist): Sales and Customer Insights

PRP Cohort 4, Project 1. Analysis of 99,441 orders (Sep 2016 to Oct 2018, complete trading window Jan 2017 to Aug 2018) across 9 tables.

## Folder map
| Folder | Contents |
|---|---|
| `Data_and_Data_Dictionary/` | ER diagram and data dictionary (tables, columns, relationships, data issues, clean views) |
| `SQL_Codes/` | `01` quality checks, `02` cleaning (clean views), `03` business analysis; early exploration queries in `exploration/` |
| `PowerBI_Dashboards_Links/` | Power BI file, page screenshots and the published link (below) |
| `Python_Codes_App/` | `02_analysis.py`, `03_predictive_model.py`, the Streamlit app (`app.py`), summary tables in `outputs/`, charts in `charts/`, saved model in `model/` |
| `Presentation/` | Final presentation |

## How to reproduce
1. SQL Server: import the 9 CSV files into database `BrazilianECommerce`, run `01`, then `02` (creates `vw_order_master`, `vw_item_detail`; `vw_rfm_customer` is created in `03`), then `03`.
2. Python: `pip install -r requirements_scripts.txt`, then `python 02_analysis.py` and `python 03_predictive_model.py` (both read the SQL views; set `SQL_SERVER` to your server name).
3. Web app: `pip install -r requirements.txt`, then `streamlit run app.py`. Set `APP_USER` and `APP_PASSWORD` (environment variables or `.streamlit/secrets.toml`). The app reads only `outputs/` and `model/`, so it does not need SQL Server.

## Definitions used everywhere (SQL, Python, Power BI, app)
- GMV and revenue: non-canceled orders. GMV = sum of payment value. Product revenue = sum of item price.
- Delivery and review KPIs: delivered orders. Late = delivered date is after the estimated date (date level; estimated dates have no time of day).
- Customers are counted by `customer_unique_id`. Reviews are averaged to one row per order. Missing product category = `Others`.
- Profitable categories means highest revenue (the data has no cost or margin).

## Key results
| KPI | Value |
|---|---|
| Orders / unique customers | 99,441 / 96,096 |
| GMV / product revenue | R$15.87M / R$13.50M |
| Average order value | R$159.86 |
| Average review | 4.16 |
| Late deliveries | 6.77% |
| Average delivery time | 12.56 days |
| Repeat customers | 3.12% |
| Top 10% of sellers' share of revenue | 67.5% |
| Review score on time vs 4 to 7 days late | 4.29 vs 2.11 |
| High-value customers at risk | 23,392 (R$6.31M past spend) |
| Repeat rate after a late vs on-time first order | 2.9% vs 4.1% (association, not proof) |

**Predictive model:** logistic regression predicting a 4 or 5 star review for a delivered order (AUC 0.71, accuracy 76%). It catches about 49% of unhappy orders; always guessing "satisfied" would score 79% accuracy, so it is a triage tool, not a precise predictor.

## Links (fill in)
- Power BI dashboards: _paste link_  (user ID: _paste_, password: _paste_)
- Web app: (https://olist-suraj.streamlit.app/) (user ID: olist, password: olist@2026)
- GitHub repository: https://github.com/ctrlSURAJ/Olist-Ecommerce-analysis
- Google Drive: _paste link_
