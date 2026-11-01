import pyodbc
import pandas as pd


# =====================================================
# 1. SQL SERVER CONNECTION SETTINGS
# =====================================================

server = r"LAPTOP-QPM4MO6V\SQLEXPRESS01"
database = "BrazilianECommerce"
driver = "ODBC Driver 18 for SQL Server"

connection_string = (
    f"DRIVER={{{driver}}};"
    f"SERVER={server};"
    f"DATABASE={database};"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)


# =====================================================
# 2. CONNECT TO SQL SERVER
# =====================================================

connection = None

try:
    connection = pyodbc.connect(connection_string, timeout=10)

    print("=" * 60)
    print("SUCCESSFULLY CONNECTED TO SQL SERVER")
    print("=" * 60)


    # =====================================================
    # 3. LOAD ORDERS DATA
    # =====================================================

    query = "SELECT * FROM Orders"

    df = pd.read_sql_query(query, connection)


    # =====================================================
    # 4. BASIC DATASET OVERVIEW
    # =====================================================

    print("\n--- DATASET OVERVIEW ---")

    print("Total rows:", df.shape[0])
    print("Total columns:", df.shape[1])

    print("\n--- COLUMN DATA TYPES ---")
    print(df.dtypes)

    print("\n--- FIRST 5 ROWS ---")
    print(df.head())


    # =====================================================
    # 5. MISSING VALUES
    # =====================================================

    print("\n--- MISSING VALUES ---")
    print(df.isnull().sum())

    print("\n--- DUPLICATE ORDER IDs ---")
    print(df["order_id"].duplicated().sum())


    # =====================================================
    # 6. ORDER STATUS DISTRIBUTION
    # =====================================================

    print("\n--- ORDER STATUS COUNTS ---")

    status_counts = df["order_status"].value_counts(dropna=False)

    print(status_counts)


    # =====================================================
    # 7. MISSING DELIVERY DATES BY ORDER STATUS
    # =====================================================

    print("\n--- MISSING CUSTOMER DELIVERY DATES BY STATUS ---")

    missing_delivery = (
        df[df["order_delivered_customer_date"].isna()]
        .groupby("order_status")
        .size()
        .sort_values(ascending=False)
    )

    print(missing_delivery)


    print("\n--- MISSING CARRIER DATES BY STATUS ---")

    missing_carrier = (
        df[df["order_delivered_carrier_date"].isna()]
        .groupby("order_status")
        .size()
        .sort_values(ascending=False)
    )

    print(missing_carrier)


    # =====================================================
    # 8. INVESTIGATE DELIVERED ORDERS WITH MISSING DATES
    # =====================================================

    print("\n--- DELIVERED ORDERS WITH MISSING CUSTOMER DELIVERY DATE ---")

    missing_delivered = df[
        (df["order_status"] == "delivered")
        & (df["order_delivered_customer_date"].isna())
    ]

    print("Number of affected orders:", len(missing_delivered))

    if not missing_delivered.empty:
        print(missing_delivered.to_string(index=False))
    else:
        print("No affected orders found.")


    print("\n--- DELIVERED ORDERS WITH MISSING CARRIER DATE ---")

    missing_carrier_delivered = df[
        (df["order_status"] == "delivered")
        & (df["order_delivered_carrier_date"].isna())
    ]

    print("Number of affected orders:", len(missing_carrier_delivered))

    if not missing_carrier_delivered.empty:
        print(missing_carrier_delivered.to_string(index=False))
    else:
        print("No affected orders found.")


    # =====================================================
    # 9. DELIVERY PERFORMANCE ANALYSIS
    # =====================================================

    # Calculate the time between purchase and actual delivery.
    # Exclude records where actual delivery date is missing.

    delivered_orders = df[
        (df["order_status"] == "delivered")
        & (df["order_delivered_customer_date"].notna())
        & (df["order_purchase_timestamp"].notna())
    ].copy()

    delivered_orders["delivery_days"] = (
        delivered_orders["order_delivered_customer_date"]
        - delivered_orders["order_purchase_timestamp"]
    ).dt.total_seconds() / 86400


    # Compare actual delivery date with estimated delivery date.
    # Only compare records that have an actual delivery date.

    delivered_orders["delivered_late"] = (
        delivered_orders["order_delivered_customer_date"].dt.date
        > delivered_orders["order_estimated_delivery_date"].dt.date
    )


    print("\n--- DELIVERY PERFORMANCE ---")

    print("All orders:", len(df))

    print(
        "Orders marked delivered:",
        (df["order_status"] == "delivered").sum()
    )

    print(
        "Delivered orders with a recorded delivery date:",
        len(delivered_orders)
    )

    print(
        "Average purchase-to-delivery time (days):",
        round(delivered_orders["delivery_days"].mean(), 2)
    )

    print(
        "Median purchase-to-delivery time (days):",
        round(delivered_orders["delivery_days"].median(), 2)
    )

    late_orders = int(delivered_orders["delivered_late"].sum())

    print("Orders delivered after estimated date:", late_orders)

    if len(delivered_orders) > 0:
        late_percentage = late_orders / len(delivered_orders) * 100

        print(
            "Percentage delivered after estimated date:",
            round(late_percentage, 2),
            "%"
        )


    # =====================================================
    # 10. DELIVERY TIME SUMMARY
    # =====================================================

    print("\n--- DELIVERY TIME SUMMARY ---")

    print(
        delivered_orders["delivery_days"]
        .describe()
        .round(2)
    )
    # =====================================================
    # 11. INVESTIGATE THE 10 LONGEST DELIVERY TIMES
    # =====================================================

    print("\n--- 10 ORDERS WITH THE LONGEST DELIVERY TIMES ---")

    longest_deliveries = delivered_orders.sort_values(
        by="delivery_days",
        ascending=False
    )

    columns_to_show = [
        "order_id",
        "order_status",
        "order_purchase_timestamp",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
        "delivery_days",
        "delivered_late"
    ]

    print(
        longest_deliveries[columns_to_show]
        .head(10)
        .to_string(index=False)
    )

    # =====================================================
    # 12. COMPLETION MESSAGE
    # =====================================================

    print("\n" + "=" * 60)
    print("DATA EXPLORATION COMPLETED SUCCESSFULLY")
    print("=" * 60)


except Exception as error:
    print("\nAN ERROR OCCURRED:")
    print(error)


finally:
    # Close the connection only after all analyses finish.
    if connection is not None:
        connection.close()
        print("\nSQL Server connection closed.")