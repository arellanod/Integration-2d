#!/bin/bash

CEMLI=FND.02.01

usage() {
  echo "Usage: ./FND.02.01_archive.sh <apps password>"
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

tar -cvf $CEMLI-R-$REL_NUM.tar install/FND.02.01_install.sh
tar -rvf $CEMLI-R-$REL_NUM.tar bin/XXFND_INTERFACE_CTL.prog
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFNDINBDIRP.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFNDOUTDIRP.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFNDSYSUSER.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFND_CMNINT_INT_ERR_RPT_DT.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFND_CMNINT_INT_ERR_RPT_RG.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFND_CMNINT_INT_ERR_RPT_XML.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFND_CMNINT_INT_RUN_ERR_RPT.rtf
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFND_CMNINT_INT_RUN_ERR_RPT_XML.xml
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFND_CMNINT_INT_RUN_PROCESS.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFND_CMNINT_INT_RUN_RPT.rtf
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFND_CMNINT_INT_RUN_RPT_DT.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFND_CMNINT_INT_RUN_RPT_RG.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFND_CMNINT_INT_RUN_RPT_XML.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFND_CMNINT_INT_RUN_RPT_XML.xml
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFNDFILEQUE.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFNDFILEMVE.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar import/XXFND_CMNINT_INT_FILE_QUEUE.ldt
tar -rvf $CEMLI-R-$REL_NUM.tar install/java/au/net/redrock/common/utils/fileManager.java
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXFND_COMMON_DDL.sql
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXFND_COMMON_INT_DDL.sql
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXFND_COMMON_INT_DML.sql
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXFND_COMMON_INT_JAVA.sql
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXFND_COMMON_INT_PKG.pkb
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXFND_COMMON_INT_PKG.pks
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXFND_COMMON_PKG.pkb
tar -rvf $CEMLI-R-$REL_NUM.tar install/sql/XXFND_COMMON_PKG.pks
tar -rvf $CEMLI-R-$REL_NUM.tar sql/XXFND_INTERFACE_CTL.sql

echo
echo TAR file $CEMLI-R-$REL_NUM.tar created.
echo

exit 0
