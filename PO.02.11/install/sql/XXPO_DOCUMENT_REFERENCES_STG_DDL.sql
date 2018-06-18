-------------------------------------------------
-- $HeadURL: $
-- $Date: $
-- CEMLI ID: PO.02.11
-- Script: XXPO_DOCUMENT_REFERENCES_STG_DDL.sql
-- Author: Dart Arellano DXC Red Rock
-------------------------------------------------

CREATE TABLE xxnzcl.xxpo_document_references_stg
(
   request_id            NUMBER,
   po_header_id          NUMBER,
   po_num                VARCHAR2(30),
   org_id                NUMBER,
   last_update_date      DATE,
   authorization_status  VARCHAR2(25)
);

CREATE SYNONYM xxpo_document_references_stg FOR xxnzcl.xxpo_document_references_stg;

