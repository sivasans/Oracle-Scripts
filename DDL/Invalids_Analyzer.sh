#!/bin/bash
# =====================================================================
# Script  : invalid_objects_analyzer.sh
# Purpose : Analyze INVALID objects, force compile, show real errors
# =====================================================================

read -p "Enter Schema Name : " SCHEMA
SCHEMA=$(echo "$SCHEMA" | tr '[:lower:]' '[:upper:]')

sqlplus -s / as sysdba <<EOF
SET PAGESIZE 200
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET TRIMSPOOL ON

COLUMN object_name FORMAT A35
COLUMN object_type FORMAT A25
COLUMN invalid_count FORMAT 999999

PROMPT
PROMPT =====================================================
PROMPT INVALID OBJECTS IN SCHEMA: $SCHEMA
PROMPT =====================================================

SELECT object_name, object_type
FROM   dba_objects
WHERE  owner  = '$SCHEMA'
AND    status = 'INVALID'
ORDER  BY object_type, object_name;

PROMPT
PROMPT ================= INVALID COUNT (SCHEMA LEVEL) =================

SELECT COUNT(*) AS invalid_count
FROM   dba_objects
WHERE  owner  = '$SCHEMA'
AND    status = 'INVALID';
EOF

read -p "Do you want to analyze error causes? (Y/N): " CHOICE
CHOICE=$(echo "$CHOICE" | tr '[:lower:]' '[:upper:]')
[[ "$CHOICE" != "Y" ]] && exit 0

while true
do
  read -p "Enter INVALID Object Name (or EXIT to finish): " OBJ
  OBJ=$(echo "$OBJ" | tr '[:lower:]' '[:upper:]')

  [[ "$OBJ" == "EXIT" ]] && break

  sqlplus -s / as sysdba <<EOF
SET SERVEROUTPUT ON
SET FEEDBACK OFF

DECLARE
  v_type   dba_objects.object_type%TYPE;
  v_cnt    NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO   v_cnt
  FROM   dba_objects
  WHERE  owner = '$SCHEMA'
  AND    object_name = '$OBJ'
  AND    status = 'INVALID';

  IF v_cnt = 0 THEN
    DBMS_OUTPUT.PUT_LINE('Object not found or not INVALID.');
    RETURN;
  END IF;

  SELECT object_type
  INTO   v_type
  FROM   dba_objects
  WHERE  owner = '$SCHEMA'
  AND    object_name = '$OBJ';

  -- Force compilation
  BEGIN
    IF v_type = 'PACKAGE' THEN
      EXECUTE IMMEDIATE 'ALTER PACKAGE $SCHEMA.$OBJ COMPILE';
      EXECUTE IMMEDIATE 'ALTER PACKAGE $SCHEMA.$OBJ COMPILE BODY';
    ELSIF v_type = 'PACKAGE BODY' THEN
      EXECUTE IMMEDIATE 'ALTER PACKAGE $SCHEMA.$OBJ COMPILE BODY';
    ELSE
      EXECUTE IMMEDIATE 'ALTER '||v_type||' $SCHEMA.$OBJ COMPILE';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Compilation raised error (captured below).');
  END;

  DBMS_OUTPUT.PUT_LINE('---------------------------------------------');
  DBMS_OUTPUT.PUT_LINE('Compilation Errors for '||v_type||' $OBJ');
  DBMS_OUTPUT.PUT_LINE('---------------------------------------------');

  FOR r IN (
    SELECT line, position, text
    FROM   dba_errors
    WHERE  owner = '$SCHEMA'
    AND    name  = '$OBJ'
    ORDER  BY sequence
  ) LOOP
    DBMS_OUTPUT.PUT_LINE(
      'Line '||r.line||', Pos '||r.position||' : '||r.text
    );
  END LOOP;

  IF SQL%ROWCOUNT = 0 THEN
    DBMS_OUTPUT.PUT_LINE('No DBA_ERRORS rows found.');
    DBMS_OUTPUT.PUT_LINE('Likely dependency invalidation.');
  END IF;
END;
/
EOF
done

echo "Analysis completed."
