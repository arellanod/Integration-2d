#!/bin/bash
# $Header:$
# ------------------------------------------------------------------------------
# Install script for CEMLI extension FND.02.01 
# Usage: FND.02.01_install.sh <apps_pwd> | tee FND.02.01_install.<instance>.log
# ------------------------------------------------------------------------------
CEMLI=FND.02.01
INSTSH=_install.sh
INSTLOG=_install.test.log

usage() {
  echo "Usage: $CEMLI$INSTSH <apps_pwd> | tee $CEMLI$INSTLOG"
  exit 1
}

# --------------------------------------------------------------
# Validate parameter
# --------------------------------------------------------------
if [ $# == 1 ]
then
  APPSPWD=$1
else
  usage
fi

APPSLOGIN=apps/$APPSPWD
DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

echo "Installing $CEMLI"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------

$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @./java/au/net/redrock/common/utils/fileManager.java
  @./sql/XXFND_COMMON_DDL.sql
  @./sql/XXFND_COMMON_INT_DDL.sql
  @./sql/XXFND_COMMON_INT_JAVA.sql
  show errors
  @./sql/XXFND_COMMON_PKG.pks
  show errors
  @./sql/XXFND_COMMON_PKG.pkb
  show errors
  @./sql/XXFND_COMMON_INT_PKG.pks
  show errors
  @./sql/XXFND_COMMON_INT_PKG.pkb
  show errors
  @./sql/XXFND_COMMON_INT_DML.sql
  EXIT
EOF

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------

IMPORT=$XXNZCL_TOP/import

## Concurrent Program 

FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORT/XXFND_CMNINT_INT_ERR_RPT_XML.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORT/XXFND_CMNINT_INT_RUN_RPT_XML.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORT/XXFND_CMNINT_INT_RUN_PROCESS.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORT/XXFNDFILEQUE.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORT/XXFNDFILEMVE.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE

## Request Group

FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORT/XXFND_CMNINT_INT_ERR_RPT_RG.ldt
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORT/XXFND_CMNINT_INT_RUN_RPT_RG.ldt
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORT/XXFND_CMNINT_INT_FILE_QUEUE.ldt

## Profile Option

FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afscprof.lct $IMPORT/XXFNDINBDIRP.ldt
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afscprof.lct $IMPORT/XXFNDOUTDIRP.ldt
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afscprof.lct $IMPORT/XXFNDSYSUSER.ldt

## BI Publisher Templates and Data Definitions

FNDLOAD $APPSLOGIN 0 Y UPLOAD $XDO_TOP/patch/115/import/xdotmpl.lct $IMPORT/XXFND_CMNINT_INT_ERR_RPT_DT.ldt
FNDLOAD $APPSLOGIN 0 Y UPLOAD $XDO_TOP/patch/115/import/xdotmpl.lct $IMPORT/XXFND_CMNINT_INT_RUN_RPT_DT.ldt

java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
-DB_USERNAME apps \
-DB_PASSWORD $APPSPWD \
-JDBC_CONNECTION $DBHOST:$DBPORT:$DBSID \
-LOB_TYPE DATA_TEMPLATE \
-APPS_SHORT_NAME XXNZCL \
-LOB_CODE XXFND_CMNINT_INT_ERR_RPT_XML \
-LANGUAGE en \
-TERRITORY 00 \
-XDO_FILE_TYPE XML \
-NLS_LANG en \
-FILE_NAME $IMPORT/XXFND_CMNINT_INT_RUN_ERR_RPT_XML.xml \
-CUSTOM_MODE FORCE \
-DEBUG true

java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
-DB_USERNAME apps \
-DB_PASSWORD $APPSPWD \
-JDBC_CONNECTION $DBHOST:$DBPORT:$DBSID \
-LOB_TYPE DATA_TEMPLATE \
-APPS_SHORT_NAME XXNZCL \
-LOB_CODE XXFND_CMNINT_INT_RUN_RPT_XML \
-LANGUAGE en \
-TERRITORY 00 \
-XDO_FILE_TYPE XML \
-NLS_LANG en \
-FILE_NAME $IMPORT/XXFND_CMNINT_INT_RUN_RPT_XML.xml \
-CUSTOM_MODE FORCE \
-DEBUG true

java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
-DB_USERNAME apps \
-DB_PASSWORD $APPSPWD \
-JDBC_CONNECTION $DBHOST:$DBPORT:$DBSID \
-LOB_TYPE TEMPLATE \
-APPS_SHORT_NAME XXNZCL \
-LOB_CODE XXFND_CMNINT_INT_ERR_RPT \
-LANGUAGE en \
-TERRITORY 00 \
-XDO_FILE_TYPE RTF \
-NLS_LANG en \
-FILE_NAME $IMPORT/XXFND_CMNINT_INT_RUN_ERR_RPT.rtf \
-CUSTOM_MODE FORCE \
-DEBUG true

java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
-DB_USERNAME apps \
-DB_PASSWORD $APPSPWD \
-JDBC_CONNECTION $DBHOST:$DBPORT:$DBSID \
-LOB_TYPE TEMPLATE \
-APPS_SHORT_NAME XXNZCL \
-LOB_CODE XXFND_CMNINT_INT_RUN_RPT \
-LANGUAGE en \
-TERRITORY 00 \
-XDO_FILE_TYPE RTF \
-NLS_LANG en \
-FILE_NAME $IMPORT/XXFND_CMNINT_INT_RUN_RPT.rtf \
-CUSTOM_MODE FORCE \
-DEBUG true

# --------------------------------------------------------------
# File permission and symbolic link
# --------------------------------------------------------------

chmod +x $XXNZCL_TOP/bin/XXFND_INTERFACE_CTL.prog
ln -s $FND_TOP/bin/fndcpesr $XXNZCL_TOP/bin/XXFND_INTERFACE_CTL

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0

