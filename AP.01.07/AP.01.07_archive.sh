#!/bin/bash

CEMLI=AP.01.07

usage() {
  echo "Usage: ./AP.01.07_archive.sh <apps password>"
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

tar -cvf $CEMLI-R-$REL_NUM.tar install/AP.01.07_install.sh
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXAPREQGRP.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXADMREQGRP.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXAPSUPPLIERS.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXAP_SUPPLIERS_XML_STG_DDL.sql
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXAP_SUPPLIERS_XML_PKG.pks
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXAP_SUPPLIERS_XML_PKG.pkb
tar -rvf $CEMLI-R-$REL_NUM.tar reports/US/XXAPSUPPLIERS.rdf

echo
echo TAR file $CEMLI-R-$REL_NUM.tar created.
echo

exit 0
