--/* ov��en�, nad kter�mi sloupci se histogram spo��tal */--

SELECT table_name,
       column_name,
       num_distinct,
       density,
       num_buckets,
       histogram
  FROM dba_tab_columns
 WHERE table_name = '&table_name';
 
--/* zji�t�n� nastaven� default hodnot instance */--

col spare4 for a40
select sname, sval1, spare4 from sys.optstat_hist_control$;