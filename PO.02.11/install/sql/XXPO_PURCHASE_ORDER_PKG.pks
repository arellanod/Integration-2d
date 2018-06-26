CREATE OR REPLACE PACKAGE xxpo_purchase_order_pkg AS

/****************************************************************************
**
**  $HeadURL: $
**
**  CEMLI ID: PO.02.11 - PO to ERP (Oracle)
**            PO.01.12 - PO Import (Basware)
**
**  Author: Dart Arellano DXC RED ROCK 
**
**  $Date: $
**
**  $Revision: $
**
**  History: Refer to Source Control
**
****************************************************************************/

PROCEDURE run_po_import_all
(
   p_errbuff       OUT VARCHAR2,
   p_retcode       OUT NUMBER,
   p_buyer         IN  VARCHAR2,
   p_debug_flag    IN  VARCHAR2
);

PROCEDURE run_po_import
(
   p_errbuff         OUT VARCHAR2,
   p_retcode         OUT NUMBER,
   p_control_id      IN  NUMBER,
   p_object_type     IN  VARCHAR2,
   p_buyer           IN  VARCHAR2,
   p_debug_flag      IN  VARCHAR2,
   p_purge_interface IN  VARCHAR2
);

PROCEDURE stage
(
   p_run_id         IN NUMBER,
   p_run_phase_id   IN NUMBER,
   p_control_id     IN NUMBER,
   p_stage_status   IN OUT BOOLEAN
);

PROCEDURE transform
(
   p_run_id            IN  NUMBER,
   p_run_phase_id      IN  NUMBER,
   p_control_id        IN  NUMBER,
   p_stage_status      IN  BOOLEAN,
   p_transform_status  IN  OUT BOOLEAN
);

PROCEDURE load
(
   p_run_id            IN NUMBER,
   p_run_phase_id      IN NUMBER,
   p_control_id        IN NUMBER,
   p_transform_status  IN BOOLEAN,
   p_load_status       IN OUT BOOLEAN,
   p_warning           IN OUT NUMBER
);

PROCEDURE switch_resp
(
   p_errbuff       OUT VARCHAR2,
   p_retcode       OUT NUMBER,
   p_org_id        IN  NUMBER
);

PROCEDURE create_po_xml
(
   p_errbuff        OUT VARCHAR2,
   p_retcode        OUT NUMBER,
   p_source         IN  VARCHAR2,
   p_last_run_date  IN  VARCHAR2,
   p_debug_flag     IN  VARCHAR2
);

END xxpo_purchase_order_pkg;
/
