-------------------------------------------------
-- $HeadURL: $
-- $Date: $
-- CEMLI ID: AP.01.07
-- Script: XXAP_SUPPLIERS_XML_STG_DDL.sql
-- Author: Dart Arellano DXC Red Rock
-------------------------------------------------

CREATE TABLE xxnzcl.xxap_suppliers_xml_stg
(
   request_id          NUMBER,
   request_date        DATE,
   vendor_site_id      NUMBER,
   org_id              NUMBER
);

CREATE SYNONYM xxap_suppliers_xml_stg FOR xxnzcl.xxap_suppliers_xml_stg;
