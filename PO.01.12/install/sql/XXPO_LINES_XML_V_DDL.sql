-------------------------------------------------
-- $HeadURL: $
-- $Date: $
-- CEMLI ID: PO.01.12
-- Script: XXPO_LINES_XML_V_DDL.sql
-- Author: Dart Arellano DXC Red Rock
-------------------------------------------------

CREATE OR REPLACE VIEW xxpo_lines_xml_v
AS
SELECT pol.po_line_id,
       poh.po_header_id po_header_id_l,
       poh.segment1 order_number_l,
       pol.line_num row_index,
       pol.quantity,
       uom.uom_code unit_code,
       pol.unit_price net_price,
       pll.price_override net_sum_l,
       (
       SELECT flv.tag basware_tax_code
       FROM   fnd_lookup_values flv
       WHERE  flv.lookup_type = 'XX_BASWARE_TAX_MAPPING'
       AND    flv.lookup_code = tax.tax_rate_code
       AND    TO_NUMBER(flv.description) = pol.org_id
       AND    NVL(flv.enabled_flag, 'N') = 'Y'
       ) tax_code,
       (
       SELECT txr.percentage_rate
       FROM   zx_rates_vl txr
       WHERE  txr.tax_rate_id = tax.tax_rate_id
       ) tax_percent,
       pol.quantity delivered_quantity,
       'True' goods_receipt_required,
       TO_CHAR(pll.need_by_date, 'YYYY-MM-DD') requested_delivery_date,
       TO_CHAR((
               SELECT MIN(transaction_date)
               FROM   rcv_transactions rcv
               WHERE  rcv.transaction_type = 'RECEIVE'
               AND    rcv.po_line_location_id = pll.line_location_id
               AND    rcv.po_line_id = pll.po_line_id
               ), 'YYYY-MM-DD') actual_delivery_date,
       pol.item_description,
       (
       SELECT segment1
       FROM   mtl_system_items_b mtls
       WHERE  mtls.inventory_item_id = pol.item_id
       AND    EXISTS (SELECT 1
                      FROM   mtl_parameters mtlp
                      WHERE  mtlp.master_organization_id = mtls.organization_id)
       ) text1,
       '0' matching_mode_l,
       DECODE(NVL(pol.cancel_flag, 'N'), 'Y', '0', '1') deleted_l,
       'True' goods_receipt_invoicing_l
FROM   po_headers_all poh,
       po_lines_all pol,
       po_units_of_measure_val_v uom,
       po_line_locations_all pll,
       zx_lines tax
WHERE  poh.po_header_id = pol.po_header_id
AND    pol.unit_meas_lookup_code = uom.unit_of_measure
AND    pol.po_header_id = pll.po_header_id
AND    pol.po_line_id = pll.po_line_id
AND    NVL((pol.unit_price * pol.quantity), 0) <> 0
AND    pll.line_location_id = tax.trx_line_id(+)
AND    pll.po_header_id = tax.trx_id(+)
AND    tax.entity_code(+) = 'PURCHASE_ORDER'
AND    tax.trx_level_type(+) = 'SHIPMENT';
