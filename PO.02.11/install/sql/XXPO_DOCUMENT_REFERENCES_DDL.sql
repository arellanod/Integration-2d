-------------------------------------------------
-- $HeadURL: $
-- $Date: $
-- CEMLI ID: PO.02.11
-- Script: XXPO_DOCUMENT_REFERENCES_DDL.sql
-- Author: Dart Arellano DXC Red Rock
-------------------------------------------------

CREATE TABLE xxnzcl.xxpo_document_references
(
   document_id      NUMBER,         -- po_header_id
   document_num     VARCHAR2(20),   -- segment1
   org_id           NUMBER,
   document_source  VARCHAR2(60),
   file_name        VARCHAR2(150),
   file_content     XMLTYPE,
   xml_output       XMLTYPE,
   created_by       NUMBER,
   creation_date    DATE
);

CREATE SYNONYM xxpo_document_references FOR xxnzcl.xxpo_document_references;

CREATE INDEX xxnzcl.xxpo_document_references_n1 ON xxnzcl.xxpo_document_references (document_id);

CREATE INDEX xxnzcl.xxpo_document_references_n2 ON xxnzcl.xxpo_document_references (document_num);

CREATE INDEX xxnzcl.xxpo_document_references_n3 ON xxnzcl.xxpo_document_references (org_id);
