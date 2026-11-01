
import pyodbc

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

try:
    connection = pyodbc.connect(connection_string, timeout=10)

    print("Successfully connected to SQL Server!")

    cursor = connection.cursor()

    cursor.execute("SELECT COUNT(*) FROM Orders")
    total_orders = cursor.fetchone()[0]

    print("Total orders in database:", total_orders)

    cursor.close()
    connection.close()

    print("Connection closed successfully.")

except pyodbc.Error as error:
    print("Connection failed:")
    print(error)