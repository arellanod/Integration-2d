CREATE OR REPLACE PACKAGE BODY xxap_suppliers_xml_pkg AS

/****************************************************************************
**
**  $HeadURL: $
**
**  CEMLI ID: AP.01.07 - 2D Supplier XML File Creation
**
**  Author: Dart Arellano (DXC RED ROCK) 
**
**  $Date: $
**
**  $Revision: $
**
**  History: Refer to Source Control
**
****************************************************************************/

/* Stage SUPPLIER incremental updates */
FUNCTION populate_staging
(
   p_request_id           NUMBER, 
   p_include_org_id       VARCHAR2,
   p_file_name            VARCHAR2,
   p_object_type          VARCHAR2,
   p_object_source_table  VARCHAR2,
   p_test_data_flag       VARCHAR2,
   p_full_extract_flag    VARCHAR2
)
RETURN VARCHAR2
IS
   CURSOR c_supplier (p_last_run_date DATE) IS
      SELECT 1 rec_type,
             payee.supplier_site_id,
             payee.org_id
      FROM   iby_pmt_instr_uses_all instr_assign,
             iby_external_payees_all payee,
             iby_ext_bank_accounts bankacct,
             ce_bank_branches_v cebranch,
             hz_contact_points ibcp
      WHERE  instr_assign.instrument_id = bankacct.ext_bank_account_id
      AND    instr_assign.ext_pmt_party_id = payee.ext_payee_id
      AND    instr_assign.instrument_type = 'BANKACCOUNT'
      AND    instr_assign.payment_flow = 'DISBURSEMENTS'
      AND    payee.supplier_site_id IS NOT NULL
      AND    payee.payment_function = 'PAYABLES_DISB'
      AND    payee.org_type = 'OPERATING_UNIT'
      AND    bankacct.branch_id = cebranch.branch_party_id(+)
      AND    ibcp.owner_table_name(+) = 'HZ_PARTIES'
      AND    ibcp.owner_table_id(+) = bankacct.branch_id
      AND    ibcp.contact_point_type(+) = 'EFT'
      AND    NVL(ibcp.status(+), 'A') = 'A'
      AND    NVL(p_full_extract_flag, 'N') = 'N'
      AND    GREATEST(instr_assign.last_update_date,
                      payee.last_update_date,
                      bankacct.last_update_date,
                      NVL(ibcp.last_update_date, bankacct.last_update_date)) > p_last_run_date
      UNION ALL
      SELECT 2 rec_type,
             apsi.vendor_site_id supplier_site_id,
             apsi.org_id
      FROM   ap_supplier_sites_all apsi,
             ap_suppliers apsu
      WHERE  apsi.vendor_id = apsu.vendor_id
      AND    NVL(p_full_extract_flag, 'N') = 'N'
      AND    GREATEST(apsi.last_update_date, apsu.last_update_date) > p_last_run_date
      UNION ALL
      -- cater for future end dated suppliers
      SELECT 3 rec_type,
             apsi.vendor_site_id supplier_site_id,
             apsi.org_id
      FROM   ap_supplier_sites_all apsi,
             ap_suppliers apsu
      WHERE  apsi.vendor_id = apsu.vendor_id
      AND    NVL(p_full_extract_flag, 'N') = 'N'
      AND    ((apsu.end_date_active IS NOT NULL AND 
               apsu.end_date_active BETWEEN TRUNC(p_last_run_date) AND SYSDATE)
               OR
              (apsi.inactive_date IS NOT NULL AND 
               apsi.inactive_date BETWEEN TRUNC(p_last_run_date) AND SYSDATE))
      UNION ALL
      -- full extract
      SELECT 4 rec_type,
             apsi.vendor_site_id supplier_site_id,
             apsi.org_id
      FROM   ap_supplier_sites_all apsi,
             ap_suppliers apsu
      WHERE  apsi.vendor_id = apsu.vendor_id
      AND    NVL(p_full_extract_flag, 'N') = 'Y';

   CURSOR c_site (p_supplier_site_id  NUMBER) IS
      SELECT apsi.vendor_site_id,
             apsi.attribute_category,
             apsi.attribute1
      FROM   ap_supplier_sites_all apsi,
             ap_suppliers apsu      
      WHERE  apsi.vendor_id = apsu.vendor_id
      AND    apsi.vendor_site_id = p_supplier_site_id
      AND    (apsi.attribute1 IS NULL OR
             (apsi.attribute1 IS NOT NULL AND
              apsi.attribute1 IN (SELECT fvv.flex_value
                                  FROM   fnd_flex_value_sets fvs,
                                         fnd_flex_values fvv
                                  WHERE  fvs.flex_value_set_name = 'Supplier Category'
                                  AND    fvs.flex_value_set_name = apsi.attribute_category
                                  AND    fvs.flex_value_set_id = fvv.flex_value_set_id
                                  AND    fvv.attribute7 IS NOT NULL
                                  AND    (INSTR(fvv.attribute7, '01') > 0 OR 
                                          INSTR(fvv.attribute7, '06') > 0 OR
                                          INSTR(fvv.attribute7, '07') > 0)
                                  AND    fvv.value_category = 'Basware')));

   CURSOR c_admin (p_resp_id NUMBER) IS
      SELECT responsibility_id
      FROM   fnd_responsibility
      WHERE  responsibility_key = 'SYSTEM_ADMINISTRATOR'
      AND    responsibility_id = p_resp_id;

   CURSOR c_test (p_supplier_site_id  NUMBER) IS
      SELECT apsu.vendor_id
      FROM   ap_suppliers apsu,
             ap_supplier_sites_all apsi
      WHERE  apsu.vendor_id = apsi.vendor_id
      AND    apsi.vendor_site_id = p_supplier_site_id
      AND    apsu.segment1 IN ('4417', '1039', '4340', '6758',
                               '7196', '7390', '7555');

   r_supplier           c_supplier%ROWTYPE;
   r_site               c_site%ROWTYPE;
   l_row_count          NUMBER := 0;
   l_error              VARCHAR2(300);
   l_include_org_id     VARCHAR2(150) := TRIM(p_include_org_id);
   l_include_flag       VARCHAR2(1);
   l_last_run_date      DATE;
   l_sql                VARCHAR2(2000);
   l_resp_id            NUMBER := fnd_profile.value('RESP_ID');
   l_login_as           NUMBER;
   l_test_supplier      NUMBER;
   l_end_count          NUMBER;
   l_end_date_active    ap_suppliers.end_date_active%TYPE;
   l_inactive_date      ap_supplier_sites_all.inactive_date%TYPE;

   pragma               autonomous_transaction;
BEGIN
   IF SUBSTR(l_include_org_id, -1) = ',' THEN
      l_include_org_id := SUBSTR(l_include_org_id, 1, LENGTH(l_include_org_id) - 1);
   END IF;

   IF SUBSTR(l_include_org_id, 1, 1) = ',' THEN
      l_include_org_id := SUBSTR(l_include_org_id, 2, LENGTH(l_include_org_id));
   END IF;

   SELECT MAX(last_run_date)
   INTO   l_last_run_date
   FROM   xxfnd_interface_stg
   WHERE  object_type = p_object_type
   AND    object_source_table = p_object_source_table
   AND    in_out = 'OUT'
   AND    status = 'CREATED';

   IF l_last_run_date IS NULL THEN
      l_last_run_date := (SYSDATE - 1);
   END IF;

   OPEN c_supplier (l_last_run_date);
   LOOP
      FETCH c_supplier INTO r_supplier;
      EXIT WHEN c_supplier%NOTFOUND;

      r_site := NULL;
      l_test_supplier := NULL;
      l_include_flag := NULL;
      l_end_count := 0;

      IF c_site%ISOPEN THEN
         CLOSE c_site;
      END IF;

      OPEN c_site (r_supplier.supplier_site_id);
      FETCH c_site INTO r_site;
      IF c_site%NOTFOUND THEN
         CONTINUE;
      END IF;
      CLOSE c_site;

      IF NVL(p_test_data_flag, 'N') = 'Y' THEN
         OPEN c_test (r_supplier.supplier_site_id);
         FETCH c_test INTO l_test_supplier; 
         CLOSE c_test;

         IF l_test_supplier IS NULL THEN
            CONTINUE;
         END IF;
      END IF;

      BEGIN
         -----------------------------------
         -- arellanod 2018/07/06
         -- filter inactive suppliers
         -- <start>
         -----------------------------------
         SELECT su.end_date_active,
                si.inactive_date
         INTO   l_end_date_active,
                l_inactive_date
         FROM   ap_suppliers su,
                ap_supplier_sites_all si
         WHERE  su.vendor_id = si.vendor_id
         AND    si.vendor_site_id = r_supplier.supplier_site_id;

         IF l_end_date_active IS NOT NULL AND
            l_end_date_active < TRUNC(l_last_run_date) THEN
            l_end_count := l_end_count + 1;
         END IF;

         IF l_inactive_date IS NOT NULL AND
            l_inactive_date < TRUNC(l_last_run_date) THEN
            l_end_count := l_end_count + 1;
         END IF;
         -----------------------------------
         -- <end>
         -----------------------------------

         l_sql := 'SELECT ''Y'' FROM dual WHERE ' ||
                  r_supplier.org_id || 
                  ' IN (' ||
                  l_include_org_id || 
                  ')';

         EXECUTE IMMEDIATE l_sql INTO l_include_flag;

         IF (NVL(l_include_flag, 'N') = 'Y') AND (l_end_count = 0) 
         THEN
            INSERT INTO xxap_suppliers_xml_stg
            VALUES (p_request_id,
                    SYSDATE,
                    r_supplier.supplier_site_id,
                    r_supplier.org_id);

            l_row_count := l_row_count + 1;
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            NULL;
      END;
   END LOOP;

   IF (l_row_count > 0) AND
      (NVL(p_full_extract_flag, 'N') = 'N')
   THEN
      INSERT INTO xxfnd_interface_stg
             (record_id,
              control_id,
              request_id,
              file_name,
              object_type,
              object_source_table,
              status,
              in_out,
              last_run_date,
              creation_date,
              created_by,
              last_update_date,
              last_updated_by)
      VALUES (xxfnd_interface_stg_rec_id_s.nextval,
              xxfnd_interface_ctl_s.nextval,
              p_request_id,
              p_file_name,
              p_object_type,
              p_object_source_table,
              'STAGED',
              'OUT',
              SYSDATE,
              SYSDATE,
              fnd_global.user_id,
              SYSDATE,
              fnd_global.user_id);
   END IF;

   COMMIT;

   RETURN NULL;

EXCEPTION
   WHEN others THEN
      ROLLBACK;

      l_error := SQLERRM || ' ' ||
                 'Supplier XML File staging error [' ||
                 l_sql || '] ' || l_resp_id;

      RETURN l_error;
END populate_staging;

/* Get supplier site language setting */
FUNCTION get_language_code
(
   p_nls_lang   VARCHAR2
)
RETURN VARCHAR2
IS
   CURSOR c_nls IS
      SELECT fnl.language_code,
             b.nls_language,
             b.nls_territory,
             b.iso_language,
             b.iso_territory,
             b.nls_codeset,
             b.iso_language_3
      FROM   fnd_languages b,
             fnd_natural_languages fnl
      WHERE  fnl.iso_territory = b.iso_territory
      AND    nls_language = NVL(p_nls_lang, 'ENGLISH');

   r_nls     c_nls%ROWTYPE;
BEGIN
   OPEN c_nls;
   FETCH c_nls INTO r_nls;
   CLOSE c_nls;

   RETURN r_nls.language_code;
END get_language_code;

END xxap_suppliers_xml_pkg;
/
