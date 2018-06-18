#!/bin/bash

CEMLI=PO.02.11

usage() {
  echo "Usage: ./PO.02.11_archive.sh <apps password>"
  exit 1
}

if [ $# == 1 ]
then
  APPSLOGIN=apps/$1
else
  usage
fi

SEQ_NO=`sqlplus -s $APPSLOGIN << !
set heading off
set feedback off
set pages 0
select xxnzcl.xxtar_seq_no.nextval seq_no from dual;
exit;
!`

REL_NUM="$(echo -e "${SEQ_NO}" | sed -e 's/^[[:space:]]*//')"

tar -cvf $CEMLI-R-$REL_NUM.tar install/PO.02.11_install.sh
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXPOIMPTBAS.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXPOIMPTM.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXPOREQGRP.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXPO_DOCUMENT_REFERENCES_DDL.sql
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXPO_DOCUMENT_REFERENCES_STG_DDL.sql
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXPO_PO_INTERFACE_STG_DDL.sql
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXPO_PO_INTERFACE_TFM_DDL.sql
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXPO_PURCHASE_ORDER_PKG.pks
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXPO_PURCHASE_ORDER_PKG.pkb

echo
echo TAR file $CEMLI-R-$REL_NUM.tar created.
echo

exit 0
