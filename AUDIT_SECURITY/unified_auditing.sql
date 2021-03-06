--
-- Unified Auditing
--
How To Enable The New Unified Auditing In 12c ? (Doc ID 1567006.1)

-- records count
select COUNT(*) from UNIFIED_AUDIT_TRAIL;
SELECT COUNT(*) FROM ARM_CLIENT.ARM_UNIAUD12TMP;

-- AUDSYS v
select round(o.space_usage_kbytes / 1048576) as space_usage_GB from v$sysaux_occupants o where occupant_name = 'AUDSYS';

-- Simply clean all audit records
exec DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,FALSE);
truncate table ARM_CLIENT.ARM_UNIAUD12TMP;

--
exec DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(audit_trail_type => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED, last_archive_time => sysdate -1/1440) ;
exec DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(audit_trail_type => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED, use_last_arch_timestamp => true);
DELETE FROM  DBA_AUDIT_MGMT_LAST_ARCH_TS;


-- kdy došlo k nárůstu auditních dat
select *
  from ARM_CLIENT.ARM_AUDIT_HISTOGRAM
order by log_id desc, bucket_id;

-- DBID v auditu, po vytvoreni klonované db
SELECT DATABASE_ID, count(*) over () FROM DBA_AUDIT_MGMT_LAST_ARCH_TS;

-- unified_audit_trail
-- co nejvice zabira misto v auditu
set lines 180 pages 999
col ACTION_NAME for a20
col UNIFIED_AUDIT_POLICIES for a25
select dbusername,action_name,unified_audit_policies,return_code, count(*)
  from unified_audit_trail
-- from ARM_CLIENT.ARM_AUD$12TMP
 group by dbusername,action_name,unified_audit_policies,return_code
order by count(*) ;


--
-- kontrola nataveni
--
-- show parameter audit
select value from v$option where parameter = 'Unified Auditing';

-- enabled policies
set lines 2000 pages 2000
col USER_NAME for A30
col POLICY_NAME for A30
col AUDIT_CONDITION for a5
select * from AUDIT_UNIFIED_ENABLED_POLICIES
--WHERE USER_NAME = 'SYS'
order by POLICY_NAME, USER_NAME, ENABLED_OPT, SUCCESS, FAILURE
;

-- ALL audit policies
select * from AUDIT_UNIFIED_POLICIES
  WHERE 1=1
 -- where policy_name like '%DWH'
  and policy_name like 'CS%'
  and AUDIT_OPTION like 'INSERT%'
--order by policy_name
 ;


-- NOAUDIT SYS
noaudit policy CS_ACTIONS_FREQUENT_SYS by SYS;
SELECT POLICY_NAME FROM AUDIT_UNIFIED_ENABLED_POLICIES where user_name like 'SYS';

-- NOAUDIT all
BEGIN
  FOR rec IN
    (SELECT POLICY_NAME, decode(USER_NAME,'ALL USERS','',' BY '||USER_NAME) as username
		FROM AUDIT_UNIFIED_ENABLED_POLICIES)
  LOOP
    EXECUTE immediate 'noaudit policy '||rec.policy_name||' '||rec.username;
end LOOP;
END;
/

-- Drop ALL audit policy CS_%
BEGIN
  FOR rec IN
    (select distinct policy_name from AUDIT_UNIFIED_POLICIES
      WHERE policy_name like 'CS_%'
    )
  LOOP
    execute immediate 'drop audit policy '||rec.policy_name;
end LOOP;
END;
/

-- NOAUDIT ALTER SESSION
SELECT * FROM auditable_system_actions
  WHERE component='Standard'
   AND name like 'ALTER SES%'
  ;
--
ALTER AUDIT POLICY CS_ACTIONS_GENERAL DROP ACTIONS ALTER SESSION;

-- INFO - audit SELECT  per username INFO
-- INFO na testovacích DB 'TS0', 'TS0I', 'TS1', 'TS1I'
create audit policy CS_INFO_POLICY actions ALL, SELECT;
audit policy CS_INFO_POLICY by INFO;

select DBMS_LOB.SUBSTR(SQL_TEXT_VARCHAR2,4000), count(*)
  from UNIFIED_AUDIT_TRAIL where dbusername = 'INFO'
group by DBMS_LOB.SUBSTR(SQL_TEXT_VARCHAR2,4000)
order by 2 desc;

-- SELECT
exec dbms_audit_mgmt.flush_unified_audit_trail;

select
--    *
--  object_schema, object_name, count(*) cnt
--   substr(sql_text, 1, 32767)
--    sql_text, count(*)
--    action_name, return_code, count(*)
--    dbusername, count(*)
--    return_code, count(*)
 event_timestamp, Dbusername, Action_Name, return_code
-- sql_text, Unified_Audit_Policies,
  from UNIFIED_AUDIT_TRAIL
--   FROM ARM_CLIENT.ARM_AUD$12TMP --meziskladiste
 where 1=1
--    AND event_timestamp between timestamp'2015-07-08 22:00:00'
--                            and timestamp'2015-07-08 22:05:00'
  AND event_timestamp > SYSTIMESTAMP - INTERVAL '4' HOUR
   -- AND return_code > 0
   AND return_code = 1017
--  and unified_audit_policies = 'CS_ACTIONS_FREQUENT'
-- AND UNIFIED_AUDIT_POLICIES is null
 -- and action_name like 'LOG%'
--  and action_name like 'INSERT'
   and dbusername='JOB_APP'
--group by dbusername ORDER by 2 desc
--group by return_code ORDER by 2 desc
--group by action_name, return_code order by 3 desc
--group by substr(sql_text, 1, 32767)
--group by object_schema, object_name order by 3 desc
--fetch first 100 ROWS ONLY
order by event_timestamp desc
FETCH FIRST 5 PERCENT ROWS ONLY
;

-- group by HOUR - lokálně , group by client
select
    trunc(event_timestamp, 'HH24'), client_program_name, count(*)
  from UNIFIED_AUDIT_TRAIL
--     FROM ARM_CLIENT.ARM_AUD$12TMP --meziskladiste
 where event_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY
--   and dbusername='SYS'
 group by trunc(event_timestamp,'HH24'), client_program_name
 ORDER BY 3 desc
;


-- Known Issues
*** 2017-04-26 09:12:21.480
ORA-12012: error on auto execute of job "SYS"."ARM_CLIENT_JOB"
ORA-01476: divisor is equal to zero
ORA-06512: at "SYS.DBMS_STATS", line 34830
ORA-06512: at "SYS.ARM_MOVE_C", line 503
ORA-06512: at "SYS.ARM_MOVE_C", line 883
ORA-06512: at line 1


"ORA-01476: divisor is equal to zero
ORA-06512: at "SYS.DBMS_STATS", line 34830
ORA-06512: at "SYS.ARM_MOVE_C", line 503
ORA-06512: at "SYS.ARM_MOVE_C", line 883
ORA-06512: at line 1
"


exec dbms_stats.gather_table_stats('SYS','X$UNIFIED_AUDIT_TRAIL');


exec dbms_stats.set_table_prefs('SYS','X$UNIFIED_AUDIT_TRAIL','CONCURRENT','OFF');

exec dbms_stats.gather_table_stats('SYS','X$UNIFIED_AUDIT_TRAIL', method_opt=> 'for all columns size auto');

-- p. Fiala, dát vědět, dočasně vypnout audit

-- change tablespace
BEGIN
   dbms_audit_mgmt.set_audit_trail_location(
   audit_trail_type => dbms_audit_mgmt.audit_trail_unified,
   audit_trail_location_value => 'SYSAUX');
END;
/
