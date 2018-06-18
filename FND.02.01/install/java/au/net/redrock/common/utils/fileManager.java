/****************************************************************************
**
**  $HeadURL: $
**
**  Purpose : Provides file management facilities that are difficult to
**              achieve in PL/SQL.  Specifically:
**
**              - directory listings
**
**  Author: DXC RED ROCK
**
**  $Date: $
**
**  $Revision: $
**
**  History  : Refer to Source Control
**
****************************************************************************/
-- $Id: $
--
create or replace and compile java source named "au.com.redrock.common.utils.fileManager" as

package au.com.redrock.common.utils;

import java.io.File;
import java.io.FilenameFilter;
import java.io.IOException;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.ResultSet;
import java.sql.PreparedStatement;
import java.sql.Timestamp;

import oracle.sql.ARRAY;
import oracle.sql.STRUCT;
import oracle.sql.ArrayDescriptor;
import oracle.sql.StructDescriptor;

import oracle.jdbc.driver.OracleDriver;

public class fileManager {

    private static Connection conn;

    static {
        try {
            conn = (new OracleDriver()).defaultConnection();
        } catch (SQLException e) {
            System.out.println(e);
        }
    }


    /**
     * List the files in the directory represented by the given Oracle DIRECTORY
     * object.
     *
     * @param dirname The name of the DIRECTORY object for which we want to list
     * the files (case sensitive).
     * @throws IOException
     * @throws SQLException
     */
    public static ARRAY listFiles(String dirname)
        throws IOException, SQLException {

        String dirpath = getDirectoryPath(dirname);
        File directory = getDirectory(dirpath);

        STRUCT[] ret = fileList(directory);

        // Create an array descriptor and return it.
        ArrayDescriptor desc = ArrayDescriptor.createDescriptor (
            "XXFND_DIR_ARRAY", conn);

        return new ARRAY(desc, conn, ret);
    }

    /**
     * Create a File object with the abstract pathname given by the parameter.
     *
     * @param dirpath The filesystem path of the directory
     * @throws IOException If the directory represented by this pathname does
     * not exist, or if it is a file.
     */
    private static File getDirectory(String dirpath) throws IOException {

        File directory = new File(dirpath);

        if(!directory.exists()) {
            throw new IOException("Directory: "+dirpath+" does not exist.");
        }
        if(!directory.isDirectory()) {
            throw new IOException("Path: "+dirpath+" is not a directory.");
        }

        return directory;
    }

    /**
     * Get the filesystem path for the Oracle DIRECTORY object given by the
     * input parameter.
     *
     * @param dir The name of the DIRECTORY object for which we want the path.
     * @throws IOException If there is no DIRECTORY object with the given name.
     */
    private static String getDirectoryPath(String dir)
        throws SQLException, IOException {
        String sql = "select directory_path from all_directories where " +
            "directory_name = ?";

        PreparedStatement s = conn.prepareStatement(sql);
        s.setString(1, dir);
        ResultSet rs = s.executeQuery();

        // There should be one row and one only.
        if(rs.next()) {
            return rs.getString(1);
        } else {
            throw new IOException("Directory object "+dir+" does not exist.");
        }

    }

    /**
     * Create an array of STRUCT objects representing the files in the given
     * directory.
     *
     * @param directory The File object representing the directory.
     * @throws SQLException
     */
    private static STRUCT[] fileList(File directory) throws SQLException {

        // Create the array of files to add.
        File[] files = directory.listFiles (
            new FilenameFilter() {
                // Accept all files
                public boolean accept(File dirpath, String name) {
                    return true;
                }
            }
        );

        // No files in directory
        if(files == null) {
            return null;
        }

        STRUCT[] ret = new STRUCT[files.length];

        // Create the struct entry for each file.
        for(int i=0; i<files.length; i++) {
            File f = files[i];
            StructDescriptor sd = StructDescriptor.createDescriptor ("XXFND_DIR_ENTRY", conn);
            Object[] attributes = {
                f.isDirectory() ? "D" : (f.isFile() ? "F" : "U"),
                f.canRead() ? "Y" : "N",
                f.canWrite() ? "Y" : "N",
                f.isHidden() ? "Y" : "N",
                new Long(f.length()),
                new Timestamp(f.lastModified()),
                f.getName()
            };
            STRUCT s = new STRUCT(sd, conn, attributes);
            ret[i] = s;
        }

        return ret;
    }

}
/
