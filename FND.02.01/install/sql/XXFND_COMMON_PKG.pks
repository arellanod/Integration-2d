CREATE OR REPLACE PACKAGE xxfnd_common_pkg AS
/****************************************************************************
**
**  $HeadURL: $
**
**  Purpose: Common Utilities Package 
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
-- Concurrent Program Completion Values
--
gv_cp_success             CONSTANT VARCHAR2(1) := 0;
gv_cp_warning             CONSTANT VARCHAR2(1) := 1;
gv_cp_error               CONSTANT VARCHAR2(1) := 2;
gt_acct_calendar_name     CONSTANT gl_periods.period_set_name%TYPE := '';

/***************************************************************************
**  FUNCTION
**    log 
**
**  DESCRIPTION
**    Output the messages into Concurrent process's log file.
***************************************************************************/
PROCEDURE log
(
   p_message IN VARCHAR2,
   p_newline IN BOOLEAN DEFAULT TRUE
);

/***************************************************************************
**  FUNCTION
**    out 
**
**  DESCRIPTION
**    Output the messages into Concurrent process's output file.
***************************************************************************/
PROCEDURE out
(
   p_message IN VARCHAR2,
   p_newline IN BOOLEAN DEFAULT TRUE
);

/***************************************************************************
**  PROCEDURE
**    LOG_DEBUG
**
**  DESCRIPTION
**    Used to log custom debug messages into custom debug table.
***************************************************************************/         
PROCEDURE log_debug
(
   p_debug_message  IN VARCHAR2,
   p_procedure_name IN VARCHAR2 DEFAULT NULL,
   p_wf_item_type   IN VARCHAR2 DEFAULT NULL,
   p_wf_item_key    IN VARCHAR2 DEFAULT NULL
);

/***************************************************************************
**  FUNCTION
**    f_get_gl_calendar_name 
**
**  DESCRIPTION
**    Returns the Accounting Calendar Name 
***************************************************************************/
FUNCTION f_get_gl_calendar_name
RETURN gl_periods.period_set_name%type;

/***************************************************************************
**  FUNCTION
**    file_copy 
**
**  DESCRIPTION
**    File utility program (java) for copying files, from source to
**    destination. Parameters must contain the full absolute path 
**    including file name.
***************************************************************************/
FUNCTION file_copy 
(
   p_file_from  IN  VARCHAR2,
   p_file_to    IN  VARCHAR2
) 
RETURN NUMBER;

/***************************************************************************
**  FUNCTION
**    file_delete 
**
**  DESCRIPTION
**    File utility program (java) for deleting files. Parameter must contain
**    the full absolute path including file name.
***************************************************************************/
FUNCTION file_delete 
(
   p_file IN VARCHAR2
) 
RETURN NUMBER;

/***************************************************************************
**  PROCEDURE
**    move_file 
**
**  DESCRIPTION
**    Move file command executed as concurrent program.
**    
***************************************************************************/
PROCEDURE move_file
(
   p_errbuff      OUT VARCHAR2,
   p_retcode      OUT NUMBER,
   p_file_from    IN  VARCHAR2,
   p_file_to      IN  VARCHAR2,
   p_delete_flag  IN  VARCHAR2
);

/***************************************************************************
**  PROCEDURE
**    submit_move_file 
**
**  DESCRIPTION
**    Wrapper to run job from the calling program.
**    
***************************************************************************/
PROCEDURE submit_move_file
(
   p_file_from    IN VARCHAR2,
   p_file_to      IN VARCHAR2,
   p_delete_flag  IN VARCHAR2
);

/***************************************************************************
**  FUNCTION
**    replace_string 
**
**  DESCRIPTION
**    Function for removing extended ascii characters including new line
**    and carriage return.
**    
***************************************************************************/
FUNCTION replace_string
(
   p_string   VARCHAR2
)
RETURN VARCHAR2;

/***************************************************************************
**  FUNCTION
**    replace_string (overload)
**
**  DESCRIPTION
**    Function for removing extended ascii characters including new line
**    and carriage return.
**    
**  XML Entity Reference
**    &exclamation;   !   33
**    &quot;          "   34
**    &percent;       %   37
**    &amp;           &   38
**    &apos;          '   39
**    &add;           +   43
**    &lt;            <   60
**    &equal;         =   61
**    &gt;            >   62
***************************************************************************/
FUNCTION replace_string
(
   p_string   CLOB
)
RETURN CLOB;

/***************************************************************************
**  PROCEDURE
**    send_mail 
**
**  DESCRIPTION
**    Send FYI email directly through SMTP server.
**    
***************************************************************************/
PROCEDURE send_mail
(
   p_to         IN VARCHAR2,
   p_from       IN VARCHAR2,
   p_subject    IN VARCHAR2,
   p_message    IN VARCHAR2,
   p_smtp_host  IN VARCHAR2 DEFAULT 'mail.2degrees.nz',
   p_smtp_port  IN NUMBER DEFAULT 25
);

END xxfnd_common_pkg;
/
