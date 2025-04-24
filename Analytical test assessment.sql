-- Cleaning and exploring the deviceproperty table 
SELECT * FROM deviceproperty;
-- data looks clean 

-- Exploring productionmetrics table
SELECT * FROM productionmetric;
-- negative count doesnt make sense, it should be 0 
UPDATE productionmetric
SET good_count =0 
WHERE good_count <0 ;


-- if good , rejected count , run time is 0 and state is Meal/Break , we do not need this data 
SELECT * 
FROM productionmetric
WHERE run_time = 0 and good_count = 0 and run_time = 0 and process_state_display_name = 'Meal/Break';

-- Deleting this from the table
DELETE FROM productionmetric
WHERE run_time = 0 
  AND good_count = 0 
  AND reject_count = 0
  AND process_state_display_name = 'Meal/Break';

-- There are some values where status is meal/break, run time is 0 and good count is more than 0
SELECT * 
FROM productionmetric
WHERE good_count > 0 and process_state_display_name = 'Meal/Break';

-- This doesn't make sense 
CREATE TABLE break_productionmetric AS
SELECT * FROM productionmetric
WHERE NOT (good_count > 0 AND process_state_display_name = 'Meal/Break');

SELECT * FROM break_productionmetric
WHERE good_count = 0 and reject_count =0 and run_time =0;

-- There are two unplanned_stop_time column
SELECT * 
FROM break_productionmetric
WHERE unplanned_stop_time <> `unplanned_stop_time_[0]`;

-- Since both the columns are same , delete one of the column
ALTER TABLE break_productionmetric
DROP `unplanned_stop_time_[0]`;

SELECT * FROM break_productionmetric;

-- Means all the  rows are unique and not duplicated
SELECT COUNT(prodmetric_stream_key) FROM break_productionmetric;

-- devicekey values are line3, line2, adding space to keep the values of devicekey column as other tables
UPDATE break_productionmetric
SET devicekey = CONCAT('line ', SUBSTRING(devicekey, 5))
WHERE devicekey LIKE 'line%';

-- Viewing quality table
SELECT * FROM quality;

UPDATE quality
SET devicekey = LOWER(devicekey);

-- joining quality and break_productionmetric
SELECT bp.* , q.*
FROM quality q JOIN break_productionmetric bp 
ON bp.prodmetric_stream_key = q.prodmetric_stream_key;

SELECT * FROM deviceproperty;
UPDATE deviceproperty
SET deviceKey = concat('line ',SUBSTRING(deviceKey,5))
WHERE deviceKey LIKE 'line%';

-- Joining device with production
SELECT dp.*, bp.*
FROM deviceproperty dp
JOIN break_productionmetric bp 
ON dp.deviceKey = bp.deviceKey;

-- Joining quality with the device table
SELECT  dp.* , q.*
FROM deviceproperty dp
JOIN quality q 
ON dp.devicekey = q.devicekey;

-- Calculate total unplanned_stop_time and planned_stop_time
SELECT deviceKey,ROUND(SUM(unplanned_stop_time),2) AS total_unplanned_stop_time , 
SUM(planned_stop_time) AS total_planned_stop_time ,
ROUND(SUM(unplanned_stop_time) * 1.0 / 
        (SUM(unplanned_stop_time) + SUM(planned_stop_time)), 4) AS unplanned_proportion,
ROUND(SUM(planned_stop_time)* 1.0 /
        (SUM(unplanned_stop_time) + SUM(planned_stop_time)),4) AS planned_proportion
FROM break_productionmetric
GROUP BY deviceKey
ORDER BY 1;

-- The most frequent process_state_reason_display_name associated with unplanned_stop_time
SELECT process_state_reason_display_name,
COUNT(*) AS frequency,
ROUND(SUM(unplanned_stop_time),2) AS total_unplanned_stop_time
FROM break_productionmetric
WHERE unplanned_stop_time >0 
GROUP BY process_state_reason_display_name
ORDER BY frequency desc
LIMIT 1;

-- The overall reject rate
SELECT (SUM(bp.reject_count) + SUM(q.count))/
	   (SUM(bp.reject_count) + SUM(q.count) + SUM(good_count)) AS overall_reject_count
FROM break_productionmetric bp
JOIN quality q 
ON bp.prodmetric_stream_key = q.prodmetric_stream_key;

-- The most common reject_reason_display_name from the Quality table
SELECT reject_reason_display_name , 
COUNT(*) AS frequency,
SUM(count) AS total_count
FROM quality
GROUP BY reject_reason_display_name
ORDER BY frequency DESC
LIMIT 1;

-- The average good_count per hour of run_time across different deviceKey
SELECT devicekey, ROUND(SUM(good_count)/SUM(run_time/60),2) AS avg_good_count_per_run_time
FROM break_productionmetric
WHERE run_time > 0
GROUP BY deviceKey
ORDER BY 2 desc;


--