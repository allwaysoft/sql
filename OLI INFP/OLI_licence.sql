--

Enterprise Edition - používat pouze volbu "Enterprise Edition"


Diagnostics Pack  PP  8 8 -
Enterprise Edition  PP  8 8 -
Partitioning  PP  8 8 -
Real Application Clusters PP  8 8 -
Tuning Pack PP  8 8 -

Lic. Environment - nazev serveru
CSI: 18314601
Active: Y
Licence count: 8


-- PRODUCTS
select * from OLI_OWNER.PRODUCTS
  where 1=1
--  AND prod_name like '%Enterprise Edition'
  and db_product = 'Y'
order by PROD_ID;


--> INSERT do LICENSE_ALLOCATIONS

--
-- fyzický server
--
select lic_env_id from servers
  where hostname like 'bordb08%';

define LIC_ENV_ID = 3292
define PP = 64

-- Diagnostics Pack
Insert into OLI_OWNER.LICENSE_ALLOCATIONS (PROD_ID,CSI_ID,LIC_TYPE_ID,LIC_CNT_USED,ACTIVE,HIDDEN,LIC_ENV_ID)
  values ('36','133','3','&PP','Y','N',&LIC_ENV_ID);
-- Enterprise Edition
Insert into OLI_OWNER.LICENSE_ALLOCATIONS (PROD_ID,CSI_ID,LIC_TYPE_ID,LIC_CNT_USED,ACTIVE,HIDDEN,LIC_ENV_ID)
  values ('38','133','3','&PP','Y','N',&LIC_ENV_ID);
-- Partitioning
Insert into OLI_OWNER.LICENSE_ALLOCATIONS (PROD_ID,CSI_ID,LIC_TYPE_ID,LIC_CNT_USED,ACTIVE,HIDDEN,LIC_ENV_ID)
  values ('46','133','3','&PP','Y','N',&LIC_ENV_ID);
-- Tuning Pack
Insert into OLI_OWNER.LICENSE_ALLOCATIONS (PROD_ID,CSI_ID,LIC_TYPE_ID,LIC_CNT_USED,ACTIVE,HIDDEN,LIC_ENV_ID)
  values ('51','133','3','&PP','Y','N',&LIC_ENV_ID);
-- Real Application Clusters
--Insert into OLI_OWNER.LICENSE_ALLOCATIONS (PROD_ID,CSI_ID,LIC_TYPE_ID,LIC_CNT_USED,ACTIVE,HIDDEN,LIC_ENV_ID)
--  values ('48','133','3','&PP','Y','N',&LIC_ENV_ID);

commit;


-- VMWare
ORACLE-01-ANT
ORACLE-01-BUD


--
select * from OLI_OWNER.PRODUCTS
  where prod_name like '%Enterprise Edition'
  and db_product = 'Y'
order by PROD_ID;


-- Licence summary
-- LICENSE_COSTS_FULL
--
select
    app_name,
    lic_env_name,
    current_prod_name,
    --licdb_name,
    lic_type_name,
    round(sum(calc_lic_cnt),1)
  from OLI_OWNER.LICENSE_COSTS_FULL
 where app_name like 'FASCR'
  -- and current_prod_name = 'Enterprise Edition'
 group by app_name, LIC_ENV_NAME,current_prod_name, lic_type_name
order by 1,2, 3, 4
 ;

select * from OLI_OWNER.OLAPI_LICENCE_USAGE_SUMMARY
fetch first 5 rows only
-- where hostname like 'tgsymdb1%'
 ;

-- oprava Active na Y v Oracle licencích
select a.*
  from OLI_OWNER.LICENSE_ALLOCATIONS a
  join OLI_OWNER.LICENSED_ENVIRONMENTS e on (a.lic_env_id = e.lic_env_id)
  where lic_env_name like 'pordb06%';
;

update OLI_OWNER.LICENSE_ALLOCATIONS
  SET allocation_date = trunc(sysdate),
      csi_id = 133,
      initial_csi_id = 133,
      active='Y'
where lic_env_id in (1187,1188) ;


--
-- pridani licencí
--
select * from OLI_OWNER.LICENSED_ENVIRONMENTS
  where lic_env_name like 'pordb06%'
;
