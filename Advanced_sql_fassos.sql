use fassos;
-- ----How many roles were orderd--
select count(roll_id)
from customer_orders;
-- ----How many unique customers orders were made---
select count(distinct customer_id)
from customer_orders;
-- how many successful orders were deliverd by each driver?
SELECT driver_id, count(cancellation) as successfully_delievrd
FROM driver_order
join customer_orders on customer_orders.order_id=driver_order.order_id
WHERE cancellation NOT IN ('Cancellation', 'Customer Cancellation')
OR cancellation IS NULL
group by driver_id;
-- How many of each type of rolls were deliverd?
SELECT roll_id, count(roll_id) 
FROM customer_orders
WHERE order_id IN (
    SELECT co.order_id
    FROM driver_order do
    JOIN customer_orders co ON co.order_id = do.order_id
    WHERE do.cancellation NOT IN ('Cancellation', 'Customer Cancellation')
       OR do.cancellation IS NULL
)
GROUP BY roll_id;
-- How many veg and nonveg rolls were ordered by each of customer

SELECT a.customer_id, a.roll_id, a.cnt, b.roll_name
FROM (
    SELECT customer_id, roll_id, COUNT(roll_id) AS cnt
    FROM customer_orders
    GROUP BY customer_id, roll_id
) a
INNER JOIN rolls b ON b.roll_id = a.roll_id
order by cnt desc;
-- What was the maximum number or rolls deliverd in single order
select *,rank() over (order by max_roll desc) rnk 
from
(SELECT d.order_id,count(roll_id) as max_roll
FROM driver_order d
join customer_orders on customer_orders.order_id=d.order_id
WHERE cancellation NOT IN ('Cancellation', 'Customer Cancellation')
OR cancellation IS NULL
group by d.order_id) c;
-- for each customers  how many  deliverd rolls had atleast 1 change and how many had no change?  
Select customer_id,
CASE WHEN w.not_include_items NOT IN ('', 'nan', 'null') THEN 'Change' ELSE 'no change' END AS not_include_items, 
CASE WHEN w.extra_items_included NOT IN ('', 'nan', 'null') THEN'chnage'ELSE 'no change' END AS extra_items_included
from
(Select customer_orders.customer_id,not_include_items,extra_items_included
from customer_orders, (
SELECT driver_id,count(cancellation) as successfully_delievrd
FROM driver_order
join customer_orders on customer_orders.order_id=driver_order.order_id
WHERE cancellation NOT IN ('Cancellation', 'Customer Cancellation')
OR cancellation IS NULL
group by driver_id) as a
where not_include_items  NOT IN ('', 'nan', 'null') or 
extra_items_included   NOT IN ('', 'nan', 'null')
group by customer_orders.customer_id,not_include_items,extra_items_included
)as w;
-- How many rolls have been ordered that have both excusion and extras?
SELECT *
from
(Select customer_id,
CASE WHEN w.not_include_items NOT IN ('', 'nan', 'null') THEN 'Change' ELSE 'no change' END AS not_include_items, 
CASE WHEN w.extra_items_included NOT IN ('', 'nan', 'null') THEN'change'ELSE 'no change' END AS extra_items_included
from
(Select customer_orders.customer_id,not_include_items,extra_items_included
from customer_orders, (
SELECT driver_id,count(cancellation) as successfully_delievrd
FROM driver_order
join customer_orders on customer_orders.order_id=driver_order.order_id
WHERE cancellation NOT IN ('Cancellation', 'Customer Cancellation')
OR cancellation IS NULL
group by driver_id) as a
where not_include_items  NOT IN ('', 'nan', 'null') or 
extra_items_included   NOT IN ('', 'nan', 'null')
group by customer_orders.customer_id,not_include_items,extra_items_included)as w)
as y
where y.extra_items_included='change' And y.not_include_items='change';

-- what was the total number of rolls orderd for each hour of the day?
SELECT concat(CONVERT(HOUR(order_date), CHAR),'-',CONVERT(HOUR(order_date) + 1, CHAR)) as bucket,
COUNT(order_id) AS rolls_ordered
from customer_orders
group by bucket
order by bucket;
-- what was the total number of rolls orderd for each day of the week?
select day,count(a.order_id) from
(
SELECT dayname(order_date)as day,order_id
from customer_orders) as a
group by day;
-- what was the average time in minutes each took for each driver to arrive at fassos hq to pickup the order?
select b.driver_id,round(sum(b.diff)/count(order_id)) as averagetime
from
(
select *,minute(timediff(a.p,a.o)) as diff
from
(
select driver_order.driver_id,customer_orders.customer_id,customer_orders.order_date,driver_order.pickup_time,driver_order.order_id,
Time(driver_order.pickup_time) as p ,Time(customer_orders.order_date) as o
FROM driver_order
Inner JOIN customer_orders ON customer_orders.order_id = driver_order.order_id
WHERE driver_order.pickup_time IS NOT NULL) 
as a)b
group by b.driver_id;
-- Is there any relationship between the number of rolls and how long the order is taking to get prepared?
SELECT b.order_id, COUNT(b.roll_id) AS roll_count, b.diff
FROM (
    SELECT a.order_id, a.roll_id, MINUTE(TIMEDIFF(a.p, a.o)) AS diff
    FROM (
        SELECT co.roll_id, do.driver_id, co.customer_id, co.order_date,
               do.pickup_time, do.order_id,
               TIME(do.pickup_time) AS p, TIME(co.order_date) AS o
        FROM driver_order do
        INNER JOIN customer_orders co ON co.order_id = do.order_id
        WHERE do.pickup_time IS NOT NULL
    ) AS a
) AS b
GROUP BY b.order_id, b.diff;

-- what was the average distance travelled for each of the customers by each drivers?
select distinct(b.customer_id),sum(b.distancee)/count(b.order_id) as average_distance
from
(
select a.customer_id,a.distance,a.duration,a.driver_id,a.order_id,
cast(trim(replace(lower(a.distance),'km',' ')) as decimal(4,2))distancee
from
(select driver_order.driver_id,driver_order.distance,driver_order.duration,driver_order.order_id,customer_orders.customer_id
from driver_order join customer_orders on customer_orders.order_id=driver_order.order_id
group by customer_orders.customer_id,driver_order.driver_id,driver_order.distance,driver_order.duration,driver_order.order_id) as a) as b
group by b.customer_id ;
 -- what is the difference for the longest and shortest delivery time of specific order
SELECT MAX(CAST(a.duration AS UNSIGNED)) - MIN(CAST(a.duration AS UNSIGNED)) AS difference
FROM (
    SELECT duration
    FROM driver_order
    WHERE duration IS NOT NULL
) AS a;
-- what was the average speed for each driver for each delivery and do you notice any relation in the trend? 
SELECT a.driver_id, a.order_id, CAST(a.distance / a.duration AS DECIMAL(10, 2)) AS speed, b.cnt
FROM (
    SELECT distance, duration, driver_id, order_id
    FROM driver_order
    WHERE distance IS NOT NULL AND duration IS NOT NULL
) AS a
INNER JOIN (
    SELECT order_id, COUNT(roll_id) AS cnt
    FROM customer_orders
    GROUP BY order_id
) AS b ON a.order_id = b.order_id;
-- what is the  successful delivery percentage of each driver?
SELECT B.DRIVER_ID,B.SUCCESSFULLY_DELIVERD,B.TOTAL_OREDRERS_TAKEN,(B.SUCCESSFULLY_DELIVERD/B.TOTAL_OREDRERS_TAKEN)*100 AS delivery_perecntage
from
(SELECT DRIVER_ID,SUM(A.CAN_PER) AS SUCCESSFULLY_DELIVERD,COUNT(A.CAN_PER) AS TOTAL_OREDRERS_TAKEN
FROM(
SELECT DRIVER_ID,CASE WHEN LOWER(CANCELLATION) LIKE '%CANCEL%' THEN 0 ELSE 1 END AS CAN_PER FROM DRIVER_ORDER) AS A
GROUP BY A.DRIVER_ID)AS B
group by B.driver_id;








