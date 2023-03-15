/*
Returns table with sum of expenses in last 30, 90 and 180 days for each client along with number of days that passed from last order (instead of current time the date of the newest order present in the initial database is used)
*/
CREATE TABLE sum_expenses AS WITH tDate (
	maxDate
) AS (
	SELECT
		max(ORDERDATE)
	FROM
		sales
),
customerExpenses AS (
	SELECT
		CUSTOMERNAME,
		SUM(
			CASE WHEN ORDERDATE >= DATE_ADD(tDate.maxDate,
				INTERVAL - 30 DAY) THEN
				PRICEEACH * QUANTITYORDERED
			ELSE
				0
			END) AS 30DaysExpenses,
		SUM(
			CASE WHEN ORDERDATE >= DATE_ADD(tDate.maxDate,
				INTERVAL - 90 DAY) THEN
				PRICEEACH * QUANTITYORDERED
			ELSE
				0
			END) AS 90DaysExpenses,
		SUM(
			CASE WHEN ORDERDATE >= DATE_ADD(tDate.maxDate,
				INTERVAL - 180 DAY) THEN
				PRICEEACH * QUANTITYORDERED
			ELSE
				0
			END) AS 180DaysExpenses,
		MAX(ORDERDATE) AS LastPurchaseDate
	FROM
		sales,
		tDate
	GROUP BY
		CUSTOMERNAME
)
SELECT
	CUSTOMERNAME,
	30DaysExpenses,
	90DaysExpenses,
	180DaysExpenses,
	DATEDIFF(tDate.maxDate, LastPurchaseDate) AS LastPurchaseInterval
FROM
	customerExpenses,
	tDate;
/*
Returns table with name of the productline with most orders for each customer
*/

CREATE TABLE popular_productline AS WITH t1 AS (
	SELECT
		CUSTOMERNAME,
		PRODUCTLINE,
		COUNT(1) AS LineQuantity
	FROM
		sales
	GROUP BY
		CUSTOMERNAME,
		PRODUCTLINE
),
t2 AS (
	SELECT
		CUSTOMERNAME,
		MAX(LineQuantity) AS MaxLineQuantity
	FROM
		t1
	GROUP BY
		CUSTOMERNAME
)
SELECT
	t2.CUSTOMERNAME,
	t1.PRODUCTLINE,
	t2.MaxLineQuantity
FROM
	t2
	LEFT JOIN t1 ON t2.MaxLineQuantity = t1.LineQuantity
		AND t2.CUSTOMERNAME = t1.CUSTOMERNAME
	ORDER BY
		t1.CUSTOMERNAME ASC;
/*
Returns avarage time distance between orders for each customer
*/

CREATE TABLE order_time_diff AS WITH tempOrder AS (
	SELECT DISTINCT
		ORDERNUMBER,
		ORDERDATE,
		CUSTOMERNAME
	FROM
		sales
),
t3 AS (
	SELECT
		CUSTOMERNAME,
		ORDERDATE,
		LAG(ORDERDATE,
			1) OVER (PARTITION BY CUSTOMERNAME ORDER BY ORDERDATE) AS PreviousOrderDate
	FROM
		tempOrder
)
SELECT
	CUSTOMERNAME,
	AVG(DATEDIFF(ORDERDATE, PreviousOrderDate)) AS AvgDateDifference
FROM
	t3
WHERE
	PreviousOrderDate IS NOT NULL
GROUP BY
	CUSTOMERNAME;

/*
Returns the trend of sales for each productline
 */
CREATE TABLE sales_trends AS WITH t4 AS (
	SELECT
		SUM(QUANTITYORDERED) AS y,
		DATEDIFF(ORDERDATE,
			"2003/01/01") AS x,
		PRODUCTLINE
	FROM
		sales
	GROUP BY
		PRODUCTLINE,
		x
),
t5 AS (
	SELECT
		PRODUCTLINE,
		x,
		AVG(x) OVER (PARTITION BY PRODUCTLINE) AS X_bar,
		y,
		AVG(y) OVER (PARTITION BY PRODUCTLINE) AS Y_bar
	FROM
		t4
)
SELECT
	PRODUCTLINE,
	SUM((x - x_bar) * (y - y_bar)) / SUM((x - x_bar) * (x - x_bar)) AS Slope
FROM
	t5
GROUP BY
	PRODUCTLINE
ORDER BY
	Slope DESC;


CREATE VIEW customer_raport AS
SELECT 
	sum_expenses.*,
	popular_productline.PRODUCTLINE,
	popular_productline.MaxLineQuantity,
	order_time_diff.AvgDateDifference
FROM 
	sum_expenses
LEFT JOIN
	popular_productline
ON sum_expenses.CUSTOMERNAME = popular_productline.CUSTOMERNAME
LEFT JOIN 
	order_time_diff
ON
	sum_expenses.CUSTOMERNAME = order_time_diff.CUSTOMERNAME