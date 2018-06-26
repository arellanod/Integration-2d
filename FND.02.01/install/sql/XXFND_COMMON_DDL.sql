/****************************************************************************
**
**  $HeadURL: $
**
**  Purpose: Create Tables for Common Utilities.
**
**  Author: DXC Red Rock
**
**  $Date: $
**
**  $Revision: $
**
**  History: Refer to Source Control
**
****************************************************************************/
-- $Id:$
--

-------------------------
PROMPT create debug table
-------------------------

CREATE TABLE xxnzcl.xxfnd_int_debug
(
   debug_id         NUMBER           NOT NULL,
   message_date     DATE             NOT NULL,
   procedure_name   VARCHAR2(100),
   debug_message    VARCHAR2(2000),
   wf_item_type     VARCHAR2(8),
   wf_item_key      VARCHAR2(30)
);
            
CREATE SYNONYM xxfnd_int_debug FOR xxnzcl.xxfnd_int_debug;

----------------------------------------
PROMPT create sequence xxfnd_int_debug_s
----------------------------------------

CREATE SEQUENCE xxnzcl.xxfnd_int_debug_s START WITH 1000 INCREMENT BY 1 NOCACHE;

CREATE SYNONYM xxfnd_int_debug_s FOR xxnzcl.xxfnd_int_debug_s;

-------------------------------------
PROMPT create interface control table
-------------------------------------

CREATE TABLE xxnzcl.xxfnd_interface_ctl
(
  control_id             NUMBER        NOT NULL,
  request_id             NUMBER        NOT NULL,
  file_name              VARCHAR2(240) NOT NULL,
  status                 VARCHAR2(30)  NOT NULL,
  error_message          VARCHAR2(1000),
  org_id                 NUMBER,
  creation_date          DATE,
  created_by             NUMBER,
  last_update_date       DATE,
  last_updated_by        NUMBER
);

CREATE SYNONYM xxfnd_interface_ctl FOR xxnzcl.xxfnd_interface_ctl;

---------------------
PROMPT create indexes
---------------------

CREATE UNIQUE INDEX xxnzcl.xxfnd_interface_ctl_u1 ON xxnzcl.xxfnd_interface_ctl (file_name);

CREATE INDEX xxnzcl.xxfnd_interface_ctl_n1 ON xxnzcl.xxfnd_interface_ctl (control_id);

CREATE INDEX xxnzcl.xxfnd_interface_ctl_n2 ON xxnzcl.xxfnd_interface_ctl (request_id);

CREATE INDEX xxnzcl.xxfnd_interface_ctl_n3 ON xxnzcl.xxfnd_interface_ctl (status);

--------------------------------------------
PROMPT create sequence xxfnd_interface_ctl_s
--------------------------------------------

CREATE SEQUENCE xxnzcl.xxfnd_interface_ctl_s START WITH 1000 INCREMENT BY 1 NOCACHE;

CREATE SYNONYM xxfnd_interface_ctl_s FOR xxnzcl.xxfnd_interface_ctl_s;

-------------------------------------
PROMPT create interface staging table
-------------------------------------

CREATE TABLE xxnzcl.xxfnd_interface_stg
(
  record_id            NUMBER NOT NULL,
  control_id           NUMBER NOT NULL,
  request_id           NUMBER NOT NULL,
  run_id               NUMBER,
  file_name            VARCHAR2(240) NOT NULL,
  object_type          VARCHAR2(150),
  object_source_table  VARCHAR2(150),
  object_source_id     NUMBER,
  status               VARCHAR2(60),
  file_content         XMLTYPE,
  in_out               VARCHAR2(60),
  last_run_date        DATE,
  org_id               NUMBER,
  creation_date        DATE,
  created_by           NUMBER,
  last_update_date     DATE,
  last_updated_by      NUMBER
);


CREATE SYNONYM xxfnd_interface_stg FOR xxnzcl.xxfnd_interface_stg;

---------------------
PROMPT create indexes
---------------------

CREATE INDEX xxnzcl.xxfnd_interface_stg_n1 ON xxnzcl.xxfnd_interface_stg (control_id);

CREATE INDEX xxnzcl.xxfnd_interface_stg_n2 ON xxnzcl.xxfnd_interface_stg (request_id);

CREATE INDEX xxnzcl.xxfnd_interface_stg_n3 ON xxnzcl.xxfnd_interface_stg (run_id);

CREATE INDEX xxnzcl.xxfnd_interface_stg_n4 ON xxnzcl.xxfnd_interface_stg (object_type);

CREATE UNIQUE INDEX xxnzcl.xxfnd_interface_stg_u1 ON xxnzcl.xxfnd_interface_stg (record_id);

-------------------------------
PROMPT create staging directory
-------------------------------

CREATE OR REPLACE DIRECTORY BASWARE_STAGING_DIR AS '/usr/tmp';

----------------------
PROMPT create sequence
----------------------

CREATE SEQUENCE xxnzcl.xxfnd_interface_stg_rec_id_s START WITH 1000 INCREMENT BY 1 NOCACHE;

CREATE SYNONYM xxfnd_interface_stg_rec_id_s FOR xxnzcl.xxfnd_interface_stg_rec_id_s;
