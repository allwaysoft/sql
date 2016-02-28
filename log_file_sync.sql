-- LGWR - log file parallel write

-- prom�nnou je interval - po�et sekund, po kter� chci hodnotu 'user commits' sledovat
-- ve verzi v2 p�id�n loop p�es v�echny DB instance

SET SERVEROUTPUT ON
DECLARE
    beginTimeWaited V$SESSION_EVENT.time_waited_micro%TYPE;
    endTimeWaited   V$SESSION_EVENT.time_waited_micro%TYPE;
    beginWaits      V$SESSION_EVENT.total_waits%TYPE;
    endWaits        V$SESSION_EVENT.total_waits%TYPE;

    N PLS_INTEGER :=2;        --po�et vzork�
    sleep PLS_INTEGER  := 5;   -- sleep time

BEGIN
  dbms_output.put_line('|timestamp|log file parallel write[ms]|');		-- header output
  for id in 1..N loop
    -- gather #1 stats value
   SELECT  time_waited_micro, total_waits
      into beginTimeWaited, beginWaits
     FROM V$SESSION_EVENT
    WHERE 
    event = 'log file parallel write'
    and sid IN
    (SELECT   sid FROM v$session
        WHERE program LIKE '%(LGWR)'
    ) ;
    -- sleep N seconds
    dbms_lock.sleep(sleep);

    -- gather #2 stats value
   SELECT  time_waited_micro, total_waits
      into endTimeWaited, endWaits
     FROM V$SESSION_EVENT
    WHERE 
    event = 'log file parallel write'
    and sid IN
    (SELECT   sid FROM v$session
        WHERE program LIKE '%(LGWR)'
    ) ;

    -- display delta values for each instance
    dbms_output.put_line(
      '|'||systimestamp||
      '|'|| round((endTimeWaited-beginTimeWaited) / ((endWaits-beginWaits)*1000),2) || 
      '|');
  end loop;
END;
/
