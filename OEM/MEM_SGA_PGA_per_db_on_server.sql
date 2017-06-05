--
-- Memory
--

-- Server MEM utilization
-- MEM util, MEM free a MEM total free pres vsechny servery
select
   m.rollup_timestamp,
   substr(m.target_name, 1, instr(m.target_name, '.')-1) target_name,
   -- REPLACE(substr(a.target_name, 1, instr(a.target_name, '.')-1), 'ordb') target_name,
   ROUND(m.maximum,2) "MEM max util [%]",
   ROUND(m.maximum * mem/100/1024) "MEM util [GB]",
   ROUND((mem - (m.maximum * mem/100))/1024) "MEM free [GB]",
   ROUND(sum((mem - (m.maximum * mem/100))/1024)
     over (PARTITION BY m.rollup_timestamp)) "MEM free all [GB]"
 FROM
   mgmt$metric_daily m join MGMT$OS_HW_SUMMARY h  -- dotahuje velikost RAM
    on (m.target_name = h.host_name)
 where metric_name = 'Load' AND metric_column = 'memUsedPct'
--   AND m.target_name like 'dordb01%'
   AND REGEXP_LIKE(m.target_name, '^(t|d)ordb[0-9][0-9].vs.csin.cz')
--   AND REGEXP_LIKE(m.target_name, '^(p|b|zp|zb|t|d)ordb0[0-9].vs.csin.cz')
   AND m.rollup_timestamp > sysdate - interval '1' month
   -- AND m.rollup_timestamp > systimestamp - NUMTOYMINTERVAL( :MONTHS, 'MONTH' )
ORDER by m.rollup_timestamp, target_name
;


-- SGA a PGA - real allocated size MB
AND m.metric_name = 'memory_usage' AND m.metric_column = 'total_memory'


-- Memory init params
SELECT
   --host_name,
   target_name,  name, --value,
   round(value/1048576/1024) "GB",
   sum(value/1048576/1024) over ()
 FROM MGMT$DB_INIT_PARAMS
 where
    name in ('memory_target','sga_target','pga_aggregate_target')
    AND target_name like 'CLM%'
    AND host_name like '&server%'
    AND REGEXP_LIKE(host_name, 'z(p|b)ordb03.vs.csin.cz')
    -- AND REGEXP_LIKE(host_name, 'z?(t|d|p|b)ordb0[0-5].vs.csin.cz')
    and value > 0
order by target_name, name;

-- MGMT$DB_SGA
select host_name, target_name, collection_timestamp, sganame, sgasize
  from   sysman.MGMT$DB_SGA
 where  target_name like 'MDWP%';

-- SGA per db on server
SELECT
   m.target_name,
   round(avg(m.average)) SGA
FROM
  MGMT$METRIC_DAILY m join mgmt$target t on (M.target_GUID = t.TARGET_GUID)
WHERE  1 = 1
  AND T.HOST_NAME like '&server%'
AND m.metric_name = 'memory_usage_sga_pga' AND m.metric_column = 'sga_total'
AND m.rollup_timestamp > sysdate - interval '3' month
  group by m.target_name
order by SGA desc;

-- PGA per db on server
SELECT
    m.rollup_timestamp,
   m.target_name,
   m.maximum PGA
FROM
  MGMT$METRIC_DAILY m join mgmt$target t on (M.target_GUID = t.TARGET_GUID)
WHERE  1 = 1
  --AND T.HOST_NAME like '&server%'
  and m.target_name like 'CTLP'
AND m.metric_name = 'memory_usage_sga_pga' AND m.metric_column = 'pga_total'
AND m.rollup_timestamp > sysdate - interval '3' month
--  group by m.target_name
order by 1 desc;

-- HugePages
SELECT
   --host_name,
   target_name,  name, --value,
   round(value/1048576/1024) "GB",
   sum(value/1048576/1024) over (),
   sum(value/1024) over () / 2048 HugePages
 FROM MGMT$DB_INIT_PARAMS
 where
    name in ('sga_target')
    AND host_name like 'tordb03%'
    and value > 0
order by target_name, name;