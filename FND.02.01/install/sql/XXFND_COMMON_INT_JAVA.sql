/* $Header: $ */
DECLARE
   l_sql  VARCHAR2(32767);
BEGIN
l_sql := 
'create or replace and compile java source named "java_utl_file" as
import java.lang.*;
import java.util.*;
import java.io.*;
import java.sql.Timestamp;

public class java_utl_file
{
  private static int SUCCESS = 1;
  private static int FAILURE = 0;

  public static int copy (String fromPath, String toPath) {
    try {
          File fromFile = new File (fromPath);
          File toFile   = new File (toPath);

          InputStream  in  = new FileInputStream(fromFile);
          OutputStream out = new FileOutputStream(toFile);

          byte[] buf = new byte[1024];
          int len;
          while ((len = in.read(buf)) > 0) {
                out.write(buf, 0, len);
          }
          in.close();
          out.close();
          return SUCCESS;
    }
    catch (Exception ex) {
      return FAILURE;
    }
  }

  public static int delete (String path) {
    File myFile = new File (path);
    if (myFile.delete()) return SUCCESS; else return FAILURE;
  }  
  
};';
   EXECUTE IMMEDIATE l_sql;
END;
/
