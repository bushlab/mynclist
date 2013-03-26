CREATE PROCEDURE `MyNCList_Remove_Interval`(
  node_table varchar(255),
  edge_table varchar(255),
  masterkey_table varchar(255),
  input_table varchar(255),
  chromosome_col varchar(255),
  start_col varchar(255),
  end_col varchar(255)
 )
BEGIN

  ## PREP
  DROP TABLE IF EXISTS delete_table_temp;

  ##Join to offsets table to generate absolute genomic positions
  ##Insert values into delete_table_temp
  CREATE TABLE delete_table_temp(
    abs_start bigint, abs_end bigint);

  SET @a = CONCAT(
    'INSERT INTO delete_table_temp SELECT a.', start_col,
    '+b.offset, a.', end_col,
    '+b.offset from ', input_table,
    ' a inner join chromosome_offset b on a.', chromosome_col,
    ' = b.chromosome;');
  PREPARE stmt FROM @a;
  EXECUTE stmt;

  CREATE INDEX start_end on delete_table_temp(abs_start, abs_end);


##############################################################################
## Create loop to run through the delete table
  BEGIN
    ## Set up the cursors and loop functions
    DECLARE done INT DEFAULT 0;
    DECLARE cur_start, cur_end BIGINT;
    DECLARE delete_table_cursor CURSOR FOR
      SELECT abs_start, abs_end FROM delete_table_temp;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    ## Begin by row loop
    OPEN delete_table_cursor;
    Byrow_loop: LOOP

      FETCH delete_table_cursor INTO cur_start, cur_end;

      ##PREP:
      DROP TABLE IF EXISTS rangetodelete_temp;
      DROP TABLE IF EXISTS rangeedgetodelete_temp;
      DROP TABLE IF EXISTS childupdate_temp;

      ##END PREP

      IF done
      THEN
        select "End of table";
        LEAVE Byrow_loop;
      END IF;


      SET @a = CONCAT(
        'CREATE TABLE rangetodelete_temp SELECT a.start, a.end, a.range_id, a.sub FROM ', node_table,' a
        where a.start = ',cur_start,' and a.end = ',cur_end,';');
      PREPARE stmt FROM @a;
      EXECUTE stmt;

      SELECT range_id from rangetodelete_temp into @delrange_id;
      SELECT sub from rangetodelete_temp into @delsub;

      ##Remove ranges from masterkey table
      SET @a = CONCAT(
        'DELETE FROM ',masterkey_table,' WHERE range_id = @delrange_id;');
      PREPARE stmt FROM @a;
      EXECUTE stmt;


############################################################################################
## Option 4 or 5
      IF @delsub = 0
      THEN
        SET @a = CONCAT(
          'CREATE TABLE rangeedgetodelete_temp select a.range_id, a.sub FROM ', edge_table,' a
          where a.range_id = @delrange_id;');
        PREPARE stmt FROM @a;
        EXECUTE stmt;

        SELECT COUNT(*) FROM rangeedgetodelete_temp INTO @edgecount;

        ## Case 5
        IF @edgecount = 0
        THEN
          SET @b = CONCAT(
            'DELETE FROM ',node_table,' WHERE range_id = @delrange_id;');
          PREPARE stmt FROM @b;
          EXECUTE stmt;

        ## Case 4
        ELSE
          SELECT sub FROM rangeedgetodelete_temp INTO @delpointersub;

          SET @b = CONCAT(
            'UPDATE ',node_table,' SET sub = 0 WHERE sub = @delpointersub;');
          PREPARE stmt FROM @b;
          EXECUTE stmt;

          SET @c = CONCAT(
            'DELETE FROM ',node_table,' WHERE range_id = @delrange_id;');
          PREPARE stmt FROM @c;
          EXECUTE stmt;

          SET @d = CONCAT(
            'DELETE FROM ',edge_table,' WHERE range_id = @delrange_id;');
          PREPARE stmt FROM @d;
          EXECUTE stmt;
        END IF;

## END OPTION 4 or 5
############################################################################################

############################################################################################
## Options 1-3
      ELSE
        SET @a = CONCAT(
          'CREATE TABLE rangeedgetodelete_temp SELECT a.range_id, a.sub FROM ', edge_table,' a
          where a.range_id = @delrange_id;');
        PREPARE stmt FROM @a;
        EXECUTE stmt;

        SELECT COUNT(*) FROM rangeedgetodelete_temp INTO @edgecount;

        ## Case 2 or 3
        IF @edgecount = 0
        THEN
          SET @a = CONCAT(
            'SELECT COUNT(*) FROM ',node_table,' WHERE sub = @delsub into @delsamesub;');
          PREPARE stmt FROM @a;
          EXECUTE stmt;

          ## Case 2
          IF @delsamesub = 1
          THEN
            SET @a = CONCAT(
              'DELETE FROM ',node_table,' WHERE range_id = @delrange_id;');
            PREPARE stmt FROM @a;
            EXECUTE stmt;

            SET @b = CONCAT(
              'DELETE FROM ', edge_table,' WHERE sub = @delsub;');
            PREPARE stmt FROM @b;
            EXECUTE stmt;

          ## Case 3
          ELSE
            SET @a = CONCAT(
              'DELETE FROM ',node_table,' WHERE range_id = @delrange_id;');
            PREPARE stmt FROM @a;
            EXECUTE stmt;

          END IF;

        ## Case 1
        ELSE
          SELECT sub FROM rangeedgetodelete_temp into @childsub;

          SET @b = CONCAT(
            'UPDATE ',node_table,' SET sub = @delsub where sub = @childsub;');
          PREPARE stmt FROM @b;
          EXECUTE stmt;

          SET @c = CONCAT(
            'DELETE FROM ',edge_table,' WHERE range_id = @delrange_id;');
          PREPARE stmt FROM @c;
          EXECUTE stmt;

          SET @d = CONCAT(
            'DELETE FROM ',node_table,' WHERE range_id = @delrange_id;');
          PREPARE stmt FROM @d;
          EXECUTE stmt;
        END IF;

## END OPTIONS 1-3
############################################################################################

      END IF;
    END LOOP;
  END;

## CLEAN UP
DROP TABLE IF EXISTS rangetodelete_temp;
DROP TABLE IF EXISTS rangeedgetodelete_temp;
DROP TABLE IF EXISTS delete_table_temp;
DROP TABLE IF EXISTS childupdate_temp;



END 
