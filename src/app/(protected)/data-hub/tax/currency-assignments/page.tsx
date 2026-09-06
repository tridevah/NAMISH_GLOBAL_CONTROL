'use client'

import React from 'react';
import GenericCrudPage from '../CrudTemplate';

export default function CurrencyAssignmentsPage() {
  return (
    <GenericCrudPage
      title="Currency Scope Assignments"
      apiPath="/api/data-hub/tax/currency-assignments"
      columns={[
        { key: 'currency_id', label: 'Currency ID' },
        { key: 'applicability_scope_id', label: 'Scope ID' },
        { key: 'usage', label: 'Usage' },
        { key: 'display_symbol', label: 'Display Symbol' },
        { key: 'status', label: 'Status' }
      ]}
      defaultForm={{ currency_id: '', applicability_scope_id: '', usage: 'LEGAL_TENDER', display_symbol: '', symbol_position: 'BEFORE_AMOUNT', space_between_symbol_and_amount: false, priority: 0, status: 'ACTIVE' }}
    />
  );
}
