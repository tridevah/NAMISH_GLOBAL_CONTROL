'use client'

import React from 'react';
import GenericCrudPage from '../CrudTemplate';

export default function ScopeGeographiesPage() {
  return (
    <GenericCrudPage
      title="Applicability Scope Geographies"
      apiPath="/api/data-hub/tax/scope-geographies"
      columns={[
        { key: 'scope_id', label: 'Scope ID' },
        { key: 'geography_unit_id', label: 'Geo Unit ID' },
        { key: 'action', label: 'Action (INCLUDE/EXCLUDE)' },
        { key: 'includes_descendants', label: 'Descendants' }
      ]}
      defaultForm={{ scope_id: '', geography_unit_id: '', action: 'INCLUDE', includes_descendants: true }}
    />
  );
}
