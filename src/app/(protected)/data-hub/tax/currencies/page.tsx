'use client'

import React, { useState, useEffect } from 'react';
import GenericCrudPage from '../CrudTemplate';

export default function CurrenciesPage() {
  const [countries, setCountries] = useState<any[]>([]);
  const [currencies, setCurrencies] = useState<any[]>([]);
  const [selectedCountryCode, setSelectedCountryCode] = useState<string>('');

  useEffect(() => {
    fetch('/api/data-hub/countries').then(r => r.json()).then(data => {
      setCountries(data);
      if (data.length > 0) setSelectedCountryCode(data[0].iso2);
    });
    fetch('/api/data-hub/tax/currencies').then(r => r.json()).then(data => {
      if (Array.isArray(data)) setCurrencies(data);
    });
  }, []);

  const selectedCountry = countries.find(c => c.iso2 === selectedCountryCode);
  const selectedCurrency = selectedCountry 
    ? currencies.find(c => c.iso_alpha_code === selectedCountry.default_currency_code)
    : null;

  const verificationCodes = ['INR', 'USD', 'EUR', 'GBP', 'JPY'];
  // Keep original order from verificationCodes
  const verificationCurrencies = verificationCodes
    .map(code => currencies.find(c => c.iso_alpha_code === code))
    .filter(Boolean);

  return (
    <div className="space-y-6">
      
      {/* Dynamic Country Selector */}
      <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6">
        <h2 className="text-xl font-bold text-white mb-4">Country Currency Resolver</h2>
        
        <div className="flex flex-col md:flex-row gap-6">
          <div className="w-full md:w-1/3">
            <label className="block text-sm text-zinc-400 mb-2">Select Country</label>
            <select 
              className="w-full bg-black border border-zinc-700 rounded p-2 text-white"
              value={selectedCountryCode}
              onChange={e => setSelectedCountryCode(e.target.value)}
            >
              <option value="">-- Select --</option>
              {countries.map(c => (
                <option key={c.iso2} value={c.iso2}>{c.display_name} ({c.iso2})</option>
              ))}
            </select>
          </div>
          
          <div className="w-full md:w-2/3">
            {selectedCountry && selectedCurrency ? (
              <div className="p-4 bg-black border border-zinc-800 rounded-lg flex items-center justify-between">
                <div>
                  <p className="text-zinc-400 text-sm">Official Currency</p>
                  <p className="text-xl text-white font-semibold">
                    {selectedCurrency.name} ({selectedCurrency.iso_alpha_code})
                  </p>
                </div>
                <div className="text-4xl text-green-400 font-mono">
                  {selectedCurrency.default_symbol}
                </div>
              </div>
            ) : selectedCountry ? (
              <div className="p-4 bg-black border border-zinc-800 rounded-lg flex items-center justify-center text-zinc-500">
                No active currency mapping found for this country.
              </div>
            ) : null}
          </div>
        </div>
      </div>

      {/* Major Currencies Verification Cards */}
      {verificationCurrencies.length > 0 && (
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
          {verificationCurrencies.map(c => (
            <div key={c.iso_alpha_code} className="p-4 rounded-xl border border-zinc-800 bg-zinc-900/50 flex flex-col items-center justify-center text-center">
              <div className="text-2xl text-green-400 font-mono mb-2">{c.default_symbol}</div>
              <div className="text-sm font-semibold text-white">{c.iso_alpha_code}</div>
              <div className="text-xs text-zinc-500 truncate w-full" title={c.name}>{c.name}</div>
            </div>
          ))}
        </div>
      )}

      {/* Main CRUD */}
      <GenericCrudPage
        title="Currencies Master"
        apiPath="/api/data-hub/tax/currencies"
        columns={[
          { key: 'iso_alpha_code', label: 'ISO Alpha' },
          { key: 'iso_numeric_code', label: 'ISO Numeric' },
          { key: 'name', label: 'Name' },
          { key: 'default_symbol', label: 'Default Symbol' },
          { key: 'native_symbol', label: 'Native Symbol' },
          { key: 'minor_units', label: 'Minor Units' }
        ]}
        defaultForm={{ iso_alpha_code: '', iso_numeric_code: '', name: '', default_symbol: '', native_symbol: '', minor_units: 2, status: 'ACTIVE' }}
      />
    </div>
  );
}
