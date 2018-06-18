/* $Header: $ */
/* CEMLI ID: FND.02.01 */
/* Description: Interface Framework - File queueing routine */

SET ECHO OFF;
SET FEEDBACK OFF;
SET VERIFY OFF;

DECLARE
   l_file_name  xxfnd_interface_ctl.file_name%TYPE := '&2';
   l_req_id     NUMBER := &1;
   l_user_id    NUMBER := &3;
   l_ctl_id     NUMBER;
   l_org_id     NUMBER;
BEGIN
   SELECT xxfnd_interface_ctl_s.NEXTVAL
   INTO   l_ctl_id
   FROM   dual;

   l_org_id := fnd_global.org_id;

   IF INSTR(l_file_name, '*', 1, 1) = 0 THEN
      INSERT INTO xxfnd_interface_ctl
      VALUES (l_ctl_id,
              l_req_id,
              l_file_name,
              'NEW',
              NULL,
              l_org_id,
              SYSDATE,
              l_user_id,
              SYSDATE,
              l_user_id);

      COMMIT;

      -- Invoke the import process
      xxfnd_common_int_pkg.run_import_process(l_ctl_id, l_req_id);

   END IF;

EXCEPTION
   WHEN others THEN
      fnd_file.put_line(fnd_file.log, SQLERRM);
END;
/

EXIT;
