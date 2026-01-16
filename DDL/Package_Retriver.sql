-- =====================================================================
-- File Name  : PKG_DDL.sql
-- Purpose    : Generate PACKAGE + PACKAGE BODY DDL to a file
-- Output     : <schema>_<package>_pkg.sql
-- Location   : Same directory where SQL*Plus is executed
-- =====================================================================

--Retrives the Package when user inputs the schema and package name.

SET LONG 1000000
SET LONGCHUNKSIZE 1000000
SET PAGESIZE 0
SET LINESIZE 32767
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TRIMSPOOL ON

ACCEPT p_schema  CHAR PROMPT 'Enter Schema Name  : '
ACCEPT p_package CHAR PROMPT 'Enter Package Name : '

-- File will be created in the CURRENT working directory
SPOOL &p_schema._&p_package._pkg.sql

BEGIN
  DBMS_METADATA.SET_TRANSFORM_PARAM(
    DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',TRUE);
  DBMS_METADATA.SET_TRANSFORM_PARAM(
    DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',TRUE);
END;
/

PROMPT
PROMPT ================= PACKAGE SPEC =================
PROMPT

SELECT DBMS_METADATA.GET_DDL(
         'PACKAGE',
         UPPER('&p_package'),
         UPPER('&p_schema')
       )
FROM DUAL;

PROMPT
PROMPT ================= PACKAGE BODY =================
PROMPT

SELECT DBMS_METADATA.GET_DDL(
         'PACKAGE_BODY',
         UPPER('&p_package'),
         UPPER('&p_schema')
       )
FROM DUAL;

SPOOL OFF
EXIT
