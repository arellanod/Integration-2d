/****************************************************************************
**
**  $HeadURL: $
**
**  Purpose: Populate interface sources table with unique data sources.
**
**  Author: DXC RED ROCK
**
**  $Date: $
**
**  $Revision: $
**
**  History: Refer to Source Control
**
****************************************************************************/
-- $Id: $

BEGIN
   INSERT INTO xxfnd_int_data_sources
   (src_code, src_name, created_by, creation_date, last_updated_by, last_update_date, last_update_login, request_id)
   VALUES
   ('Basware', 'Basware', 1, SYSDATE, 1, SYSDATE, 1, NULL);

   INSERT INTO xxfnd_int_interfaces
   (int_id, int_code, int_name, ebs_in_out, appl_short_name, enabled_flag, creation_date, created_by, last_updated_by, last_update_date, last_update_login, request_id)
   VALUES
   (1001, 'PO.02.11', 'Basware Integration: Purchase Order', 'IN', 'XXNZCL', 'Y', SYSDATE, -1, -1, SYSDATE, NULL, NULL);

   INSERT INTO xxfnd_int_interfaces
   (int_id, int_code, int_name, ebs_in_out, appl_short_name, enabled_flag, creation_date, created_by, last_updated_by, last_update_date, last_update_login, request_id)
   VALUES
   (1002, 'AP.02.10', 'Basware Integration: Invoice', 'IN', 'XXNZCL', 'Y', SYSDATE, -1, -1, SYSDATE, NULL, NULL);

   COMMIT;
END;
/
