CREATE OR REPLACE PACKAGE xxap_suppliers_xml_pkg AS

/****************************************************************************
**
**  $HeadURL: $
**
**  CEMLI ID: AP.01.07 - 2D Supplier XML File Creation
**
**  Author: Dart Arellano (DXC RED ROCK) 
**
**  $Date: $
**
**  $Revision: $
**
**  History: Refer to Source Control
**
****************************************************************************/

FUNCTION populate_staging
(
   p_request_id           NUMBER, 
   p_include_org_id       VARCHAR2,
   p_file_name            VARCHAR2,
   p_object_type          VARCHAR2,
   p_object_source_table  VARCHAR2,
   p_test_data_flag       VARCHAR2,
   p_full_extract_flag    VARCHAR2
)
RETURN VARCHAR2;

FUNCTION get_language_code
(
   p_nls_lang   VARCHAR2
)
RETURN VARCHAR2;

END xxap_suppliers_xml_pkg;
/
