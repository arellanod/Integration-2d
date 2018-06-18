-------------------------------------------------
-- $HeadURL: $
-- $Date: $
-- CEMLI ID: PO.01.12
-- Script: XXPO_RECEIPTS_XML_V_DDL.sql
-- Author: Dart Arellano DXC Red Rock
-------------------------------------------------

CREATE OR REPLACE VIEW xxpo_receipts_xml_v
AS
SELECT pol.po_line_id po_line_id_r,
       poh.segment1 order_number_r,
       pol.line_num order_row_number_r,
       rcsh.receipt_num goods_receipt_num,
       rcsl.line_num goods_receipt_row_num,
       rcvx.quantity quantity_r,
       (rcvx.quantity * pol.unit_price) net_sum_r,
       pol.unit_price net_price_r,
       TO_CHAR(rcsl.program_update_date, 'YYYY-MM-DD') delivery_date
FROM   rcv_shipment_headers rcsh,
       rcv_shipment_lines rcsl,
       po_headers_all poh,
       po_lines_all pol,
       (
       SELECT rcvt.shipment_header_id,
              rcvt.shipment_line_id,
              rcvt.po_line_id,
              SUM(rcvt.quantity) quantity
       FROM   rcv_transactions rcvt
       WHERE  rcvt.destination_type_code = 'RECEIVING'
       GROUP  BY rcvt.shipment_header_id,
                 rcvt.shipment_line_id,
                 rcvt.po_line_id
       HAVING SUM(rcvt.quantity) > 0
       ) rcvx
WHERE  rcsh.shipment_header_id = rcsl.shipment_header_id
AND    rcsl.po_header_id = poh.po_header_id
AND    rcsl.po_line_id = pol.po_line_id
AND    poh.po_header_id = pol.po_header_id
AND    rcsl.shipment_header_id = rcvx.shipment_header_id
AND    rcsl.shipment_line_id = rcvx.shipment_line_id
AND    rcsl.po_line_id = rcvx.po_line_id;

