-------------------------------------------
-- $HeadURL: $
-- $Date: $
-- CEMLI ID: PO.02.11
-- Script: XXPO_PO_INTERFACE_TFM_DDL.sql
-- Author: Dart Arellano DXC Red Rock
-------------------------------------------

CREATE TABLE xxnzcl.xxpo_po_interface_tfm
(
   record_id                    NUMBER,
   record_type                  VARCHAR2(15),  -- HEADER, LINE, DISTRIBUTION
   run_id                       NUMBER, 
   run_phase_id                 NUMBER,
   -- HEADER
   interface_source_code        VARCHAR2(25),
   process_code                 VARCHAR2(25),  -- PENDING
   action                       VARCHAR2(25),  -- ORIGINAL
   org_id                       NUMBER, 
   document_type_code           VARCHAR2(25),
   document_num                 VARCHAR2(20),
   currency_code                VARCHAR2(15),
   rate_type                    VARCHAR2(30),
   rate_date                    DATE,
   rate                         NUMBER,
   buyer                        VARCHAR2(150),
   agent_id                     NUMBER,
   vendor_name                  VARCHAR2(240),
   vendor_site_code             VARCHAR2(15),
   vendor_id                    NUMBER,
   vendor_site_id               NUMBER,
   payment_terms                VARCHAR2(50),
   terms_id                     NUMBER,
   ship_to_location             VARCHAR2(60),
   ship_to_location_id          NUMBER,
   bill_to_location             VARCHAR2(60),
   bill_to_location_id          NUMBER,
   approval_status              VARCHAR2(25),
   freight_terms                VARCHAR2(25),
   fob                          VARCHAR2(25),
   comments                     VARCHAR2(240),
   amount_agreed                NUMBER,
   expiration_date              DATE,
   created_by                   NUMBER,
   creation_date                DATE,
   last_update_date             DATE,
   last_updated_by              NUMBER,
   -- LINE
   line_action                  VARCHAR2(25),  -- NEW
   line_num                     NUMBER, 
   shipment_num                 NUMBER,
   line_type                    VARCHAR2(25),
   line_type_id                 NUMBER,
   category                     VARCHAR2(2000),
   category_id                  NUMBER,
   item_description             VARCHAR2(240),
   vendor_product_num           VARCHAR2(25),
   uom_code                     VARCHAR2(3),
   unit_of_measure              VARCHAR2(25),
   quantity                     NUMBER,
   unit_price                   NUMBER,
   allow_price_override_flag    VARCHAR2(1),
   note_to_vendor               VARCHAR2(480),
   taxable_flag                 VARCHAR2(1),
   tax_name                     VARCHAR2(30),
   tax_code_id                  NUMBER,
   need_by_date                 DATE,
   promised_date                DATE,
   line_expiration_date         DATE,
   amount                       NUMBER,
   note_to_receiver             VARCHAR2(480),
   -- DISTRIBUTION
   quantity_ordered             NUMBER,
   distribution_rate            NUMBER,
   distribution_rate_date       DATE,
   deliver_to_location          VARCHAR2(60),
   deliver_to_location_id       NUMBER,
   destination_organization_id  NUMBER,
   destination_type_code        VARCHAR2(25),
   set_of_books_id              NUMBER,
   charge_account_id            NUMBER,
   distribution_num             NUMBER,
   charge_account_segment1      VARCHAR2(25),
   charge_account_segment2      VARCHAR2(25),
   charge_account_segment3      VARCHAR2(25),
   charge_account_segment4      VARCHAR2(25),
   charge_account_segment5      VARCHAR2(25),
   charge_account_segment6      VARCHAR2(25),
   attribute1                   VARCHAR2(150),
   transform_status             VARCHAR2(25),
   load_status                  VARCHAR2(25)
);

CREATE SYNONYM xxpo_po_interface_tfm FOR xxnzcl.xxpo_po_interface_tfm;

CREATE SEQUENCE xxnzcl.xxpo_po_interface_tfm_s START WITH 1000 INCREMENT BY 1 NOCACHE;

CREATE SYNONYM xxpo_po_interface_tfm_s FOR xxnzcl.xxpo_po_interface_tfm_s;

CREATE INDEX xxnzcl.xxpo_po_interface_tfm_n1 ON xxnzcl.xxpo_po_interface_tfm (run_id);

CREATE INDEX xxnzcl.xxpo_po_interface_tfm_n2 ON xxnzcl.xxpo_po_interface_tfm (run_phase_id);

CREATE INDEX xxnzcl.xxpo_po_interface_tfm_n3 ON xxnzcl.xxpo_po_interface_tfm (document_num);

