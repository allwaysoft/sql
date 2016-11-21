-- group by version
  SELECT SUBSTR (banner, 1, 57), COUNT ( * )
    FROM MGMT$DB_DBNINSTANCEINFO
   WHERE target_type = 'oracle_database'
GROUP BY SUBSTR (banner, 1, 57)
ORDER BY 1;

-- db version
SELECT --*
       target_name||':'||target_type
       --database_name, host, dbversion, characterset, supplemental_log_data_min
    FROM MGMT$DB_DBNINSTANCEINFO
   WHERE target_type like '%database'
     and dbversion like '12.1%'
--   and target_name in ('BRAP','CPSP','CRMP','CSPO','MCIP','DMSLAPP')
ORDER BY database_name
;