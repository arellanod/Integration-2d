-------------------------------------------------
-- $HeadURL: $
-- $Date: $
-- CEMLI ID: PO.01.12
-- Script: XXPO_DOCUMENT_REFERENCES_DML.sql
-- Author: Dart Arellano DXC Red Rock
-- Purpose: Apply patch to accommodate open PO
--          data migration.
-------------------------------------------------

CREATE TABLE xxpo_document_references_tmp
AS
SELECT *
FROM   xxpo_document_references;

DROP TABLE xxnzcl.xxpo_document_references;

DROP SYNONYM xxpo_document_references;

@XXPO_DOCUMENT_REFERENCES_DDL.sql;

INSERT INTO xxpo_document_references
SELECT document_id,
       document_num,
       org_id,
       document_source,
       file_name,
       file_content,
       xml_output,
       'N',
       created_by,
       creation_date
FROM   xxpo_document_references_tmp;

COMMIT;

DROP TABLE xxpo_document_references_tmp;

@XXPO_PURCHASE_ORDER_PKG.pkb;

