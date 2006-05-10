/*
DROP TABLE test CASCADE;

CREATE TABLE test (
	x INTEGER PRIMARY KEY,
        s TEXT
); 
*/

--SELECT pglog.enable_log('test');
--LISTEN pglog;
--INSERT INTO test VALUES (1, 'test');
--UPDATE test SET s='modified' WHERE x = 1;
--DELETE FROM test WHERE x = 1;
--SELECT * FROM pglog.Logs;
--SELECT * FROM test;
--SELECT pglog.revert(4);
--SELECT pglog.disable_log('test');
--SELECT pglog.last_change_id();