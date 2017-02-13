--
-- Orchestrace klonování
--

-- Flask start
/dba/clone/rest/run.sh

-- spusteni klonu
http://127.0.0.1:5000/clone/BOSON

-- LOG
SELECT * FROM cloning_task
ORDER BY TASK_ID desc
;

SELECT * FROM cloning_status_history
ORDER BY status_date DESC
;

-- TRACE
SELECT * FROM cloning_trace
ORDER BY TASK_ID desc, INS_ID DESC
;

-- update CLONE_SOURCE_LICDB_ID
update OLI_OWNER.DATABASES
  set CLONE_SOURCE_LICDB_ID = (
    -- source db
    select licdb_id from OLI_OWNER.DATABASES where dbname = 'RTOTP')
  -- target db
  where dbname like 'RTODP';

select * FROM OLI_OWNER.DATABASES
  where dbname in ('BOSON', 'JIRKA');

-- update serveru
update  OLI_OWNER.DBINSTANCES
  set server_id = 569
  where inst_name = 'BOSON';


-- target_db, target hostname
SELECT
   'source_db='||s.dbname source_db,
   'target_db='||d.dbname target_db,
   --d.CLONE_SOURCE_LICDB_ID,
   d.CLONING_METHOD_ID,
   --env_status,
   --app_name,
   'target_hostname='||CONCAT(hostname, '.'||domain) server
FROM
  -- target db
  OLI_OWNER.DATABASES d
  -- source db
  join OLI_OWNER.DATABASES s ON (d.CLONE_SOURCE_LICDB_ID = s.licdb_id)
  join OLI_OWNER.APP_DB o ON (d.licdb_id = o.licdb_id)
  JOIN OLI_OWNER.APPLICATIONS a ON (A.APP_ID = o.APP_ID)
  JOIN OLI_OWNER.DBINSTANCES i ON (d.licdb_id = i.licdb_id)
  JOIN OLI_OWNER.SERVERS s ON (i.SERVER_ID = s.server_id)
 WHERE d.dbname
   in ('BOSON')
ORDER BY APP_NAME;


-- spfile
SELECT
    distinct 'source_spfile='||VALUE
  FROM
    dashboard.mgmt$db_init_params p
    join OLI_OWNER.DATABASES d ON (d.dbname = REDIM_GET_SHORT_NAME(p.target_name))
    join OLI_OWNER.DATABASES s ON (s.CLONE_SOURCE_LICDB_ID = d.licdb_id)
  WHERE NAME like 'spfile'
    and s.dbname like 'CLMTA'
;

--
-- init parametry pro klonování
SELECT 'init_params='|| listagg(param,',') WITHIN GROUP (ORDER BY param)
FROM (
SELECT
    --TARGET_NAME,
    -- NAME,
    CASE upper(ISDEFAULT)
      WHEN 'FALSE' THEN name ||'='|| VALUE
      WHEN 'TRUE' then name
    END param
  FROM
    dashboard.mgmt$db_init_params
  WHERE TARGET_NAME like 'RTOTP'
    and NAME in ('memory_target','sga_target','pga_aggregate_target',
                 'cpu_count')
);

-- init parametry pro klonování ALL
SELECT
    TARGET_NAME,
    NAME,
    ISDEFAULT,
    value
  FROM
    dashboard.mgmt$db_init_params
  WHERE TARGET_NAME like 'RTOTP'
    and NAME in ('memory_target','sga_target','pga_aggregate_target',
                 'cpu_count')
;



-- drop user
--
-- drop user cloning_py cascade;
-- create user cloning_py identified by abcd1234 profile PROF_APPL;
-- grant execute on cloning_owner.cloning_api to cloning_py;
-- grant SELECT on CLONING_OWNER.CLONING_TASKS to CLONING_PY ;


drop user cloning_owner cascade;
create user cloning_owner identified by abcd1234 profile PROF_APPL
  default tablespace users quota unlimited on users ;

grant select,references on OLI_OWNER.DATABASES  to CLONING_OWNER;
grant select on OLI_OWNER.SERVERS to CLONING_OWNER;
grant select on OLI_OWNER.DBINSTANCES to CLONING_OWNER;
grant update on OLI_OWNER.DATABASES to CLONING_OWNER;


-- cloning methods
REM INSERTING into CLONING_METHOD
SET DEFINE OFF;
Insert into CLONING_METHOD (CLONING_METHOD_ID,METHOD_NAME,METHOD_TITLE,DESCRIPTION) values ('1','RMAN_DUPLICATE','Duplikace RMAN - do GUI',null);
Insert into CLONING_METHOD (CLONING_METHOD_ID,METHOD_NAME,METHOD_TITLE,DESCRIPTION) values ('2','HUSVM','Pole HITACHI snapshot metoda',null);
Insert into CLONING_METHOD (CLONING_METHOD_ID,METHOD_NAME,METHOD_TITLE,DESCRIPTION) values ('3','VMAX3_SNAPVX','Pole VMAX3 přes SnapVX snapshoty',null);
Insert into CLONING_METHOD (CLONING_METHOD_ID,METHOD_NAME,METHOD_TITLE,DESCRIPTION) values ('4','GI_CREATE','Create Golden Image on SBT_TAPE',null);


-- CLONING_METHOD_STEP: VMAX3
REM INSERTING into CLONING_METHOD_STEP
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP001_prepare.sh',001,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP005_pre_sql_scripts.sh',005,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP010_shutdown_db.sh',010,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP020_umount_asm_dg.sh',020,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP100_create_disk_snapshot.sh',100,'Desc','N','Y');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP109_mount_asm_dg.sh',109,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP110_recover_clone_db.sh',110,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP120_rename_clone_db.sh',120,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP130_rename_clone_asmdg.sh',130,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP140_password_file.sh',140,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP180_rac_drop_unused_redo_thread.sh',180,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP205_emcli_stop_blackout.sh',205,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP210_rman_reset_config.sh',210,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP220_rman_resync.sh',220,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP230_rman_backup_validate.sh',230,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP300_app_sql_scripts.sh',300,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP310_grant_dba.sh',310,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP320_autoextend_on.sh',320,'Desc','Y','N');
INSERT INTO CLONING_OWNER.CLONING_METHOD_STEP values (3,'STEP400_arm_audit.sh',400,'Desc','Y','Y');
--

select
  --*
  step_name
  from CLONING_OWNER.CLONING_METHOD_STEP
  where cloning_method_id = 3
order by position  ;

-- CLONNING PARAMS
asm_source_dg=JIRKA_DATA
source_spfile=+JIRKA_DATA/JIRKA/spfilejirka.ora
clone_opts=
init_params=large_pool_size,shared_pool_size,db_cache_size,sga_max_size,local_listener,remote_listener,db_recovery_file_dest,log_archive_dest_1

REM INSERTING into CLONING_PARAMETER
SET DEFINE OFF;
Insert into CLONING_PARAMETER values ('-999','pre_sql_scripts','Y','0',null,null);
Insert into CLONING_PARAMETER values ('-999','post_sql_scripts','Y','0',null,null);
Insert into CLONING_PARAMETER values ('-999','clone_opts','Y','0',null,null);
Insert into CLONING_PARAMETER values ('-999','init_params','Y','0',null,null);
Insert into CLONING_PARAMETER values ('3','snapshot_name','N','0',null,null);
Insert into CLONING_PARAMETER values ('3','recover_opts','N','0',null,'--noarchivelog');
Insert into CLONING_PARAMETER values ('3','asm_source_dg','Y','0',null,null);
Insert into CLONING_PARAMETER values ('3','source_spfile','Y','0',null,null);
--

REM INSERTING into CLONING_PARAM_VALUE
SET DEFINE OFF;
Insert into CLONING_PARAM_VALUE values ('371','C','asm_source_dg','JIRKA_DATA','N');
Insert into CLONING_PARAM_VALUE values ('371','C','source_spfile','+JIRKA_DATA/JIRKA/spfilejirka.ora','N');


-- upravy od Rasti ...
ALTER TABLE CLONING_OWNER.CLONING_METHOD_STEP  ADD (LOCAL VARCHAR2(1) DEFAULT 'N' NOT NULL);