CREATE OR REPLACE PACKAGE BODY xxfnd_common_pkg 
AS
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
) 
IS
BEGIN
   IF p_message = 'NEWLINE' THEN
      FND_FILE.NEW_LINE(FND_FILE.LOG, 1);
   ELSIF (p_newline) THEN
      FND_FILE.put_line(fnd_file.log, p_message);
   ELSE
      FND_FILE.put(fnd_file.log, p_message);
   END IF;
END log;

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
) 
IS
BEGIN
   IF p_message = 'NEWLINE' THEN
      FND_FILE.NEW_LINE(FND_FILE.output, 1);
   ELSIF (p_newline) THEN
      FND_FILE.put_line(fnd_file.output, p_message);
   ELSE
      FND_FILE.put(fnd_file.output, p_message);
   END IF;
END out;

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
) 
IS
   l_debug_id xxfnd_int_debug.debug_id%TYPE;
   pragma autonomous_transaction;
BEGIN

   SELECT xxfnd_int_debug_s.NEXTVAL
   INTO   l_debug_id
   FROM   dual;

   INSERT INTO xxfnd_int_debug
      (debug_id,
       message_date,
       procedure_name,
       debug_message,
       wf_item_type,
       wf_item_key)
   VALUES
      (l_debug_id,
       SYSDATE,
       p_procedure_name,
       p_debug_message,
       p_wf_item_type,
       p_wf_item_key);

   COMMIT;

EXCEPTION
   WHEN others THEN
      NULL;
   
END log_debug;

/***************************************************************************
**  FUNCTION
**    f_get_gl_calendar_name 
**
**  DESCRIPTION
**    Returns the Accounting Calendar Name 
***************************************************************************/

FUNCTION f_get_gl_calendar_name 
RETURN gl_periods.period_set_name%TYPE 
IS
BEGIN
   RETURN(gt_acct_calendar_name);
END f_get_gl_calendar_name;

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
RETURN NUMBER
AS LANGUAGE JAVA
NAME 'java_utl_file.copy (java.lang.String, java.lang.String) return java.lang.int';

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
RETURN NUMBER
AS LANGUAGE JAVA
NAME 'java_utl_file.delete (java.lang.String) return java.lang.int';

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
)
IS
   l_result         NUMBER;
   l_request_id     NUMBER;
   l_to             VARCHAR2(240);  -- Administrator Email (profile option)
   l_from           VARCHAR2(240);  -- Instance host name
   l_sql            VARCHAR2(600);
   l_subject        VARCHAR2(600);
   l_message_body   VARCHAR2(600);
BEGIN
   l_request_id := fnd_global.conc_request_id;

   -- Email parameters
   -- l_sql := 'SELECT instance_name || ''@'' || host_name FROM v$instance';
   l_sql := 'SELECT ''No-reply@'' || host_name FROM v$instance';
   EXECUTE IMMEDIATE l_sql INTO l_from;

   l_to := fnd_profile.value('XXFND_NOTIFICATION_EMAIL');
   l_subject := 'Concurrent Program Error: Request ID (' || l_request_id || ')';
   l_message_body := 'Error encountered while trying to move file from ' || p_file_from || ' to ' || p_file_to || '.';

   -- Copy command
   l_result := file_copy(p_file_from, p_file_to);

   IF l_result = 1 THEN
      fnd_file.put_line(fnd_file.log, 'Move file SUCCESS');
   ELSE
      fnd_file.put_line(fnd_file.log, 'Move file FAIL');

      send_mail(p_to      => l_to,
                p_from    => l_from,
                p_subject => l_subject,
                p_message => l_message_body);
   END IF;

   IF NVL(p_delete_flag, 'N') = 'Y' THEN
      l_result := file_delete(p_file_from);
      IF l_result = 1 THEN
         fnd_file.put_line(fnd_file.log, 'File has been deleted from source directory');
      ELSE
         fnd_file.put_line(fnd_file.log, 'Failed to delete file from source directory');
      END IF;
   END IF;
END move_file;

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
)
IS
   l_req_id    NUMBER;
BEGIN
   l_req_id := fnd_request.submit_request(application => 'XXNZCL',
                                          program => 'XXFND_MOVE_FILE',
                                          description => NULL,
                                          start_time => NULL,
                                          sub_request => FALSE,
                                          argument1 => p_file_from,
                                          argument2 => p_file_to,
                                          argument3 => p_delete_flag);
   COMMIT;
END submit_move_file; 

/***************************************************************************
**  FUNCTION
**    replace_string 
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
   p_string   VARCHAR2
)
RETURN VARCHAR2
IS
   l_return_string   VARCHAR2(4000);
   l_amp             VARCHAR2(1) := CHR(38);
   l_pipe            VARCHAR2(1) := CHR(124);
BEGIN
   SELECT REGEXP_REPLACE(SUBSTR(p_string, 1, 4000), '[^' || CHR(32) || '-' || CHR(126) || ']', '')
   INTO   l_return_string
   FROM   dual;

   -- Translate
   l_return_string := REPLACE(l_return_string, CHR(38), l_amp || 'amp;'); 
   l_return_string := REPLACE(l_return_string, CHR(33), l_amp || 'exclamation;');
   l_return_string := REPLACE(l_return_string, CHR(34), l_amp || 'quot;'); 
   l_return_string := REPLACE(l_return_string, CHR(37), l_amp || 'percent;'); 
   l_return_string := REPLACE(l_return_string, CHR(39), l_amp || 'apos;'); 
   l_return_string := REPLACE(l_return_string, CHR(43), l_amp || 'add;'); 
   l_return_string := REPLACE(l_return_string, CHR(60), l_amp || 'lt;'); 
   l_return_string := REPLACE(l_return_string, CHR(61), l_amp || 'equal;'); 
   l_return_string := REPLACE(l_return_string, CHR(62), l_amp || 'gt;');

   -- Remove
   l_return_string := REPLACE(l_return_string, l_pipe, NULL);

   RETURN TRIM(l_return_string);
END replace_string;

/***************************************************************************
**  FUNCTION
**    replace_string (overload)
**
**  DESCRIPTION
**    Function for removing extended ascii characters excluding new line
**    and carriage return.
***************************************************************************/
FUNCTION replace_string
(
   p_string   CLOB
)
RETURN CLOB
IS
   l_return_string   CLOB;
BEGIN
   SELECT REGEXP_REPLACE(p_string, '[^' || CHR(32) || '-' || CHR(126) || ']', '')
   INTO   l_return_string
   FROM   dual;

   RETURN TRIM(l_return_string);
END replace_string;

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
)
IS
   l_mail_conn   utl_smtp.connection;
BEGIN
   l_mail_conn := utl_smtp.open_connection(p_smtp_host, p_smtp_port);

   utl_smtp.helo(l_mail_conn, p_smtp_host);
   utl_smtp.mail(l_mail_conn, p_from);
   utl_smtp.rcpt(l_mail_conn, p_to);

   utl_smtp.open_data(l_mail_conn);
  
   utl_smtp.write_data(l_mail_conn, 'Date: ' || to_char(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || utl_tcp.crlf);
   utl_smtp.write_data(l_mail_conn, 'To: ' || p_to || utl_tcp.crlf);
   utl_smtp.write_data(l_mail_conn, 'From: ' || p_from || utl_tcp.crlf);
   utl_smtp.write_data(l_mail_conn, 'Subject: ' || p_subject || utl_tcp.crlf);
   utl_smtp.write_data(l_mail_conn, 'Reply-To: ' || p_from || utl_tcp.crlf || utl_tcp.crlf);
  
   utl_smtp.write_data(l_mail_conn, p_message || utl_tcp.crlf || utl_tcp.crlf);
   utl_smtp.close_data(l_mail_conn);

   utl_smtp.quit(l_mail_conn);

END send_mail;

END xxfnd_common_pkg;
/
