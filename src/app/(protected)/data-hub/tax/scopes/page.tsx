'use client'

import React from 'react';
import GenericCrudPage from '../CrudTemplate';

export default function ScopesPage() {
  return (
    <GenericCrudPage
      title="Applicability Scopes"
      apiPath="/api/data-hub/tax/scopes"
      columns={[
        { key: 'country_id', label: 'Country ID' },
        { key: 'scope_type', label: 'Scope Type' },
        { key: 'priority', label: 'Priority' },
        { key: 'status', label: 'Status' }
      ]}
      defaultForm={{ country_id: '', scope_type: 'COUNTRY_WIDE', priority: 0, status: 'ACTIVE' }}
    />
  );
}
