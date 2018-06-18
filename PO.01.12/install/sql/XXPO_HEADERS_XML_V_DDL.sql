-------------------------------------------------
-- $HeadURL: $
-- $Date: $
-- CEMLI ID: PO.01.12
-- Script: XXPO_HEADERS_XML_V_DDL.sql
-- Author: Dart Arellano DXC Red Rock
-------------------------------------------------

CREATE OR REPLACE VIEW xxpo_headers_xml_v
AS
SELECT poh.po_header_id,
       poh.segment1 order_number,
       '1' order_type,
       poh.comments description,
       poh.currency_code,
       poh.rate exchange_rate,
       poh.vendor_site_id invoice_supplier_code,
       DECODE(poh.org_id,
              82, '01',
              453, 07,
              452, 06) organization_code,
       DECODE(poh.org_id,
              82, '01',
              453, 07,
              452, 06) company_code,
       (
       SELECT SUM(pol.unit_price * pol.quantity)
       FROM   po_lines_all pol
       WHERE  NVL(pol.cancel_flag, 'N') = 'N'
       AND    pol.po_header_id = poh.po_header_id
       ) net_sum,
       '0' matching_mode,
       (
       SELECT SUM(recoverable_tax)
       FROM   po_distributions_all pod
       WHERE  pod.po_header_id = poh.po_header_id
       ) tax_sum,
       poh.vendor_site_id main_supplier_code,
       'True' goods_received_invoice,
       DECODE(NVL(poh.cancel_flag, 'N'), 'Y', '0', '1') deleted,
       poh.last_update_date,
       poh.org_id
FROM   po_headers_all poh
WHERE  poh.type_lookup_code = 'STANDARD';
