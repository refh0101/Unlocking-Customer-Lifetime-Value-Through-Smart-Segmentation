--create table Nexasat in schema

CREATE Table "Nexa_Sat".Nexasat(
       Customer_id Varchar (50),
	   gender varchar(10),
	   Partner varchar(3),
	   Dependents varchar(3),
	   Senior_Citizens INT,
	   Call_Duration float,
	   Data_Usage Float,
	   Plan_Type VARCHAR(20),
	   Plan_Level varchar(20),
	   Monthly_Bill_Amount Float,
	   Tenure_Months INT,
	   Multiple_Lines varchar(3),
	   Tech_Support varchar(3),
	   Churn INT
);

-- Import the data in the table

-- Return Data from entire table limit to 20 records
SELECT * FROM "Nexa_Sat".Nexasat
limit 20;


-- Check the current schema 
SELECT current_schema();


-- Set Path for queries - helps not to point to the schema each time
SET search_path TO "Nexa_Sat";


--- DATA CLEANING

-- Checking Duplicplicates
select  Customer_id ,
	   gender,
	   Partner,
	   Dependents,
	   Senior_Citizens,
	   Call_Duration ,
	   Data_Usage ,
	   Plan_Type,
	   Plan_Level,
	   Monthly_Bill_Amount,
	   Tenure_Months ,
	   Multiple_Lines,
	   Tech_Support,
	   Churn 
from nexasat
GROUP by Customer_id ,
	   gender,
	   Partner,
	   Dependents,
	   Senior_Citizens,
	   Call_Duration ,
	   Data_Usage ,
	   Plan_Type,
	   Plan_Level,
	   Monthly_Bill_Amount,
	   Tenure_Months ,
	   Multiple_Lines,
	   Tech_Support,
	   Churn 
HAVING COUNT (*) > 1 ; -- this filters out rows that are duplicate

-- Checking if all rows have null 
select *
from nexasat
where Customer_id IS NULL
OR	gender IS NULL
OR	   Partner IS NULL
OR   Dependents IS NULL
OR	   Senior_Citizens IS NULL
OR	   Call_Duration IS NULL
OR	   Data_Usage IS NULL
OR	   Plan_Type IS NULL
OR	   Plan_Level IS NULL
OR	   Monthly_Bill_Amount IS NULL
OR	   Tenure_Months IS NULL
OR	   Multiple_Lines IS NULL
OR	   Tech_Support IS NULL
OR	   Churn IS NULL;


---- EXPLORETARY DATA ANALYSIS

-- number of current users
select
COUNT (customer_id) as currentusers
from nexasat
where churn = 0;

-- total users by LEVEL

select Plan_Level
count(customer_id) as total users
from nexasat
-- where churn = 0
group  by 1;

-- total revenue
select 
ROUND(sum (Monthly_Bill_Amount::NUMERIC),2) as revenue
from naxasat;


--revenue by plan_level
select plan_level,
round(sum(monthly_bill_amount::numeric),2)
from nexasat
group by plan_level;


--churn count y plan-type and plan_level
select plan_type,plan_level,
       count (*) as totalcustomers,
       sum (churn) as churncount
from nexasat
group by plan_type,plan_level
Order by plan_type;


--avg tenure by plan level
select plan_level,
round(avg(tenure_months),2) as avgtenure
from nexasat
group by 1;


--- MARKETING SEGMENT

-- create table of existing customers ONLY
CREATE TABLE existing_customers as
select * 
from nexaset
where churn = 0;


-- view the new table
select * 
from existing_customers;


-- average revenue per USER
select
round(avg(Monthly_Bill_Amount::numeric),2) AS ARPU
from existing_customers;


-- CLV

-- Add new column to table
ALTER TABLE existing_customers
ADD column clv FLOAT;

-- calculating and updating rows for clv
UPDATE existing_customers
SET clv = Monthly_Bill_Amount * tenure_months;

-- View data in new column
SELECT Customer_id, clv
from existing_customers;


-- CLV SCORES Monthly_Bill_Amount 40%, tenure 30%, Call_Duration 10%, Data_Usage 10%, premium 10%

--  create the new column for clv SCORES
ALTER table existing_users
add column clv_score;


-- updating the new column
UPDATE existing_users
SET clv_score = 
	(0.4 * monthly_bill_amount) + 
	(0.3 * tenure_months) + 
	(0.1 * data_usage)+
	(0.1 * call_duration) + 
	(0.1 * CASE WHEN plan_level = 'Premium' 
	THEN 1 ELSE 0
	End);
	

-- View of the data
select customer_id, clv_score
from existing_customers;

-- group the customers based on clv_score

--create the segment clv score
ALTER TABLE existing_users
ADD COLUMN segments_clv VARCHAR;


-- update the segment clv score column by calcullating it by segment
UPDATE existing_users
SET segments_clv = 
   case when clv_score > (select percentile_cont(0.85) within 
	group (order by clv_score) from existing_users
	)THEN 'high value'

        when clv_score >= (select percentile_cont(0.5) within 
	group (order by clv_score) from existing_users
	)THEN 'Moderate Value'

      when clv_score >= (select percentile_cont(0.25) within 
	group (order by clv_score) from existing_users
	)THEN 'low value'

   else 'churn-risk'
end;

-- view the data in new COLUMN
select customer_id, clv, clv_score, segments_clv
from existing_users;

---- ANALYSING THE SEGMENTS


-- avg bill and tenure per segment

select segments_clv,
round(avg(tenure_months),2) AS avg_tenure, 
round(avg(monthly_bill_amount::numeric),2) AS avg_monthly_charges
from existing_users
group by segments_clv


-- tech suport and multiple lines count across each segments
SELECT segments_clv,
       ROUND(AVG(CASE WHEN LOWER(TRIM(tech_support)) = 'yes' THEN 1 ELSE 0 END), 2) AS tech_support_pct,
       ROUND(AVG(CASE WHEN LOWER(TRIM(multiple_lines)) = 'yes' THEN 1 ELSE 0 END), 2) AS multiple_lines_pct
FROM existing_users
GROUP BY 1;

-- revenue per SEGMENT
select segments_clv,count(customer_id) round(sum(monthly_bill_amount::INT),2) AS total_revenue
from existing_users
group by 1; 


----- CROSS SELLING AND UPSELLING

-- thinking of offering support to the senior citizens, they may have trouble using the services

-- number of senior citizens who have no IT support per segmnet

select segments_clv, count(senior_citizens) AS total_seniors, 
 COUNT(CASE WHEN LOWER (trim(tech_support)) = 'no' THEN 1 ELSE NULL END) AS tech_support_no
from existing_users
group by 1;

--- cross selling tech support to snr citizens
SELECT customer_id
FROM existing_users
WHERE senior_citizens = 1    --- snr citizens
AND LOWER(TRIM(dependents)) = 'no'  --- no dependents to help 
AND LOWER(TRIM(tech_support)) = 'no'  --- they dont have anything
AND (LOWER(TRIM(segments_clv)) = 'churn risk' OR LOWER(TRIM(segments_clv)) = 'low value');  --- targetting only customers in the churn risk and low value



-- cross selling multiple lines to those customers with Dependents, partners
SELECT customer_id
FROM existing_users
WHERE LOWER(TRIM(multiple_lines)) = 'no'
AND (LOWER(TRIM(dependents)) = 'yes' OR LOWER(TRIM(partner)) = 'yes')  -- customers who have dependents
AND LOWER(TRIM(plan_level)) = 'basic'; -- those with basic plan


--- up selling: Premium discount for basic users with churn risk
select Customer_id
from existing_customers
where 


--- up selling: Premium discount for basic users with churn risk
select Customer_id
from existing_users
where LOWER (TRIM(segments_clv)) = 'churn risk'
AND LOWER (TRIM(plan_level)) = 'basic'


--- up-selling : basic to premium for longer lock-in period and higher ARPU
SELECT plan_level, 
       ROUND(AVG(monthly_bill_amount::NUMERIC), 2), 
       ROUND(AVG(tenure_months::NUMERIC), 2)
FROM existing_users
WHERE LOWER(TRIM(segments_clv)) IN ('high value', 'moderate value')
GROUP BY 1;


--- select the customers 
select customer_id, monthly_bill_amount
from existing_users
where plan_level = 'Basic'
AND (segments_clv = 'High Value' OR segments_clv = 'Moderate Value')
AND monthly_bill_amount > 150;


--------------------------------STORED PROCEDURE ----------------------------


----snr citizens who will be offered tech support
CREATE FUNCTION tech_support_snr_citizens()
RETURNS TABLE (customer_id VARCHAR(50))
AS $$
BEGIN
  RETURN QUERY
  SELECT eu.Customer_id
  FROM existing_users eu
  WHERE eu.senior_citizens = 1 --senior citizens
  AND LOWER(TRIM(eu.dependents)) = 'no'
  AND LOWER(TRIM(eu.tech_support)) = 'no'
  AND (LOWER(TRIM(eu.segments_clv)) = 'churn risk' OR LOWER(TRIM(eu.segments_clv)) = 'low value');
END
$$ LANGUAGE plpgsql;

---- at risk customers who will be offered premium discount
CREATE FUNCTION churn_risk_discount()
RETURNS TABLE (customer_id VARCHAR(50))
AS $$
BEGIN 
   RETURN QUERY
   SELECT eu.customer_id
   FROM existing_users eu
   WHERE (LOWER(TRIM(eu.segments_clv)) = 'churn risk'
   AND eu.plan_level = 'Basic');
END
$$ LANGUAGE plpgsql;




----- high usage customer who will be offered premium upgrade
CREATE FUNCTION high_usage_basic()
RETURNS TABLE (customer_id VARCHAR(50))
AS $$
BEGIN
   RETURN QUERY
   SELECT eu.Customer_id, eu.month_bill_amount
   FROM existing_user eu
   WHERE eu.plan_leve = 'Basic'
   AND (eu.segments_clv = 'High Value' OR eu.segments_clv = 'Moderate Value')
   AND eu.monthly_bill_amount > 150;
END
$$ LANGUAGE plpgsql;


------USE THE PROCEDURES

---- snr citizens who will recieve discounts
SELECT *
from tech_support_snr_citizens();


----- at risk customers who will be offered premium discount
SELECT *
from high_usage_basic();

----high usage customer who will be offered premium upgrade
SELECT *
from high_usage_basic();


---- 
--- 

