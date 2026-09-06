'use client'

import React from 'react';
import GenericCrudPage from '../CrudTemplate';

export default function JurisdictionsPage() {
  return (
    <GenericCrudPage
      title="Tax Jurisdictions"
      apiPath="/api/data-hub/tax/jurisdictions"
      columns={[
        { key: 'country_id', label: 'Country ID' },
        { key: 'applicability_scope_id', label: 'Scope ID' },
        { key: 'code', label: 'Code' },
        { key: 'name', label: 'Name' }
      ]}
      defaultForm={{ country_id: '', applicability_scope_id: '', code: '', name: '' }}
    />
  );
}
