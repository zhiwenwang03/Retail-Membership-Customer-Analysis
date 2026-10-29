# Retail Membership Customer Analysis

A retail analytics project using **MySQL, Power BI, and DAX** to explore customer spending, segment buyers, evaluate product performance, and identify purchase funnel drop-offs.

**Data note:** This project uses a synthetic dataset modeled on a Sam's Club-style membership retail scenario. It does not use actual Sam's Club customer or transaction data and is not affiliated with the company. Findings illustrate analytical methods rather than verified business outcomes.

## Project Objectives

- Build a structured analytical model from six related source tables.
- Identify customer segments and opportunities for retention and reactivation.
- Compare sales performance across categories, brands, and price bands.
- Examine conversion metrics and customer drop-offs across five funnel stages.
- Present results through an interactive Power BI dashboard.

## Tools and Methods

| Tool / Method | Application |
|---|---|
| MySQL 8.0+ | Data import, validation, cleaning, joins, CTEs, aggregations, and window functions |
| Dimensional modeling | Two fact tables and two dimension tables |
| RFM analysis | Customer scoring and segmentation using recency, frequency, and monetary value |
| Power BI and DAX | Interactive reporting, measures, and business metrics |
| Funnel analysis | Cumulative user counts and stage-to-stage conversion |
| Python | Included synthetic data generation script |

## Dataset

The order period covers **October 1, 2025 to September 30, 2026**.

| Source Table | Records | Description |
|---|---:|---|
| `users` | 5,000 | Customer demographics and membership information |
| `user_features` | 5,000 | Customer-level spending and behavior features |
| `products` | 2,000 | Product categories, brands, and prices |
| `product_features` | 2,000 | Product-level traffic and sales features |
| `orders` | 15,000 | Orders, payments, quantities, and fulfillment information |
| `user_behaviors` | 30,000 | Browse, click, favorite, and add-to-cart events |

CSV files and the generation script are included in `Customer Spending Dataset/`. Some source values and SQL output labels are in Chinese.

## Analysis Workflow

### 1. Data Exploration and Cleaning

- Validate record counts, missing values, duplicate identifiers, numeric ranges, and relationships between tables.
- Flag **38 abnormal orders**, including 8 zero-quantity orders and 30 zero-payment orders, instead of deleting them.
- Exclude flagged orders from downstream valid-order analysis.

### 2. Dimensional Modeling

Create an analytical schema with:

- **`dim_user`**: customer information and aggregated customer features.
- **`dim_product`**: product information and aggregated product features.
- **`fact_orders`**: order records, including the abnormal-order flag.
- **`fact_behaviors`**: customer behavior events.

### 3. Customer Profiling and RFM Segmentation

Analyze customer demographics, membership levels, geographic distribution, and spending patterns. Score **3,652 valid buyers** on:

- **Recency:** days since the latest valid order, measured as of October 1, 2026.
- **Frequency:** number of valid orders.
- **Monetary value:** total actual payment from valid orders.

Assign scores from 1 to 5 and classify buyers into **8 segments** to inform retention, repeat-purchase, and reactivation strategies. Valid orders are paid, shipped, or completed orders with `is_abnormal = 0`.

### 4. Product Performance Analysis

- Compare category and brand revenue, order value, and price-band performance.
- Pre-aggregate orders before joining product tables to avoid JOIN fan-out.
- Use non-overlapping price bands for consistent classification.
- Calculate traffic-weighted conversion as total sales divided by total views for products with at least 10 views, reducing the influence of tiny samples.

### 5. Funnel Analysis and Dashboarding

Analyze the five-stage path: **Browse -> Click -> Favorite -> Add to Cart -> Order**.

A user is counted at a stage only if they also completed all preceding stages. Save the resulting counts in `funnel_strict` for Power BI, and use DAX measures to support interactive customer, product, and conversion analysis.

## Selected Findings

The SQL scripts document the following results for the included synthetic data:

- The high-value segment represents **18.9% of valid buyers** and contributes **51.5% of valid-order payment value**, suggesting a focus on retention.
- **1,165 buyers purchased only once**, highlighting repeat-purchase opportunities.
- The funnel narrows from **4,103 browsing users to 538 buyers** who also completed every preceding stage, an overall rate of **13.11%**.
- The largest proportional funnel drop-off is **Click -> Favorite**, at approximately **56%**.

These findings support example recommendations; the project does not measure the impact of implementing those recommendations.

## Repository Contents

| File / Folder | Purpose |
|---|---|
| `01_Data_Exploration_and_Quality_Check.sql` | Database setup, CSV import, and data quality checks |
| `02_Data_Cleaning.sql` | Missing-value handling and abnormal-order flags |
| `03_Dimensional_Modeling.sql` | Dimension and fact table construction |
| `04_User_Profile.sql` | Demographic, membership, geographic, and spending analysis |
| `05_RFM_Segmentation.sql` | RFM metrics, scores, and customer segments |
| `06_Product_Analysis.sql` | Category, brand, price-band, and conversion analysis |
| `07_Funnel_Analysis.sql` | Behavior analysis and the saved funnel table |
| `Customer Spending Dataset/` | Synthetic CSV files, generation script, and dataset notes |
| `Sam's Club Business Analysis.pbix` | Power BI report |

## How to Reproduce

### Requirements

- MySQL 8.0 or later.
- A SQL client such as DataGrip, MySQL Workbench, or DBeaver.
- Power BI Desktop to open the `.pbix` report.
- Python only if regenerating the synthetic data; the CSV files are already included.

### Run the SQL Analysis

1. Clone or download this repository.
2. Open `01_Data_Exploration_and_Quality_Check.sql` and replace each `LOAD DATA LOCAL INFILE` path with the actual path to its CSV in `Customer Spending Dataset/`.
3. Ensure local file loading is enabled in both the MySQL server and your SQL client. Preserve the CSV encoding and check that the configured line endings match the files.
4. Run script `01` to create the `sam_analysis` database, import the six source tables, and inspect data quality.
5. Keep `sam_analysis` selected and run scripts `02` through `07` in numerical order.
6. Review the query outputs and the generated RFM and funnel tables.

**Rerun note:** Use a fresh database for a full rerun. Some setup and cleaning statements create existing tables or add columns and are not designed to run repeatedly without resetting the database.

### Open the Power BI Report

1. Open `Sam's Club Business Analysis.pbix` in Power BI Desktop.
2. To refresh the report, update the data source settings to point to your own MySQL server and `sam_analysis` database.
3. Configure your local connection credentials and any connector dependencies requested by Power BI, then refresh.

## Interpretation Notes

- The funnel checks cumulative participation across the dataset period. It does **not** enforce timestamp order, a common session, or the same product across stages.
- Orders and behaviors are generated independently, so funnel rates should not be interpreted as observed real-world customer journeys.
- Requiring a favorite action before add-to-cart is a modeling choice for this project; other purchase paths are excluded from later funnel stages.
- Product conversion metrics use the supplied product features, while valid-order revenue and RFM analysis use filtered orders. Their calculation scopes differ.
