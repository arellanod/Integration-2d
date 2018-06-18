-------------------------------------------------
-- $HeadURL: $
-- $Date: $
-- CEMLI ID: PO.01.12
-- Script: XXPO_DISTRIBUTIONS_XML_V_DDL.sql
-- Author: Dart Arellano DXC Red Rock
-------------------------------------------------

CREATE OR REPLACE VIEW xxpo_distributions_xml_v
AS
SELECT pol.po_line_id po_line_id_d,
       poh.segment1 order_number_d,
       pol.line_num order_row_number,
       pod.distribution_num row_index_d,
       gcc.segment4 account_code,
       gcc.segment3 cost_center_code,
       gcc.segment5 project_code,
       pll.price_override net_sum_d,
       pod.quantity_ordered,
       gcc.segment6 text4,
       pod.attribute1 text5,
       gcc.segment2 text14
FROM   po_headers_all poh,
       po_lines_all pol,
       po_line_locations_all pll,
       po_distributions_all pod,
       gl_code_combinations_kfv gcc
WHERE  poh.po_header_id = pol.po_header_id
AND    pol.po_header_id = pll.po_header_id
AND    pol.po_line_id = pll.po_line_id
AND    pll.po_header_id = pod.po_header_id
AND    pll.po_line_id = pod.po_line_id
AND    pll.line_location_id = pod.line_location_id
AND    pod.code_combination_id = gcc.code_combination_id;
