--
-- iSourcing extract
--

- před exportem prov0st kontroly dle OLI_kontrola.sql
- před exportem provést sync emguid a verzí

- licence
   - NUP se již nevykazuje, vše jako PP
   - NUP se vykazuje jako PP = NUP/10

- Service Levels
  - Platinum má pouze produkce v RAC,
  - A/P clustery produkce jsou Gold
  - Na Silver kašlu v
  - zbytek je Bronze.

-- report SQL serveru - zrušeno
http://reports12.csin.cz/Reports/Pages/Report.aspx?ItemPath=%2fDashBoard%2fOracleSlo

-- zjednodusena verze, pouze SL
select SL, count(*)
from
(
select
    case
    -- produkce v RAC
    when (d.rac = 'Y' and env_status = 'Production')
              then 'Platinum'
    -- produkce v A/P clusteru
    when  env_status = 'Production'
              then 'Gold'
    -- others = Bronze
    else 'Bronze'
  end SL
FROM
     OLI_OWNER.DATABASES d
     JOIN OLI_OWNER.DBINSTANCES i ON (d.licdb_id = i.licdb_id)
)
group by SL
order by SL DESC ;

select sl, count(*) from (
SELECT
--  count(*) cnt
  ca.sn,
  app_name,
  i.INST_NAME,
  decode(dc.country,'CZ','Czech Republic','AT','Austria',dc.country) "DC location country",
  env_status "Business environment",
  'Database' as "Application environment",
  'Oracle' as Platform,
  NVL(DBVersion, '11.2') DBVersion,   --pokud verze chybi, uved 11.2 ;-)
  1,'N/A','N/A','N/A',
  s.OS,
  NVL2(s.DOMAIN, s.HOSTNAME||'.'||s.DOMAIN, s.HOSTNAME) "server",
  dbs.alloc_gb,
  'Enterprise Edition' CURRENT_PROD_NAME,
  -- vše na PP, hodnota NUP/10
  'PP' lic_type_name,
  --round(lic_cnt_used) lic_cnt_used,
  -- connections - všude dávat NULL
  NULL "avg_conn",
  --case when L.lic_type_name = 'NUP' then log.LOGONS ELSE NULL END "avg_conn"
  NULL, NULL, NULL,
  -- service Levels
  case
    -- produkce v RAC
    when (d.rac = 'Y' and env_status = 'Production')
              then 'Platinum'
    -- produkce v clusteru
    when  env_status = 'Production'
              then 'Gold'
    -- vše ostatní je Bronze
    else 'Bronze'
  end SL
FROM
  OLI_OWNER.DATABASES d
  JOIN OLI_OWNER.DBINSTANCES i ON (d.licdb_id = i.licdb_id)
  JOIN OLI_OWNER.SERVERS s ON (i.SERVER_ID = s.server_id)
  left join OLI_OWNER.CA_SERVERS ca on (ca.cmdb_ci_id = s.ca_id)
  -- LICENCE USAGE
  LEFT JOIN (
      select lic_env_id,
             decode(LIC_TYPE_ID,2,'NUP',3,'PP') lic_type,
             sum(decode(LIC_TYPE_ID,2,lic_cnt_used/10,3,lic_cnt_used)) lic_cnt_used
          from OLI_OWNER.license_allocations
      where active = 'Y'
        and prod_id in (33,38)  -- Enterprise Edition
      group by  lic_env_id, decode(LIC_TYPE_ID,2,'NUP',3,'PP')
            ) l ON (l.lic_env_id = s.lic_env_id)
    --JOIN OLI_OWNER.products p ON (L.CURRENT_PROD_ID = p.prod_id)
    join OLI_OWNER.LICENSED_ENVIRONMENTS l on (s.lic_env_id = l.lic_env_id)
    LEFT join OLI_OWNER.DATACENTERS dc on (dc.datacenter_id = l.datacenter_id)
    -- nazev aplikace
    LEFT JOIN (
       select licdb_id, LISTAGG(a.APP_NAME,',') WITHIN GROUP (ORDER BY a.app_id) app_name
         from OLI_OWNER.APPLICATIONS a join OLI_OWNER.APP_DB o ON (A.APP_ID = o.APP_ID)
        group by licdb_id) o ON (o.licdb_id = d.licdb_id)
    -- current logons
    LEFT JOIN (select NVL2(rac_guid, rac_guid, target_guid) guid, max(logons) logons from SRBA.MGMT_LOGONS
 group by NVL2(rac_guid, rac_guid, target_guid)) log ON (LOG.GUID = D.EM_GUID)
    -- allocated space
    LEFT JOIN (select target_guid, round(max(maximum)) alloc_gb from dashboard.mgmt$metric_daily
        WHERE     metric_column = 'ALLOCATED_GB' and rollup_timestamp > sysdate - 7
               group by target_guid) dbs on (dbs.target_guid = d.em_guid)
WHERE 1=1
    -- exception, co nechci do vypisu
--    AND d.dbname not in ('COGD', 'COGT','TS8D')
--and env_status = 'srvok'
--  AND SN IS NULL
--  and s.HOSTNAME like '%aix%'
--    AND d.em_guid is NULL
--    AND L.lic_type_name = 'NUP'  AND log.LOGONS is NULL
--    AND app_name like '%EIGER%'
--    AND d.rac = 'Y'
--    and d.dbname= 'RMAN'
--    and s.os is NULL
--and dbs.alloc_gb is NULL
ORDER BY upper(INST_NAME)
)
group by sl order by 1 desc;


-- 458  rows exported
-- 601 rows exported
-- 615 rows exported

-- kontrola na
select target_name, target_type, target_guid
  from DASHBOARD.MGMT$TARGET
--    DASHBOARD.MGMT_TARGETS
 where
 target_name like '%BMWDB%'
-- target_guid = 'E0E30DF24B1A7C2C491DA5718924233A'
 ;

-- MGMT_LOGONS
select * from SRBA.MGMT_LOGONS
  where 1=1
--  AND dbname like 'AFSZ%'
  and rac_guid is null;

--
INSERT INTO SRBA.MGMT_LOGONS VALUES ('510EDD05BFD20518EE69F1DC9F1A8688',30,NULL,'BMWDB');

-- MGMT_LOGONS
select * from SRBA.MGMT_LOGONS
where target_guid in (
select em_guid from OLI_OWNER.DATABASES
where dbname like 'AFSZ%');


-- duplicity v logons
select target_guid, count(*) from SRBA.MGMT_LOGONS
--  where DBNAME like 'TST1'
  group by  target_guid having count(*) > 1;


-- INSERT do dočasné tabulky MGMT_LOGONS
-- current logons - 50, kdyz je <50, tak 0
MERGE INTO SRBA.MGMT_LOGONS l
USING (
---
--;
--
SELECT
   m.target_guid,
   case
     when max(m.maximum) > 50 then round(max(m.maximum)-45)
     else 0
   end logons,
   NULL,
   -- m.target_name,
   REDIM_OWNER.REDIM_GET_SHORT_NAME(m.target_name) target_name
FROM
  dashboard.mgmt$metric_daily m
WHERE  1 = 1
--  AND m.target_name like 'AFSZ%'
  --AND REDIM_OWNER.REDIM_GET_SHORT_NAME(m.target_name) in (
  --'AFSDB','AFSDC','AFSZA1','AFSZA2','backupAT','backupAT','backupAT','backupAT','backupCZ','backupCZ','CMTZA1','CMTZA2','COLDA','DLKZA1','DLKZA2','DLKZDATA1','DLKZDATA2','DWHPKS','DWMPKS','FMWDA1','FMWDA2','FMWDB1','FMWDB2','FMWZA1','FMWZA2','INFTA','ISS1','N/A','N/A','N/A','N/A','ODIZA1','ODIZA2','ODSPKS','OMST','QCTA','RDLPT','RDSDA','RDSTA','rotpa','TS4D','TS4Q','TS8B','TS8D','WCMDVL','WCMZA1','WCMZA2','XEN1'
  --)
AND m.metric_column like 'logons'
AND m.rollup_timestamp > sysdate - 7
  group by  m.target_guid, m.target_name
--;
--
--
--
  ) oem
on (oem.target_guid = l.target_guid)
when NOT MATCHED THEN
INSERT (l.target_guid, l.logons, l.dbname )
  VALUES (oem.target_guid, oem.logons, oem.target_name)
 ;


-- update pro RAC
MERGE
 into SRBA.MGMT_LOGONS l
USING (
select t.target_guid, d.dbname, d.em_guid
  FROM DASHBOARD.MGMT$TARGET t
  join OLI_OWNER.DATABASES d on (t.target_name = d.dbname)
--  where  target_type = 'rac_database'
  AND t.target_name in (
'AFSZA1'
      )
  ) t
ON (l.target_guid = t.target_guid)
when matched then
update set l.rac_guid = t.em_guid;

update SRBA.MGMT_LOGONS set rac_guid = '06FE8AFA0E4370A1E053B011B10ABDF3' where dbname like 'BRADD%';


-- iSourcing data extract - space
select target_guid, round(max(maximum))
  from dashboard.mgmt$metric_daily
 WHERE     metric_column = 'ALLOCATED_GB'
 and rollup_timestamp > sysdate - 7
 group by target_guid;
