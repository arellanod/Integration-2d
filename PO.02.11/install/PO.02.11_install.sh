#!/bin/bash
# $Header:$
# ------------------------------------------------------------------------------
# Install script for CEMLI extension PO.02.11 
# Usage: PO.02.11_install.sh <apps_pwd> | tee PO.02.11_install.<instance>.log
# ------------------------------------------------------------------------------
CEMLI=PO.02.11
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
  @./sql/XXPO_DOCUMENT_REFERENCES_DDL.sql
  @./sql/XXPO_DOCUMENT_REFERENCES_STG_DDL.sql
  @./sql/XXPO_PO_INTERFACE_STG_DDL.sql
  @./sql/XXPO_PO_INTERFACE_TFM_DDL.sql
  @./sql/XXPO_PURCHASE_ORDER_PKG.pks
  show errors
  @./sql/XXPO_PURCHASE_ORDER_PKG.pkb  
  show errors
  EXIT
EOF

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------

IMPORT=$XXNZCL_TOP/import

## Concurrent Program 

FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORT/XXPOIMPTBAS.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORT/XXPOIMPTM.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE

## Request group

FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORT/XXPOREQGRP.ldt

## BI Publisher Templates and Data Definitions

# --------------------------------------------------------------
# File permission and symbolic link
# --------------------------------------------------------------

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0

