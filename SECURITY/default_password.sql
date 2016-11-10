SELECT  u.username, u.account_status
  FROM dba_users_with_defpwd p INNER JOIN dba_users u
  ON (u.username = p.username)
  where u.username not in ('XS$NULL')
  ;
  
--  zm�na hesla default systemovych ��t�
BEGIN
  FOR rec IN
  (
  SELECT  u.username
    FROM dba_users_with_defpwd p INNER JOIN dba_users u
  ON (u.username = p.username)
    where account_status <> 'OPEN'
    AND u.username not in ('XS$NULL')  -- nejedna se o realny ucet
  )
  LOOP
    execute immediate ('alter user "'||rec.username ||'" identified by "'||
    dbms_random.string('a',14)||ABS(TRUNC(dbms_random.value(0, 9))) ||'"');
  END LOOP;
END;
/
  