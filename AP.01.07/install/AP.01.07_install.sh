#!/bin/bash
# $Header:$
# ------------------------------------------------------------------------------
# Install script for CEMLI extension AP.01.07 
# Usage: AP.01.07_install.sh <apps_pwd> | tee AP.01.07_install.<instance>.log
# ------------------------------------------------------------------------------
CEMLI=AP.01.07
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

echo "Installing $CEMLI"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------

$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @./sql/XXAP_SUPPLIERS_XML_STG_DDL.sql
  @./sql/XXAP_SUPPLIERS_XML_PKG.pks
  @./sql/XXAP_SUPPLIERS_XML_PKG.pkb
  show errors
  EXIT
EOF

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------

IMPORT=$XXNZCL_TOP/import

## Concurrent Program 

FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORT/XXAPSUPPLIERS.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE

## Request group

FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORT/XXAPREQGRP.ldt
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORT/XXADMREQGRP.ldt

## BI Publisher Templates and Data Definitions

# --------------------------------------------------------------
# File permission and symbolic link
# --------------------------------------------------------------

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
