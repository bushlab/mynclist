CREATE PROCEDURE `MyNCList_Query`( search_table varchar(50), search_column varchar(50), node_table varchar(50), edge_table varchar(50), masterkey_table varchar(50))
BEGIN
  DROP TABLE IF EXISTS MyNCList_Query_Results;

  SET @q = CONCAT('
    CREATE TABLE MyNCList_Query_Results
       SELECT b.', search_column, ' as searchpos, start, end, range_id, sub
       FROM ',node_table,' a
       JOIN ', search_table,' b ON b.', search_column, ' BETWEEN start AND end
       WHERE sub = 0;');
  PREPARE stmt FROM @q;
  EXECUTE stmt;

  ALTER TABLE MyNCList_Query_Results ADD PRIMARY KEY(searchpos,sub,start,end);
  REPEAT
    SET @q = CONCAT('
      INSERT IGNORE INTO MyNCList_Query_Results
        SELECT s.searchpos, q.start, q.end, q.range_id, q.sub
        FROM MyNCList_Query_Results AS s
        JOIN ',edge_table,' AS f ON f.range_id = s.range_id
        JOIN ',node_table,' AS q ON f.sub = q.sub
        WHERE s.searchpos BETWEEN q.start AND q.end;');
    PREPARE stmt FROM @q;
    EXECUTE stmt;
  UNTIL Row_Count() = 0 END REPEAT;
  SET @r = CONCAT('
    SELECT a.searchpos, database_ids FROM MyNCList_Query_Results a inner join ', masterkey_table,' b on a.range_id = b.range_id order by a.searchpos;');
  PREPARE stmt FROM @r;
  EXECUTE stmt;
END
