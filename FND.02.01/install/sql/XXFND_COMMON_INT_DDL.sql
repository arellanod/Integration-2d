/****************************************************************************
**
**  $HeadURL: $
**
**  Purpose: Install custom objects for Common Interface
**
**  Author: DXC RED ROCK
**
**  $Date: $
**
**  $Revision: $
**
**  History: Refer to Source Control
**
****************************************************************************/
-- $Id: $
--

PROMPT create object xxfnd_dir_entry

CREATE OR REPLACE TYPE xxfnd_dir_entry AS OBJECT
(
   FILE_TYPE    VARCHAR2(1),
   READABLE     VARCHAR2(1),
   WRITEABLE    VARCHAR2(1),
   HIDDEN       VARCHAR2(1),
   FILE_SIZE    NUMBER,
   MODIFIED     DATE,
   NAME         VARCHAR2(4000)
);
/

PROMPT create object xxfnd_dir_array

CREATE OR REPLACE TYPE xxfnd_dir_array AS TABLE OF xxfnd_dir_entry;
/

PROMPT create object xxfnd_int_interfaces_s

CREATE SEQUENCE xxnzcl.xxfnd_int_interfaces_s START WITH 1000 INCREMENT BY 1 NOCACHE;

PROMPT create object xxfnd_int_runs_id_s

CREATE SEQUENCE xxnzcl.xxfnd_int_runs_id_s START WITH 1000 INCREMENT BY 1 NOCACHE;

PROMPT create object xxfnd_int_run_phases_id_s

CREATE SEQUENCE xxnzcl.xxfnd_int_run_phases_id_s START WITH 1000 INCREMENT BY 1 NOCACHE;

PROMPT create object xxfnd_int_run_phase_err_id_s

CREATE SEQUENCE xxnzcl.xxfnd_int_run_phase_err_id_s START WITH 1000 INCREMENT BY 1 NOCACHE;

PROMPT create object xxfnd_int_data_sources

CREATE TABLE xxnzcl.xxfnd_int_data_sources
(
   SRC_CODE            VARCHAR2(10) NOT NULL,
   SRC_NAME            VARCHAR2(240),
   CREATED_BY          NUMBER(15) NOT NULL,
   CREATION_DATE       DATE NOT NULL,
   LAST_UPDATED_BY     NUMBER(15) NOT NULL,
   LAST_UPDATE_DATE    DATE NOT NULL,
   LAST_UPDATE_LOGIN   NUMBER(15),
   REQUEST_ID          NUMBER(15)
);

PROMPT create object xxfnd_int_interfaces

CREATE TABLE xxnzcl.xxfnd_int_interfaces
(
   INT_ID             NUMBER NOT NULL,
   INT_CODE           VARCHAR2(25),
   INT_NAME           VARCHAR2(240),
   EBS_IN_OUT         VARCHAR2(3),
   APPL_SHORT_NAME    VARCHAR2(30),
   ENABLED_FLAG       VARCHAR2(1) DEFAULT 'Y' NOT NULL,
   CREATION_DATE      DATE NOT NULL,
   CREATED_BY         NUMBER(15) NOT NULL,
   LAST_UPDATED_BY    NUMBER(15) NOT NULL,
   LAST_UPDATE_DATE   DATE NOT NULL,
   LAST_UPDATE_LOGIN  NUMBER(15),
   REQUEST_ID         NUMBER(15)
);

PROMPT create object xxfnd_int_runs

CREATE TABLE xxnzcl.xxfnd_int_runs
(
   RUN_ID              NUMBER NOT NULL,
   INT_ID              NUMBER NOT NULL,
   SRC_REC_COUNT       NUMBER,
   SRC_HASH_TOTAL      NUMBER,
   SRC_BATCH_NAME      VARCHAR2(150),
   CREATED_BY          NUMBER(15) NOT NULL,
   CREATION_DATE       DATE NOT NULL,
   LAST_UPDATED_BY     NUMBER(15),
   LAST_UPDATE_DATE    DATE NOT NULL,
   LAST_UPDATE_LOGIN   NUMBER(15),
   REQUEST_ID          NUMBER(15)
);

PROMPT create object xxfnd_int_run_phase_errors

CREATE TABLE xxnzcl.xxfnd_int_run_phase_errors
(
   ERROR_ID            NUMBER(15) NOT NULL,
   RUN_ID              NUMBER(15),
   RUN_PHASE_ID        NUMBER(15),
   RECORD_ID           NUMBER,
   MSG_CODE            VARCHAR2(15),
   ERROR_TEXT          VARCHAR2(2000),
   ERROR_TOKEN_VAL1    VARCHAR2(250),
   ERROR_TOKEN_VAL2    VARCHAR2(250),
   ERROR_TOKEN_VAL3    VARCHAR2(250),
   ERROR_TOKEN_VAL4    VARCHAR2(250),
   ERROR_TOKEN_VAL5    VARCHAR2(250),
   INT_TABLE_KEY_VAL1  VARCHAR2(250),
   INT_TABLE_KEY_VAL2  VARCHAR2(250),
   INT_TABLE_KEY_VAL3  VARCHAR2(250),
   CREATED_BY          NUMBER(15) NOT NULL,
   CREATION_DATE       DATE NOT NULL,
   LAST_UPDATED_BY     NUMBER(15),
   LAST_UPDATE_DATE    DATE,
   LAST_UPDATE_LOGIN   NUMBER(15),
   REQUEST_ID          NUMBER (15)
);

PROMPT create object xxfnd_int_run_phases

CREATE TABLE xxnzcl.xxfnd_int_run_phases
(
   RUN_PHASE_ID             NUMBER(15) NOT NULL,
   RUN_ID                   NUMBER NOT NULL,
   PHASE_CODE               VARCHAR2(10),
   PHASE_MODE               VARCHAR2(25),
   START_DATE               DATE,
   END_DATE                 DATE,
   SRC_CODE                 VARCHAR2(10),
   REC_COUNT                NUMBER,
   HASH_TOTAL               NUMBER,
   BATCH_NAME               VARCHAR2(250),
   STATUS                   VARCHAR2(15),
   ERROR_COUNT              NUMBER,
   SUCCESS_COUNT            NUMBER,
   INT_TABLE_NAME           VARCHAR2(100),
   INT_TABLE_KEY_COL1       VARCHAR2(25),
   INT_TABLE_KEY_COL_DESC1  VARCHAR2(50),
   INT_TABLE_KEY_COL2       VARCHAR2(25),
   INT_TABLE_KEY_COL_DESC2  VARCHAR2(50),
   INT_TABLE_KEY_COL3       VARCHAR2(25),
   INT_TABLE_KEY_COL_DESC3  VARCHAR2(50),
   CREATION_DATE            DATE,
   CREATED_BY               NUMBER,
   LAST_UPDATE_DATE         DATE,
   LAST_UPDATED_BY          NUMBER,
   LAST_UPDATE_LOGIN        NUMBER(15),
   REQUEST_ID               NUMBER
);

PROMPT create object xxfnd_int_messages

CREATE TABLE xxnzcl.xxfnd_int_messages
(
   MSG_CODE             VARCHAR2(15) NOT NULL,
   MSG_TEXT             VARCHAR2(2000),
   CREATED_BY           NUMBER(15) NOT NULL,
   CREATION_DATE        DATE NOT NULL,
   LAST_UPDATED_BY      NUMBER(15) NOT NULL,
   LAST_UPDATE_DATE     DATE NOT NULL,
   LAST_UPDATE_LOGIN    NUMBER(15),
   REQUEST_ID           NUMBER(15)
);

PROMPT create constraint on xxfnd_int_data_sources

ALTER TABLE xxnzcl.xxfnd_int_data_sources
ADD CONSTRAINT xxfnd_int_data_sources_pk1 PRIMARY KEY (SRC_CODE) ENABLE;

PROMPT create constraint on xxfnd_int_interfaces

ALTER TABLE xxnzcl.xxfnd_int_interfaces
ADD CONSTRAINT xxfnd_int_interfaces_pk1 PRIMARY KEY (INT_ID) ENABLE;

PROMPT create constraint on xxfnd_int_interfaces

ALTER TABLE xxnzcl.xxfnd_int_interfaces 
ADD CONSTRAINT xxfnd_int_interfaces_uk1 UNIQUE (INT_CODE) ENABLE;

PROMPT create constraint on xxfnd_int_runs

ALTER TABLE xxnzcl.xxfnd_int_runs 
ADD CONSTRAINT xxfnd_int_runs_pk1 PRIMARY KEY (RUN_ID) ENABLE;

PROMPT create constraint on xxfnd_int_run_phase_errors

ALTER TABLE xxnzcl.xxfnd_int_run_phase_errors
ADD CONSTRAINT xxfnd_int_run_errors_pk1 PRIMARY KEY (ERROR_ID) ENABLE;

PROMPT create constraint on xxfnd_int_run_phases

ALTER TABLE xxnzcl.xxfnd_int_run_phases
ADD CONSTRAINT xxfnd_int_run_phases_pk1 PRIMARY KEY (RUN_PHASE_ID) ENABLE;

PROMPT create constraint on xxfnd_int_messages

ALTER TABLE xxnzcl.xxfnd_int_messages 
ADD CONSTRAINT xxfnd_int_messages_pk1 PRIMARY KEY (MSG_CODE) ENABLE;

COMMENT ON COLUMN xxnzcl.xxfnd_int_data_sources.SRC_CODE IS 'Data source short code';
COMMENT ON COLUMN xxnzcl.xxfnd_int_data_sources.SRC_NAME IS 'Data source description';
COMMENT ON COLUMN xxnzcl.xxfnd_int_data_sources.CREATED_BY IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_data_sources.CREATION_DATE IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_data_sources.LAST_UPDATED_BY IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_data_sources.LAST_UPDATE_DATE IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_data_sources.LAST_UPDATE_LOGIN IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_data_sources.REQUEST_ID IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_interfaces.INT_ID IS 'Primary key for table';
COMMENT ON COLUMN xxnzcl.xxfnd_int_interfaces.INT_CODE IS 'Interface short code.';
COMMENT ON COLUMN xxnzcl.xxfnd_int_interfaces.INT_NAME IS 'Description of interface';
COMMENT ON COLUMN xxnzcl.xxfnd_int_interfaces.EBS_IN_OUT IS 'IN = Inbound Interface into EBS; OUT = Outbound Interface from EBS';
COMMENT ON COLUMN xxnzcl.xxfnd_int_interfaces.APPL_SHORT_NAME IS 'EBS Application Short Code';
COMMENT ON COLUMN xxnzcl.xxfnd_int_interfaces.ENABLED_FLAG IS 'Interface enabled flag';
COMMENT ON COLUMN xxnzcl.xxfnd_int_interfaces.CREATION_DATE IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_interfaces.CREATED_BY IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_interfaces.LAST_UPDATED_BY IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_interfaces.LAST_UPDATE_DATE IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_interfaces.LAST_UPDATE_LOGIN IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_interfaces.REQUEST_ID IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_runs.RUN_ID IS 'Primary Key';
COMMENT ON COLUMN xxnzcl.xxfnd_int_runs.INT_ID IS 'Foreign key to xxfnd_int_interfaces';
COMMENT ON COLUMN xxnzcl.xxfnd_int_runs.SRC_REC_COUNT IS 'Data batch record count';
COMMENT ON COLUMN xxnzcl.xxfnd_int_runs.SRC_HASH_TOTAL IS 'Data batch hash total';
COMMENT ON COLUMN xxnzcl.xxfnd_int_runs.SRC_BATCH_NAME IS 'Data batch name';
COMMENT ON COLUMN xxnzcl.xxfnd_int_runs.CREATED_BY IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_runs.CREATION_DATE IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_runs.LAST_UPDATED_BY IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_runs.LAST_UPDATE_DATE IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_runs.LAST_UPDATE_LOGIN IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_runs.REQUEST_ID IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.ERROR_ID IS 'Primary Key';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.RUN_ID IS 'Foreign key to xxfnd_int_runs';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.RUN_PHASE_ID IS 'Foreign key to xxfnd_int_run_phases';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.RECORD_ID IS 'Record ID from interface table with error as detailed in xxfnd_int_run_phases.table_name';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.MSG_CODE IS 'Foreign key to xxfnd_int_messages.';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.ERROR_TEXT IS 'For unexpected error messages for example from APIs.';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.ERROR_TOKEN_VAL1 IS 'Error message token value 1';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.ERROR_TOKEN_VAL2 IS 'Error message token value 2';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.ERROR_TOKEN_VAL3 IS 'Error message token value 3';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.ERROR_TOKEN_VAL4 IS 'Error message token value 4';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.ERROR_TOKEN_VAL5 IS 'Error message token value 5';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.INT_TABLE_KEY_VAL1 IS 'Interface table key value 1';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.INT_TABLE_KEY_VAL2 IS 'Interface table key value 2';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.INT_TABLE_KEY_VAL3 IS 'Interface table key value 3';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.CREATED_BY IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.CREATION_DATE IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.LAST_UPDATED_BY IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.LAST_UPDATE_DATE IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.LAST_UPDATE_LOGIN IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phase_errors.REQUEST_ID IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.RUN_PHASE_ID IS 'Primary Key';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.RUN_ID IS 'Foreign Key to xxfnd_int_runs';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.PHASE_CODE IS 'Run Phase Code STAGE, TRANSFORM, LOAD, EXTRACT';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.PHASE_MODE IS 'Phase Run Mode for Transform Stage: VALIDATE VALIDATE_TRANSFER';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.START_DATE IS 'Run phase start date and time';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.END_DATE IS 'Run phase end date and time';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.SRC_CODE IS 'Foreign key to xxfnd_int_data_sources';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.REC_COUNT IS 'Total data records processed  in phase';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.HASH_TOTAL IS 'Hash total for data records processed in phase';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.BATCH_NAME IS 'File name or data batch name';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.STATUS IS 'Phase status = ERROR, SUCCESS';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.ERROR_COUNT IS 'Number of record in error for the phase';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.SUCCESS_COUNT IS 'Number of records successfuly processed for the phase';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.INT_TABLE_NAME IS 'Interface table name upon which phase has been run.';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.INT_TABLE_KEY_COL1 IS 'Column name of table on interface table that is to be used as a key for error reporting.';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.INT_TABLE_KEY_COL_DESC1 IS 'Description of column name of table on interface table that is to be used as a key for error reporting.';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.INT_TABLE_KEY_COL2 IS 'Column name of table on interface table that is to be used as a key for error reporting.';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.INT_TABLE_KEY_COL_DESC2 IS 'Description of column name of table on interface table that is to be used as a key for error reporting.';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.INT_TABLE_KEY_COL3 IS 'Column name of table on interface table that is to be used as a key for error reporting.';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.INT_TABLE_KEY_COL_DESC3 IS 'Description of column name of table on interface table that is to be used as a key for error reporting.';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.CREATION_DATE IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.CREATED_BY IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.LAST_UPDATE_DATE IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.LAST_UPDATED_BY IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.LAST_UPDATE_LOGIN IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_run_phases.REQUEST_ID IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_messages.MSG_CODE IS 'Primary key';
COMMENT ON COLUMN xxnzcl.xxfnd_int_messages.MSG_TEXT IS 'Message description';
COMMENT ON COLUMN xxnzcl.xxfnd_int_messages.CREATED_BY IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_messages.CREATION_DATE IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_messages.LAST_UPDATED_BY IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_messages.LAST_UPDATE_DATE IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_messages.LAST_UPDATE_LOGIN IS 'Standard WHO column';
COMMENT ON COLUMN xxnzcl.xxfnd_int_messages.REQUEST_ID IS 'Standard WHO column';
COMMENT ON TABLE xxnzcl.xxfnd_int_data_sources IS 'To store data sources / source systems.';
COMMENT ON TABLE xxnzcl.xxfnd_int_interfaces IS 'Interface definition information.  Each interface will have a separate record.';
COMMENT ON TABLE xxnzcl.xxfnd_int_runs IS 'To store interface run information.';
COMMENT ON TABLE xxnzcl.xxfnd_int_run_phase_errors IS 'To store individual errors raised for an interface run phase.';
COMMENT ON TABLE xxnzcl.xxfnd_int_run_phases IS 'Interface Run Phases table';
COMMENT ON TABLE xxnzcl.xxfnd_int_messages IS 'Holds interface error messages.';

PROMPT create foreign key constraint on xxfnd_int_runs

ALTER TABLE xxnzcl.xxfnd_int_runs
ADD CONSTRAINT xxfnd_int_runs_fk1 FOREIGN KEY (INT_ID)
REFERENCES xxnzcl.xxfnd_int_interfaces (INT_ID) ENABLE;

PROMPT create foreign key constraint on xxfnd_int_run_phase_errors

ALTER TABLE xxnzcl.xxfnd_int_run_phase_errors
ADD CONSTRAINT xxfnd_int_run_errors_fk1 FOREIGN KEY (RUN_PHASE_ID)
REFERENCES xxnzcl.xxfnd_int_run_phases (RUN_PHASE_ID) ENABLE;

PROMPT create foreign key constraint on xxfnd_int_run_phase_errors

ALTER TABLE xxnzcl.xxfnd_int_run_phase_errors
ADD CONSTRAINT xxfnd_int_run_errors_fk2 FOREIGN KEY (MSG_CODE)
REFERENCES xxnzcl.xxfnd_int_messages (MSG_CODE) ENABLE;

PROMPT create foreign key constraint on xxfnd_int_run_phases

ALTER TABLE xxnzcl.xxfnd_int_run_phases
ADD CONSTRAINT xxfnd_int_run_phases_fk1 FOREIGN KEY (RUN_ID)
REFERENCES xxnzcl.xxfnd_int_runs (RUN_ID) ENABLE;

PROMPT create foreign key constraint on xxfnd_int_run_phases

ALTER TABLE xxnzcl.xxfnd_int_run_phases
ADD CONSTRAINT xxfnd_int_run_phases_xxc_fk1 FOREIGN KEY (SRC_CODE)
REFERENCES xxnzcl.xxfnd_int_data_sources (SRC_CODE) ENABLE;

PROMPT create check constraint on xxfnd_int_interfaces

ALTER TABLE xxnzcl.xxfnd_int_interfaces
ADD CONSTRAINT xxfnd_int_interfaces_chk1 CHECK (EBS_IN_OUT IN ('IN','OUT')) ENABLE;

PROMPT create check constraint on xxfnd_int_interfaces

ALTER TABLE xxnzcl.xxfnd_int_interfaces
ADD CONSTRAINT xxfnd_int_interfaces_chk2 CHECK (ENABLED_FLAG IN ('Y','N')) ENABLE;

PROMPT create check constraint on xxfnd_int_run_phases

ALTER TABLE xxnzcl.xxfnd_int_run_phases
ADD CONSTRAINT xxfnd_int_run_phases_chk1 CHECK (PHASE_MODE IN ('VALIDATE','VALIDATE_TRANSFER')) ENABLE;

PROMPT create check constraint on xxfnd_int_run_phases

ALTER TABLE xxnzcl.xxfnd_int_run_phases
ADD CONSTRAINT xxfnd_int_run_phases_chk2 CHECK (PHASE_CODE IN('STAGE','TRANSFORM','LOAD','EXTRACT')) ENABLE;

PROMPT create check constraint on xxfnd_int_run_phases

ALTER TABLE xxnzcl.xxfnd_int_run_phases
ADD CONSTRAINT xxfnd_int_run_phases_chk3 CHECK (STATUS IN ('SUCCESS','ERROR','WARNING')) ENABLE;

PROMPT synonyms

CREATE OR REPLACE SYNONYM xxfnd_int_interfaces FOR xxnzcl.xxfnd_int_interfaces;

CREATE OR REPLACE SYNONYM xxfnd_int_data_sources FOR xxnzcl.xxfnd_int_data_sources;

CREATE OR REPLACE SYNONYM xxfnd_int_messages FOR xxnzcl.xxfnd_int_messages;

CREATE OR REPLACE SYNONYM xxfnd_int_run_phases FOR xxnzcl.xxfnd_int_run_phases;

CREATE OR REPLACE SYNONYM xxfnd_int_runs FOR xxnzcl.xxfnd_int_runs;

CREATE OR REPLACE SYNONYM xxfnd_int_run_phase_errors FOR xxnzcl.xxfnd_int_run_phase_errors;

CREATE OR REPLACE SYNONYM xxfnd_int_interfaces_s FOR xxnzcl.xxfnd_int_interfaces_s;

CREATE OR REPLACE SYNONYM xxfnd_int_runs_id_s FOR xxnzcl.xxfnd_int_runs_id_s;

CREATE OR REPLACE SYNONYM xxfnd_int_run_phases_id_s FOR xxnzcl.xxfnd_int_run_phases_id_s;

CREATE OR REPLACE SYNONYM xxfnd_int_run_phase_err_id_s FOR xxnzcl.xxfnd_int_run_phase_err_id_s;

CREATE OR REPLACE PUBLIC SYNONYM xxfnd_dir_entry FOR xxfnd_dir_entry;

CREATE OR REPLACE PUBLIC SYNONYM xxfnd_dir_array FOR xxfnd_dir_array;
