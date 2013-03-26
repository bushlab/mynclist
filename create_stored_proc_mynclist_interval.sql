CREATE PROCEDURE `MyNCList_Insert_Interval`(
  node_table varchar(255),
  edge_table varchar(255),
  masterkey_table varchar(255),
  input_table varchar(255),
  chromosome_col varchar(255),
  start_col varchar(255),
  end_col varchar(255),
  label_col varchar(255)
 )
BEGIN

  ## PREP:
  DROP TABLE IF EXISTS update_table_temp;
  DROP TABLE IF EXISTS duplicate_temp;
  DROP TABLE IF EXISTS id_key_temp;

  #Identify the max sub value before beginning
  SET @b = CONCAT('SELECT MAX(sub) from ', node_table, ' into @newsub;');
  PREPARE stmt FROM @b;
  EXECUTE stmt;

  ## DONE WITH PREP

  ##Join to offsets table to generate absolute genomic positions
  ##Insert values into update_table_temp
  CREATE TABLE update_table_temp(
    abs_start bigint, abs_end bigint, label text,
    update_id bigint NOT NULL AUTO_INCREMENT PRIMARY KEY);

  SET @a = CONCAT(
    'INSERT INTO update_table_temp(abs_start, abs_end, label) SELECT a.', start_col,
    '+b.offset, a.', end_col,
    '+b.offset, a.', label_col,
    ' from ', input_table,
    ' a inner join chromosome_offset b on a.', chromosome_col,
    ' = b.chromosome;');
  PREPARE stmt FROM @a;
  EXECUTE stmt;

  CREATE INDEX start_end on update_table_temp(abs_start, abs_end);
  ## DONE with Update


  ## Create indexes to prepare for join
  #SET @b = CONCAT(
    #'CREATE INDEX start_end_temp ON ', node_table, '(start,end);');
  #PREPARE stmt FROM @b;
  #EXECUTE stmt;
  ## Done with create indexes

  #####################################################################################
  ## Check for identical overlaps

  #Put all overlaps into table duplicate_temp
  SET @a = CONCAT(
    'CREATE TABLE duplicate_temp SELECT concat(a.database_ids, group_concat(b.label separator ";"), ";") as label,
    a.range_id, b.update_id FROM update_table_temp b
    INNER JOIN ', node_table, ' r ON r.start = b.abs_start AND r.end = b.abs_end
    INNER JOIN ', masterkey_table, ' a ON r.range_id = a.range_id
    GROUP BY b.abs_start, b.abs_end;');
  PREPARE stmt FROM @a;
  EXECUTE stmt;

  #Check contents of duplicate_temp and store count in @duplicatecounter
  SELECT count(*) from duplicate_temp into @duplicatecounter;

  #If duplicate_temp as contents then update masterkey and remove from update_table_temp
  IF @duplicatecounter > 0
  THEN

    SET @b = CONCAT(
      'UPDATE ', masterkey_table, ' a, duplicate_temp b SET a.database_ids = b.label WHERE a.range_id = b.range_id;');
    PREPARE stmt FROM @b;
    EXECUTE stmt;

    ##Remove all duplicates from update table
    DELETE a from update_table_temp a inner join duplicate_temp b on a.update_id = b.update_id;
  END IF;

   #####################################################################################


  #####################################################################################
  ## Get range_ids for all remaining ranges in update_table_temp

  SET @a = CONCAT('SELECT MAX(range_id) from ', masterkey_table, ' into @max_rangeid;');
  PREPARE stmt FROM @a;
  EXECUTE stmt;

  CREATE TABLE id_key_temp SELECT update_id, update_id+@max_rangeid as range_id, label FROM update_table_temp;

  SET @b = CONCAT('INSERT INTO ', masterkey_table, ' SELECT @max_rangeid+update_id as range_id,
    label from update_table_temp;');
  PREPARE stmt FROM @b;
  EXECUTE stmt;

  #####################################################################################


  #####################################################################################
  ## Identify Type of Insert
  BEGIN
    ## Set up the cursors and loop functions
    DECLARE done INT DEFAULT 0;
    DECLARE cur_start, cur_end, cur_rangeid BIGINT;
    DECLARE update_table_cursor CURSOR FOR
      SELECT a.abs_start, a.abs_end, b.range_id FROM update_table_temp a
      INNER JOIN id_key_temp b on a.update_id = b.update_id
      ORDER BY a.abs_start DESC;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    ## Begin by row loop
    OPEN update_table_cursor;
    Byrow_loop: LOOP

      FETCH update_table_cursor INTO cur_start, cur_end, cur_rangeid;

      ##PREP:
      DROP TABLE IF EXISTS cur_range_temp;
      DROP TABLE IF EXISTS rangequery_temp;
      DROP TABLE IF EXISTS rangequery_temp2;
      DROP TABLE IF EXISTS rangequery_upperbound_temp;
      DROP TABLE IF EXISTS rangequery_sameparent_temp;

      ##END PREP

      CREATE TABLE cur_range_temp SELECT cur_start, cur_end, cur_rangeid;

      IF done
      THEN
        select "End of table";
        LEAVE Byrow_loop;
      END IF;

      SET @a = CONCAT(
        'CREATE TABLE rangequery_temp SELECT c.cur_start, c.cur_end, c.cur_rangeid, a.start, a.end, a.range_id, a.sub
        FROM ', node_table,' a inner join cur_range_temp c on c.cur_start >= a.start and c.cur_end <= a.end where a.sub = 0 limit 1;');
      PREPARE stmt FROM @a;
      EXECUTE stmt;

      SELECT count(*) from rangequery_temp into @rangequerycount;

      IF @rangequerycount = 0
      THEN

############################################################################################
## Begin Option 4 & 5

        ##Check if any of the sub 0 ranges fit within the new range
        SET @b = CONCAT(
          'CREATE TABLE rangequery_upperbound_temp SELECT c.cur_start, c.cur_end, c.cur_rangeid, a.start, a.end, a.range_id, a.sub
          FROM ', node_table, ' a inner join cur_range_temp c on c.cur_start <= a.start and c.cur_end >= a.end WHERE a.sub = 0;');
        PREPARE stmt FROM @b;
        EXECUTE stmt;

        SELECT count(*) FROM rangequery_upperbound_temp INTO @rangeupperboundcount;

        IF @rangeupperboundcount = 0
        THEN

          ##OPTION 5
          SET @c = CONCAT(
            'INSERT INTO ',node_table, ' values (',cur_start,',', cur_end,',', cur_rangeid,', 0);');
          PREPARE stmt FROM @c;
          EXECUTE stmt;

        ELSE

          ##OPTION 4
          SET @a = CONCAT(
            'INSERT INTO ',node_table, ' values (',cur_start,',', cur_end,',', cur_rangeid,', 0);');
          PREPARE stmt FROM @a;
          EXECUTE stmt;

          ##Puts newsub value into temp to suppress output only,  @temp never used in script
          SELECT @newsub:=@newsub+1 into @temp;

          SET @c = CONCAT(
            'UPDATE ',node_table,' a, rangequery_upperbound_temp b SET a.sub = @newsub where a.range_id = b.range_id;');
          PREPARE stmt FROM @c;
          EXECUTE stmt;

          SET @d = CONCAT(
            'INSERT INTO ',edge_table, ' VALUES (',cur_rangeid,', @newsub);');
          PREPARE stmt FROM @d;
          EXECUTE stmt;

        END IF;
## END OPTION 4 & 5
#############################################################################################


      ELSE

        BLOCK2: BEGIN
          DECLARE done_inner INT DEFAULT 0;
          Search_loop: REPEAT

            ## STEP 2 & 3
            DROP TABLE IF EXISTS rangequery_temp2;
            SET @a = CONCAT(
              'CREATE TABLE rangequery_temp2 SELECT b.cur_start, b.cur_end, b.cur_rangeid, a.start, a.end, a.range_id, a.sub
              from rangequery_temp b inner join ', edge_table, ' c on c.range_id = b.range_id
              inner join ', node_table,' a on c.sub = a.sub where b.cur_start >= a.start and b.cur_end <= a.end limit 1;');
            PREPARE stmt FROM @a;
            EXECUTE stmt;


            SELECT count(*) FROM rangequery_temp2 INTO @rangequerycount2;

            IF @rangequerycount2 != 0
            THEN
              DROP TABLE IF EXISTS rangequery_temp;
              SET @b = CONCAT(
                'CREATE TABLE rangequery_temp SELECT a.cur_start, a.cur_end, a.cur_rangeid, c.start, c.end, c.range_id, c.sub
                FROM rangequery_temp2 a INNER JOIN ', edge_table, ' b on a.range_id = b.range_id
                INNER JOIN ', node_table, ' c on b.sub = c.sub where a.cur_start >= c.start and a.cur_end <= c.end limit 1;');
              PREPARE stmt FROM @b;
              EXECUTE stmt;

              SELECT count(*) FROM rangequery_temp INTO @rangequerycount;

              IF @rangequerycount = 0
              THEN set done_inner = 1;
              END IF;

            ELSE
              SET done_inner = 1;
            END If;

          UNTIL
          done_inner = 1
          END REPEAT;

       IF @rangequerycount2 = 0
       THEN
          SET @parenttable  = 'rangequery_temp';
       ELSE
          SET @parenttable = 'rangequery_temp2';
       END IF;
       END BLOCK2;


#############################################################################################
## BEGIN OPTIONS 1-3
       DROP TABLE IF EXISTS rangequery_upperbound_temp;
       SET @a = CONCAT(
          'CREATE TABLE rangequery_upperbound_temp SELECT a.cur_start, a.cur_end, a.cur_rangeid, c.start, c.end, c.range_id, c.sub
          FROM ',@parenttable, ' a INNER JOIN ', edge_table, ' b on a.range_id = b.range_id
          INNER JOIN ', node_table, ' c on b.sub = c.sub where a.cur_start <= c.start and a.cur_end >= c.end;');
       PREPARE stmt FROM @a;
       EXECUTE stmt;

       SELECT count(*) FROM rangequery_upperbound_temp INTO @rangeupperboundcount;

       IF @rangeupperboundcount !=0
       THEN

        ##Option 1
         SET @a = CONCAT(
            'INSERT INTO ', node_table, ' SELECT cur_start, cur_end, cur_rangeid, sub FROM rangequery_upperbound_temp limit 1;');
         PREPARE stmt FROM @a;
         EXECUTE stmt;

         ##Puts newsub value into temp to suppress output only,  @temp never used in script
         SELECT @newsub:=@newsub+1 into @temp;

         SET @c = CONCAT(
            'UPDATE ',node_table,' a, rangequery_upperbound_temp b SET a.sub = @newsub where a.range_id = b.range_id;');
         PREPARE stmt FROM @c;
         EXECUTE stmt;

         SET @d = CONCAT(
            'INSERT INTO ',edge_table, ' VALUES (',cur_rangeid,', @newsub);');
         PREPARE stmt FROM @d;
         EXECUTE stmt;

        ELSE
         SET @a = CONCAT(
            'CREATE TABLE rangequery_sameparent_temp SELECT a.cur_start, a.cur_end, a.cur_rangeid, c.start, c.end, c.range_id, c.sub
            FROM ', @parenttable, ' a INNER JOIN ',edge_table,' b on a.range_id  = b.range_id
            INNER JOIN ',node_table, ' c on b.sub = c.sub;');
         PREPARE stmt FROM @a;
         EXECUTE stmt;

         SELECT count(*) from rangequery_sameparent_temp INTO @rangesameparentcount;

         IF @rangesameparentcount != 0
         THEN

           ##OPTION 3
           SET @a = CONCAT(
              'INSERT INTO ',node_table,' SELECT cur_start, cur_end, cur_rangeid, sub FROM rangequery_sameparent_temp LIMIT 1;');
           PREPARE stmt FROM @a;
           EXECUTE stmt;

         ELSE
           ##OPTION 2
           ##Puts newsub value into temp to suppress output only,  @temp never used in script
           SELECT @newsub:=@newsub+1 into @temp;

           SET @b = CONCAT(
              'INSERT INTO ',node_table,' VALUES(',cur_start,',', cur_end,',', cur_rangeid,', @newsub);');
           PREPARE stmt FROM @b;
           EXECUTE stmt;

           SET @c = CONCAT(
              'INSERT INTO ',edge_table,' SELECT range_id, @newsub FROM ', @parenttable,' LIMIT 1');
           PREPARE stmt FROM @c;
           EXECUTE stmt;

          END IF;
        END IF;
      END IF;
    END LOOP;
  END;
## END OPTIONS 1-3
###########################################################################################


  ##CLEAN UP
  ## NEED TO DROP ALL TEMP TABLES!!!!!!!

  DROP TABLE IF EXISTS update_table_temp;
  DROP TABLE IF EXISTS duplicate_temp;
  DROP TABLE IF EXISTS id_key_temp;
  DROP TABLE IF EXISTS rangequery_temp;
  DROP TABLE IF EXISTS rangequery_temp2;
  DROP TABLE IF EXISTS cur_range_temp;
  DROP TABLE IF EXISTS rangequery_upperbound_temp;
  DROP TABLE IF EXISTS rangequery_sameparent_temp;

  #SET @a = CONCAT('DROP INDEX start_end_temp ON ', node_table,';');
  #PREPARE stmt FROM @a;
  #EXECUTE stmt;


END 
