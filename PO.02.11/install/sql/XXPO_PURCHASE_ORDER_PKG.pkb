CREATE OR REPLACE PACKAGE BODY xxpo_purchase_order_pkg AS

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

-- Constants --
z_object_type        CONSTANT VARCHAR2(30)  := 'ORDER';
z_debug              CONSTANT VARCHAR2(30)  := 'DEBUG: ';
z_error              CONSTANT VARCHAR2(30)  := 'ERROR: ';
z_int_mode           CONSTANT VARCHAR2(60)  := 'VALIDATE_TRANSFER';
z_stage              CONSTANT VARCHAR2(30)  := 'STAGE';
z_transform          CONSTANT VARCHAR2(30)  := 'TRANSFORM';
z_load               CONSTANT VARCHAR2(30)  := 'LOAD';
z_processed          CONSTANT VARCHAR2(30)  := 'PROCESSED';
z_rejected           CONSTANT VARCHAR2(30)  := 'REJECTED';
z_src_code           CONSTANT VARCHAR2(10)  := 'Basware';
z_int_code           CONSTANT VARCHAR2(25)  := 'PO.02.11';
z_in                 CONSTANT VARCHAR2(5)   := 'IN';
z_new                CONSTANT VARCHAR2(5)   := 'NEW';
z_staging_dir        CONSTANT VARCHAR2(150) := '/usr/tmp';
z_staging_alias      CONSTANT VARCHAR2(150) := 'BASWARE_STAGING_DIR';
z_appl_short_name    CONSTANT VARCHAR2(10)  := 'PO';
z_profile_name       CONSTANT VARCHAR2(25)  := 'ORG_ID';
z_profile_level      CONSTANT NUMBER        := 10003;
z_retention          CONSTANT NUMBER        := -2; -- 2 months
z_delimiter          CONSTANT VARCHAR2(1)   := '.';
z_header_rec_type    CONSTANT VARCHAR2(30)  := 'HEADER';
z_line_rec_type      CONSTANT VARCHAR2(30)  := 'LINE';
z_distr_rec_type     CONSTANT VARCHAR2(30)  := 'DISTRIBUTION';
z_document_type      CONSTANT VARCHAR2(60)  := 'STANDARD';
z_pdoi_status        CONSTANT VARCHAR2(60)  := 'INCOMPLETE';
z_wait               CONSTANT NUMBER        := 10;
z_nl                 CONSTANT VARCHAR2(1)   := CHR(10);
z_po_xml_status      CONSTANT VARCHAR2(60)  := 'APPROVED';

-- Global --
g_user_id            NUMBER;
g_resp_id            NUMBER;
g_org_id             NUMBER;
g_set_of_books_id    NUMBER;
g_coa_id             NUMBER;
g_request_id         NUMBER;
g_control_id         NUMBER;
g_batch_id           NUMBER;
g_buyer              VARCHAR2(240);
g_control_status     VARCHAR2(30);
g_debug_flag         VARCHAR2(1);
g_object_type        VARCHAR2(60);
g_order_number       VARCHAR2(20);
g_period_name        VARCHAR2(60);
g_base_currency      gl_ledgers.currency_code%TYPE;
g_purge_interface    VARCHAR2(1);

-- SRS --
srs_wait             BOOLEAN;
srs_phase            VARCHAR2(30);
srs_status           VARCHAR2(30);
srs_dev_phase        VARCHAR2(30);
srs_dev_status       VARCHAR2(30);
srs_message          VARCHAR2(240);

-- Types --
TYPE r_request_record_type IS RECORD
(
   request_id     NUMBER,
   po_header_id   NUMBER,
   po_num         VARCHAR2(30),
   po_xml_file    VARCHAR2(150),
   org_id         NUMBER,
   status         VARCHAR2(15)
);

TYPE t_requests_tab_type IS TABLE OF r_request_record_type INDEX BY binary_integer;

------------------------------------------------------
-- Procedure
--     PRINT_DEBUG
-- Purpose
--     Print debug messages to fnd_file.log
-------------------------------------------------------

PROCEDURE print_debug
(
   p_message  VARCHAR2
)
IS
BEGIN
   IF g_debug_flag = 'Y' THEN
      fnd_file.put_line(fnd_file.log, z_debug || p_message);
   END IF;
END print_debug;

------------------------------------------------------
-- Procedure
--     UPDATE_CONTROL_QUEUE
-- Purpose
--     Set control queue table status at every 
--     phase. Helps keep track of the interface 
--     process. Especially useful when investigating
--     unexpected errors.
-------------------------------------------------------

PROCEDURE update_control_queue
(
   p_error_message  VARCHAR2
)
IS
   pragma   autonomous_transaction;
BEGIN
   UPDATE xxfnd_interface_ctl
   SET    status = g_control_status,
          error_message = NVL(p_error_message, error_message),
          last_updated_by = g_user_id,
          last_update_date = SYSDATE
   WHERE  control_id = g_control_id;

   COMMIT;
END update_control_queue;

------------------------------------------------------
-- Procedure
--    UPDATE_STAGE_TABLE
--
-- Description
--    Update record status in stage table 
------------------------------------------------------

PROCEDURE update_stage_table
(
   p_record_id  IN NUMBER,
   p_org_id     IN NUMBER,
   p_status     IN VARCHAR2  
)
IS
   pragma      autonomous_transaction;
BEGIN
   UPDATE xxfnd_interface_stg
   SET    org_id = p_org_id,
          status = p_status
   WHERE  record_id = p_record_id;

   COMMIT;
END update_stage_table;

------------------------------------------------------
-- Procedure
--    UPDATE_TRANSFORM_TABLE
--
-- Description
--    Update record status in transform table
------------------------------------------------------

PROCEDURE update_transform_table
(
   p_run_id    IN NUMBER,
   p_status    IN VARCHAR2  
)
IS
   pragma      autonomous_transaction;
BEGIN
   UPDATE xxpo_po_interface_tfm
   SET    load_status = p_status 
   WHERE  run_id = p_run_id;

   COMMIT;
END update_transform_table;

------------------------------------------------------
-- Procedure
--    RESET_STAGE_TABLE
--
-- Description
--    Remove record from staging table 
------------------------------------------------------

PROCEDURE reset_stage_table
(
   p_record_id  IN NUMBER
)
IS
   pragma      autonomous_transaction;
BEGIN
   DELETE FROM xxfnd_interface_stg
   WHERE  record_id = p_record_id;

   COMMIT;
END reset_stage_table;

------------------------------------------------------
-- Procedure
--    PURGE_TRANSFORM_TABLE
--
-- Description
--    Remove old records from transformation table 
------------------------------------------------------

PROCEDURE purge_transform_table
IS
   l_date   DATE;
   pragma   autonomous_transaction;
BEGIN
   SELECT add_months(SYSDATE, z_retention)
   INTO   l_date
   FROM   dual;

   DELETE FROM xxpo_po_interface_tfm
   WHERE  creation_date < TRUNC(l_date);

   COMMIT;
END purge_transform_table;

------------------------------------------------------
-- Procedure
--    SEND_ERROR_NOTIFICATION
--
-- Description
--    Notification email to inform administrator
--    of error encountered.  
------------------------------------------------------

PROCEDURE send_error_notification
(
   p_message_body  VARCHAR2
)
IS
   l_to             VARCHAR2(240);  -- Administrator Email (profile option)
   l_from           VARCHAR2(240);  -- Instance host name
   l_sql            VARCHAR2(600);
   l_subject        VARCHAR2(600);
BEGIN
   l_sql := 'SELECT ''No-reply@'' || host_name FROM v$instance';
   EXECUTE IMMEDIATE l_sql INTO l_from;

   l_to := fnd_profile.value('XXFND_NOTIFICATION_EMAIL');
   l_subject := 'Concurrent Program Error: Request ID (' || g_request_id || ')';

   IF l_to IS NOT NULL THEN
      xxfnd_common_pkg.send_mail(p_to      => l_to,
                                 p_from    => l_from,
                                 p_subject => l_subject,
                                 p_message => p_message_body);
   END IF;
END send_error_notification;

------------------------------------------------------
-- Procedure
--     WAIT_FOR_REQUEST
-- Purpose
--     Oracle standard API for concurrent processing
------------------------------------------------------

PROCEDURE wait_for_request
(
   p_request_id   NUMBER,
   p_wait_time    NUMBER
)
IS
BEGIN
   srs_wait := fnd_concurrent.wait_for_request(p_request_id,
                                               p_wait_time,
                                               0,
                                               srs_phase,
                                               srs_status,
                                               srs_dev_phase,
                                               srs_dev_status,
                                               srs_message);
END wait_for_request;

----------------------------------------------------------
-- Procedure
--     RAISE_ERROR
-- Purpose
--     Subroutine for calling run phase errors log 
--     report (Interface Framework API).
----------------------------------------------------------

PROCEDURE raise_error
(
   p_error_rec   xxfnd_int_run_phase_errors%ROWTYPE
)
IS
BEGIN
   xxfnd_common_int_pkg.raise_error(p_run_id => p_error_rec.run_id,
                                    p_run_phase_id => p_error_rec.run_phase_id,
                                    p_record_id => p_error_rec.record_id,
                                    p_msg_code => p_error_rec.msg_code,
                                    p_error_text => p_error_rec.error_text,
                                    p_error_token_val1 => p_error_rec.error_token_val1,
                                    p_error_token_val2 => p_error_rec.error_token_val2,
                                    p_error_token_val3 => p_error_rec.error_token_val3,
                                    p_error_token_val4 => p_error_rec.error_token_val4,
                                    p_error_token_val5 => p_error_rec.error_token_val5,
                                    p_int_table_key_val1 => p_error_rec.int_table_key_val1,
                                    p_int_table_key_val2 => p_error_rec.int_table_key_val2,
                                    p_int_table_key_val3 => p_error_rec.int_table_key_val3);
END raise_error;

/* count_errors */ 
FUNCTION count_errors
(
   p_run_id        NUMBER,
   p_run_phase_id  NUMBER,
   p_record_id     NUMBER
)
RETURN NUMBER
IS
   l_count   NUMBER;
BEGIN
   SELECT COUNT(1)
   INTO   l_count
   FROM   xxfnd_int_run_phase_errors
   WHERE  run_id = p_run_id
   AND    run_phase_id = p_run_phase_id
   AND    record_id = p_record_id;

   RETURN l_count;
END count_errors;
 
----------------------------------------------------------
-- Function
--     SET_CONTEXT
-- Purpose
--     Reinitialize context: attempt to set the
--     correct application user responsibility.
--     Pre-validate to avoid file error due from 
--     configuration issue.
----------------------------------------------------------

FUNCTION set_context
(
   p_control_id    IN  NUMBER,
   p_message_text  OUT VARCHAR2
)
RETURN BOOLEAN
IS
   CURSOR c_rec IS
      SELECT company_code
      FROM   xxpo_po_interface_stg
      WHERE  control_id = p_control_id;

   CURSOR c_resp (p_profile_value VARCHAR2) IS
      SELECT fugr.user_id,
             fugr.responsibility_id,
             fres.responsibility_key,
             fugr.start_date,
             fugr.end_date,
             fapp.application_id,
             TO_NUMBER(fprv.profile_option_value) org_id
      FROM   fnd_profile_options fpop,
             fnd_profile_option_values fprv,
             fnd_user_resp_groups_all fugr,
             fnd_responsibility fres,
             fnd_application fapp
      WHERE  fpop.profile_option_name = z_profile_name
      AND    fpop.profile_option_id = fprv.profile_option_id
      AND    fprv.level_value = fugr.responsibility_id
      AND    fprv.level_id = z_profile_level
      AND    fprv.level_value_application_id = fapp.application_id
      AND    fapp.application_short_name = z_appl_short_name
      AND    fapp.application_id = fugr.responsibility_application_id
      AND    TRUNC(SYSDATE) BETWEEN fugr.start_date AND NVL(fugr.end_date, SYSDATE + 1)
      AND    fugr.responsibility_id = fres.responsibility_id
      AND       (fres.responsibility_key LIKE '%PURCHASING_SUPER_USER' OR
                 fres.responsibility_key LIKE '%PO_SU%' OR
                 fres.responsibility_key LIKE '%PO_ADM_USER%')
      AND    fprv.profile_option_value IN ('82', '453', '452')
      AND    fugr.user_id > 0
      AND    fugr.user_id = g_user_id
      AND    fprv.profile_option_value = p_profile_value;

   r_resp           c_resp%ROWTYPE;
   l_profile_value  fnd_profile_option_values.profile_option_value%TYPE;
   l_org_id         NUMBER;
BEGIN
   FOR r_rec IN c_rec LOOP
      CASE r_rec.company_code
         WHEN '01' THEN l_org_id := 82;
         WHEN '07' THEN l_org_id := 453;
         WHEN '06' THEN l_org_id := 452;
      END CASE;
      IF l_org_id IS NOT NULL THEN
         EXIT;
      END IF;
   END LOOP;

   IF c_resp%ISOPEN THEN
      CLOSE c_resp;
   END IF;

   IF l_org_id <> g_org_id THEN
      l_profile_value := TO_CHAR(l_org_id);
      OPEN c_resp (l_profile_value);
      FETCH c_resp INTO r_resp;
      IF c_resp%FOUND THEN
         fnd_global.apps_initialize(user_id => r_resp.user_id,
                                    resp_id => r_resp.responsibility_id,
                                    resp_appl_id => r_resp.application_id);

         g_resp_id := r_resp.responsibility_id;
         g_org_id := r_resp.org_id;

         print_debug('set_context');
         print_debug('user_id=' || g_user_id);
         print_debug('resp_id=' || g_resp_id);
         print_debug('org_id=' || g_org_id);
      ELSE
         p_message_text := 'Unable to set application context with the current user and responsibility';
         RETURN FALSE;
      END IF;
      CLOSE c_resp;
   END IF;

   mo_global.set_policy_context('S', g_org_id);
   fnd_profile.get('GL_SET_OF_BKS_ID', g_set_of_books_id);

   print_debug('set_of_books_id=' || g_set_of_books_id);

   SELECT chart_of_accounts_id,
          currency_code
   INTO   g_coa_id,
          g_base_currency
   FROM   gl_sets_of_books
   WHERE  set_of_books_id = g_set_of_books_id;

   RETURN TRUE;

EXCEPTION
   WHEN others THEN
      p_message_text := SQLERRM;
      RETURN FALSE;
END set_context;

------------------------------------------------------
-- Procedure
--     INITIALIZE
-- Purpose
--     Initializes the interface run phases
--     STAGE-TRANSFORM-LOAD
------------------------------------------------------

PROCEDURE initialize
(
   p_file_name        IN VARCHAR2,
   p_run_id           IN OUT NUMBER,
   p_stage_id         IN OUT NUMBER,
   p_transform_id     IN OUT NUMBER,
   p_load_id          IN OUT NUMBER
)
IS
BEGIN
   print_debug('initialize interface run ids');

   -- Interface Run
   p_run_id := xxfnd_common_int_pkg.initialise_run
                  (p_int_code       => z_int_code,
                   p_src_rec_count  => NULL,
                   p_src_hash_total => NULL,
                   p_src_batch_name => p_file_name);

   -- Staging
   p_stage_id := xxfnd_common_int_pkg.start_run_phase
                    (p_run_id                  => p_run_id,
                     p_phase_code              => z_stage,
                     p_phase_mode              => NULL,
                     p_int_table_name          => 'XXPO_PO_INTERFACE_STG (' || p_file_name || ')',
                     p_int_table_key_col1      => 'CONTROL_ID',
                     p_int_table_key_col_desc1 => 'Control ID',
                     p_int_table_key_col2      => NULL,
                     p_int_table_key_col_desc2 => NULL,
                     p_int_table_key_col3      => NULL,
                     p_int_table_key_col_desc3 => NULL);

   -- Transform
   p_transform_id := xxfnd_common_int_pkg.start_run_phase
                        (p_run_id                  => p_run_id,
                         p_phase_code              => z_transform,
                         p_phase_mode              => z_int_mode,
                         p_int_table_name          => 'XXPO_PO_INTERFACE_TFM',
                         p_int_table_key_col1      => 'ORDER_NUMBER',
                         p_int_table_key_col_desc1 => 'Order Number',
                         p_int_table_key_col2      => 'LINE_NUM',
                         p_int_table_key_col_desc2 => 'Line',
                         p_int_table_key_col3      => 'DISTRIBUTION_NUM',
                         p_int_table_key_col_desc3 => 'Distribution');

   -- Load
   p_load_id := xxfnd_common_int_pkg.start_run_phase
                   (p_run_id                  => p_run_id,
                    p_phase_code              => z_load,
                    p_phase_mode              => z_int_mode,
                    p_int_table_name          => 'PO_HEADERS_INTERFACE, PO_LINES_INTERFACE, PO_DISTRIBUTIONS_INTERFACE',
                    p_int_table_key_col1      => 'DOCUMENT_NUM',
                    p_int_table_key_col_desc1 => 'Document Num',
                    p_int_table_key_col2      => NULL,
                    p_int_table_key_col_desc2 => NULL,
                    p_int_table_key_col3      => NULL,
                    p_int_table_key_col_desc3 => NULL);

END initialize;

-----------------------------------------------------------
-- Procedure
--     RUN_PO_IMPORT_ALL
-- Purpose
--     Submit one sub-request per file. Schedule this
--     program to run on a periodic basis to automatically
--     pick-up and process incoming PO XML files from
--     Basware.
-----------------------------------------------------------

PROCEDURE run_po_import_all
(
   p_errbuff       OUT VARCHAR2,
   p_retcode       OUT NUMBER,
   p_buyer         IN  VARCHAR2,
   p_debug_flag    IN  VARCHAR2
)
IS
   CURSOR c_file IS
      SELECT ctl.control_id,
             REPLACE(file_name, 
                     SUBSTR(file_name, 1, INSTR(file_name, '/', -1)),
                     NULL) file_name
      FROM   xxfnd_interface_ctl ctl
      WHERE  ctl.status = z_new
      AND    INSTR(NVL(UPPER(ctl.file_name), 'NULL'), 'ORDER') > 0
      ORDER  BY 1;

   l_set_of_books_id    NUMBER;
   l_request_id         NUMBER;
   l_sub_request_id     NUMBER;
   l_resp_id            NUMBER;
   l_program_id         NUMBER;
   l_program_name       fnd_concurrent_programs_tl.user_concurrent_program_name%TYPE;
   l_user_name          fnd_user.user_name%TYPE;
   l_inbound_directory  VARCHAR2(340);
   l_file_count         NUMBER := 0;
   l_report_text        VARCHAR2(1000);
BEGIN
   l_request_id := fnd_global.conc_request_id;
   l_resp_id := fnd_global.resp_id;
   l_user_name := fnd_global.user_name;
   l_program_id := fnd_global.conc_program_id;
   l_inbound_directory := fnd_profile.value('XXFND_INBOUND_BASWARE');
   l_set_of_books_id := fnd_profile.value('GL_SET_OF_BKS_ID');
   g_debug_flag := NVL(p_debug_flag, 'N');
   g_request_id := l_request_id;

   BEGIN
      SELECT user_concurrent_program_name
      INTO   l_program_name
      FROM   fnd_concurrent_programs_tl
      WHERE  concurrent_program_id = l_program_id;
   EXCEPTION
      WHEN others THEN
         NULL;
   END;

   -- pre-validate open period to avoid
   -- file error due from configuration issue.
   IF l_set_of_books_id IS NOT NULL THEN
      BEGIN
         SELECT glps.period_name
         INTO   g_period_name
         FROM   gl_period_statuses glps
         WHERE  glps.adjustment_period_flag = 'N'
         AND    glps.closing_status IN (SELECT lookup_code
                                     FROM   ap_lookup_codes
                                     WHERE  lookup_type = 'CLOSING STATUS')
         AND    glps.application_id = 201
         AND    glps.closing_status = 'O'
         AND    (TRUNC(SYSDATE) BETWEEN glps.start_date
                             AND     glps.end_date)
         AND    glps.set_of_books_id = l_set_of_books_id;
      EXCEPTION
         WHEN no_data_found THEN
            fnd_file.put_line(fnd_file.log, z_error || 'Period status is not open');
            send_error_notification(z_error || z_nl || 'Period status is not open');
            p_retcode := 2;
            RETURN;
      END;
   ELSE
      fnd_file.put_line(fnd_file.log, z_error || 'Unable to determine set of books id from user profile');
      send_error_notification(z_error || z_nl || 'Unable to determine set of books id from user profile');
      p_retcode := 2;
      RETURN;
   END IF;

   print_debug('parent_request_id=' || l_request_id);
   print_debug('resp_id=' || l_resp_id);
   print_debug('conc_program_id=' || l_program_id);

   fnd_file.put_line(fnd_file.output, fnd_global.newline);
   fnd_file.put_line(fnd_file.output, 'Program Name      : ' || l_program_name);
   fnd_file.put_line(fnd_file.output, 'Run Datetime      : ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH:MI:SS AM'));
   fnd_file.put_line(fnd_file.output, 'Username          : ' || l_user_name);
   fnd_file.put_line(fnd_file.output, fnd_global.newline);
   fnd_file.put_line(fnd_file.output, 'Run Parameters');
   fnd_file.put_line(fnd_file.output, 'Object Type       : ' || z_object_type);
   fnd_file.put_line(fnd_file.output, 'Default Buyer     : ' || p_buyer);
   fnd_file.put_line(fnd_file.output, 'Debug On          : ' || p_debug_flag);
   fnd_file.put_line(fnd_file.output, 'Inbound Directory : ' || l_inbound_directory);
   fnd_file.put_line(fnd_file.output, fnd_global.newline);

   fnd_file.put_line(fnd_file.output, 'Request ID  Control ID  PO XML Filename');
   fnd_file.put_line(fnd_file.output, '----------  ----------  ----------------------------------------------');

   FOR r_file IN c_file LOOP
      l_sub_request_id := fnd_request.submit_request
                             (application => 'XXNZCL',
                              program     => 'XXPOIMPTBAS', 
                              description => NULL,
                              start_time  => SYSDATE,
                              sub_request => FALSE, 
                              argument1   => TO_CHAR(r_file.control_id),
                              argument2   => z_object_type,
                              argument3   => p_buyer,
                              argument4   => p_debug_flag,
                              argument5   => 'Y');
      COMMIT;

      l_file_count := l_file_count + 1;
      l_report_text := RPAD(TO_CHAR(l_sub_request_id), 12) ||
                       RPAD(TO_CHAR(r_file.control_id), 12) ||
                       r_file.file_name;
      fnd_file.put_line(fnd_file.output, l_report_text); 
   END LOOP;

   fnd_file.put_line(fnd_file.output, fnd_global.newline);

   IF l_file_count = 0 THEN
      fnd_file.put_line(fnd_file.output, '                       *** No data found ***');
   ELSE
      fnd_file.put_line(fnd_file.output, '                       *** End of Report ***');
   END IF;

END run_po_import_all;

------------------------------------------------------
-- Procedure
--     RUN_PO_IMPORT
-- Purpose
--     Main program for importing purchase order
--     transaction from Basware.
-------------------------------------------------------

PROCEDURE run_po_import
(
   p_errbuff         OUT VARCHAR2,
   p_retcode         OUT NUMBER,
   p_control_id      IN  NUMBER,
   p_object_type     IN  VARCHAR2,
   p_buyer           IN  VARCHAR2,
   p_debug_flag      IN  VARCHAR2,
   p_purge_interface IN  VARCHAR2
)
IS
   CURSOR c_file IS
      SELECT ctl.control_id,
             REPLACE(file_name, 
                     SUBSTR(file_name, 1, INSTR(file_name, '/', -1)),
                     NULL) file_name
      FROM   xxfnd_interface_ctl ctl
      WHERE  ctl.status = z_new
      AND    INSTR(NVL(UPPER(ctl.file_name), 'NULL'), 'ORDER') > 0
      AND    ctl.control_id = p_control_id
      ORDER  BY 1;

   l_run_id             NUMBER;
   l_stage_id           NUMBER;
   l_transform_id       NUMBER;
   l_load_id            NUMBER;
   l_file_name          VARCHAR2(150);
   l_run_report         NUMBER;
   l_user_name          VARCHAR2(150);
   l_control_id         NUMBER;
   l_error_count        NUMBER;
   l_warning            NUMBER;
   l_error_message      VARCHAR2(600);

   stage_status         BOOLEAN := TRUE;
   transform_status     BOOLEAN := TRUE;
   load_status          BOOLEAN := TRUE;

   e_interface_error    EXCEPTION;
BEGIN
   g_debug_flag := NVL(p_debug_flag, 'N');
   g_request_id := fnd_global.conc_request_id;
   g_user_id := fnd_global.user_id;
   g_resp_id := fnd_global.resp_id;
   g_org_id := fnd_global.org_id;
   g_object_type := p_object_type;
   g_buyer := p_buyer;
   g_purge_interface := NVL(p_purge_interface, 'N');
   l_user_name := fnd_global.user_name;

   print_debug('object_type=' || g_object_type);
   print_debug('user_id=' || g_user_id);
   print_debug('resp_id=' || g_resp_id);
   print_debug('org_id=' || g_org_id);
   print_debug('user_name=' || l_user_name);
   print_debug('fetch purchase order xml file from queue');

   OPEN c_file;
   FETCH c_file INTO l_control_id, l_file_name;
   IF c_file%NOTFOUND THEN
      print_debug('purchase order file queue is empty');
      RETURN;
   END IF;
   CLOSE c_file;

   print_debug('purchase order file ' || l_file_name);

   g_control_id := l_control_id;

   ------------------------------
   -- Initialize interface run --
   ------------------------------
   initialize(l_file_name,
              l_run_id,
              l_stage_id,
              l_transform_id,
              l_load_id);

   ---------------------
   -- Stage Phase     --
   ---------------------
   stage(l_run_id, 
         l_stage_id,
         l_control_id,
         stage_status);

   ---------------------
   -- Transform Phase --
   ---------------------
   transform(l_run_id,
             l_transform_id,
             l_control_id,
             stage_status,
             transform_status);

   ---------------------
   -- Load Phase      --
   ---------------------
   load(l_run_id,
        l_load_id,
        l_control_id,
        transform_status,
        load_status,
        l_warning);

   ----------------------
   -- Interface Report --
   ----------------------
   l_run_report := xxfnd_common_int_pkg.launch_run_report
                      (l_run_id,
                       l_user_name);

   SELECT COUNT(1)
   INTO   l_error_count
   FROM   xxfnd_int_run_phase_errors
   WHERE  run_id = l_run_id;

   IF NOT load_status AND NVL(l_error_count, 0) > 0 THEN
      p_retcode := 2;
   END IF;

   IF load_status AND NVL(l_warning, 0) > 0 THEN
      p_retcode := 1;
   END IF;

EXCEPTION
   WHEN others THEN
      p_retcode := 2;
      fnd_file.put_line(fnd_file.log, SQLERRM);
      l_error_message := z_error || z_nl || SQLERRM;
      send_error_notification(l_error_message);

END run_po_import;

--------------------------------------------------------
-- Procedure
--     STAGE
-- Purpose
--     Interface Framework STAGE phase. This is the
--     procedure that loads the data file from a
--     specified source into the staging area.
--------------------------------------------------------

PROCEDURE stage
(
   p_run_id         IN NUMBER,
   p_run_phase_id   IN NUMBER,
   p_control_id     IN NUMBER,
   p_stage_status   IN OUT BOOLEAN
)
IS
   CURSOR c_file IS
      SELECT ctl.control_id,
             ctl.file_name inbound_file,
             SUBSTR(file_name, 1, INSTR(file_name, '/', -1)) inbound_directory,
             REPLACE(file_name, 
                     SUBSTR(file_name, 1, INSTR(file_name, '/', -1)),
                     NULL) file_name
      FROM   xxfnd_interface_ctl ctl
      WHERE  ctl.control_id = p_control_id;

   r_file             c_file%ROWTYPE;
   l_status           VARCHAR2(1);
   l_record_count     NUMBER := 1;
   l_success_count    NUMBER := 0;
   l_error_count      NUMBER := 0;
   l_error_report     NUMBER;
   l_error_message    VARCHAR2(600);
   l_phase_status     VARCHAR2(30) := 'SUCCESS';
   l_in_file          INTEGER;
   l_record_id        NUMBER;
   r_error            xxfnd_int_run_phase_errors%ROWTYPE;
   reset_stage        BOOLEAN;
BEGIN
   g_control_status := z_stage;

   print_debug('start ' || z_stage);
   print_debug('run_id=' || p_run_id);
   print_debug('run_phase_id=' || p_run_phase_id);

   reset_stage := FALSE;

   OPEN c_file;
   FETCH c_file INTO r_file;
   IF c_file%FOUND THEN
      l_in_file := xxfnd_common_pkg.file_copy(p_file_from => r_file.inbound_file,
                                              p_file_to => z_staging_dir || '/' || r_file.file_name);

      print_debug('inbound_file=' || r_file.inbound_file);
      print_debug('inbound_directory=' || r_file.inbound_directory);
      print_debug('file_name=' || r_file.file_name);

      IF l_in_file = 1 THEN
         xxfnd_common_int_pkg.stage_xml_file(p_control_id,
                                             g_request_id,
                                             p_run_id,
                                             r_file.file_name,
                                             z_in,
                                             g_object_type,
                                             g_user_id,
                                             l_status,
                                             l_error_message,
                                             l_record_id);

         print_debug('stage_xml_file.p_status=' || l_status);
         print_debug('stage_xml_file.p_message=' || NVL(l_error_message, 'NULL'));

         IF l_status = 'E' THEN
            l_error_count := l_error_count + 1;
         ELSE
            l_in_file := xxfnd_common_pkg.file_delete(r_file.inbound_file);
            IF l_in_file = 0 THEN
               l_error_count := l_error_count + 1;
               l_error_message := 'File permission error';
            END IF;
         END IF;
      ELSE
         l_error_count := l_error_count + 1;
         l_error_message := 'File permission error';
      END IF;
   END IF;
   CLOSE c_file;

   -- errored record cannot be identified
   l_record_id := NVL(l_record_id, -1);

   IF l_error_count > 0 THEN
      l_phase_status := 'ERROR';
      g_control_status := 'ERROR';
      p_stage_status := FALSE;

      r_error.run_id := p_run_id;
      r_error.run_phase_id := p_run_phase_id;
      r_error.record_id := l_record_id;
      r_error.int_table_key_val1 := p_control_id;
      r_error.error_text := l_error_message;
      raise_error(r_error);
   ELSE
      IF NOT set_context(p_control_id, l_error_message) THEN
         l_error_count := l_error_count + 1;

         l_phase_status := 'ERROR';
         g_control_status := 'ERROR';
         p_stage_status := FALSE;

         r_error.run_id := p_run_id;
         r_error.run_phase_id := p_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.int_table_key_val1 := p_control_id;
         r_error.error_text := l_error_message;
         raise_error(r_error);

         reset_stage := TRUE;

         -- return file to source
         l_in_file := xxfnd_common_pkg.file_copy(p_file_from => z_staging_dir || '/' || r_file.file_name,
                                                 p_file_to => r_file.inbound_file);
      ELSE
         l_success_count := l_record_count;
      END IF;
   END IF;

   -- clean-up staging directory
   l_in_file := xxfnd_common_pkg.file_delete(z_staging_dir || '/' || r_file.file_name);

   print_debug('l_record_count=' || l_record_count);
   print_debug('l_success_count=' || l_success_count);
   print_debug('l_error_count=' || l_error_count);

   IF reset_stage THEN
      reset_stage_table(l_record_id);
   ELSE
      update_control_queue(l_error_message);
      update_stage_table(l_record_id, g_org_id, l_phase_status);
   END IF;

   print_debug('update run phase ' || z_stage);
   print_debug('end ' || z_stage);

   -- update run phase
   xxfnd_common_int_pkg.update_run_phase
      (p_run_phase_id => p_run_phase_id,
       p_src_code     => z_src_code,
       p_rec_count    => l_record_count,
       p_hash_total   => NULL,
       p_batch_name   => r_file.file_name);

   -- end run phase
   xxfnd_common_int_pkg.end_run_phase
      (p_run_phase_id => p_run_phase_id,
       p_status => l_phase_status,
       p_error_count => l_error_count,
       p_success_count => l_success_count);

   IF l_error_count > 0 THEN
      l_error_report := xxfnd_common_int_pkg.launch_error_report
                           (p_run_id => p_run_id,
                            p_run_phase_id => p_run_phase_id);

      l_error_message := 'Please review interface error report (' || l_error_report || ').';
      send_error_notification(l_error_message);
   END IF;

EXCEPTION
   WHEN others THEN
      l_error_message := 'Unhandled exception encountered during STAGE phase: ' || SQLERRM;
      l_error_count := l_record_count;
      l_record_id := l_record_id;
      l_phase_status := 'ERROR';
      g_control_status := 'ERROR';
      p_stage_status := FALSE;

      r_error.run_id := p_run_id;
      r_error.run_phase_id := p_run_phase_id;
      r_error.record_id := l_record_id;
      r_error.int_table_key_val1 := p_control_id;
      r_error.error_text := l_error_message;
      raise_error(r_error);

      update_control_queue(l_error_message);
      update_stage_table(l_record_id, NULL, l_phase_status);

      print_debug('exception ' || SQLERRM);
      print_debug('update run phase ' || z_stage);
      print_debug('end ' || z_stage);

      -- update run phase
      xxfnd_common_int_pkg.update_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_src_code     => z_src_code,
          p_rec_count    => l_record_count,
          p_hash_total   => NULL,
          p_batch_name   => r_file.file_name);

      -- end run phase
      xxfnd_common_int_pkg.end_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_status => l_phase_status,
          p_error_count => l_error_count,
          p_success_count => l_success_count);

      l_error_report := xxfnd_common_int_pkg.launch_error_report
                           (p_run_id => p_run_id,
                            p_run_phase_id => p_run_phase_id);

      l_error_message := 'Please review interface error report (' || l_error_report || ').';
      send_error_notification(l_error_message);

END stage;

------------------------------------------------------------
-- Procedure
--     TRANSFORM
-- Purpose
--     Interface Framework TRANSFORM phase. This is the
--     procedure that performs data transformation,
--     derivation and validation. Checks system parameters
--     and global variables for defaulting and processing
--     rules involved to successfully load Basware purchase
--     order transaction.
------------------------------------------------------------

PROCEDURE transform
(
   p_run_id            IN  NUMBER,
   p_run_phase_id      IN  NUMBER,
   p_control_id        IN  NUMBER,
   p_stage_status      IN  BOOLEAN,
   p_transform_status  IN  OUT BOOLEAN
)
IS
   CURSOR c_file IS
      SELECT ctl.control_id,
             REPLACE(file_name, 
                     SUBSTR(file_name, 1, INSTR(file_name, '/', -1)),
                     NULL) file_name
      FROM   xxfnd_interface_ctl ctl
      WHERE  ctl.control_id = p_control_id;

   CURSOR c_fkey IS
     SELECT order_number,
            line_number,
            distribution_num
     FROM   xxpo_po_interface_stg
     WHERE  control_id = p_control_id;

   CURSOR c_header IS
      SELECT h.control_id,
             h.file_name,
             h.order_number,
             h.order_type,
             h.status,
             h.supplier_id,
             h.supplier_code,
             h.supplier_name,
             h.creation_date,
             h.created_by,
             h.payment_term_code,
             h.payment_term_name,
             h.gross_sum,
             h.net_sum,
             h.owner,
             h.purpose,
             h.company_code,
             h.purchase_currency,
             h.desired_delivery_enddate
      FROM   xxpo_po_interface_stg h
      WHERE  h.control_id = p_control_id;

   CURSOR c_line IS
      SELECT l.line_number,
             l.note_to_vendor,
             l.promised_date,
             l.need_by_date,
             l.contract_num,
             l.note_to_receiver,
             l.item_description,
             l.rate,
             l.unit_of_measure,
             l.quantity,
             l.amount,
             l.tax_name,
             l.category_code,
             l.vendor_product_num,
             l.expiration_date,
             COUNT(1) distribution_count
      FROM   xxpo_po_interface_stg l
      WHERE  l.control_id = p_control_id
      GROUP  BY
             l.line_number,
             l.note_to_vendor,
             l.promised_date,
             l.need_by_date,
             l.contract_num,
             l.note_to_receiver,
             l.item_description,
             l.rate,
             l.unit_of_measure,
             l.quantity,
             l.amount,
             l.tax_name,
             l.category_code,
             l.vendor_product_num,
             l.expiration_date
      ORDER  BY 1;

   CURSOR c_distr (p_line_number VARCHAR2) IS
      SELECT d.line_number,
             d.distribution_num,
             d.split_percent,
             d.account_segment1,
             d.account_segment2,
             d.account_segment3,
             d.account_segment4,
             d.account_segment5,
             d.account_segment6,
             d.attribute1
      FROM   xxpo_po_interface_stg d
      WHERE  d.control_id = p_control_id
      AND    d.line_number = p_line_number
      ORDER  BY 2;

   r_file             c_file%ROWTYPE;
   r_header           c_header%ROWTYPE;
   r_line             c_line%ROWTYPE;
   r_distr            c_distr%ROWTYPE;
   l_run_id           NUMBER := p_run_id;
   l_run_phase_id     NUMBER := p_run_phase_id;
   l_record_id        NUMBER;
   l_record_id_cur    NUMBER;
   l_vendor_id        NUMBER;
   l_vendor_site_id   NUMBER;
   l_supplier_id      NUMBER;
   l_agent_id         NUMBER;
   l_buyer_user_id    NUMBER;
   l_ship_to_loc_id   NUMBER;
   l_bill_to_loc_id   NUMBER;
   l_inv_org_id       NUMBER;
   l_po_date          DATE;
   l_amount           NUMBER;
   l_record_count     NUMBER := 0;
   l_success_count    NUMBER := 0;
   l_error_count      NUMBER := 0;
   l_error            NUMBER := 0;
   l_error_text       VARCHAR2(600);
   l_order_line       NUMBER := 0;
   l_order_distr      NUMBER := 0;
   l_order_number     VARCHAR2(60);
   l_company_code     VARCHAR2(25);
   l_charge_account   VARCHAR2(240);
   l_key_val          NUMBER;
   l_percent          NUMBER;
   l_split_percent    NUMBER;
   l_error_report     NUMBER;
   l_error_message    VARCHAR2(600);
   l_phase_status     VARCHAR2(30) := 'SUCCESS';

   r_tfm              xxpo_po_interface_tfm%ROWTYPE;
   r_error            xxfnd_int_run_phase_errors%ROWTYPE;
   e_transform_error  EXCEPTION;

   ------------- Subprogram Declaration -------------

   /* get_record_id */
   FUNCTION get_record_id
   RETURN NUMBER
   IS
      l_record_id  NUMBER;
   BEGIN
      SELECT xxpo_po_interface_tfm_s.nextval
      INTO   l_record_id
      FROM   dual;
      RETURN l_record_id;
   END get_record_id;

   /* get_agent_id */
   FUNCTION get_agent_id
   (
      p_buyer      VARCHAR2,
      p_key_val1   VARCHAR2
   )
   RETURN NUMBER
   IS
      l_agent_id     NUMBER;
   BEGIN
      SELECT employee_id
      INTO   l_agent_id
      FROM   po_buyers_v
      WHERE  full_name = p_buyer;

      RETURN l_agent_id;
   EXCEPTION
      WHEN others THEN
         l_error_text := 'Unable to get employee id for this buyer ' || p_buyer;
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.error_token_val1 := p_buyer;
         r_error.int_table_key_val1 := p_key_val1;
         r_error.error_text := l_error_text;
         raise_error(r_error);
         RETURN NULL;
   END get_agent_id;

   /* validate_doc_num */
   FUNCTION validate_doc_num
   (
      p_doc_num   VARCHAR2,
      p_key_val1  VARCHAR2
   )
   RETURN VARCHAR2
   IS
      l_doc_num     po_headers_interface.document_num%TYPE;
      l_doc_count   NUMBER;
   BEGIN
      l_doc_num := SUBSTR(p_doc_num, 1, 20);

      SELECT COUNT(1)
      INTO   l_doc_count
      FROM   po_headers_all
      WHERE  type_lookup_code = z_document_type
      AND    segment1 = l_doc_num
      AND    org_id = g_org_id;

      IF l_doc_count > 0 THEN
         l_error_text := 'Document number ' || l_doc_num || ' already exists';
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.error_token_val1 := p_doc_num;
         r_error.int_table_key_val1 := p_key_val1;
         r_error.error_text := l_error_text;
         raise_error(r_error);
      END IF;

      RETURN l_doc_num;      
   END validate_doc_num;

   /* get_supplier */
   FUNCTION get_supplier 
   (
      p_supplier_id_in   IN  VARCHAR2,
      p_supplier_id_out  OUT NUMBER,
      p_key_val1         IN  VARCHAR2
   )
   RETURN NUMBER
   IS
      l_vendor_id_out       NUMBER;
      l_vendor_site_id_out  NUMBER;
   BEGIN
      FOR si IN (SELECT si.vendor_id,
                        si.vendor_site_id,
                        su.vendor_name || ' [' || si.vendor_site_code || ']' supplier_name,
                        si.inactive_date,
                        su.end_date_active
                 FROM   ap_supplier_sites si,
                        ap_suppliers su
                 WHERE  si.vendor_site_id = TO_NUMBER(p_supplier_id_in)
                 AND    si.vendor_id = su.vendor_id)
      LOOP
         l_vendor_id_out := si.vendor_id;
         l_vendor_site_id_out := si.vendor_site_id;

         IF (NVL(si.inactive_date, SYSDATE + 1) <= SYSDATE) OR
            (NVL(si.end_date_active, SYSDATE + 1) <= SYSDATE) THEN
            l_error_text := 'Supplier ' || si.supplier_name || ' is not active';
         END IF;
      END LOOP;

      IF l_vendor_id_out IS NULL THEN
         l_error_text := 'Supplier ID ' || LTRIM(p_supplier_id_in || ' ')  || 'is not valid';
      END IF;

      IF l_error_text IS NOT NULL THEN
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.error_token_val1 := p_supplier_id_in;
         r_error.int_table_key_val1 := p_key_val1;
         r_error.error_text := l_error_text;
         raise_error(r_error);
         RETURN NULL;
      END IF;

      p_supplier_id_out := l_vendor_id_out;
      RETURN l_vendor_site_id_out;

   END get_supplier;

   /* get_currency_code */
   FUNCTION get_currency_code
   (
      p_currency_code  VARCHAR2,
      p_key_val1       VARCHAR2
   )
   RETURN VARCHAR2
   IS
      l_currency_code  fnd_currencies.currency_code%TYPE;
   BEGIN
      SELECT currency_code
      INTO   l_currency_code
      FROM   fnd_currencies
      WHERE  currency_code = p_currency_code
      AND    enabled_flag = 'Y'
      AND    currency_flag = 'Y'
      AND    TRUNC(SYSDATE) BETWEEN NVL(start_date_active, SYSDATE - 1) 
                            AND     NVL(end_date_active, SYSDATE + 1);
      RETURN l_currency_code;
   EXCEPTION
      WHEN others THEN
         l_error_text := p_currency_code || ' is not valid currency code (' || SQLERRM || ')';
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.error_token_val1 := p_currency_code;
         r_error.int_table_key_val1 := p_key_val1;
         r_error.error_text := l_error_text;
         raise_error(r_error);
         RETURN p_currency_code;
   END get_currency_code;

   /* get_ap_terms */
   FUNCTION get_ap_terms
   (
      p_term_code   VARCHAR2,
      p_key_val1    VARCHAR2
   )
   RETURN VARCHAR2
   IS
      l_term_name    ap_terms.name%TYPE;
   BEGIN
      SELECT apt.name
      INTO   l_term_name
      FROM   fnd_lookup_values flv,
             ap_terms_tl apt
      WHERE  flv.lookup_type = 'XX_BASWARE_PAYMENT_TERMS'
      AND    flv.description = apt.name(+)
      AND    flv.lookup_code = p_term_code
      AND    NVL(flv.enabled_flag, 'N') = 'Y'
      AND    (TRUNC(SYSDATE) BETWEEN TRUNC(NVL(flv.start_date_active, SYSDATE -1)) 
                             AND     TRUNC(NVL(flv.end_date_active, SYSDATE + 1)))
      AND    NVL(apt.enabled_flag, 'N') = 'Y'
      AND    (TRUNC(SYSDATE) BETWEEN TRUNC(NVL(apt.start_date_active, SYSDATE -1)) 
                             AND     TRUNC(NVL(apt.end_date_active, SYSDATE + 1)));

      /* 
      -- arellanod 30/05/2018 
      -- use lookup mapping to translate term name
      SELECT name
      INTO   l_term_name
      FROM   ap_terms
      WHERE  name = p_term_name;
      */

      RETURN l_term_name;
   EXCEPTION
      WHEN others THEN
         l_error_text := 'Payment Term ' || p_term_code || ' is not found (' || SQLERRM || ')';
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.error_token_val1 := p_term_code;
         r_error.int_table_key_val1 := p_key_val1;
         r_error.error_text := l_error_text;
         raise_error(r_error);
         RETURN p_term_code;
   END get_ap_terms;

   /* convert_to_date */
   FUNCTION convert_to_date
   (
      p_string_name    IN VARCHAR2, 
      p_string_value   IN VARCHAR2,
      p_key_val1       IN VARCHAR2,
      p_key_val2       IN VARCHAR2 DEFAULT NULL,
      p_key_val3       IN VARCHAR2 DEFAULT NULL
   )
   RETURN DATE
   IS
      l_date_value   DATE;
   BEGIN
      l_date_value := TO_DATE(REPLACE(SUBSTR(p_string_value, 1, 19), 'T', ' '), 'YYYY-MM-DD HH24:MI:SS');
      RETURN l_date_value;
   EXCEPTION
      WHEN others THEN
         l_error_text := 'Unable to convert ' || p_string_name || ': ' || p_string_value ||
                         ' to DATE datatype (' || SQLERRM || ')';
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.error_token_val1 := p_string_name; 
         r_error.error_token_val2 := p_string_value; 
         r_error.int_table_key_val1 := p_key_val1;
         r_error.int_table_key_val2 := p_key_val2;
         r_error.int_table_key_val3 := p_key_val3;
         r_error.error_text := l_error_text;
         raise_error(r_error);
         RETURN NULL;
   END convert_to_date;

   /* convert_to_number */
   FUNCTION convert_to_number
   (
      p_string_name    IN VARCHAR2, 
      p_string_value   IN VARCHAR2,
      p_key_val1       IN VARCHAR2,
      p_key_val2       IN VARCHAR2 DEFAULT NULL,
      p_key_val3       IN VARCHAR2 DEFAULT NULL
   )
   RETURN NUMBER
   IS
      l_number_value   NUMBER;
   BEGIN
      l_number_value := TO_NUMBER(p_string_value);
      RETURN l_number_value;
   EXCEPTION
      WHEN others THEN
         l_error_text := 'Unable to convert ' || p_string_name || ': ' || p_string_value ||
                         ' to NUMBER datatype (' || SQLERRM || ')';
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.error_token_val1 := p_string_name; 
         r_error.error_token_val2 := p_string_value; 
         r_error.int_table_key_val1 := p_key_val1;
         r_error.int_table_key_val2 := p_key_val2;
         r_error.int_table_key_val3 := p_key_val3;
         r_error.error_text := l_error_text;
         raise_error(r_error);
         RETURN NULL;
   END convert_to_number;

   /* assign_location */ 
   /* select the most commonly used as default */
   PROCEDURE assign_location
   (
      p_ship_to     OUT NUMBER,
      p_bill_to     OUT NUMBER,
      p_inv_org_id  OUT NUMBER,
      p_key_val1    IN  VARCHAR2
   )
   IS
   BEGIN
      SELECT ship_to_location_id,
             bill_to_location_id,
             inventory_organization_id
      INTO   p_ship_to,
             p_bill_to,
             p_inv_org_id
      FROM   financials_system_parameters;
   EXCEPTION
      WHEN no_data_found THEN
         l_error_text := 'Unable to assign default SHIP TO and BILL TO locations';
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.int_table_key_val1 := p_key_val1;
         r_error.error_text := l_error_text;
         raise_error(r_error);
   END assign_location;

   /* get_user */
   FUNCTION get_user
   (
      p_employee_id  NUMBER,
      p_key_val1     VARCHAR2
   )
   RETURN NUMBER
   IS
      l_user_id     NUMBER;
   BEGIN
      SELECT user_id
      INTO   l_user_id
      FROM   fnd_user
      WHERE  employee_id = p_employee_id
      AND    NVL(end_date, SYSDATE + 1) > SYSDATE;

      RETURN l_user_id;
   EXCEPTION
      WHEN too_many_rows THEN
         l_error_text := 'Employee ' || g_buyer || ' has more than one user assignment (' || SQLERRM || ')';
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.error_token_val1 := TO_CHAR(p_employee_id); 
         r_error.int_table_key_val1 := p_key_val1;
         r_error.error_text := l_error_text;
         raise_error(r_error);
         RETURN NULL;
      WHEN others THEN
         l_error_text := 'Unable to associate Buyer ' || g_buyer || ' to a system user (' || SQLERRM || ')';
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.int_table_key_val1 := p_key_val1;
         r_error.error_text := l_error_text;
         raise_error(r_error);
         RETURN NULL;
   END get_user;

   /* get_uom_code */
   FUNCTION get_uom_code
   (
      p_uom  VARCHAR2
   )
   RETURN VARCHAR2
   IS
      l_uom_code  po_units_of_measure_val_v.uom_code%TYPE;
   BEGIN
      SELECT uom_code
      INTO   l_uom_code
      FROM   po_units_of_measure_val_v
      WHERE  unit_of_measure = p_uom;

      RETURN l_uom_code;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN 'EA'; -- defaulting rule
   END get_uom_code;

   /* calculate_unit_price */
   FUNCTION calculate_unit_price
   (
      p_quantity      NUMBER,
      p_amount        NUMBER,
      p_key_val1      VARCHAR2,
      p_key_val2      VARCHAR2
   )
   RETURN NUMBER
   IS
      l_unit_price   NUMBER;
   BEGIN
      l_unit_price := ROUND(NVL(p_amount, 0) / NVL(p_quantity, 0), 4);
      RETURN l_unit_price;
   EXCEPTION
      WHEN others THEN
         l_error_text := 'Error calculating unit price of PO line (' || SQLERRM || ')';
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.error_token_val1 := TO_CHAR(p_quantity); 
         r_error.error_token_val2 := TO_CHAR(p_amount); 
         r_error.int_table_key_val1 := p_key_val1;
         r_error.int_table_key_val2 := p_key_val2;
         r_error.error_text := l_error_text;
         raise_error(r_error);
         RETURN NULL;
   END calculate_unit_price;

   /* get_tax_rate_id */
   FUNCTION get_tax_name
   (
      p_tax_code        VARCHAR2,
      p_vendor_site_id  NUMBER,
      p_key_val1        VARCHAR2,
      p_key_val2        VARCHAR2
   )
   RETURN VARCHAR2
   IS
      CURSOR c_tax IS
         SELECT zx.tax_rate_name,
                flv.tag basware_tax_code,
                zx.org_id
         FROM   fnd_lookup_values flv,
                (
                SELECT zt.tax_rate_id,
                       ou.organization_id org_id,
                       ou.name operating_unit,
                       zt.tax_rate_name,
                       zt.tax_jurisdiction_code,
                       zt.rate_type_code,
                       zt.percentage_rate,
                       zt.effective_from,
                       zt.effective_to
                FROM   zx_rates_vl zt,
                       zx_accounts za,
                       hr_operating_units ou
                WHERE  zt.tax_rate_id = za.tax_account_entity_id
                AND    zt.active_flag = 'Y'
                AND    zt.tax_rate_code = zt.tax_rate_name
                AND    za.tax_account_entity_code = 'RATES'
                AND    (TRUNC(SYSDATE) BETWEEN TRUNC(NVL(zt.effective_from, SYSDATE - 1))
                                       AND     TRUNC(NVL(zt.effective_to, SYSDATE + 1)))
                AND    za.internal_organization_id = ou.organization_id
                AND    ou.organization_id = g_org_id
                ) zx
         WHERE  flv.lookup_type = 'XX_BASWARE_TAX_MAPPING'
         AND    flv.lookup_code = zx.tax_rate_name(+)
         AND    TO_NUMBER(flv.description) = zx.org_id(+)
         AND    flv.tag = p_tax_code
         AND    TO_NUMBER(flv.description) = g_org_id
         AND    NVL(flv.enabled_flag, 'N') = 'Y';

      r_tax          c_tax%ROWTYPE;
      l_tax_name     zx_rates_vl.tax_rate_name%TYPE;
   BEGIN
      print_debug('tax_code=' || p_tax_code);
      print_debug('vendor_site_id=' || p_vendor_site_id);

      OPEN c_tax;
      FETCH c_tax INTO r_tax;
      IF c_tax%FOUND THEN
         l_tax_name := r_tax.tax_rate_name;

         IF l_tax_name IS NULL THEN
            l_error_text := 'Tax code ' || p_tax_code || ' is not mapped or Basware Tax mapping not matched with EBS Tax';
            l_error := l_error + 1;
            r_error := NULL;
            r_error.run_id := l_run_id;
            r_error.run_phase_id := l_run_phase_id;
            r_error.record_id := l_record_id;
            r_error.error_token_val1 := p_tax_code; 
            r_error.int_table_key_val1 := p_key_val1;
            r_error.int_table_key_val2 := p_key_val2;
            r_error.error_text := l_error_text;
            raise_error(r_error);
         END IF;
      ELSE
         BEGIN
            SELECT vat_code
            INTO   l_tax_name
            FROM   ap_supplier_sites_all si
            WHERE  si.vendor_site_id = p_vendor_site_id;
         EXCEPTION
            WHEN no_data_found THEN
               l_error_text := 'Derive tax code from supplier site failed';
               l_error := l_error + 1;
               r_error := NULL;
               r_error.run_id := l_run_id;
               r_error.run_phase_id := l_run_phase_id;
               r_error.record_id := l_record_id;
               r_error.int_table_key_val1 := p_key_val1;
               r_error.int_table_key_val2 := p_key_val2;
               r_error.error_text := l_error_text;
               raise_error(r_error);
         END;
      END IF;
      CLOSE c_tax;

      RETURN l_tax_name;
   END get_tax_name;

   /* get_ccid */
   FUNCTION get_ccid
   (
      p_concat_segs  VARCHAR2,
      p_key_val1     VARCHAR2,
      p_key_val2     VARCHAR2,
      p_key_val3     VARCHAR2
   )
   RETURN NUMBER
   IS
      l_ccid  NUMBER;
   BEGIN
      l_ccid := fnd_flex_ext.get_ccid(application_short_name => 'SQLGL',
                                      key_flex_code => 'GL#',
                                      structure_number => g_coa_id,
                                      validation_date => NULL,
                                      concatenated_segments => p_concat_segs);
      IF NVL(l_ccid, 0) = 0 THEN
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.error_token_val1 := p_concat_segs;
         r_error.int_table_key_val1 := p_key_val1;
         r_error.int_table_key_val2 := p_key_val2;
         r_error.int_table_key_val3 := p_key_val3;
         r_error.error_text := fnd_flex_ext.get_message;
         raise_error(r_error);
      END IF;
      RETURN l_ccid;
   END get_ccid;

   /* validate_capex_code */
   FUNCTION validate_capex_code
   (
      p_capex_code   VARCHAR2,
      p_key_val1     VARCHAR2,
      p_key_val2     VARCHAR2,
      p_key_val3     VARCHAR2
   )
   RETURN VARCHAR2
   IS
      l_capex_code       fnd_flex_values_vl.flex_value%TYPE;
      l_enabled_flag     fnd_flex_values_vl.enabled_flag%TYPE;
      l_end_date_active  fnd_flex_values_vl.end_date_active%TYPE;
   BEGIN
      l_error_text := NULL;

      IF p_capex_code IS NOT NULL THEN
         SELECT flex_value,
                enabled_flag,
                end_date_active
         INTO   l_capex_code,
                l_enabled_flag,
                l_end_date_active
         FROM   fnd_flex_values_vl fv,
                fnd_flex_value_sets fs
         WHERE  fv.flex_value = SUBSTR(p_capex_code, 1, 150)
         AND    fv.flex_value_set_id = fs.flex_value_set_id
         AND    fs.flex_value_set_name = 'XXNZCL_CAPEX_CODE';

         IF TRUNC(NVL(l_end_date_active, SYSDATE + 1)) <= TRUNC(SYSDATE) THEN
            l_error_text := 'CAPEX DFF ' || p_capex_code || ' has been end dated';
         ELSIF NVL(l_enabled_flag, 'N') = 'N' THEN
            l_error_text := 'CAPEX DFF ' || p_capex_code || ' has been disabled';
         END IF;
      END IF;

      IF l_error_text IS NOT NULL THEN
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.error_token_val1 := p_capex_code;
         r_error.int_table_key_val1 := p_key_val1;
         r_error.int_table_key_val2 := p_key_val2;
         r_error.int_table_key_val3 := p_key_val3;
         r_error.error_text := l_error_text;
         raise_error(r_error);
      END IF;

      RETURN l_capex_code;
   EXCEPTION
      WHEN no_data_found THEN
         l_error_text := 'CAPEX DFF value ' || p_capex_code || ' is not found';
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.error_token_val1 := p_capex_code;
         r_error.int_table_key_val1 := p_key_val1;
         r_error.int_table_key_val2 := p_key_val2;
         r_error.int_table_key_val3 := p_key_val3;
         r_error.error_text := l_error_text;
         raise_error(r_error);
         RETURN NULL;
   END validate_capex_code;

   /* get_category_id */
   FUNCTION get_category_id
   (
      p_category_code  VARCHAR2,
      p_key_val1       VARCHAR2,
      p_key_val2       VARCHAR2
   )
   RETURN NUMBER
   IS
      l_category_id   NUMBER;
   BEGIN
      IF p_category_code IS NOT NULL THEN
         SELECT mcat.category_id
         INTO   l_category_id
         FROM   fnd_id_flex_structures_vl fifs,
                mtl_categories_b mcat
         WHERE  fifs.id_flex_structure_code = 'ITEM_CATEGORIES'
         AND    fifs.id_flex_code = 'MCAT'
         AND    fifs.id_flex_num = mcat.structure_id
         AND    mcat.enabled_flag = 'Y'
         AND    EXISTS (SELECT 1
                        FROM   fnd_lookup_values_vl flv
                        WHERE  flv.lookup_type = 'XX_BASWARE_CATEGORY_MAPPING'
                        AND    flv.lookup_code = p_category_code
                        AND    flv.enabled_flag = 'Y'
                        AND    NVL(flv.end_date_active, SYSDATE + 1) > TRUNC(SYSDATE)
                        AND    flv.description = (mcat.segment1 || '.' || mcat.segment2));
      END IF;
      RETURN l_category_id;
   EXCEPTION
      WHEN no_data_found THEN
         l_error_text := 'Category Code ' || p_category_code || ' lookup error. Please check if value from Basware Category Mapping is active and enabled.';
         l_error := l_error + 1;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := l_record_id;
         r_error.error_token_val1 := p_category_code;
         r_error.int_table_key_val1 := p_key_val1;
         r_error.int_table_key_val2 := p_key_val2;
         r_error.error_text := l_error_text;
         raise_error(r_error);
         RETURN NULL;
   END get_category_id;

   ------------- Subprogram Declaration -------------

BEGIN
   print_debug('start ' || z_transform);
   print_debug('run_id=' || l_run_id);
   print_debug('run_phase_id=' || l_run_phase_id);

   purge_transform_table;

   OPEN c_file;
   FETCH c_file INTO r_file;
   CLOSE c_file;

   IF p_stage_status THEN
      g_control_status := z_transform;

      print_debug('validating order header, line and distribution ids');

      FOR r_fkey IN c_fkey LOOP
         l_record_id := -1;
         IF r_fkey.order_number IS NULL THEN
            l_error_text := 'Document number reference error (OrderNumber is null)';
            l_error := l_error + 1;
            r_error := NULL;
            r_error.run_id := l_run_id;
            r_error.run_phase_id := l_run_phase_id;
            r_error.record_id := l_record_id;
            r_error.int_table_key_val1 := 'NULL';
            r_error.error_text := l_error_text;
            raise_error(r_error);
         END IF;

         l_key_val := convert_to_number('LineNumber', r_fkey.line_number, r_fkey.order_number);
         l_key_val := convert_to_number('RowIndex', r_fkey.distribution_num, r_fkey.order_number);
      END LOOP;

      print_debug('reference key check completed');

      IF count_errors(l_run_id, l_run_phase_id, l_record_id) > 0 THEN
         l_record_count := 1;
         l_error_count := 1;
         GOTO close_transform;
      END IF;

      print_debug('transform header record');

      OPEN c_header;
      FETCH c_header INTO r_header;
      IF c_header%FOUND THEN
         r_tfm := NULL;
         l_record_id := get_record_id;
         l_order_number := r_header.order_number;
         g_order_number := l_order_number;

         -- get rate from first line
         OPEN c_line;
         FETCH c_line INTO r_line;
         IF c_line%FOUND THEN 
            l_order_line := 1;
         ELSE
            l_error_text := 'Cannot create PO without order lines';
            l_error := l_error + 1;
            r_error := NULL;
            r_error.run_id := l_run_id;
            r_error.run_phase_id := l_run_phase_id;
            r_error.record_id := l_record_id;
            r_error.int_table_key_val1 := l_order_number;
            r_error.error_text := l_error_text;
            raise_error(r_error);
         END IF;
         CLOSE c_line;

         r_tfm.run_id := l_run_id;
         r_tfm.run_phase_id := l_run_phase_id;
         r_tfm.record_id := l_record_id;
         r_tfm.record_type := z_header_rec_type;

         l_agent_id := get_agent_id(g_buyer, l_order_number);
         l_buyer_user_id := get_user(l_agent_id, l_order_number);
         l_supplier_id := convert_to_number('SupplierCode', r_header.supplier_code, l_order_number);
         l_vendor_site_id := get_supplier(l_supplier_id, l_vendor_id, l_order_number);
         l_company_code := r_header.company_code;
         l_po_date := convert_to_date('CreationTime', r_header.creation_date, l_order_number);

         assign_location(l_ship_to_loc_id, l_bill_to_loc_id, l_inv_org_id, l_order_number);

         r_tfm.process_code := 'PENDING';
         r_tfm.action := 'ORIGINAL';
         r_tfm.org_id := g_org_id;
         r_tfm.document_type_code := z_document_type;
         r_tfm.document_num := validate_doc_num(r_header.order_number, l_order_number);
         r_tfm.currency_code := get_currency_code(r_header.purchase_currency, l_order_number);
         r_tfm.buyer := g_buyer;
         r_tfm.agent_id := l_agent_id;
         r_tfm.vendor_id := l_vendor_id;
         r_tfm.vendor_site_id := l_vendor_site_id;
         r_tfm.payment_terms := get_ap_terms(r_header.payment_term_code, l_order_number);
         r_tfm.approval_status := z_pdoi_status;
         r_tfm.comments := SUBSTR(r_header.purpose, 1, 240);
         r_tfm.creation_date := l_po_date;
         r_tfm.created_by := l_buyer_user_id;
         r_tfm.last_updated_by := l_buyer_user_id;
         r_tfm.last_update_date := l_po_date;
         r_tfm.expiration_date := convert_to_date('DesiredDeliveryEndDate', r_header.desired_delivery_enddate, l_order_number);
         r_tfm.amount_agreed := convert_to_number('NetSum', r_header.net_sum, l_order_number);
         r_tfm.ship_to_location_id := l_ship_to_loc_id;
         r_tfm.bill_to_location_id := l_bill_to_loc_id;

         -- Conversion Rate
         IF r_header.purchase_currency <> g_base_currency THEN
            r_tfm.rate_type := 'User';
            r_tfm.rate_date := convert_to_date('CreationTime', r_header.creation_date, l_order_number);
            r_tfm.rate := convert_to_number('ExchangeRateComp', r_line.rate, l_order_number);
         END IF;

         l_record_count := l_record_count + 1;

         IF count_errors(l_run_id, l_run_phase_id, l_record_id) > 0 THEN
            l_error_count := l_error_count + 1;
            r_tfm.transform_status := 'ERROR';
         ELSE
            l_success_count := l_success_count + 1;
            r_tfm.transform_status := 'SUCCESS';
         END IF;

         -- create header record
         INSERT INTO xxpo_po_interface_tfm
         VALUES r_tfm;

      END IF;
      CLOSE c_header;

      -- close transform process
      IF l_order_line = 0 OR l_record_count = 0 THEN
         GOTO close_transform;
      END IF;

      print_debug('transform line record(s)');

      OPEN c_line;
      LOOP
         FETCH c_line INTO r_line;
         EXIT WHEN c_line%NOTFOUND;

         r_tfm := NULL;
         l_order_distr := 0;
         l_percent := 0;
         l_record_id := get_record_id;
         l_record_id_cur := l_record_id;

         print_debug('order line ' || r_line.line_number);

         r_tfm.run_id := l_run_id;
         r_tfm.run_phase_id := l_run_phase_id;
         r_tfm.record_id := l_record_id;
         r_tfm.record_type := z_line_rec_type;
         r_tfm.line_action := 'NEW';
         r_tfm.line_num := TO_NUMBER(r_line.line_number);
         r_tfm.shipment_num := 1;
         r_tfm.line_type := 'Goods';
         r_tfm.line_type_id := NULL;
         r_tfm.category := NULL;
         r_tfm.category_id := get_category_id(r_line.category_code, l_order_number, r_line.line_number);
         r_tfm.item_description := SUBSTR(r_line.item_description, 1, 240);
         r_tfm.vendor_product_num := SUBSTR(r_line.vendor_product_num, 1, 25);
         r_tfm.uom_code := get_uom_code(r_line.unit_of_measure);
         r_tfm.unit_of_measure := NULL;
         r_tfm.quantity := convert_to_number('Quantity', r_line.quantity, l_order_number, r_line.line_number);
         l_amount := convert_to_number('NetSum', r_line.amount, l_order_number, r_line.line_number);

         --PO_SVC_NO_AMT: 
         --Error: Amount is only allowed on lines with a value basis of Rate or Fixed Price.
         --Fix: Populate unit_price instead of amount
         --r_tfm.amount := convert_to_number('GrossSum', r_line.amount, l_order_number, r_line.line_number);
         IF NVL(l_amount, 0) > 0 THEN
            r_tfm.unit_price := calculate_unit_price(r_tfm.quantity, l_amount, l_order_number, r_line.line_number);
         END IF;

         r_tfm.allow_price_override_flag := NULL;
         r_tfm.note_to_vendor := SUBSTR(r_line.note_to_vendor, 1, 480);
         r_tfm.tax_name := get_tax_name(r_line.tax_name, l_vendor_site_id, l_order_number, r_line.line_number);
         r_tfm.need_by_date := convert_to_date('DesiredDeliveryDate', r_line.need_by_date, l_order_number, r_line.line_number);
         r_tfm.promised_date := convert_to_date('PromisedDeliveryDate', r_line.promised_date, l_order_number, r_line.line_number);
         r_tfm.expiration_date := convert_to_date('DesiredDeliveryEndDate', r_line.expiration_date, l_order_number, r_line.line_number);
         r_tfm.note_to_receiver := SUBSTR(r_line.note_to_receiver, 1, 480);
         r_tfm.org_id := g_org_id;
         r_tfm.creation_date := l_po_date;
         r_tfm.created_by := l_buyer_user_id;
         r_tfm.last_updated_by := l_buyer_user_id;
         r_tfm.last_update_date := l_po_date;

         IF r_line.tax_name IS NOT NULL THEN
            r_tfm.taxable_flag := 'Y';
         END IF;

         l_record_count := l_record_count + 1;

         IF count_errors(l_run_id, l_run_phase_id, l_record_id) > 0 THEN
            l_error_count := l_error_count + 1;
            r_tfm.transform_status := 'ERROR';
         ELSE
            l_success_count := l_success_count + 1;
            r_tfm.transform_status := 'SUCCESS';
         END IF;

         -- create line record
         INSERT INTO xxpo_po_interface_tfm
         VALUES r_tfm;

         print_debug('transform distribution record(s)');

         OPEN c_distr (r_line.line_number);
         LOOP
            FETCH c_distr INTO r_distr;
            EXIT WHEN c_distr%NOTFOUND;

            print_debug('order distribution ' || r_distr.line_number || '.' || r_distr.distribution_num);

            r_tfm := NULL;
            l_order_distr := l_order_distr + 1;
            l_record_id := get_record_id;

            r_tfm.run_id := l_run_id;
            r_tfm.run_phase_id := l_run_phase_id;
            r_tfm.record_id := l_record_id;
            r_tfm.record_type := z_distr_rec_type;
            r_tfm.line_num := TO_NUMBER(r_distr.line_number);
            r_tfm.distribution_num := TO_NUMBER(r_distr.distribution_num);
            r_tfm.attribute1 := validate_capex_code(r_distr.attribute1, l_order_number, r_distr.line_number, r_distr.distribution_num);
            r_tfm.deliver_to_location_id := NULL;

            --PO_PDOI_INVALID_DEST_ORG
            --Error: Destination Organization (Value = ??) is not a valid organization.
            --r_tfm.destination_organization_id := l_inv_org_id;

            l_split_percent := convert_to_number('SplitPercent', r_distr.split_percent, l_order_number, r_distr.line_number, r_distr.distribution_num); 
            l_percent := l_percent + NVL(l_split_percent, 0);

            IF NVL(l_split_percent, 0) > 0 THEN 
               r_tfm.quantity_ordered := ROUND(r_line.quantity * (l_split_percent / 100), 4);
            END IF;

            r_tfm.charge_account_segment1 := l_company_code;
            r_tfm.charge_account_segment2 := r_distr.account_segment2;
            r_tfm.charge_account_segment3 := r_distr.account_segment3;
            r_tfm.charge_account_segment4 := r_distr.account_segment4;
            r_tfm.charge_account_segment5 := r_distr.account_segment5;
            r_tfm.charge_account_segment6 := r_distr.account_segment6;

            l_charge_account := l_company_code || z_delimiter ||
                                r_distr.account_segment2 || z_delimiter ||
                                r_distr.account_segment3 || z_delimiter ||
                                r_distr.account_segment4 || z_delimiter ||
                                r_distr.account_segment5 || z_delimiter ||
                                r_distr.account_segment6;

            r_tfm.charge_account_id := get_ccid(l_charge_account, l_order_number, r_distr.line_number, r_distr.distribution_num);

            r_tfm.org_id := g_org_id;
            r_tfm.set_of_books_id := g_set_of_books_id;
            r_tfm.creation_date := l_po_date;
            r_tfm.created_by := l_buyer_user_id;
            r_tfm.last_updated_by := l_buyer_user_id;
            r_tfm.last_update_date := l_po_date;

            l_record_count := l_record_count + 1;

            IF count_errors(l_run_id, l_run_phase_id, l_record_id) > 0 THEN
               l_error_count := l_error_count + 1;
               r_tfm.transform_status := 'ERROR';
            ELSE
               l_success_count := l_success_count + 1;
               r_tfm.transform_status := 'SUCCESS';
            END IF;

            -- create distribution record
            INSERT INTO xxpo_po_interface_tfm
            VALUES r_tfm;

         END LOOP;
         CLOSE c_distr;

         IF l_order_distr = 0 THEN
            l_error_text := 'Cannot create PO without distribution lines';
            l_error := l_error + 1;
            r_error := NULL;
            r_error.run_id := l_run_id;
            r_error.run_phase_id := l_run_phase_id;
            r_error.record_id := l_record_id;
            r_error.int_table_key_val1 := l_order_number;
            r_error.int_table_key_val2 := r_line.line_number;
            r_error.error_text := l_error_text;
            raise_error(r_error);
         END IF;

         IF ROUND(l_percent) <> 100 THEN
            l_error_text := 'Percent split total is not 100%';
            l_error := l_error + 1;
            r_error := NULL;
            r_error.run_id := l_run_id;
            r_error.run_phase_id := l_run_phase_id;
            r_error.record_id := l_record_id_cur;
            r_error.int_table_key_val1 := l_order_number;
            r_error.int_table_key_val2 := r_line.line_number;
            r_error.error_text := l_error_text;
            raise_error(r_error);
         END IF;

      END LOOP;
      CLOSE c_line;

      IF l_record_count > 0 THEN
         IF l_error = 0 THEN
            -- create document reference
            INSERT INTO xxpo_document_references
            VALUES (NULL,
                    g_order_number,
                    g_org_id,
                    z_src_code,
                    r_file.file_name,
                    NULL,
                    NULL,
                    g_user_id,
                    SYSDATE);
         END IF;
         COMMIT;
      END IF;
   ELSE
      l_phase_status := 'ERROR';
      g_control_status := 'ERROR';
      p_transform_status := FALSE;
   END IF;

   <<close_transform>>

   IF l_error > 0 THEN
      l_phase_status := 'ERROR';
      g_control_status := 'ERROR';
      p_transform_status := FALSE;

      l_error_report := xxfnd_common_int_pkg.launch_error_report
                           (p_run_id => l_run_id,
                            p_run_phase_id => l_run_phase_id);

      l_error_message := z_error || z_nl || 'Please review interface error report (' || l_error_report || ').';
      send_error_notification(l_error_message);
   END IF;

   -- update control queue
   update_control_queue(NULL);

   print_debug('update run phase ' || z_transform);
   print_debug('end ' || z_transform);

   -- update run phase
   xxfnd_common_int_pkg.update_run_phase
      (p_run_phase_id => l_run_phase_id,
       p_src_code     => z_src_code,
       p_rec_count    => l_record_count,
       p_hash_total   => NULL,
       p_batch_name   => r_file.file_name);

   -- end run phase
   xxfnd_common_int_pkg.end_run_phase
      (p_run_phase_id => l_run_phase_id,
       p_status => l_phase_status,
       p_error_count => l_error_count,
       p_success_count => l_success_count);

EXCEPTION
   WHEN others THEN
      l_error_message := 'Unhandled exception encountered during TRANSFORM phase: ' || SQLERRM;
      l_record_count := 1;
      l_success_count := 0;
      l_error_count := 1;
      l_phase_status := 'ERROR';
      g_control_status := 'ERROR';
      p_transform_status := FALSE;

      r_error := NULL;
      r_error.run_id := l_run_id;
      r_error.run_phase_id := l_run_phase_id;
      r_error.record_id := NVL(l_record_id, -1);
      r_error.int_table_key_val1 := g_order_number;
      r_error.error_text := l_error_message;
      raise_error(r_error);

      -- update control queue
      update_control_queue(l_error_message);

      print_debug('exception ' || SQLERRM);
      print_debug('update run phase ' || z_transform);
      print_debug('end ' || z_transform);

      -- update run phase
      xxfnd_common_int_pkg.update_run_phase
         (p_run_phase_id => l_run_phase_id,
          p_src_code     => z_src_code,
          p_rec_count    => l_record_count,
          p_hash_total   => NULL,
          p_batch_name   => r_file.file_name);

      -- end run phase
      xxfnd_common_int_pkg.end_run_phase
         (p_run_phase_id => l_run_phase_id,
          p_status => l_phase_status,
          p_error_count => l_error_count,
          p_success_count => l_success_count);

      l_error_report := xxfnd_common_int_pkg.launch_error_report
                           (p_run_id => l_run_id,
                            p_run_phase_id => l_run_phase_id);

      l_error_message := 'Please review interface error report (' || l_error_report || ').';
      send_error_notification(l_error_message);

END transform;

----------------------------------------------------------
-- Procedure
--     LOAD
-- Purpose
--     Interface Framework LOAD phase. This is the
--     procedure that performs the actual data load to
--     Purchasing application tables. LOAD utilizes
--     standard Oracle Open Interface/API.
--     There must be no transformation routines during
--     load. The only acceptable DML here is INSERT INTO
--     PDOI tables.
----------------------------------------------------------

PROCEDURE load
(
   p_run_id            IN NUMBER,
   p_run_phase_id      IN NUMBER,
   p_control_id        IN NUMBER,
   p_transform_status  IN BOOLEAN,
   p_load_status       IN OUT BOOLEAN,
   p_warning           IN OUT NUMBER
)
IS
   CURSOR c_file IS
      SELECT ctl.control_id,
             REPLACE(file_name, 
                     SUBSTR(file_name, 1, INSTR(file_name, '/', -1)),
                     NULL) file_name
      FROM   xxfnd_interface_ctl ctl
      WHERE  ctl.control_id = p_control_id;

   CURSOR c_line IS
      SELECT record_id,
             org_id,
             created_by,
             creation_date,
             last_update_date,
             last_updated_by,
             line_action,
             line_num,
             shipment_num,
             line_type,
             line_type_id,
             category,
             category_id,
             item_description,
             vendor_product_num,
             uom_code,
             unit_of_measure,
             quantity,
             unit_price,
             allow_price_override_flag,
             note_to_vendor,
             taxable_flag,
             tax_name,
             tax_code_id,
             need_by_date,
             promised_date,
             line_expiration_date,
             amount,
             note_to_receiver
      FROM   xxpo_po_interface_tfm
      WHERE  run_id = p_run_id
      AND    record_type = z_line_rec_type;

   CURSOR c_distr (p_line_num NUMBER) IS
      SELECT record_id,
             org_id,
             created_by,
             creation_date,
             last_update_date,
             last_updated_by,
             quantity_ordered,
             distribution_rate,
             distribution_rate_date,
             deliver_to_location,
             deliver_to_location_id,
             destination_organization_id,
             destination_type_code,
             set_of_books_id,
             charge_account_id,
             distribution_num,
             charge_account_segment1,
             charge_account_segment2,
             charge_account_segment3,
             charge_account_segment4,
             charge_account_segment5,
             charge_account_segment6,
             attribute1
      FROM   xxpo_po_interface_tfm
      WHERE  run_id = p_run_id
      AND    line_num = p_line_num
      AND    record_type = z_distr_rec_type;

   CURSOR c_req (p_request_id NUMBER) IS
      SELECT completion_text
      FROM   fnd_concurrent_requests
      WHERE  request_id = p_request_id;

   CURSOR c_errors (p_request_id NUMBER) IS
      SELECT interface_transaction_id,
             error_message 
      FROM   po_interface_errors
      WHERE  request_id = p_request_id;

   r_file                       c_file%ROWTYPE;
   r_line                       c_line%ROWTYPE;
   r_distr                      c_distr%ROWTYPE;
   l_record_count               NUMBER := 0;
   l_success_count              NUMBER := 0;
   l_error_count                NUMBER := 0;
   l_error                      NUMBER := 0;
   l_warning                    NUMBER := 0;
   l_error_report               NUMBER;
   l_error_message              VARCHAR2(600);
   l_phase_status               VARCHAR2(30) := 'SUCCESS';
   l_interface_header_id        NUMBER;
   l_interface_line_id          NUMBER;
   l_interface_distribution_id  NUMBER;
   l_valid_count                NUMBER := 0;
   l_import_request_id          NUMBER;
   r_error                      xxfnd_int_run_phase_errors%ROWTYPE;

   ------------- Subprogram Declaration -------------

   /* get_interface_id */
   FUNCTION get_interface_id
   (
      p_rec_type  VARCHAR2
   )
   RETURN NUMBER
   IS
      l_interface_id  NUMBER;
   BEGIN
      CASE p_rec_type
         WHEN z_header_rec_type THEN
            SELECT po_headers_interface_s.nextval
            INTO   l_interface_id
            FROM   dual;
         WHEN z_line_rec_type THEN
            SELECT po_lines_interface_s.nextval
            INTO   l_interface_id
            FROM   dual;
         WHEN z_distr_rec_type THEN
            SELECT po_distributions_interface_s.nextval
            INTO   l_interface_id
            FROM   dual;
      END CASE;
      RETURN l_interface_id;
   END get_interface_id;

   /* purge_interface */
   PROCEDURE purge_interface
   (
      p_batch_id    NUMBER
   )
   IS
   BEGIN
      DELETE FROM po_distributions_interface
      WHERE  interface_header_id = (SELECT interface_header_id
                                    FROM   po_headers_interface
                                    WHERE  batch_id = p_batch_id);

      DELETE FROM po_lines_interface
      WHERE  interface_header_id = (SELECT interface_header_id
                                    FROM   po_headers_interface
                                    WHERE  batch_id = p_batch_id);

      DELETE FROM po_headers_interface
      WHERE  batch_id = p_batch_id;
   END purge_interface;

   /* update_document_reference */
   FUNCTION update_document_reference
   RETURN BOOLEAN
   IS
   BEGIN
      UPDATE xxpo_document_references dref
      SET    dref.document_id = (SELECT poh.po_header_id
                                 FROM   po_headers_all poh
                                 WHERE  poh.segment1 = dref.document_num
                                 AND    poh.org_id = dref.org_id
                                 AND    poh.type_lookup_code = z_document_type
                                 AND    poh.request_id = l_import_request_id)
      WHERE  dref.document_id IS NULL
      AND    dref.document_num = g_order_number
      AND    dref.org_id = g_org_id;

      -- processed
      IF sql%FOUND THEN
         RETURN TRUE;
      END IF;

      -- rejected
      RETURN FALSE;
   END update_document_reference;

   ------------- Subprogram Declaration -------------

BEGIN
   print_debug('start ' || z_load);
   print_debug('run_id=' || p_run_id);
   print_debug('run_phase_id=' || p_run_phase_id);

   OPEN c_file;
   FETCH c_file INTO r_file;
   CLOSE c_file;

   IF p_transform_status THEN
      g_control_status := z_load;

      l_interface_header_id := get_interface_id(z_header_rec_type);
      g_batch_id := l_interface_header_id;
      l_record_count := l_record_count + 1;

      print_debug('populate po interface tables');

      INSERT INTO po_headers_interface
            (interface_header_id,
             batch_id,
             interface_source_code,
             process_code,
             action,
             org_id,
             document_type_code,
             document_num,
             currency_code,
             rate_type,
             rate_date,
             rate,
             agent_id,
             vendor_name,
             vendor_site_code,
             vendor_id,
             vendor_site_id,
             payment_terms,
             terms_id,
             ship_to_location,
             ship_to_location_id,
             bill_to_location,
             bill_to_location_id,
             approval_status,
             freight_terms,
             fob,
             comments,
             amount_agreed,
             expiration_date,
             created_by,
             creation_date,
             last_update_date,
             last_updated_by)
      SELECT l_interface_header_id,
             g_batch_id,
             interface_source_code,
             process_code,
             action,
             org_id,
             document_type_code,
             document_num,
             currency_code,
             rate_type,
             rate_date,
             rate,
             agent_id,
             vendor_name,
             vendor_site_code,
             vendor_id,
             vendor_site_id,
             payment_terms,
             terms_id,
             ship_to_location,
             ship_to_location_id,
             bill_to_location,
             bill_to_location_id,
             approval_status,
             freight_terms,
             fob,
             comments,
             amount_agreed,
             expiration_date,
             created_by,
             creation_date,
             last_update_date,
             last_updated_by
      FROM   xxpo_po_interface_tfm
      WHERE  run_id = p_run_id
      AND    record_type = z_header_rec_type;

      OPEN c_line;
      LOOP
         FETCH c_line INTO r_line;
         EXIT WHEN c_line%NOTFOUND;

         l_interface_line_id := get_interface_id(z_line_rec_type);
         l_record_count := l_record_count + 1;

         INSERT INTO po_lines_interface
                (interface_header_id,
                 interface_line_id,
                 created_by,
                 creation_date,
                 last_update_date,
                 last_updated_by,
                 action,
                 line_num,
                 shipment_num,
                 line_type,
                 line_type_id,
                 category,
                 category_id,
                 item_description,
                 vendor_product_num,
                 uom_code,
                 unit_of_measure,
                 quantity,
                 unit_price,
                 allow_price_override_flag,
                 note_to_vendor,
                 taxable_flag,
                 tax_name,
                 tax_code_id,
                 need_by_date,
                 promised_date,
                 expiration_date,
                 amount,
                 note_to_receiver)
         VALUES (l_interface_header_id,
                 l_interface_line_id,
                 r_line.created_by,
                 r_line.creation_date,
                 r_line.last_update_date,
                 r_line.last_updated_by,
                 r_line.line_action,
                 r_line.line_num,
                 r_line.shipment_num,
                 r_line.line_type,
                 r_line.line_type_id,
                 r_line.category,
                 r_line.category_id,
                 r_line.item_description,
                 r_line.vendor_product_num,
                 r_line.uom_code,
                 r_line.unit_of_measure,
                 r_line.quantity,
                 r_line.unit_price,
                 r_line.allow_price_override_flag,
                 r_line.note_to_vendor,
                 r_line.taxable_flag,
                 r_line.tax_name,
                 r_line.tax_code_id,
                 r_line.need_by_date,
                 r_line.promised_date,
                 r_line.line_expiration_date,
                 r_line.amount,
                 r_line.note_to_receiver);

         OPEN c_distr (r_line.line_num);
         LOOP
            FETCH c_distr INTO r_distr;
            EXIT WHEN c_distr%NOTFOUND;

            l_interface_distribution_id := get_interface_id(z_distr_rec_type);
            l_record_count := l_record_count + 1;
            l_valid_count := l_valid_count + 1;

            INSERT INTO po_distributions_interface
                   (interface_header_id,
                    interface_line_id,
                    interface_distribution_id,
                    org_id,
                    created_by,
                    creation_date,
                    last_update_date,
                    last_updated_by,
                    quantity_ordered,
                    rate,
                    rate_date,
                    deliver_to_location,
                    deliver_to_location_id,
                    destination_organization_id,
                    destination_type_code,
                    set_of_books_id,
                    charge_account_id,
                    distribution_num,
                    attribute1)
            VALUES (l_interface_header_id,
                    l_interface_line_id,
                    l_interface_distribution_id,
                    r_distr.org_id,
                    r_distr.created_by,
                    r_distr.creation_date,
                    r_distr.last_update_date,
                    r_distr.last_updated_by,
                    r_distr.quantity_ordered,
                    r_distr.distribution_rate,
                    r_distr.distribution_rate_date,
                    r_distr.deliver_to_location,
                    r_distr.deliver_to_location_id,
                    r_distr.destination_organization_id,
                    r_distr.destination_type_code,
                    r_distr.set_of_books_id,
                    r_distr.charge_account_id,
                    r_distr.distribution_num,
                    r_distr.attribute1);
         END LOOP;
         CLOSE c_distr;

      END LOOP;
      CLOSE c_line;

      IF l_valid_count > 0 THEN
         -- commit interface data
         print_debug('commit interface data');
         COMMIT;

         print_debug('submit standard po import program');

         l_import_request_id := fnd_request.submit_request
                                    (application => 'PO',
                                     program     => 'POXPOPDOI', 
                                     description => NULL,
                                     start_time  => SYSDATE,
                                     sub_request => FALSE, 
                                     argument1   => NULL, --Default Buyer
                                     argument2   => z_document_type, 
                                     argument3   => NULL,
                                     argument4   => 'N',
                                     argument5   => NULL,
                                     argument6   => z_pdoi_status,
                                     argument7   => NULL,
                                     argument8   => g_batch_id,
                                     argument9   => g_org_id,
                                     argument10  => NULL,
                                     argument11  => NULL,
                                     argument12  => NULL,
                                     argument13  => NULL,
                                     argument14  => NULL);
         -- commit request
         COMMIT;

         print_debug('po import program request id ' || l_import_request_id);
         print_debug('wait for request to complete');
         wait_for_request(l_import_request_id, z_wait);

         IF NOT (srs_dev_phase = 'COMPLETE' AND
                (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
            OPEN c_req (l_import_request_id);
            FETCH c_req INTO l_error_message;
            IF c_req%FOUND THEN
               l_error_count := l_record_count;
               r_error := NULL;
               r_error.run_id := p_run_id;
               r_error.run_phase_id := p_run_phase_id;
               r_error.record_id := l_import_request_id;
               r_error.int_table_key_val1 := g_order_number;
               r_error.error_text := l_error_message;
               raise_error(r_error);

               l_phase_status := 'ERROR';
               g_control_status := z_rejected;
               update_transform_table(p_run_id, z_rejected);
               p_load_status := FALSE;
            END IF;
            CLOSE c_req;
         ELSE
            -- process completed normal 
            OPEN c_errors (l_import_request_id);
            LOOP
               r_error := NULL;
               r_error.run_id := p_run_id;
               r_error.run_phase_id := p_run_phase_id;
               r_error.int_table_key_val1 := g_order_number;

               FETCH c_errors INTO r_error.record_id, r_error.error_text;
               EXIT WHEN c_errors%NOTFOUND;
               raise_error(r_error);

               CASE 
                  WHEN INSTR(UPPER(r_error.error_text), 'ERROR') > 0 THEN
                       l_error := l_error + 1;
                  WHEN INSTR(UPPER(r_error.error_text), 'WARNING') > 0 THEN
                       l_warning := l_warning + 1;
               END CASE;
            END LOOP;

            p_warning := l_warning;

            IF update_document_reference THEN
               print_debug('reconciled with document reference');
               print_debug('update transformation tables ' || z_processed);
               update_transform_table(p_run_id, z_processed);
               l_success_count := l_record_count;
               g_control_status := z_processed;
            ELSE
               p_load_status := FALSE;
               print_debug('update transformation tables ' || z_rejected);
               update_transform_table(p_run_id, z_rejected);
               l_error_count := l_record_count;
               g_control_status := z_rejected;
            END IF;
         END IF;

         -- purge interface data
         IF g_purge_interface = 'Y' THEN
            print_debug('purging PDOI tables');
            purge_interface(g_batch_id);
         END IF;

         -- commit residual updates
         COMMIT;
      END IF;

   ELSE
      l_phase_status := 'ERROR';
      g_control_status := 'ERROR';
      p_load_status := FALSE;
   END IF;

   print_debug('update control queue table');
   update_control_queue(l_error_message);

   print_debug('update run phase ' || z_load);
   print_debug('end ' || z_load);

   -- Update Run Phase
   xxfnd_common_int_pkg.update_run_phase
      (p_run_phase_id => p_run_phase_id,
       p_src_code     => z_src_code,
       p_rec_count    => l_record_count,
       p_hash_total   => NULL,
       p_batch_name   => r_file.file_name);

   -- End Run Phase
   xxfnd_common_int_pkg.end_run_phase
      (p_run_phase_id => p_run_phase_id,
       p_status => l_phase_status,
       p_error_count => l_error_count,
       p_success_count => l_success_count);

   IF l_error > 0 THEN
      l_error_report := xxfnd_common_int_pkg.launch_error_report
                           (p_run_id => p_run_id,
                            p_run_phase_id => p_run_phase_id);

      l_error_message := 'Import Standard Purchase Orders concurrent program completed with errors (Request ID: ' || l_import_request_id || ')';
      l_error_message := z_error || z_nl || l_error_message;
      send_error_notification(l_error_message);
   END IF;

EXCEPTION
   WHEN others THEN
      l_error_message := 'Unhandled exception encountered during LOAD phase: ' || SQLERRM;
      l_record_count := 1;
      l_success_count := 0;
      l_error_count := 1;
      l_phase_status := 'ERROR';
      g_control_status := 'ERROR';
      p_load_status := FALSE;

      r_error := NULL;
      r_error.run_id := p_run_id;
      r_error.run_phase_id := p_run_phase_id;
      r_error.record_id := -1;
      r_error.int_table_key_val1 := -1;
      r_error.error_text := l_error_message;
      raise_error(r_error);

      -- update control queue
      update_control_queue(l_error_message);

      print_debug('exception ' || SQLERRM);
      print_debug('update run phase ' || z_load);
      print_debug('end ' || z_load);

      -- update run phase
      xxfnd_common_int_pkg.update_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_src_code     => z_src_code,
          p_rec_count    => l_record_count,
          p_hash_total   => NULL,
          p_batch_name   => r_file.file_name);

      -- end run phase
      xxfnd_common_int_pkg.end_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_status => l_phase_status,
          p_error_count => l_error_count,
          p_success_count => l_success_count);

      l_error_report := xxfnd_common_int_pkg.launch_error_report
                           (p_run_id => p_run_id,
                            p_run_phase_id => p_run_phase_id);

      l_error_message := 'Please review interface error report (' || l_error_report || ').';
      send_error_notification(l_error_message);

END load;

-------------------------------------------
-- Procedure
--    SWITCH_RESP
-- Purpose
--    Test responsibility switching to
--    confirm if APPS_GLOBAL.INITIALIZE
--    can be used.
-------------------------------------------

PROCEDURE switch_resp
(
   p_errbuff       OUT VARCHAR2,
   p_retcode       OUT NUMBER,
   p_org_id        IN  NUMBER
)
IS
   l_org_id            NUMBER;
BEGIN
   g_debug_flag := 'Y';
   g_request_id := fnd_global.conc_request_id;

   g_user_id := fnd_global.user_id;
   g_resp_id := fnd_global.resp_id;
   g_set_of_books_id := fnd_profile.value('GL_SET_OF_BKS_ID');
   l_org_id := fnd_global.org_id;

   print_debug('submit request profile setting is');
   print_debug('user_id=' || g_user_id);
   print_debug('resp_id=' || g_resp_id);
   print_debug('set_of_books_id=' || g_set_of_books_id);
   print_debug('org_id=' || l_org_id);

   fnd_global.apps_initialize(user_id => 3333, resp_id => 51114, resp_appl_id => 201); 

   g_user_id := fnd_global.user_id;
   g_resp_id := fnd_global.resp_id;
   g_set_of_books_id := fnd_profile.value('GL_SET_OF_BKS_ID');
   l_org_id := fnd_global.org_id;

   print_debug('switching now to');
   print_debug('user_id=' || g_user_id);
   print_debug('resp_id=' || g_resp_id);
   print_debug('set_of_books_id=' || g_set_of_books_id);
   print_debug('org_id=' || l_org_id);

END switch_resp;

-----------------------------------------------------------
-- Procedure
--    CREATE_PO_XML
-- Purpose
--    Batch process for creating PO XML files. POs are 
--    referenced as Basware Orders, returning the document
--    to Basware with complete PO details after document
--    has been approved.
-----------------------------------------------------------

PROCEDURE create_po_xml
(
   p_errbuff        OUT VARCHAR2,
   p_retcode        OUT NUMBER,
   p_source         IN  VARCHAR2,
   p_last_run_date  IN  VARCHAR2,
   p_debug_flag     IN  VARCHAR2
)
IS
   l_xml_file        VARCHAR2(150) := 'Order$PO_NUM$.xml';
   l_out_dir         VARCHAR2(240);
   l_out_file        VARCHAR2(240);
   l_error_message   VARCHAR2(600);
   l_last_run_date   DATE;
   l_phase_code      fnd_concurrent_requests.phase_code%TYPE;
   l_document_id     xxpo_document_references.document_id%TYPE;
   l_document_count  NUMBER := 0;
   l_tab_index       NUMBER := 0;
   l_copy_file       NUMBER;
   l_request_id      NUMBER;
   l_run             NUMBER;
   l_program_id      NUMBER;
   l_program_name    fnd_concurrent_programs_tl.user_concurrent_program_name%TYPE;
   l_user_name       fnd_user.user_name%TYPE;
   l_report_text     VARCHAR2(1000);
   t_requests        t_requests_tab_type;

   /*
   -- xml file variables
   l_clob            CLOB;
   l_bfile           BFILE;
   l_bfile_csid      NUMBER  := 0;
   l_dest_offset     INTEGER := 1;
   l_src_offset      INTEGER := 1;
   l_lang_context    INTEGER := 0;
   l_warning         INTEGER := 0;
   l_xml             XMLTYPE;
   l_doc             dbms_xmldom.DOMDocument;
   */

   -- file type
   f_read            utl_file.file_type;
   f_write           utl_file.file_type;
   f_line            VARCHAR2(1000);
   f_line_count      NUMBER;

   CURSOR c_po (p_request_id NUMBER, p_last_run_date_in DATE) IS
      SELECT p_request_id,
             poh.po_header_id,
             poh.segment1,
             poh.org_id,
             poh.last_update_date,
             poh.authorization_status
      FROM   po_headers_all poh,
             po_lines_all pol,
             po_line_locations_all pll,
             po_distributions_all pod
      WHERE  poh.org_id IN (82, 453, 452)
      AND    poh.authorization_status = z_po_xml_status
      AND    poh.po_header_id = pol.po_header_id
      AND    (NVL(pol.quantity, 0) * NVL(pol.unit_price, 0)) <> 0
      AND    pol.po_header_id = pll.po_header_id
      AND    pol.po_line_id = pll.po_line_id
      AND    pll.po_header_id = pod.po_header_id
      AND    pll.po_line_id = pod.po_line_id
      AND    pll.line_location_id = pod.line_location_id
    --AND    poh.po_header_id = 326777;
      AND    (
             poh.last_update_date > p_last_run_date_in OR
             pol.last_update_date > p_last_run_date_in OR
             pll.last_update_date > p_last_run_date_in OR
             pod.last_update_date > p_last_run_date_in
             )
      UNION
      SELECT p_request_id,
             poh.po_header_id,
             poh.segment1,
             poh.org_id,
             poh.last_update_date,
             poh.authorization_status
      FROM   po_headers_all poh, 
             po_lines_all pol
      WHERE  poh.org_id IN (82, 453, 452)
      AND    poh.authorization_status = z_po_xml_status
      AND    poh.po_header_id = pol.po_header_id
      AND    (NVL(pol.quantity, 0) * NVL(pol.unit_price, 0)) <> 0
      AND    EXISTS (SELECT 1
                     FROM   rcv_transactions rcv
                     WHERE  rcv.po_header_id = poh.po_header_id
                     AND    rcv.last_update_date > p_last_run_date_in);

   CURSOR c_basdoc (p_po_header_id NUMBER, p_org_id NUMBER) IS
      SELECT document_id
      FROM   xxpo_document_references
      WHERE  document_id = p_po_header_id
      AND    document_source = z_src_code
      AND    org_id = p_org_id;

   CURSOR c_xml (p_request_id NUMBER) IS
      SELECT poh.segment1 po_num,
             poh.po_header_id,
             poh.org_id
      FROM   po_headers_all poh
      WHERE  EXISTS (SELECT 1
                     FROM   xxpo_document_references_stg stg
                     WHERE  stg.request_id = p_request_id
                     AND    stg.po_header_id = poh.po_header_id
                     AND    stg.org_id = poh.org_id);

   CURSOR c_out (p_request_id NUMBER) IS
      SELECT outfile_name
      FROM   fnd_concurrent_requests
      WHERE  request_id = p_request_id;

   create_xml     BOOLEAN;
BEGIN
   l_request_id := fnd_global.conc_request_id;
   l_program_id := fnd_global.conc_program_id;
   l_user_name := fnd_global.user_name;
   l_out_dir := fnd_profile.value('XXFND_OUTBOUND_BASWARE');
   g_debug_flag := NVL(p_debug_flag, 'N');

   print_debug('start program create_po_xml');

   BEGIN
      SELECT user_concurrent_program_name
      INTO   l_program_name
      FROM   fnd_concurrent_programs_tl
      WHERE  concurrent_program_id = l_program_id;
   EXCEPTION
      WHEN others THEN
         NULL;
   END;

   -- truncate document reference staging
   DELETE FROM xxpo_document_references_stg;

   -- report
   fnd_file.put_line(fnd_file.output, fnd_global.newline);
   fnd_file.put_line(fnd_file.output, 'Program Name       : ' || l_program_name);
   fnd_file.put_line(fnd_file.output, 'Run Datetime       : ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH:MI:SS AM'));
   fnd_file.put_line(fnd_file.output, 'Username           : ' || l_user_name);
   fnd_file.put_line(fnd_file.output, fnd_global.newline);
   fnd_file.put_line(fnd_file.output, 'Run Parameters');
   fnd_file.put_line(fnd_file.output, 'Object Type        : ' || z_object_type);
   fnd_file.put_line(fnd_file.output, 'Source             : ' || z_src_code);
   fnd_file.put_line(fnd_file.output, 'Debug On           : ' || g_debug_flag);
   fnd_file.put_line(fnd_file.output, 'Outbound Directory : ' || l_out_dir);
   fnd_file.put_line(fnd_file.output, fnd_global.newline);

   fnd_file.put_line(fnd_file.output, 'Request ID  PO Number       Status    PO XML Filename');
   fnd_file.put_line(fnd_file.output, '----------  --------------  --------  ----------------------------------------------');

   IF p_last_run_date IS NOT NULL THEN
      print_debug('last_run_date=' || p_last_run_date);
      l_last_run_date := fnd_date.canonical_to_date(p_last_run_date);
   ELSE
      BEGIN
         SELECT MAX(last_run_date)
         INTO   l_last_run_date
         FROM   xxfnd_interface_stg
         WHERE  object_type = 'ORDER'
         AND    in_out = 'OUT'
         AND    status = 'CREATED';

         print_debug('system last_run_date=' || TO_CHAR(l_last_run_date, 'DD-MON-YYYY HH24:MI:SS'));
      EXCEPTION
         WHEN no_data_found THEN
            l_last_run_date := TRUNC(SYSDATE - 1);
            print_debug('default last_run_date=' || TO_CHAR(l_last_run_date, 'DD-MON-YYYY HH24:MI:SS'));
      END;
   END IF;

   /* create and validate document reference */
   FOR r_po IN c_po (l_request_id, l_last_run_date) LOOP
      create_xml := TRUE;

      IF p_source = z_src_code THEN
         OPEN c_basdoc(r_po.po_header_id, r_po.org_id);
         FETCH c_basdoc INTO l_document_id;
         IF c_basdoc%NOTFOUND THEN
            create_xml := FALSE;
         END IF;
         CLOSE c_basdoc;
      ELSE
         create_xml := FALSE;
      END IF;

      IF create_xml THEN
         INSERT INTO xxpo_document_references_stg
         VALUES r_po;
         l_document_count := l_document_count + 1;
      END IF;
   END LOOP;

   print_debug('document_count=' || l_document_count);

   /* update status to staged */
   IF l_document_count > 0 THEN
      INSERT INTO xxfnd_interface_stg
             (record_id,
              control_id,
              request_id,
              file_name,
              object_type,
              object_source_table,
              status,
              in_out,
              last_run_date,
              creation_date,
              created_by,
              last_update_date,
              last_updated_by)
      VALUES (xxfnd_interface_stg_rec_id_s.nextval,
              xxfnd_interface_ctl_s.nextval,
              l_request_id,
              l_xml_file,
              z_object_type,
              'PO_HEADERS_ALL',
              'STAGED',
              'OUT',
              SYSDATE,
              SYSDATE,
              fnd_global.user_id,
              SYSDATE,
              fnd_global.user_id);
      COMMIT;
      print_debug('update status to staged');
   END IF;

   /* generate xml file */
   FOR r_xml IN c_xml (l_request_id) LOOP
      l_tab_index := l_tab_index + 1;
      t_requests(l_tab_index).po_header_id := r_xml.po_header_id;
      t_requests(l_tab_index).po_num := r_xml.po_num;
      t_requests(l_tab_index).po_xml_file := REPLACE(l_xml_file, '$PO_NUM$', r_xml.po_num);
      t_requests(l_tab_index).org_id := r_xml.org_id;
      t_requests(l_tab_index).request_id := fnd_request.submit_request
                                               (application => 'XXNZCL',
                                                program     => 'XXPOEPOXML', 
                                                description => NULL,
                                                start_time  => SYSDATE,
                                                sub_request => FALSE, 
                                                argument1   => r_xml.po_header_id,
                                                argument2   => r_xml.org_id);
      COMMIT;

      print_debug('generate xml file');
      print_debug('request id ' || t_requests(l_tab_index).request_id || ' ' || t_requests(l_tab_index).po_xml_file);
   END LOOP;

   /* wait for all requests to finish */
   IF t_requests.COUNT > 0 THEN
      print_debug('wait for requests to complete');

      LOOP
         l_run := 0;

         FOR i IN 1 .. t_requests.COUNT LOOP
            BEGIN
               SELECT phase_code
               INTO   l_phase_code
               FROM   fnd_concurrent_requests
               WHERE  request_id = t_requests(i).request_id;

               IF l_phase_code = 'C' THEN
                  NULL;
               ELSE
                  l_run := l_run + 1;
               END IF;
            EXCEPTION
               WHEN no_data_found THEN
                  NULL;
            END;
         END LOOP;

         IF l_run = 0 THEN
            EXIT;
         ELSE
            -- sleep avoids burning cpu time
            dbms_lock.sleep(10);
         END IF;
      END LOOP;
   END IF;

   /* copy file to destination */
   IF t_requests.COUNT > 0 THEN
      FOR i IN 1 .. t_requests.COUNT LOOP
         t_requests(i).status := 'SUCCESS';
         g_request_id := t_requests(i).request_id;
         OPEN c_out (t_requests(i).request_id);
         FETCH c_out INTO l_out_file;
         IF c_out%FOUND THEN
            print_debug('get output file ' || l_out_file);

            l_copy_file := xxfnd_common_pkg.file_copy(p_file_from => l_out_file, 
                                                      p_file_to => z_staging_dir || '/' || 'temp.xml'); 
            IF l_copy_file = 0 THEN
               t_requests(i).status := 'ERROR';
               l_error_message := 'Unable to copy output file ' || l_out_file || ' to staging directory';
               send_error_notification(l_error_message);
               print_debug(z_error || l_error_message);
            ELSE
               /* workaround: remove empty date nodes */
               /* re-write xml output file            */
               print_debug('remove empty date fields');
               f_line_count := 0;

               BEGIN
                  f_read  := utl_file.fopen(z_staging_alias, 'temp.xml', 'r');
                  f_write := utl_file.fopen(z_staging_alias, t_requests(i).po_xml_file, 'w');
                  LOOP
                     utl_file.get_line(f_read, f_line);
                     f_line_count := f_line_count + 1;
                     CASE WHEN INSTR(f_line, '<RequestedDeliveryDate></RequestedDeliveryDate>') > 0 THEN NULL;
                          WHEN INSTR(f_line, '<ActualDeliveryDate></ActualDeliveryDate>') > 0 THEN NULL;
                          WHEN INSTR(f_line, '<DeliveryDate></DeliveryDate>') > 0 THEN NULL;
                          ELSE utl_file.put_line(f_write, f_line);
                     END CASE;
                  END LOOP;
               EXCEPTION
                  WHEN no_data_found THEN
                     IF utl_file.is_open(f_read) THEN
                        utl_file.fclose(f_read);
                     END IF;
                     IF utl_file.is_open(f_write) THEN
                        utl_file.fclose(f_write);
                     END IF;
                  WHEN others THEN
                     f_line_count := 0;
                     t_requests(i).status := 'ERROR';
                     l_error_message := 'Unexpected error during xml file re-write ' || t_requests(i).po_xml_file;
                     send_error_notification(l_error_message);
                     print_debug(z_error || l_error_message);
               END;

               /* copy xml file to target */
               IF f_line_count > 0 THEN
                  l_copy_file := xxfnd_common_pkg.file_copy(p_file_from => z_staging_dir || '/' || t_requests(i).po_xml_file, 
                                                            p_file_to => l_out_dir || '/' || t_requests(i).po_xml_file);
                  IF l_copy_file = 0 THEN
                     t_requests(i).status := 'ERROR';
                     l_error_message := 'Unable to place xml file ' || t_requests(i).po_xml_file || ' to the target directory';
                     send_error_notification(l_error_message);
                     print_debug(z_error || l_error_message);
                  ELSE
                     print_debug('place xml file ' || t_requests(i).po_xml_file || ' to target directory');
                  END IF;
               END IF;

               print_debug('delete temporary file');
               utl_file.fremove(location => z_staging_alias, filename => 'temp.xml');
               utl_file.fremove(location => z_staging_alias, filename => t_requests(i).po_xml_file);
            END IF;
         END IF;
         CLOSE c_out;

         l_report_text := RPAD(t_requests(i).request_id, 12, ' ') ||
                          RPAD(t_requests(i).po_num, 16, ' ') ||
                          RPAD(t_requests(i).status, 10, ' ') ||
                          t_requests(i).po_xml_file;
         fnd_file.put_line(fnd_file.output, l_report_text);
      END LOOP;

      fnd_file.put_line(fnd_file.output, fnd_global.newline);
      fnd_file.put_line(fnd_file.output, '                       *** End of Report ***');

   ELSE
      fnd_file.put_line(fnd_file.output, fnd_global.newline);
      fnd_file.put_line(fnd_file.output, '                       *** No data found ***');

   END IF;

   print_debug('generate xml file completed');

   /* update status to created */
   IF t_requests.COUNT > 0 THEN
      UPDATE xxfnd_interface_stg
      SET    status = 'CREATED',
             last_update_date = SYSDATE
      WHERE  request_id = l_request_id
      AND    object_type = z_object_type
      AND    in_out = 'OUT';

      -- commit status to created
      print_debug('upate status to created');
      COMMIT;
   END IF;

   print_debug('end program create_po_xml');

EXCEPTION
   WHEN others THEN
      g_request_id := l_request_id;
      send_error_notification(SQLERRM);

END create_po_xml;

END xxpo_purchase_order_pkg;
/
