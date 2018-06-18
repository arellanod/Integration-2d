CREATE OR REPLACE PACKAGE BODY xxfnd_common_int_pkg 
AS
/****************************************************************************
**
**  $HeadURL: $
**
**  Purpose: Common Interface Framework.
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
--
--
gb_debug                        CONSTANT BOOLEAN := true;
gb_test_mode                    CONSTANT BOOLEAN := false;
gv_package_name                 CONSTANT VARCHAR2(50) := 'xxfnd_common_int_pkg';
--
--
gv_cp_success                   CONSTANT VARCHAR2(1) := 0;
gv_cp_warning                   CONSTANT VARCHAR2(1) := 1;
gv_cp_error                     CONSTANT VARCHAR2(1) := 2;
--
--
/***************************************************************************
**  FUNCTION
**    get_run_id
**
**  DESCRIPTION
**    This API is used to get the interface run id
***************************************************************************/
FUNCTION get_run_id
RETURN xxfnd_int_runs.run_id%TYPE
IS
   l_run_id xxfnd_int_runs.run_id%TYPE;

   -- Get next sequence number
   CURSOR run_id_cur IS
      SELECT xxfnd_int_runs_id_s.nextval
      FROM   dual;

BEGIN
   OPEN run_id_cur;
   FETCH run_id_cur INTO l_run_id;
   CLOSE run_id_cur;

   RETURN l_run_id;

END get_run_id;

/***************************************************************************
**  Procedure
**    debug
**
**  DESCRIPTION
**    Writes debug information to either DBMS Output or Debug Table.
**
***************************************************************************/
PROCEDURE debug
(
   pv_message IN VARCHAR2,
   pv_proc    IN VARCHAR2
)
IS
BEGIN
   IF gb_debug THEN
      IF NOT (gb_test_mode) THEN
         xxfnd_common_pkg.log(gv_package_name || '.' || pv_proc || ' - ' || pv_message);

      ELSE
         dbms_output.put_line(gv_package_name || '.' || pv_proc || ' - ' || pv_message);
      END IF;
   END IF;
END debug;
--
--
/***************************************************************************
**  FUNCTION
**    writerep
**
**  DESCRIPTION
**    Writes report information to either DBMS Output or CP log file.
**
***************************************************************************/
PROCEDURE writerep(p_msg IN VARCHAR2) IS
BEGIN
   fnd_file.put_line(fnd_file.output, p_msg);
END writerep;

/***************************************************************************
**  Procedure
**    submit_request
**
**  DESCRIPTION
**    Generic request submit procudure
**
***************************************************************************/
FUNCTION submit_request
(
   p_application IN VARCHAR2 DEFAULT 'XXNZCL',
   p_program     IN VARCHAR2 DEFAULT NULL,
   p_description IN VARCHAR2 DEFAULT NULL,
   p_argument1   IN VARCHAR2 DEFAULT CHR(0),
   p_argument2   IN VARCHAR2 DEFAULT CHR(0),
   p_argument3   IN VARCHAR2 DEFAULT CHR(0),
   p_argument4   IN VARCHAR2 DEFAULT CHR(0),
   p_argument5   IN VARCHAR2 DEFAULT CHR(0),
   p_argument6   IN VARCHAR2 DEFAULT CHR(0),
   p_argument7   IN VARCHAR2 DEFAULT CHR(0),
   p_argument8   IN VARCHAR2 DEFAULT CHR(0),
   p_argument9   IN VARCHAR2 DEFAULT CHR(0),
   p_argument10  IN VARCHAR2 DEFAULT CHR(0),
   p_dev_status  OUT VARCHAR2
)
RETURN NUMBER IS
   v_request_id NUMBER;
   v_phase      VARCHAR2(240);
   v_status     VARCHAR2(240);
   v_dev_phase  VARCHAR2(240);
   v_message1   VARCHAR2(240);
   v_result     BOOLEAN;
BEGIN
   v_request_id := fnd_request.submit_request(p_application,
                                              p_program,
                                              p_description,
                                              NULL, --start_time
                                              FALSE,  --sub_request
                                              p_argument1,
                                              p_argument2,
                                              p_argument3,
                                              p_argument4,
                                              p_argument5,
                                              p_argument6,
                                              p_argument7,
                                              p_argument8,
                                              p_argument9,
                                              p_argument10);
   COMMIT;

   IF (v_request_id != 0) THEN
      -- Wait for request to finish
      v_result := fnd_concurrent.wait_for_request(v_request_id, --request_id
                                                  1,            --interval
                                                  0,            --max_wait
                                                  v_phase,      --phase
                                                  v_status,     --status
                                                  v_dev_phase,  --dev_phase
                                                  p_dev_status, --dev_status
                                                  v_message1    --message
                                                  );
   ELSE
      xxfnd_common_pkg.log('Error submitting request:' || fnd_message.get);
   END IF;

   RETURN v_request_id;

END submit_request;

/***************************************************************************
**  FUNCTION
**    INITIALISE_RUN
**
**  DESCRIPTION
**    Records interface run results and is representative of a data batch.
**    This API is used to record the start of an interface run.  An interface
**    run may have many phases.  This API will be called at the very first
**    phase of the interface run, prior to the run phase being created.
***************************************************************************/
FUNCTION initialise_run
(
   p_int_code       IN xxfnd_int_interfaces.int_code%TYPE,
   p_src_code       IN xxfnd_int_data_sources.src_code%TYPE DEFAULT NULL,
   p_src_rec_count  IN xxfnd_int_runs.src_rec_count%TYPE DEFAULT NULL,
   p_src_hash_total IN xxfnd_int_runs.src_hash_total%TYPE DEFAULT NULL,
   p_src_batch_name IN xxfnd_int_runs.src_batch_name%TYPE DEFAULT NULL,
   p_run_id         IN xxfnd_int_runs.run_id%TYPE
) RETURN xxfnd_int_runs.run_id%TYPE IS

   l_run_id           NUMBER;
   l_int_id           NUMBER;
   l_current_user_id  NUMBER := NVL(Fnd_Profile.VALUE('USER_ID'), -1);
   l_current_login_id NUMBER := NVL(Fnd_Profile.VALUE('LOGIN_ID'), -1);
   l_request_id       NUMBER := NVL(FND_PROFILE.VALUE('CONC_REQUEST_ID'), -1);
   l_current_date     DATE;
   e_no_int_id        EXCEPTION;

   -- Cursor to get the interface id
   CURSOR c_get_int_id(b_i_int_code IN VARCHAR2) IS
      SELECT int_id
      FROM   xxfnd_int_interfaces
      WHERE  int_code = b_i_int_code;

   pragma autonomous_transaction;
BEGIN

   -- Get current date
   SELECT SYSDATE
   INTO   l_current_date
   FROM   dual;

   -- If run id is passed in then use that otherwise get the next value from the sequence
   IF p_run_id IS NULL THEN
      -- Get next sequence number
      SELECT xxfnd_int_runs_id_s.nextval
      INTO   l_run_id
      FROM   dual;
   ELSE
      l_run_id := p_run_id;
   END IF;

   --Get interface id
   OPEN c_get_int_id(p_int_code);
   FETCH c_get_int_id INTO l_int_id;
   IF c_get_int_id%NOTFOUND THEN
      RAISE e_no_int_id;
   END IF;
   CLOSE c_get_int_id;

   -- Insert into xxfnd_int_runs_table
   INSERT INTO xxfnd_int_runs
      (run_id,
       int_id,
       src_rec_count,
       src_hash_total,
       src_batch_name,
       created_by,
       creation_date,
       last_updated_by,
       last_update_date,
       last_update_login,
       request_id)
   VALUES
      (l_run_id, --run_id
       l_int_id, --int_id
       p_src_rec_count, --src_rec_count
       p_src_hash_total, --src_hash_total
       p_src_batch_name, --src_batch_name
       l_current_user_id, --created_by
       l_current_date, --creation_date
       l_current_user_id, --last_updated_by
       l_current_date, --last_update_date
       l_current_login_id, --last_update_login
       l_request_id --request_id
       );

   COMMIT;
   RETURN(l_run_id);

EXCEPTION
   WHEN e_no_int_id THEN
      xxfnd_common_pkg.log('ERROR in xxfnd_common_int_pkg.initialise_run: No Interface ID found');
      RAISE;
   WHEN OTHERS THEN
      xxfnd_common_pkg.log('ERROR in xxfnd_common_int_pkg.initialise_run: ' || SQLERRM);
      RAISE;
END initialise_run;
--
--
/***************************************************************************
**  PROCEDURE
**    UPDATE_RUN
**
**  DESCRIPTION
**    Records interface batch details.  This API is used to record batch
**    details on an existing interface run.  It will be used where the
**    information about the data batch are not available until the data
**    batch has been processed (the majority of cases) and hence cannot
**    be passed in the INITIALISE_RUN API.   This API will be called after
**    the run has been created when the run information is available.
***************************************************************************/
PROCEDURE update_run
(
   p_run_id         IN xxfnd_int_runs.run_id%TYPE,
   p_src_rec_count  IN xxfnd_int_runs.src_rec_count%TYPE,
   p_src_hash_total IN xxfnd_int_runs.src_hash_total%TYPE,
   p_src_batch_name IN xxfnd_int_runs.src_batch_name%TYPE
)
IS
   l_current_date     DATE;
   l_current_user_id  NUMBER := fnd_profile.VALUE('USER_ID');
   l_current_login_id NUMBER := fnd_profile.VALUE('LOGIN_ID');
   l_request_id       NUMBER := fnd_profile.VALUE('CONC_REQUEST_ID');

   pragma autonomous_transaction;
BEGIN

   SELECT SYSDATE
   INTO   l_current_date
   FROM   dual;

   UPDATE xxfnd_int_runs
   SET    src_rec_count = p_src_rec_count,
          src_hash_total = p_src_hash_total,
          src_batch_name = p_src_batch_name,
          last_updated_by = l_current_user_id,
          last_update_date = l_current_date,
          last_update_login = l_current_login_id,
          request_id = l_request_id
   WHERE  run_id = p_run_id;

   COMMIT;

EXCEPTION
   WHEN OTHERS THEN
      xxfnd_common_pkg.log('ERROR in xxfnd_common_int_pkg.update_run: ' || SQLERRM);
END update_run;

/***************************************************************************
**  FUNCTION
**    START_RUN_PHASE
**
**  DESCRIPTION
**    This API is used to record the individual interface phase run.
**    This API will be called at every stage in the interface.
***************************************************************************/
FUNCTION start_run_phase
(
   p_run_id                  IN xxfnd_int_runs.run_id%TYPE,
   p_phase_code              IN xxfnd_int_run_phases.phase_code%TYPE,
   p_phase_mode              IN xxfnd_int_run_phases.phase_mode%TYPE,
   p_src_code                IN xxfnd_int_data_sources.src_code%TYPE DEFAULT NULL,
   p_rec_count               IN xxfnd_int_run_phases.rec_count%TYPE DEFAULT NULL,
   p_hash_total              IN xxfnd_int_run_phases.hash_total%TYPE DEFAULT NULL,
   p_batch_name              IN xxfnd_int_run_phases.batch_name%TYPE DEFAULT NULL,
   p_int_table_name          IN xxfnd_int_run_phases.int_table_name%TYPE,
   p_int_table_key_col1      IN xxfnd_int_run_phases.int_table_key_col1%TYPE,
   p_int_table_key_col_desc1 IN xxfnd_int_run_phases.int_table_key_col_desc1%TYPE,
   p_int_table_key_col2      IN xxfnd_int_run_phases.int_table_key_col2%TYPE,
   p_int_table_key_col_desc2 IN xxfnd_int_run_phases.int_table_key_col_desc2%TYPE,
   p_int_table_key_col3      IN xxfnd_int_run_phases.int_table_key_col3%TYPE,
   p_int_table_key_col_desc3 IN xxfnd_int_run_phases.int_table_key_col_desc3%TYPE
)
RETURN xxfnd_int_run_phases.run_phase_id%TYPE
IS
   l_run_phase_id     NUMBER;
   l_current_date     DATE;
   l_current_user_id  NUMBER := NVL(Fnd_Profile.VALUE('USER_ID'), -1);
   l_current_login_id NUMBER := NVL(Fnd_Profile.VALUE('LOGIN_ID'), -1);
   l_request_id       NUMBER := NVL(FND_PROFILE.VALUE('CONC_REQUEST_ID'), -1);

   pragma autonomous_transaction;

BEGIN

   -- Get next sequence number
   SELECT xxfnd_int_run_phases_id_s.nextval
   INTO   l_run_phase_id
   FROM   dual;

   -- Get current date
   SELECT SYSDATE
   INTO   l_current_date
   FROM   dual;

   -- Insert record into table
   INSERT INTO xxfnd_int_run_phases
      (run_phase_id,
       run_id,
       phase_code,
       phase_mode,
       start_date,
       end_date,
       src_code,
       rec_count,
       hash_total,
       batch_name,
       status,
       error_count,
       success_count,
       int_table_name,
       int_table_key_col1,
       int_table_key_col_desc1,
       int_table_key_col2,
       int_table_key_col_desc2,
       int_table_key_col3,
       int_table_key_col_desc3,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by,
       last_update_login,
       request_id)
   VALUES
      (l_run_phase_id, --run_phase_id
       p_run_id, --run_id
       p_phase_code, --phase_code
       p_phase_mode, --phase_mode
       l_current_date, --start_date
       NULL, --end_date
       p_src_code, --src_code
       p_rec_count, --rec_count
       p_hash_total, --hash_total
       p_batch_name, --batch_name
       NULL, --status
       NULL, --error_count
       NULL, --success_count
       p_int_table_name, --int_table_name
       p_int_table_key_col1, --int_table_key_col1
       p_int_table_key_col_desc1, --int_table_key_col_desc1
       p_int_table_key_col2, --int_table_key_col2
       p_int_table_key_col_desc2, --int_table_key_col_desc2
       p_int_table_key_col3, --int_table_key_col3
       p_int_table_key_col_desc3, --int_table_key_col_desc3
       l_current_date, --creation_date
       l_current_user_id, --created_by
       l_current_date, --last_update_date
       l_current_user_id, --last_updated_by
       l_current_login_id, --last_update_login
       l_request_id --request_id
       );

   COMMIT;

   RETURN(l_run_phase_id);

EXCEPTION
   WHEN OTHERS THEN
      xxfnd_common_pkg.log('ERROR in xxfnd_common_int_pkg.start_run_phase: ' || SQLERRM);
      RETURN NULL;

END start_run_phase;

/***************************************************************************
**  PROCEDURE
**    UPDATE_RUN_PHASE
**
**  DESCRIPTION
**    This API is used to record details of the individual interface phase
**      run where they are not available at the point of starting run phase.
**
***************************************************************************/
PROCEDURE update_run_phase
(
   p_run_phase_id IN xxfnd_int_runs.run_id%TYPE,
   p_src_code     IN xxfnd_int_data_sources.src_code%TYPE,
   p_rec_count    IN xxfnd_int_run_phases.rec_count%TYPE,
   p_hash_total   IN xxfnd_int_run_phases.hash_total%TYPE,
   p_batch_name   IN xxfnd_int_run_phases.batch_name%TYPE
)
IS
   l_current_date     DATE;
   l_current_user_id  NUMBER := NVL(fnd_profile.VALUE('USER_ID'), -1);
   l_current_login_id NUMBER := NVL(fnd_profile.VALUE('LOGIN_ID'), -1);
   l_request_id       NUMBER := NVL(fnd_profile.VALUE('CONC_REQUEST_ID'), -1);
   pragma autonomous_transaction;
BEGIN
   SELECT SYSDATE
   INTO   l_current_date
   FROM   dual;

   UPDATE xxfnd_int_run_phases
   SET    end_date = l_current_date,
          src_code = p_src_code,
          rec_count = p_rec_count,
          hash_total = p_hash_total,
          batch_name = p_batch_name,
          last_updated_by = l_current_user_id,
          last_update_date = l_current_date,
          last_update_login = l_current_login_id,
          request_id = l_request_id
   WHERE  run_phase_id = p_run_phase_id;

   COMMIT;

EXCEPTION
   WHEN OTHERS THEN
      xxfnd_common_pkg.log('ERROR in xxfnd_common_int_pkg.update_run_phase: ' || SQLERRM);

END update_run_phase;

/***************************************************************************
**  PROCEDURE
**    END_RUN_PHASE
**
**  DESCRIPTION
**    Records interface phase run results and end of run.  This API is used
**    to record the results of an individual interface phase run.  This API
**    will be called at every stage in the interface, after processing has
**    taken place.
***************************************************************************/
PROCEDURE end_run_phase
(
   p_run_phase_id  IN xxfnd_int_run_phases.run_phase_id%TYPE,
   p_status        IN xxfnd_int_run_phases.status%TYPE,
   p_error_count   IN xxfnd_int_run_phases.error_count%TYPE,
   p_success_count IN xxfnd_int_run_phases.success_count%TYPE
) IS

   l_current_date     DATE;
   l_current_user_id  NUMBER := Fnd_Profile.VALUE('USER_ID');
   l_current_login_id NUMBER := Fnd_Profile.VALUE('LOGIN_ID');
   l_request_id       NUMBER := FND_PROFILE.VALUE('CONC_REQUEST_ID');

   pragma autonomous_transaction;
BEGIN

   -- Get current date
   SELECT SYSDATE
   INTO   l_current_date
   FROM   dual;

   UPDATE xxfnd_int_run_phases
   SET    end_date = l_current_date,
          status = p_status,
          error_count = p_error_count,
          success_count = p_success_count,
          last_updated_by = l_current_user_id,
          last_update_date = l_current_date,
          last_update_login = l_current_login_id,
          request_id = l_request_id
   WHERE  run_phase_id = p_run_phase_id;

   COMMIT;

EXCEPTION
   WHEN OTHERS THEN
      xxfnd_common_pkg.log('ERROR in xxfnd_common_int_pkg.end_run_phase: ' || SQLERRM);
END end_run_phase;

/***************************************************************************
**  PROCEDURE
**    RAISE_ERROR
**
**  DESCRIPTION
**    Records interface phase run errors.  This API is used to record validation
**    errors as they occur.  Data recorded is used for reporting and data
**    analysis purposes.
***************************************************************************/
PROCEDURE raise_error
(
   p_run_id             IN xxfnd_int_runs.run_id%TYPE,
   p_run_phase_id       IN xxfnd_int_run_phases.run_phase_id%TYPE,
   p_record_id          IN NUMBER,
   p_msg_code           IN xxfnd_int_messages.msg_code%TYPE,
   p_error_text         IN xxfnd_int_run_phase_errors.error_text%TYPE,
   p_error_token_val1   IN xxfnd_int_run_phase_errors.error_token_val1%TYPE,
   p_error_token_val2   IN xxfnd_int_run_phase_errors.error_token_val2%TYPE,
   p_error_token_val3   IN xxfnd_int_run_phase_errors.error_token_val3%TYPE,
   p_error_token_val4   IN xxfnd_int_run_phase_errors.error_token_val4%TYPE,
   p_error_token_val5   IN xxfnd_int_run_phase_errors.error_token_val5%TYPE,
   p_int_table_key_val1 IN xxfnd_int_run_phase_errors.int_table_key_val1%TYPE,
   p_int_table_key_val2 IN xxfnd_int_run_phase_errors.int_table_key_val2%TYPE,
   p_int_table_key_val3 IN xxfnd_int_run_phase_errors.int_table_key_val3%TYPE
) IS
   --
   l_run_phase_error_id NUMBER;
   l_current_date       DATE;
   l_current_user_id    NUMBER := Fnd_Profile.VALUE('USER_ID');
   l_current_login_id   NUMBER := Fnd_Profile.VALUE('LOGIN_ID');
   l_request_id         NUMBER := FND_PROFILE.VALUE('CONC_REQUEST_ID');
   --
   pragma autonomous_transaction;
BEGIN

   -- Get next sequence number
   SELECT xxfnd_int_run_phase_err_id_s.nextval
   INTO   l_run_phase_error_id
   FROM   dual;

   -- Get current date
   SELECT SYSDATE
   INTO   l_current_date
   FROM   dual;

   -- Insert record into table
   INSERT INTO xxfnd_int_run_phase_errors
      (error_id,
       run_id,
       run_phase_id,
       record_id,
       msg_code,
       error_text,
       error_token_val1,
       error_token_val2,
       error_token_val3,
       error_token_val4,
       error_token_val5,
       int_table_key_val1,
       int_table_key_val2,
       int_table_key_val3,
       created_by,
       creation_date,
       last_updated_by,
       last_update_date,
       last_update_login,
       request_id)
   VALUES
      (l_run_phase_error_id, --error_id
       p_run_id, --run_id
       p_run_phase_id, --run_phase_id
       p_record_id, --record_id
       p_msg_code, --msg_code
       p_error_text, --error_text
       p_error_token_val1, --error_token_val1
       p_error_token_val2, --error_token_val2
       p_error_token_val3, --error_token_val3
       p_error_token_val4, --error_token_val4
       p_error_token_val5, --error_token_val5
       p_int_table_key_val1, --int_table_key_val1
       p_int_table_key_val2, --int_table_key_val2
       p_int_table_key_val3, --int_table_key_val3
       l_current_user_id, --created_by
       l_current_date, --creation_date
       l_current_user_id, --last_updated_by
       l_current_date, --last_update_date
       l_current_login_id, --last_update_login
       l_request_id --request_id
       );

   COMMIT;

EXCEPTION
   WHEN OTHERS THEN
      xxfnd_common_pkg.log('ERROR in xxfnd_common_int_pkg.raise_error: ' || SQLERRM);

END raise_error;

/***************************************************************************
**  FUNCTION
**    GET_INT_TABLE_COUNT
**
**  DESCRIPTION
**    Returns the number of records in a given table for a particular Interface
**    Run Phase.
***************************************************************************/
FUNCTION get_int_table_count
(
   p_run_phase_id IN xxfnd_int_run_phases.run_phase_id%TYPE
)
RETURN NUMBER
IS
BEGIN
   RETURN 1;
END get_int_table_count;

/***************************************************************************
**  FUNCTION
**    RECORD_COUNT_VALID
**
**  DESCRIPTION
**    Compares a given record count value with the record count against the
**    run phase.  Returns true if they are equal, else false.
***************************************************************************/
FUNCTION record_count_valid
(
   p_run_phase_id IN xxfnd_int_run_phases.run_phase_id%TYPE,
   p_record_count IN NUMBER
)
RETURN BOOLEAN
IS
   l_phase_rec_count NUMBER;

   -- Cursor to get the record count from the Run Phase table
   CURSOR c_get_phase_rec_count(b_i_run_phase_id IN NUMBER) IS
      SELECT rec_count
      FROM   xxfnd_int_run_phases
      WHERE  run_phase_id = b_i_run_phase_id;
BEGIN

   OPEN c_get_phase_rec_count(p_run_phase_id);
   FETCH c_get_phase_rec_count
      INTO l_phase_rec_count;
   CLOSE c_get_phase_rec_count;

   IF l_phase_rec_count = p_record_count THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      xxfnd_common_pkg.log('ERROR in xxfnd_common_int_pkg.record_count_valid: ' || SQLERRM);
      RETURN FALSE;

END record_count_valid;

/***************************************************************************
**  FUNCTION
**    HASH_TOTAL_VALID
**
**  DESCRIPTION
**    Compares a given value with the hash total against the run phase.
**    Returns true if they are equal, else false.
***************************************************************************/
FUNCTION hash_total_valid
(
   p_run_phase_id IN xxfnd_int_run_phases.run_phase_id%TYPE,
   p_hash_total   IN NUMBER
)
RETURN BOOLEAN
IS
   l_phase_hash_total NUMBER;

   -- Cursor to get the Hash Total from the Run Phase table
   CURSOR c_get_hash_total(b_i_run_phase_id IN NUMBER) IS
      SELECT hash_total
      FROM   xxfnd_int_run_phases
      WHERE  run_phase_id = b_i_run_phase_id;

BEGIN

   OPEN c_get_hash_total(p_run_phase_id);
   FETCH c_get_hash_total INTO l_phase_hash_total;
   CLOSE c_get_hash_total;

   IF l_phase_hash_total = p_hash_total THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      xxfnd_common_pkg.log('ERROR in xxfnd_common_int_pkg.hash_total_valid: ' || SQLERRM);
      RETURN FALSE;

END hash_total_valid;

/***************************************************************************
**  FUNCTION
**    DATA_TYPE_NUMBER
**
**  DESCRIPTION
**    Provides data type check validation.  Returns true if a given value
**    can be converted to a Number data type, else false.
***************************************************************************/
FUNCTION data_type_number
(
   p_data IN VARCHAR2
)
RETURN BOOLEAN
IS
   l_num NUMBER;
BEGIN

   SELECT TO_NUMBER(p_data)
   INTO   l_num
   FROM   dual;

   RETURN TRUE;
EXCEPTION
   WHEN others THEN
      RETURN FALSE;
END data_type_number;

/***************************************************************************
**  FUNCTION
**    DATA_TYPE_DATE
**
**  DESCRIPTION
**    Provides data type check validation.  Returns true if a given value
**    can be converted to a Number data type, else false.
***************************************************************************/
FUNCTION data_type_date
(
   p_data          IN VARCHAR2,
   p_format_string IN VARCHAR2
)
RETURN BOOLEAN
IS
   l_date DATE;
BEGIN

   SELECT TO_DATE(p_data, p_format_string)
   INTO   l_date
   FROM   dual;

   RETURN TRUE;

EXCEPTION
   WHEN others THEN
      RETURN FALSE;

END data_type_date;

/***************************************************************************
**  PROCEDURE
**    ADD_NOTIF_USER
**
**  DESCRIPTION
**    API called to add the Notify option to a concurrent request given a
**      string of one or more recipients separated by ";".
***************************************************************************/

PROCEDURE add_notification
(
   pv_user_list  IN VARCHAR2 DEFAULT '',
   pv_on_normal  IN VARCHAR2 DEFAULT 'Y',
   pv_on_warning IN VARCHAR2 DEFAULT 'Y',
   pv_on_error   IN VARCHAR2 DEFAULT 'Y'
) IS
   --
   TYPE test_type IS TABLE OF VARCHAR2(100);
   --
   l_string      VARCHAR2(32767);
   l_comma_index PLS_INTEGER;
   l_index       PLS_INTEGER := 1;
   l_tab         test_type := test_type();
   l_boolean     BOOLEAN;
   --
BEGIN
   l_string := pv_user_list;

   --
   -- build table of users from semi colon separated list
   --
   IF (pv_user_list IS NOT NULL) THEN
      LOOP
         l_comma_index := instr(l_string, ';', l_index);

         IF l_comma_index = 0 THEN
            l_tab.extend;
            l_tab(l_tab.count) := LTRIM(TRIM(SUBSTR(l_string, l_index, LENGTH(l_string))));
            EXIT WHEN l_comma_index = 0;
         END IF;

         l_tab.extend;
         l_tab(l_tab.count) := SUBSTR(l_string, l_index, l_comma_index - l_index);
         l_index := l_comma_index + 1;
      END LOOP;

      -- loop through table of users and set notify
      FOR i IN 1 .. l_tab.COUNT LOOP
         l_boolean := fnd_request.add_notification(user       => l_tab(i),
                                                   on_normal  => pv_on_normal,
                                                   on_warning => pv_on_warning,
                                                   on_error   => pv_on_error);
      END LOOP;
   END IF;
END add_notification;

/***************************************************************************
**  FUNCTION
**    LAUNCH_ERROR_REPORT
**
**  DESCRIPTION
**    API is used to launch the Common Interface Errors report as a
**    concurrent request.
***************************************************************************/
FUNCTION launch_error_report
(
   p_run_id       IN xxfnd_int_runs.run_id%TYPE,
   p_run_phase_id IN xxfnd_int_run_phases.run_phase_id%TYPE,
   p_notify_user  IN VARCHAR2 DEFAULT NULL
)
RETURN fnd_concurrent_requests.request_id%TYPE
IS
   l_request_id     NUMBER;
   l_err_lay        BOOLEAN;
   l_interface_name VARCHAR2(240);

   -- Cursor to get the Interface Name
   CURSOR c_get_interface_name(b_i_run_id IN NUMBER) IS
      SELECT inf.int_name
      FROM   xxfnd_int_interfaces inf,
             xxfnd_int_runs irun
      WHERE  irun.int_id = inf.int_id
      AND    irun.run_id = b_i_run_id;

BEGIN
   -- Set the report template
   l_err_lay := fnd_request.add_layout('XXNZCL',
                                       'XXFND_CMNINT_INT_ERR_RPT',
                                       'en',
                                       'US',
                                       'PDF');

   -- Set the user to be notified
   IF (p_notify_user IS NOT NULL) THEN
      xxfnd_common_int_pkg.add_notification(pv_user_list => p_notify_user);
   END IF;

   -- Get the Interface Name
   OPEN c_get_interface_name(p_run_id);
   FETCH c_get_interface_name INTO l_interface_name;
   CLOSE c_get_interface_name;

   -- Submit the concurrent request
   l_request_id := FND_REQUEST.SUBMIT_REQUEST('XXNZCL',                       --application
                                              'XXFND_CMNINT_INT_ERR_RPT_XML', --program
                                              NULL,                           --description
                                              NULL,                           --start_time
                                              FALSE,                          --sub_request
                                              l_interface_name,               --argument1
                                              p_run_id,                       --argument2
                                              p_run_phase_id                  --argument3
                                              );

   -- need to commit to submit request.
   COMMIT;

   RETURN l_request_id;

EXCEPTION
   WHEN others THEN
      xxfnd_common_pkg.log('ERROR in xxfnd_common_int_pkg.launch_error_report: ' || SQLERRM);
      RETURN NULL;

END launch_error_report;

/***************************************************************************
**  FUNCTION
**    LAUNCH_RUN_REPORT
**
**  DESCRIPTION
**    API is used to launch the Common Interface Runs report as a
**    concurrent request.
***************************************************************************/
FUNCTION launch_run_report
(
   p_run_id      IN xxfnd_int_runs.run_id%TYPE,
   p_notify_user IN VARCHAR2
)
RETURN fnd_concurrent_requests.request_id%TYPE
IS
   l_request_id     NUMBER;
   l_run_lay        BOOLEAN;
   l_interface_name VARCHAR2(240);

   -- Cursor to get the Interface Name
   CURSOR c_get_interface_name(b_i_run_id IN NUMBER) IS
      SELECT inf.int_name
      FROM   xxfnd_int_interfaces inf,
             xxfnd_int_runs irun
      WHERE  irun.int_id = inf.int_id
      AND    irun.run_id = b_i_run_id;

BEGIN
   -- Set the report template
   l_run_lay := fnd_request.add_layout('XXNZCL',
                                       'XXFND_CMNINT_INT_RUN_RPT',
                                       'en',
                                       'US',
                                       'PDF');

   -- Set the user to be notified
   xxfnd_common_int_pkg.add_notification(pv_user_list => p_notify_user);

   -- Get the Interface Name
   OPEN c_get_interface_name(p_run_id);
   FETCH c_get_interface_name INTO l_interface_name;
   CLOSE c_get_interface_name;

   -- Submit the concurrent request
   l_request_id := fnd_request.submit_request('XXNZCL',                       --application
                                              'XXFND_CMNINT_INT_RUN_RPT_XML', --program
                                              NULL,                           --description
                                              NULL,                           --start_time
                                              FALSE,                          --sub_request
                                              l_interface_name,               --argument1
                                              p_run_id                        --argument2
                                              );

   -- need to commit to submit request.
   COMMIT;

   RETURN l_request_id;

EXCEPTION
   WHEN others THEN
      xxfnd_common_pkg.log('ERROR in xxfnd_common_int_pkg.launch_run_report: ' || SQLERRM);
      RETURN NULL;

END launch_run_report;
--
--
/***************************************************************************
**  FUNCTION
**    MOVE_FILE_PROCESS
**
**  DESCRIPTION
**    With an interface definition data directory structure, moves a file
**    from the ?New? directory to the ?Process? directory.
***************************************************************************/
FUNCTION move_file_process
(
   p_data_file_name        IN VARCHAR2,
   p_interface_new_dir     IN VARCHAR2,
   p_interface_process_dir IN VARCHAR2
)
RETURN BOOLEAN
IS
BEGIN
   utl_file.frename(UPPER(p_interface_new_dir),
                    p_data_file_name,
                    UPPER(p_interface_process_dir),
                    p_data_file_name,
                    TRUE);

   RETURN TRUE;

EXCEPTION
   WHEN others THEN
      xxfnd_common_pkg.log('Error in xxfnd_common_int_pkg.move_file_process: ' || SQLERRM);
      RETURN FALSE;

END move_file_process;

/***************************************************************************
**  FUNCTION
**    MOVE_FILE_ARCHIVE
**
**  DESCRIPTION
**    With an interface definition data directory structure, moves a file
**    from the ?Process? directory to the ?Archive? directory.
***************************************************************************/
FUNCTION move_file_archive
(
   p_data_file_name        IN VARCHAR2,
   p_interface_process_dir IN VARCHAR2,
   p_interface_archive_dir IN VARCHAR2,
   p_success_flag          IN VARCHAR2
)
-- 'Y' = success
-- 'N' = fail
RETURN BOOLEAN
IS
   --l_date_time   VARCHAR2(12);
   l_conc_request_id  NUMBER := fnd_global.conc_request_id;
   l_target_file_name VARCHAR2(150);
BEGIN
   -- Get current date/time
   --SELECT to_char(sysdate, 'yymmddhhmiss')
   --INTO l_date_time
   --FROM dual;
   IF p_success_flag = 'Y' THEN
      l_target_file_name := p_data_file_name || '_' || l_conc_request_id;
   ELSE
      l_target_file_name := p_data_file_name || '_' || l_conc_request_id || '.err';
   END IF;

   utl_file.frename(UPPER(p_interface_process_dir),
                    p_data_file_name,
                    UPPER(p_interface_archive_dir),
                    l_target_file_name,
                    TRUE);

   RETURN TRUE;

EXCEPTION
   WHEN others THEN
      xxfnd_common_pkg.log('Error in xxfnd_common_int_pkg.move_file_archive: ' || SQLERRM);
      RETURN FALSE;

END move_file_archive;

/***************************************************************************
**  FUNCTION
**    REPOINT_EXT_TABLE
**
**  DESCRIPTION
**    External tables are to be used to read from data files.  An external
**    name definition contains the reference to a particular file.  As there
**    is a requirement to be able to read from files with variable names,
**    the purpose of this API is to ?Alter? an external table to point to a
**    new data file.
***************************************************************************/
FUNCTION repoint_ext_table
(
   p_data_file_name      IN VARCHAR2,
   p_external_table_name IN all_tables.table_name%TYPE
)
RETURN BOOLEAN
IS
BEGIN
   EXECUTE IMMEDIATE 'alter table ' || p_external_table_name || ' location (''' || p_data_file_name || ''')';
   RETURN TRUE;
EXCEPTION
   WHEN others THEN
      RETURN FALSE;
END repoint_ext_table;

/***************************************************************************
**  FUNCTION
**    get_files_in_dir
**
**  DESCRIPTION
**    API is used to return an array containing the files that exist within
**    a given directory.
***************************************************************************/

FUNCTION get_files_in_dir
(
   p_directory_name IN VARCHAR2
)
RETURN xxfnd_dir_array
IS
LANGUAGE JAVA name 'au.net.redrock.common.utils.fileManager.listFiles(java.lang.String) return oracle.sql.ARRAY';

/***************************************************************************
**  FUNCTION
**    CHECK_FILE_EXISTS
**
**  DESCRIPTION
**    API is used to check if a given file exists within a given directory.
**    Returns True or False
***************************************************************************/
FUNCTION check_file_exists
(
   p_directory_name IN VARCHAR2,
   p_file_name      IN VARCHAR2
)
RETURN BOOLEAN
IS
   l_handle    utl_file.file_type;
BEGIN
   l_Handle := UTL_FILE.FOPEN(p_directory_name,
                              p_file_name,
                              'R');
   utl_file.fclose(l_Handle);

   RETURN TRUE;

EXCEPTION
   WHEN others THEN
      RETURN FALSE;

END check_file_exists;

/***************************************************************************
**  FUNCTION
**    DELETE_LOG_FILES
**
**  DESCRIPTION
**    API is used to check if a given file exists within a given directory.
**    Returns True or False
***************************************************************************/
FUNCTION delete_log_files
(
   p_directory_name IN VARCHAR2
)
RETURN BOOLEAN
IS
BEGIN
   RETURN TRUE;
END delete_log_files;

/***************************************************************************
**  PROCEDURE
**    GENERIC_RUN_PROCESS
**
**  DESCRIPTION
**    Used to run Common Interface interface programs.
**
**    This program was created as the filename parameter on an interface
**    program cannot change when scheduled.  Therefore standard scheduling
**    functionality cannot be used for interface programs.
**
**    An instance of this program must be scheduled for each individual
**    interface.
**
**    If multiple files are found in the interface directory, these are
**    processed sequentially.
**
**    This procedure is call from the concurrent program named:
**      - "Common Interface Scheduler Process (Custom)"
**
**    Currently this program works only for the following interfaces as the
**      remaining interfaces will be run on an adhoc / manual basis.
**
**      - Chris Payroll - Request Set (Custom)
**      - OIE01 MasterCard - Request Set (Custom)
**
**    If future interfaces are required to be scheduled and submitted
**      via this program, if the parameters passed in are different from those
**      of the interfaces above, this program will have to be amended.  The
**      concurrent program will also need to be amended to allow more
**      parameters to be passed in.
**
***************************************************************************/
PROCEDURE generic_run_process
(
   p_o_errbuff          OUT VARCHAR2,
   p_o_retcode          OUT VARCHAR2,
   p_srs_program_name   IN fnd_concurrent_programs.concurrent_program_name%TYPE,
   p_srs_directory_name IN all_directories.directory_name%TYPE,
   p_i_run_mode         IN VARCHAR2
) IS
   cv_proc_name          CONSTANT VARCHAR2(25) := 'generic_run_process';
   v_request_id          NUMBER;
   vn_file_count         NUMBER := 0;
   v_phase               VARCHAR2(240);
   v_status              VARCHAR2(240);
   v_dev_phase           VARCHAR2(240);
   v_dev_status          VARCHAR2(240);
   v_message1            VARCHAR2(240);
   vb_job_failed         BOOLEAN := FALSE;
   v_result              BOOLEAN;
   conc_program_failure  EXCEPTION;

   CURSOR fetch_files_cur(p_directory_name VARCHAR2) IS
      SELECT name file_name,
             modified,
             file_size
      FROM   TABLE(xxfnd_common_int_pkg.get_files_in_dir(p_directory_name))
      ORDER  BY modified ASC;

   v_file_name VARCHAR2(240);
BEGIN
   debug('p_srs_program_name: ' || p_srs_program_name, cv_proc_name);
   debug('p_srs_directory_name : ' || p_srs_directory_name, cv_proc_name);

   writerep('====================================================================');
   writerep(' Common Interface Scheduler Process');
   writerep(' ');
   writerep(' Start Date     : ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
   writerep(' Program Name   : ' || p_srs_program_name);
   writerep(' Directory Name : ' || p_srs_directory_name);
   writerep(' Run Mode       : ' || p_i_run_mode);
   writerep('====================================================================');
   writerep(' ');
   writerep(' Request ID    Filename                                  Date                  Size          Completion Status');
   writerep(' ============  ========================================  ====================  ============  ==================');

   FOR fetch_files_rec IN fetch_files_cur(p_directory_name => p_srs_directory_name) LOOP
      v_file_name := fetch_files_rec.file_name;
      debug('file name: ' || fetch_files_rec.file_name, cv_proc_name);

      v_request_id := fnd_request.submit_request('XXNZCL',                  --p_application
                                                 p_srs_program_name,        --program shortname
                                                 NULL,                      --p_srs_program_name -- description
                                                 NULL,                      --start_time
                                                 FALSE,                     --sub_request
                                                 fetch_files_rec.file_name, --p_argument1
                                                 p_i_run_mode               --p_argument2
                                                 );
      COMMIT;

      -- Wait for request to finish
      v_result := fnd_concurrent.wait_for_request(v_request_id, -- request_id
                                                  1,            -- interval
                                                  0,            -- max_wait
                                                  v_phase,      -- phase
                                                  v_status,     -- status
                                                  v_dev_phase,  -- dev_phase
                                                  v_dev_status, -- dev_status
                                                  v_message1    -- message
                                                  );

      writerep(' ' || RPAD(TO_CHAR(v_request_id), 12) || '  ' ||
                      SUBSTR(RPAD(fetch_files_rec.file_name, 40), 1, 40) || '  ' ||
                      TO_CHAR(fetch_files_rec.modified, 'DD-MON-YYYY HH24:MI:SS') || '  ' ||
                      SUBSTR(RPAD(TO_CHAR(fetch_files_rec.file_size), 12), 1, 12) || '  ' ||
                      RPAD(v_status, 18));

      IF v_dev_status != 'NORMAL' THEN
         vb_job_failed := TRUE;
      END IF;

      vn_file_count := vn_file_count + 1;
   END LOOP;

   IF (vn_file_count = 0) THEN
      writerep(' ');
      writerep(' *** No files found to process ***');
      writerep(' ');
   ELSE
      writerep(' ');
      writerep(' *** End of Report ***');
      writerep(' ');
   END IF;

   IF (vb_job_failed) THEN
      p_o_retcode := gv_cp_warning;
   ELSE
      p_o_retcode := gv_cp_success;
   END IF;

   writerep(' ');
   writerep(' End Date     : ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
   writerep(' ');

EXCEPTION
   WHEN others THEN
      p_o_retcode := gv_cp_error;
      writerep('Unexpected error occurred: ' || SQLERRM);
END generic_run_process;

/***************************************************************************
**  PROCEDURE
**    run_import_process
**
**  DESCRIPTION
**    Validate incoming file and initialize interface run.
***************************************************************************/
PROCEDURE run_import_process
(
   p_ctl_id   NUMBER,
   p_req_id   NUMBER
)
IS
   CURSOR c_fqueue IS
      SELECT file_name
      FROM   xxfnd_interface_ctl fq
      WHERE  fq.control_id = p_ctl_id
      AND    fq.request_id = p_req_id;

   l_fqueue        VARCHAR2(240);
   l_system_user   VARCHAR2(150);
   l_file_name     VARCHAR2(150);
   l_in_dir        VARCHAR2(240);
BEGIN
   fnd_profile.get('XXFND_INBOUND_BASWARE', l_in_dir);
   fnd_profile.get('XXFND_USER_BASWARE', l_system_user);

   OPEN c_fqueue;
   FETCH c_fqueue INTO l_fqueue;
   IF c_fqueue%FOUND THEN
      l_file_name := REPLACE(l_fqueue, l_in_dir, NULL);
      IF INSTR(l_file_name, 'Order') > 0 THEN
         --Initialize using Basware Purchasing responsibility
         --fnd_global.apps_initialize
         --SUBMIT_REQUEST: STG-TFM-LOAD
         NULL;
      ELSIF INSTR(l_file_name, 'Transfer') > 0 THEN
         --Initialize using Basware Payables responsibility
         --fnd_global.apps_initialize
         --SUBMIT_REQUEST: STG-TFM-LOAD
         NULL;
      END IF;
   END IF;
   CLOSE c_fqueue;

END run_import_process;

/***************************************************************************
**  PROCEDURE
**    stage_xml_file
**
**  DESCRIPTION
**    Inbound and outbound XML file staging. This routine will immediately
**    throw errors if XML file is not properly formatted.
***************************************************************************/
PROCEDURE stage_xml_file
(
   p_control_id   IN  NUMBER,
   p_request_id   IN  NUMBER,
   p_run_id       IN  NUMBER,
   p_file_name    IN  VARCHAR2,
   p_in_out       IN  VARCHAR2,
   p_object_type  IN  VARCHAR2,
   p_user_id      IN  NUMBER,
   p_status       OUT VARCHAR2,
   p_message      OUT VARCHAR2,
   p_record_id    OUT NUMBER
)
IS
   l_stg_dir       VARCHAR2(150) := 'BASWARE_STAGING_DIR';
   l_clob          CLOB;
   l_bfile         BFILE;
   l_bfile_csid    NUMBER  := 0;
   l_dest_offset   INTEGER := 1;
   l_src_offset    INTEGER := 1;
   l_lang_context  INTEGER := 0;
   l_warning       INTEGER := 0;
   l_record_id     NUMBER;

   pragma          autonomous_transaction;
BEGIN
   l_bfile := BFILENAME(l_stg_dir, p_file_name);

   dbms_lob.createtemporary(l_clob, TRUE);
   dbms_lob.fileopen(l_bfile, dbms_lob.file_readonly);

   dbms_lob.loadclobfromfile(dest_lob     => l_clob,
                             src_bfile    => l_bfile,
                             amount       => dbms_lob.lobmaxsize,
                             dest_offset  => l_dest_offset,
                             src_offset   => l_src_offset,
                             bfile_csid   => l_bfile_csid ,
                             lang_context => l_lang_context,
                             warning      => l_warning);

   dbms_lob.fileclose(l_bfile);

   SELECT xxfnd_interface_stg_rec_id_s.nextval
   INTO   l_record_id
   FROM   dual;

   -- remove extended characters
   l_clob := REPLACE(l_clob, CHR(255), NULL);
   l_clob := REPLACE(l_clob, CHR(239), NULL);
   l_clob := REPLACE(l_clob, CHR(187), NULL);
   l_clob := REPLACE(l_clob, CHR(191), NULL);

   INSERT INTO xxfnd_interface_stg
   VALUES (l_record_id,
           p_control_id,
           p_request_id,
           p_run_id,
           p_file_name,
           p_object_type,
           'BASWARE',
           NULL,
           'NEW',
           XMLTYPE.createXML(l_clob),
         --Convert to default character set is not required
         --XMLTYPE.createXML(convert(l_clob, 'UTF8', 'US7ASCII')), 
           p_in_out,
           NULL,
           NULL,
           SYSDATE,
           p_user_id,
           SYSDATE,
           p_user_id);
   COMMIT;

   dbms_lob.freetemporary(l_clob);

   p_record_id := l_record_id;
   p_status := 'S';

EXCEPTION
   WHEN others THEN
      ROLLBACK;
      p_status := 'E';
      p_message := SQLERRM;

END stage_xml_file;

END xxfnd_common_int_pkg;
/
