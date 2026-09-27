SELECT
  r.rolname,
  has_table_privilege(r.rolname, 'catalog.hsn_sac', 'SELECT') as can_select,
  has_table_privilege(r.rolname, 'catalog.hsn_sac', 'INSERT') as can_insert,
  has_table_privilege(r.rolname, 'catalog.hsn_sac', 'UPDATE') as can_update,
  has_table_privilege(r.rolname, 'catalog.hsn_sac', 'DELETE') as can_delete
FROM pg_roles r
WHERE r.rolname IN ('anon', 'authenticated', 'service_role')
ORDER BY r.rolname;
