#!/bin/bash

CEMLI=PO.01.12

usage() {
  echo "Usage: ./PO.01.12_archive.sh <apps password>"
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

tar -cvf $CEMLI-R-$REL_NUM.tar install/PO.01.12_install.sh
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXPOEPOXML.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXPOBASXML.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXPOREQGRP.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXADMREQGRP.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXPO_HEADERS_XML_V_DDL.sql
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXPO_LINES_XML_V_DDL.sql
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXPO_DISTRIBUTIONS_XML_V_DDL.sql
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXPO_RECEIPTS_XML_V_DDL.sql
tar -rvf $CEMLI-R-$REL_NUM.tar reports/US/XXPOEPOXML.rdf

echo
echo TAR file $CEMLI-R-$REL_NUM.tar created.

exit 0
