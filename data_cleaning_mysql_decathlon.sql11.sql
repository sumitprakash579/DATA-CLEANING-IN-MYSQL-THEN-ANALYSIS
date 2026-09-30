-- DATA CLEANING (MySQL) | Table: decathlon_sales_raw
-- Used joins with master tables (product, customer, store)
-- to fix wrong and missing values.

-- STEP 1: Clean the transaction_date column

-- Fixed an invalid date (31 Feb does not exist) by changing it to 28 Feb.

update decathlon_sales_raw
set  transaction_date = '28/02/2024'
WHERE transaction_date like  '31/02/2024';

-- Replaced invalid dates (0000-00-00) with NULL.

UPDATE decathlon_sales_raw
SET transaction_date = NULL
WHERE TRIM(transaction_date) = '0000-00-00';


-- Removed the extra slash from dates like 12//01/2024.

update decathlon_sales_raw
SET transaction_date = REPLACE(transaction_date, '//', '/')
WHERE transaction_date LIKE '%//%';


-- Converted all the different date formats into one standard date format.


update decathlon_sales_raw
Set transaction_date = 
cASE
	WHEN transaction_date IS NULL THEN NULL
	WHEN transaction_date LIKE '__-__-____'
        THEN STR_TO_DATE(transaction_date, '%m-%d-%Y')
	WHEN transaction_date LIKE '%,%'
		THEN STR_TO_DATE(transaction_date, '%b %e, %Y')
	WHEN transaction_date LIKE '%/%/%'
		THEN STR_TO_DATE(transaction_date, '%d/%m/%Y')
        WHEN transaction_date LIKE '%//%/%'
		THEN STR_TO_DATE(transaction_date, '%d/%m/%Y')
	WHEN transaction_date LIKE '__-___-____'
		THEN STR_TO_DATE(transaction_date, '%d-%b-%Y')
	WHEN transaction_date LIKE '____-__-__'
		THEN STR_TO_DATE(transaction_date, '%Y-%m-%d')
        ELSE NULL
    END ;


-- STEP 2: Clean the text columns (extra spaces and capital letters)


-- Removed extra spaces from the text columns before changing their format.

UPDATE decathlon_sales_raw
SET customer_name = TRIM(store_city);

-- Made the first letter capital and the rest small in city, category, brand and payment mode.


UPDATE decathlon_sales_raw
SET store_city = CONCAT(UPPER(LEFT(store_city, 1)),LOWER(SUBSTRING(store_city, 2))),
category = CONCAT(UPPER(LEFT(LOWER(category), 1)), LOWER(SUBSTRING(category, 2))),
brand = CONCAT(UPPER(LEFT(LOWER(brand), 1)), LOWER(SUBSTRING(brand, 2))),
payment_mode = CONCAT(UPPER(LEFT(LOWER(payment_mode), 1)), LOWER(SUBSTRING(payment_mode, 2)));


-- STEP 3: Clean the quantity (qty) column


-- Checked all the different values in the qty column.

select distinct qty from decathlon_sales_raw;

-- Replaced hyphens with spaces.

update decathlon_sales_raw
set  qty  =  replace(qty, '-', ' ');

-- Removed extra spaces.

update decathlon_sales_raw
set  qty =  trim(qty);

-- Converted words (one, two, three) and decimals (2.0, 3.0) into proper numbers.

update decathlon_sales_raw
set qty = 
case
     when qty like 'one' then 1
     when qty like null then 0
     when qty like 'Three' then 3
     when qty like 'two' then 2
     when qty like 2.0 then 2
     when qty like 3.0 then 3
     when qty then qty
     end;



-- STEP 4: Fix product_id, unit_price, total_amount and qty


-- Checked all the different values in the product_id column.

select distinct product_id from decathlon_sales_raw;


-- Fixed product_id by matching the product name with the product_master table (join).

 UPDATE decathlon_sales_raw d
JOIN product_master s
    ON d.product_name = s.product_name
SET d.product_id = s.product_id;

-- Filled the correct unit_price from the product_master table (join),

-- so it can be used to fix missing qty.

UPDATE decathlon_sales_raw d
JOIN product_master s
ON d.product_id = s.product_id
SET d.unit_price = s.current_price;

-- Filled missing total_amount with unit_price where qty is 1 or missing.

UPDATE decathlon_sales_raw d
JOIN decathlon_sales_raw s
ON d.unit_price = s.unit_price
SET d.total_amount = s.unit_price
where d.qty = 1 OR d.qty is NULL;

-- Undo (rollback) or save (commit) the changes.

rollback;
commit;


-- Filled missing qty as 1 where unit_price and total_amount are the same.

Update decathlon_sales_raw
Set qty = 1
Where qty is null 
And unit_price = total_amount;

-- Calculated missing total_amount using unit_price x qty.

Update decathlon_sales_raw
Set total_amount = (unit_price*qty)
Where total_amount is null ;


-- Replaced 0.00 in total_amount with NULL.
 
UPDATE decathlon_sales_raw
SET total_amount = NULL
WHERE total_amount = '0.00';



-- STEP 5: Fix customer phone number


-- Filled the correct phone number from the customer_master table using customer_id (join).

update  decathlon_sales_raw d
join customer_master s
on d.customer_id = s.customer_id
set d.customer_phone = s.phone;


-- STEP 6: Clean the employee_id column
-- Checked all the different employee_id values and made them capital letters.

-- Added the EMP0 prefix to IDs that were only a single number (1 to 9).

UPDATE decathlon_sales_raw
SET employee_id = CONCAT('EMP0', employee_id)
WHERE employee_id IN ('3', '5', '6', '9','2','1','7','4','8');

-- Removed hyphens from employee_id.

UPDATE decathlon_sales_raw
SET employee_id = replace(employee_id,'-', '');


-- STEP 7: Clean the is_returned column


-- Made all values either Yes or No (y, 1 = Yes | N, 0 = No).

update decathlon_sales_raw
set is_returned = 
case
when is_returned = 'No' then 'No'
when is_returned = 'Yes' then 'Yes'
when is_returned = 'y' then 'Yes'
when is_returned =  'N' then 'No'
when is_returned = null then null
when is_returned= '0' then 'No'
when is_returned = '1' then 'Yes'
end ;


-- Checked the main table and all the master tables.

select * from decathlon_sales_raw;
select * from customer_master;
select * from store_master ;
select * from product_master;


-- STEP 8: Fix store_id, store_city and customer_city
-- (done before starting the MySQL analysis)
select store_id, store_city and customer_city
Where store_city is NULL and 
store_id is  NULL;

--  but some rows have a store_city even when store_id is NULL. So first fix the
-- city names, then use them to fill store_id.


-- Fixed misspelled and old city names (for example Bombay to Mumbai, Bangalore to Bengaluru).


  SET autocommit = 0;
  START TRANSACTION;

 UPDATE decathlon_sales_raw
SET store_city =
    CASE
   WHEN store_city = 'Ahemdabad' THEN 'Ahmedabad'
   WHEN store_city = 'Hyderbad' THEN 'Hyderabad'
	  WHEN store_city = 'Poona' THEN 'Pune'
	  WHEN store_city = 'Calcutta' THEN 'Kolkata'
	  WHEN store_city = 'New delhi' THEN 'Delhi'
	  WHEN store_city = 'Bangalore' THEN 'Bengaluru'
	  WHEN store_city = 'Madras' THEN  'Chennai'
      WHEN  store_city = 'Bombay' THEN 'Mumbai'
        ELSE store_city
    END;

-- Filled the missing store_id using the city from the store_master table (join).

update decathlon_sales_raw d 
join store_master s
on  d.store_city = s.city                                               -- store_id filled using city from store table
set d.store_ID = s.store_id 
where d.store_ID is null;

-- Filled the missing store_city using customer_city where store_id was also missing (self join).

update decathlon_sales_raw d
join decathlon_sales_raw s
on d.row_id = s.row_id                                  -- self join on row_id
 set d.store_city= s.customer_city
where d.store_city is null and d.store_id is null ;


-- Some rows still have store_id, store_city and customer_city all NULL.
-- But customer_id is available, so we get the customer_city from the customer_master table.

-- Checked the rows where store_city and store_id are still NULL.

select * from decathlon_sales_raw where store_city is null  and store_id is null; 

-- Filled the missing customer_city using home_city from the customer_master table (join).

update decathlon_sales_raw d 
join customer_master s 
on d.customer_id = s.customer_id 
set d.customer_city  = s.home_city
where d.customer_city is null;



-- STEP 9: Clean the payment_mode column

-- Made payment mode names consistent (Cash, COD, UPI, Card, Credit Card, Debit Card, NEFT).

UPDATE decathlon_sales_raw
SET payment_mode =
    CASE
        WHEN LOWER(TRIM(payment_mode)) = 'cash' THEN 'Cash'
        WHEN LOWER(TRIM(payment_mode)) = 'cod' THEN 'COD'
        WHEN LOWER(TRIM(payment_mode)) = 'upi' THEN 'UPI'
        WHEN LOWER(TRIM(payment_mode)) = 'card' THEN 'Card'
        WHEN LOWER(TRIM(payment_mode)) = 'credit card' THEN 'Credit Card'
        WHEN LOWER(TRIM(payment_mode)) = 'debit card' THEN 'Debit Card'
        WHEN LOWER(TRIM(payment_mode)) = 'neft' THEN 'NEFT'
        ELSE payment_mode
    END;

