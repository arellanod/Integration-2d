CREATE OR REPLACE PACKAGE xxfnd_common_int_pkg AS
/****************************************************************************
**
**  $HeadURL: $
**
**  Purpose: Common PL/SQL API's to be used for the Common Interface Framework.
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
/***************************************************************************
**  GLOBALS
***************************************************************************/
--
-- Interface Table "Status" field values. These are the only valid values.
--
gv_rec_status_new       CONSTANT VARCHAR2(25) := 'NEW';
gv_rec_status_processed CONSTANT VARCHAR2(25) := 'PROCESSED';
gv_rec_status_error     CONSTANT VARCHAR2(25) := 'ERROR';
--
-- Interface run phase completion status. These are the only valid values.
--
gv_phase_status_success CONSTANT VARCHAR2(25) := 'SUCCESS';
gv_phase_status_error   CONSTANT VARCHAR2(25) := 'ERROR';

/***************************************************************************
**  FUNCTION
**    get_run_id
**
**  DESCRIPTION
**    This API is used to get the interface run id
***************************************************************************/
FUNCTION get_run_id
RETURN xxfnd_int_runs.run_id%TYPE;

/***************************************************************************
**  FUNCTION
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
);

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
RETURN NUMBER;

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
);

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
   p_run_id         IN xxfnd_int_runs.run_id%TYPE DEFAULT NULL
)
RETURN xxfnd_int_runs.run_id%TYPE;

/***************************************************************************
**  PROCEDURE
**    GENERIC_RUN_PROCESS
**
**  DESCRIPTION
**    Run for any Interface process.
**  The procedure runs the associated interface program for all files found
**  in the NEW directory.
***************************************************************************/
PROCEDURE generic_run_process
(
   p_o_errbuff          OUT VARCHAR2,
   p_o_retcode          OUT VARCHAR2,
   p_srs_program_name   IN fnd_concurrent_programs.concurrent_program_name%TYPE,
   p_srs_directory_name IN all_directories.directory_name%TYPE,
   p_i_run_mode         IN VARCHAR2
);

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
);

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
) RETURN xxfnd_int_run_phases.run_phase_id%TYPE;


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
);


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
);


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
);

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
RETURN NUMBER;

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
RETURN BOOLEAN;

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
RETURN BOOLEAN;

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
RETURN BOOLEAN;

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
RETURN BOOLEAN;

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
RETURN fnd_concurrent_requests.request_id%TYPE;

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
   p_notify_user IN VARCHAR2 DEFAULT NULL
)
RETURN fnd_concurrent_requests.request_id%TYPE;

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
RETURN BOOLEAN;

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
RETURN BOOLEAN;

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
RETURN BOOLEAN;

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
RETURN xxfnd_dir_array;

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
RETURN BOOLEAN;

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
RETURN BOOLEAN;

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
);

/***************************************************************************
**  PROCEDURE
**    stage_xml_file
**
**  DESCRIPTION
**    Inbound and outbound XML file staging 
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
);

END xxfnd_common_int_pkg;
/
