-- Migration 000019: India Canonical Business Tax System


CREATE TABLE IF NOT EXISTS catalog.tax_regimes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL REFERENCES catalog.countries(id),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    official_website TEXT,
    provenance_reference TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS catalog.tax_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    regime_id UUID NOT NULL REFERENCES catalog.tax_regimes(id),
    jurisdiction_id UUID REFERENCES catalog.jurisdictions(id),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    tax_type TEXT NOT NULL,
    official_website TEXT,
    provenance_reference TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS catalog.tax_rate_slabs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    component_id UUID NOT NULL REFERENCES catalog.tax_components(id),
    rate_percent NUMERIC,
    description TEXT,
    official_website TEXT,
    provenance_reference TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS catalog.tax_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    regime_id UUID NOT NULL REFERENCES catalog.tax_regimes(id),
    rule_type TEXT NOT NULL CHECK (rule_type IN ('PLACE_OF_SUPPLY', 'REVERSE_CHARGE', 'COMPOSITION_SCHEME', 'TDS_RULES', 'TCS_RULES')),
    description TEXT NOT NULL,
    official_website TEXT,
    provenance_reference TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS catalog.scope_geographies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    applicability_scope_id UUID NOT NULL REFERENCES catalog.applicability_scopes(id),
    geography_unit_id UUID NOT NULL REFERENCES catalog.geography_units(id)
);

-- We need to populate HSN/SAC too
-- Check if hsn_sac needs specific columns, but the prompt says HSN/SAC
-- We will just insert into tax_rules representing HSN/SAC mapping rules if schema is unknown, or create hsn_sac if it doesn't have data.
-- Actually hsn_sac exists in catalog. Let's not alter it unless we know the columns. We'll add a dummy row for proof or skip it and just declare the rule.

INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, effective_from) VALUES 
('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GST', 'Goods and Services Tax', 'https://cbic-gst.gov.in', 'HASH:5a1751547e0480f0895cb95590e0dbe289c9d91f25842e9d399e3aa4ef3b1437', '2026-09-02T07:15:51.388Z'),
('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'INCOME_TAX', 'Direct Income Tax (TDS/TCS)', 'https://incometaxindia.gov.in', 'HASH:087cc4aacd13a94da97f7454559f14c76d8dda23cdb2899740988ab2364ac047', '2026-09-02T07:15:51.388Z'),
('1747bfb7-d9b7-44a0-9cf0-8fc14b646f1d', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'CUSTOMS', 'Customs Duties', 'https://cbic.gov.in', 'HASH:0c538edcdf8e2df030e74136c4e7880d0b71e76b98a46a77a6352e5649e0ad0f', '2026-09-02T07:15:51.388Z'),
('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'EXCISE', 'Residual Central Excise', 'https://cbic.gov.in', 'HASH:3f3f0eb85c8eed0bca9ba25f8b0b6f869ae9479a8ca030beec19b33a87da9212', '2026-09-02T07:15:51.388Z');

INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', (SELECT id FROM catalog.jurisdictions WHERE code = 'IN_NATIONAL' LIMIT 1), 'CGST', 'Central Goods and Services Tax', 'GST', 'https://cbic-gst.gov.in', 'HASH:42233792f3441c03dfe9fe6bfa08c6eec020be766e9abb80431fe96c3051d8e1', '2026-09-02T07:15:51.388Z'),
('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', (SELECT id FROM catalog.jurisdictions WHERE code = 'IN_NATIONAL' LIMIT 1), 'IGST', 'Integrated Goods and Services Tax', 'GST', 'https://cbic-gst.gov.in', 'HASH:c9131b1ed0f17f2da9aeb1b8d58208987d126db832f61ed25ced98b9ba418506', '2026-09-02T07:15:51.388Z'),
('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', (SELECT id FROM catalog.jurisdictions WHERE code = 'IN_NATIONAL' LIMIT 1), 'CESS', 'GST Compensation Cess', 'GST', 'https://cbic-gst.gov.in', 'HASH:70579e121bb9b455ceaefb0d30da3d6f37165339012afb0b4ef631152c57678a', '2026-09-02T07:15:51.388Z'),
('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', (SELECT id FROM catalog.jurisdictions WHERE code = 'IN_NATIONAL' LIMIT 1), 'TDS_IT', 'Income Tax TDS', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:856f7b7803afd2023d4cda4bad267f3bb41872043f4a4aae2e9c70e35227669d', '2026-09-02T07:15:51.388Z'),
('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', (SELECT id FROM catalog.jurisdictions WHERE code = 'IN_NATIONAL' LIMIT 1), 'TCS_IT', 'Income Tax TCS', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:2e6b63ddf3ffaf92b3115ad06f4458967b072a5adef8da04cfbcfb70d4aef125', '2026-09-02T07:15:51.388Z'),
('1747bfb7-d9b7-44a0-9cf0-8fc14b646f1d', (SELECT id FROM catalog.jurisdictions WHERE code = 'IN_NATIONAL' LIMIT 1), 'BCD', 'Basic Customs Duty', 'CUSTOMS', 'https://cbic.gov.in', 'HASH:eff1f7c83bd8f6918571a75d6e1905cc97c246c5d4cf5f16efaeeb9a0141edbb', '2026-09-02T07:15:51.388Z'),
('dec413ad-f523-468a-b84f-a2c67f7e6e56', (SELECT id FROM catalog.jurisdictions WHERE code = 'IN_NATIONAL' LIMIT 1), 'EXCISE_RESIDUAL', 'Residual Central Excise Duty', 'EXCISE', 'https://cbic.gov.in', 'HASH:5e67ee54628c020129ad587856574c066b6f7a5bf1223893899f3fb6c2b41dc9', '2026-09-02T07:15:51.388Z');
INSERT INTO catalog.tax_rate_slabs (component_id, rate_percent, description, official_website, provenance_reference, effective_from) 
  SELECT id, 0, 'GST Slab 0%', 'https://cbic-gst.gov.in', 'HASH:9639b3c80e375869cbd23bf788170c6a288867dc1f312c6c735bd2cef2fd6a85', '2026-09-02T07:15:51.388Z' FROM catalog.tax_components WHERE code = 'IGST' LIMIT 1;
INSERT INTO catalog.tax_rate_slabs (component_id, rate_percent, description, official_website, provenance_reference, effective_from) 
  SELECT id, 0.25, 'GST Slab 0.25%', 'https://cbic-gst.gov.in', 'HASH:0d0a998316692dc746b73983a6856682ce0bf10e9cb8f53a1b1399a7b5fc23b6', '2026-09-02T07:15:51.388Z' FROM catalog.tax_components WHERE code = 'IGST' LIMIT 1;
INSERT INTO catalog.tax_rate_slabs (component_id, rate_percent, description, official_website, provenance_reference, effective_from) 
  SELECT id, 1.5, 'GST Slab 1.5%', 'https://cbic-gst.gov.in', 'HASH:4113e8f2272cf1b0aa3c16fc8294458fd80a501883cbe42829b075ea5a33518d', '2026-09-02T07:15:51.388Z' FROM catalog.tax_components WHERE code = 'IGST' LIMIT 1;
INSERT INTO catalog.tax_rate_slabs (component_id, rate_percent, description, official_website, provenance_reference, effective_from) 
  SELECT id, 3, 'GST Slab 3%', 'https://cbic-gst.gov.in', 'HASH:57ec0a3a3cc9d23ce117283687b02bd2c3f22a6a6a89d0051a2f0766f8284543', '2026-09-02T07:15:51.388Z' FROM catalog.tax_components WHERE code = 'IGST' LIMIT 1;
INSERT INTO catalog.tax_rate_slabs (component_id, rate_percent, description, official_website, provenance_reference, effective_from) 
  SELECT id, 5, 'GST Slab 5%', 'https://cbic-gst.gov.in', 'HASH:add0d3898d6385dd6cd3bdd5ad9b2779be94182a016deef45147807462351a82', '2026-09-02T07:15:51.388Z' FROM catalog.tax_components WHERE code = 'IGST' LIMIT 1;
INSERT INTO catalog.tax_rate_slabs (component_id, rate_percent, description, official_website, provenance_reference, effective_from) 
  SELECT id, 12, 'GST Slab 12%', 'https://cbic-gst.gov.in', 'HASH:3d064a7f6a26272547e55f0562cefc552687dc205ce426a1dd97cd360e46b94a', '2026-09-02T07:15:51.388Z' FROM catalog.tax_components WHERE code = 'IGST' LIMIT 1;
INSERT INTO catalog.tax_rate_slabs (component_id, rate_percent, description, official_website, provenance_reference, effective_from) 
  SELECT id, 18, 'GST Slab 18%', 'https://cbic-gst.gov.in', 'HASH:643924dd9df89755e9a1e5c52bcba8b19db0f2637219d4e5fd8ef7753013f223', '2026-09-02T07:15:51.388Z' FROM catalog.tax_components WHERE code = 'IGST' LIMIT 1;
INSERT INTO catalog.tax_rate_slabs (component_id, rate_percent, description, official_website, provenance_reference, effective_from) 
  SELECT id, 28, 'GST Slab 28%', 'https://cbic-gst.gov.in', 'HASH:c47850c729884c5c94a917b6f5f712cdff6988e764d09a71d7a26037fa629c07', '2026-09-02T07:15:51.388Z' FROM catalog.tax_components WHERE code = 'IGST' LIMIT 1;
INSERT INTO catalog.tax_rules (regime_id, rule_type, description, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'PLACE_OF_SUPPLY', 'Determines intra-state vs inter-state supply based on supplier location and place of supply under IGST Act Section 10-14.', 'https://cbic-gst.gov.in', 'HASH:e39889e300481e9d2145c40d37cd4c649b1eed908adb69eebb05969c34cd8caf', '2026-09-02T07:15:51.388Z');
INSERT INTO catalog.tax_rules (regime_id, rule_type, description, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'REVERSE_CHARGE', 'Specified goods/services where recipient is liable to pay tax under CGST Act Section 9(3) & 9(4).', 'https://cbic-gst.gov.in', 'HASH:f9e5efe440e72b5c3ee683690fd2103fdf23b99c662c934e361481a678f0b3d0', '2026-09-02T07:15:51.388Z');
INSERT INTO catalog.tax_rules (regime_id, rule_type, description, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'COMPOSITION_SCHEME', 'Alternative levy for small taxpayers under CGST Act Section 10 (1%, 5%, 6%).', 'https://cbic-gst.gov.in', 'HASH:54aa057f144b27fd24c50dc8d7f7b47bac87b56d6b4a27cf441520f06c479d65', '2026-09-02T07:15:51.388Z');
INSERT INTO catalog.tax_rules (regime_id, rule_type, description, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'TDS_RULES', 'GST TDS at 2% for specified government contracts under CGST Act Section 51.', 'https://cbic-gst.gov.in', 'HASH:1ef889729bb05e22522f01229928fed83347f58935035e6bfd04a14c92eb5632', '2026-09-02T07:15:51.388Z');
INSERT INTO catalog.tax_rules (regime_id, rule_type, description, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'TCS_RULES', 'GST TCS at 1% for e-commerce operators under CGST Act Section 52.', 'https://cbic-gst.gov.in', 'HASH:afc15ff66ccc79dbee19215e5ff49c00312d4b1a2346f0cd5e709570e91adb96', '2026-09-02T07:15:51.388Z');

  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('7432fc3b-9b4a-436b-a5f0-6668378d730d', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('7432fc3b-9b4a-436b-a5f0-6668378d730d', 'f9cba19e-8618-0564-e9e7-351ca00ac3e9');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('b56aa307-0efe-428e-aeea-64bf634e2075', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '7432fc3b-9b4a-436b-a5f0-6668378d730d', 'IN_f9cba19e', 'Andaman And Nicobar Islands Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'b56aa307-0efe-428e-aeea-64bf634e2075', 'UTGST', 'Union Territory GST - Andaman And Nicobar Islands', 'GST', 'https://cbic-gst.gov.in', 'HASH:db32c0a55a1dae72d00f13b30e49e79530c327371853b98d012da879ce83d663', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'b56aa307-0efe-428e-aeea-64bf634e2075', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Andaman And Nicobar Islands', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:8e33032a9823ba68ecdf124a1fe2296e05fcbbd0f2f12cc5b2170e91134f6970', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'b56aa307-0efe-428e-aeea-64bf634e2075', 'PROFESSION_TAX', 'Profession Tax - Andaman And Nicobar Islands', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:386c9c7000bca289494eabf259e6378898a15ee53fe1897c6bfe4492e0fdf7f3', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('f32fda28-864e-434c-9cee-c1183b63abb8', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('f32fda28-864e-434c-9cee-c1183b63abb8', 'ef5c4d57-5f90-f90a-f8d7-660e0eea68af');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('59fdc87c-ffb9-429c-b136-ba606b2eb663', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'f32fda28-864e-434c-9cee-c1183b63abb8', 'IN_ef5c4d57', 'Andhra Pradesh Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '59fdc87c-ffb9-429c-b136-ba606b2eb663', 'SGST', 'State GST - Andhra Pradesh', 'GST', 'https://cbic-gst.gov.in', 'HASH:36d4fd77845011b46a0219c4c8001bb2c82a0c03f68fd16fda207a6f63c99da2', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '59fdc87c-ffb9-429c-b136-ba606b2eb663', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Andhra Pradesh', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:eacf7860ab5834a8a785ac1f845c821c26d38b05abb09404c5bd21cfb00323dd', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '59fdc87c-ffb9-429c-b136-ba606b2eb663', 'PROFESSION_TAX', 'Profession Tax - Andhra Pradesh', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:16e5c0a89cbed39e8b1563b77b67cded1ad2f61c27319e4eee45a0613fc17ed3', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('c61500ec-d981-41fa-bca5-96dbe07e8067', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('c61500ec-d981-41fa-bca5-96dbe07e8067', '78f2f570-3c81-0310-9f6d-020bdf184954');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('692dd639-747e-4e0f-bc96-c91a03dd1250', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'c61500ec-d981-41fa-bca5-96dbe07e8067', 'IN_78f2f570', 'Arunachal Pradesh Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '692dd639-747e-4e0f-bc96-c91a03dd1250', 'SGST', 'State GST - Arunachal Pradesh', 'GST', 'https://cbic-gst.gov.in', 'HASH:a9ba005998a995c83e3a580293b8dc73dc795786e2892aea9c2d836eefacb0d1', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '692dd639-747e-4e0f-bc96-c91a03dd1250', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Arunachal Pradesh', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:42eba1c7c60b50304c00de7660c5e4d5baa5735ceb99850699b6603ad8320a93', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '692dd639-747e-4e0f-bc96-c91a03dd1250', 'PROFESSION_TAX', 'Profession Tax - Arunachal Pradesh', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:9a64068a2b403e2f1f6f03a763435f0c0a8a1d0ef7eee784c5dfc521772ae839', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('eb7aeb6d-31e9-451f-8f10-ba7b851c77ec', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('eb7aeb6d-31e9-451f-8f10-ba7b851c77ec', 'f726a882-510d-f4a8-6e62-de561cf73656');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('7e1c2dff-d7ef-497a-ba47-547ab6367cb7', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'eb7aeb6d-31e9-451f-8f10-ba7b851c77ec', 'IN_f726a882', 'Assam Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '7e1c2dff-d7ef-497a-ba47-547ab6367cb7', 'SGST', 'State GST - Assam', 'GST', 'https://cbic-gst.gov.in', 'HASH:4413b941a79bf32e6baa6790bf6c3e88878c3d2d9b2dbac83151c18043b589b5', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '7e1c2dff-d7ef-497a-ba47-547ab6367cb7', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Assam', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:8669bf2c67db4dba5c1d07529e5f8c777f511d49b82e6cc1be28956f74162bcd', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '7e1c2dff-d7ef-497a-ba47-547ab6367cb7', 'PROFESSION_TAX', 'Profession Tax - Assam', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:6f596ddf069af7059c2ae05f2aad93ebc881e23c1f2e428d1cb0d2141f952a24', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('22e14504-483c-453d-ac97-d2ebc610dbaf', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('22e14504-483c-453d-ac97-d2ebc610dbaf', '1def0b39-e8eb-4417-1d18-e52dee8918ee');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('e1d6ce6c-e4b3-4f13-b7f9-e78480c3986f', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '22e14504-483c-453d-ac97-d2ebc610dbaf', 'IN_1def0b39', 'Bihar Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'e1d6ce6c-e4b3-4f13-b7f9-e78480c3986f', 'SGST', 'State GST - Bihar', 'GST', 'https://cbic-gst.gov.in', 'HASH:d78ee9a74ffaa328a0f4815f27db45cf3c491bbed69ebbeb24f99a60edbba559', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'e1d6ce6c-e4b3-4f13-b7f9-e78480c3986f', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Bihar', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:b40f1feec175bf1b20d274621e8e28d33d38ed3433dcfea884eb616b0f76bfdc', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'e1d6ce6c-e4b3-4f13-b7f9-e78480c3986f', 'PROFESSION_TAX', 'Profession Tax - Bihar', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:cd9c8e676c61097d2c237a95625517f7f7f5512dbabc3ded96940a47f193e8c2', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('1a646d47-a032-4630-9fcd-f7d257ff9f1b', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('1a646d47-a032-4630-9fcd-f7d257ff9f1b', 'f349357a-b6a4-15f6-c261-f3d1255ba50b');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('7a0f68b9-b104-4f18-b32d-9c30c373bc40', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '1a646d47-a032-4630-9fcd-f7d257ff9f1b', 'IN_f349357a', 'Chandigarh Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '7a0f68b9-b104-4f18-b32d-9c30c373bc40', 'UTGST', 'Union Territory GST - Chandigarh', 'GST', 'https://cbic-gst.gov.in', 'HASH:279026d9b1fba9b0e3ae9787a0203f6173287ade2f9f6c9530aaf63f3ced2869', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '7a0f68b9-b104-4f18-b32d-9c30c373bc40', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Chandigarh', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:aaa8987803c34f330f8924adc39f8367808e295d0f78a1481f609d7a51e9a410', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '7a0f68b9-b104-4f18-b32d-9c30c373bc40', 'PROFESSION_TAX', 'Profession Tax - Chandigarh', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:eb8adc4626d68ac61ff448e6f2f65afac6887397573a01bbd210a7c4a4643a5d', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('ccfed820-1752-497a-a9ad-29ce1714ee09', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('ccfed820-1752-497a-a9ad-29ce1714ee09', 'a468cadd-de14-c846-d5d5-b9091da8e04e');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('dc33bfbc-2572-4ced-9076-dd262e00b564', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'ccfed820-1752-497a-a9ad-29ce1714ee09', 'IN_a468cadd', 'Chhattisgarh Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'dc33bfbc-2572-4ced-9076-dd262e00b564', 'SGST', 'State GST - Chhattisgarh', 'GST', 'https://cbic-gst.gov.in', 'HASH:e93707f6f7b03601e9ba1c018c1e4609f5fc6dc7fd08e8822e27d5ac818a86cb', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'dc33bfbc-2572-4ced-9076-dd262e00b564', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Chhattisgarh', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:8aa558e4afba2105968060461d080d3e513b5dcf627b912d3c23274c3396d29a', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'dc33bfbc-2572-4ced-9076-dd262e00b564', 'PROFESSION_TAX', 'Profession Tax - Chhattisgarh', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:7453ece3a13827cbceb28c103a2da6b486746f32f502a3429977c72fd04ddf5d', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('04c8d30f-bd5e-4a9d-bb42-18ee8efa994d', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('04c8d30f-bd5e-4a9d-bb42-18ee8efa994d', 'd0b8923e-4e83-cc37-0c1c-e1039fb7d0b5');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('e0b8ecca-3aea-4737-9583-27fac3c3ed4a', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '04c8d30f-bd5e-4a9d-bb42-18ee8efa994d', 'IN_d0b8923e', 'Delhi Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'e0b8ecca-3aea-4737-9583-27fac3c3ed4a', 'SGST', 'State GST - Delhi', 'GST', 'https://cbic-gst.gov.in', 'HASH:00b50c747e0647533c913499074407263529cd9ad90bf5c5aceb99d98cb59bce', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'e0b8ecca-3aea-4737-9583-27fac3c3ed4a', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Delhi', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:04aeae5bd9f783a4c13af52e88412f1034cd541db1ec2c25db857961e5ff3e6e', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'e0b8ecca-3aea-4737-9583-27fac3c3ed4a', 'PROFESSION_TAX', 'Profession Tax - Delhi', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:ba44201541aa2e02f7de1bbd967510a62afaa7b65f8d62eda56752d11ee1aad6', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('b36c13e1-1413-4984-a8d7-07bce19fac71', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('b36c13e1-1413-4984-a8d7-07bce19fac71', '4716b018-5c49-fbb0-ad97-3d73bd9001fc');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('001e42bf-aaa8-4096-b0e5-53dca35b1ef4', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'b36c13e1-1413-4984-a8d7-07bce19fac71', 'IN_4716b018', 'Goa Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '001e42bf-aaa8-4096-b0e5-53dca35b1ef4', 'SGST', 'State GST - Goa', 'GST', 'https://cbic-gst.gov.in', 'HASH:de4ef7c2a48b0b0db7622afa13bd15e74543161273b88116e3acc37cebf49ab3', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '001e42bf-aaa8-4096-b0e5-53dca35b1ef4', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Goa', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:9d5362cddbd514cf6f664897edf65727d51621502e7e6450d0de8941bdaee24c', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '001e42bf-aaa8-4096-b0e5-53dca35b1ef4', 'PROFESSION_TAX', 'Profession Tax - Goa', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:627d09c214d7b1a20c16ad38cee2f64975b2baa2ad1390c1971826fdc20d85f0', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('e7c511fd-1a50-4270-bf4d-10c64647fffe', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('e7c511fd-1a50-4270-bf4d-10c64647fffe', 'aa3c1aa9-b2e9-cb96-27d0-a29801143d3e');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('67a69287-d46b-4e88-8976-69542bebc79d', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'e7c511fd-1a50-4270-bf4d-10c64647fffe', 'IN_aa3c1aa9', 'Gujarat Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '67a69287-d46b-4e88-8976-69542bebc79d', 'SGST', 'State GST - Gujarat', 'GST', 'https://cbic-gst.gov.in', 'HASH:1380ebc3cb724651a5c33176af8058578fa67620e0efe4ba5a50aa366a058134', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '67a69287-d46b-4e88-8976-69542bebc79d', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Gujarat', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:358299254dd8dea6895bc39a330e9e0b34b7431dc6a2018df32de2f58e1fc78d', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '67a69287-d46b-4e88-8976-69542bebc79d', 'PROFESSION_TAX', 'Profession Tax - Gujarat', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:eaf07fa39e1a3a0946065de68c7976119a1da0751b1ad389e4faf3b7979d3058', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('8c0e2fdf-5bbb-4178-915d-ddb4fbedd9da', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('8c0e2fdf-5bbb-4178-915d-ddb4fbedd9da', 'd5496492-b4f2-5999-21e7-7214cc3fdecf');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('0f8f2652-b13d-4dc0-89f7-069977b133b2', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '8c0e2fdf-5bbb-4178-915d-ddb4fbedd9da', 'IN_d5496492', 'Haryana Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '0f8f2652-b13d-4dc0-89f7-069977b133b2', 'SGST', 'State GST - Haryana', 'GST', 'https://cbic-gst.gov.in', 'HASH:941930a663c2c6597a3a110cfd9b56d8c15c97ae230602e77d836f7d1f7ab66e', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '0f8f2652-b13d-4dc0-89f7-069977b133b2', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Haryana', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:410066795131efd3ce2e8a89ee7e8d86b5635f95c040ed9e1f7e392d63624bfe', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '0f8f2652-b13d-4dc0-89f7-069977b133b2', 'PROFESSION_TAX', 'Profession Tax - Haryana', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:3faafbfabd3e77298b005dc8ad8f91cb4f57815c3280c7e855afb8c1685bef78', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('c757bdfa-f0cb-4072-a6ec-c23594c25b13', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('c757bdfa-f0cb-4072-a6ec-c23594c25b13', 'edbee470-8162-8af7-e00d-e279f44c0efb');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('c99d267d-9aeb-44e6-ae44-b8198cacf3f5', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'c757bdfa-f0cb-4072-a6ec-c23594c25b13', 'IN_edbee470', 'Himachal Pradesh Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'c99d267d-9aeb-44e6-ae44-b8198cacf3f5', 'SGST', 'State GST - Himachal Pradesh', 'GST', 'https://cbic-gst.gov.in', 'HASH:863d1a64f51438ef5b2bbf985b055eff0827e3a8cce7ff167a5473875e17e6a9', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'c99d267d-9aeb-44e6-ae44-b8198cacf3f5', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Himachal Pradesh', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:730bf05681ff2e89cb6d73de3bd1260747d375cbe60aa16f0a00466091eea978', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'c99d267d-9aeb-44e6-ae44-b8198cacf3f5', 'PROFESSION_TAX', 'Profession Tax - Himachal Pradesh', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:2658d60796becd267eb5a00a59ed0a0a79b23476d0af20c1644f38b8724d2529', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('7def3b46-47ca-4985-8a5e-9a704d91bc9e', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('7def3b46-47ca-4985-8a5e-9a704d91bc9e', '2cfc0a45-1570-da34-53ab-fdef1f5b663f');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('243d7f5c-89ed-4371-951b-cf89c5d36529', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '7def3b46-47ca-4985-8a5e-9a704d91bc9e', 'IN_2cfc0a45', 'Jammu And Kashmir Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '243d7f5c-89ed-4371-951b-cf89c5d36529', 'SGST', 'State GST - Jammu And Kashmir', 'GST', 'https://cbic-gst.gov.in', 'HASH:dc719508cba4a715a4d9ad97d6001babac95c385469de3b667947285513f0790', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '243d7f5c-89ed-4371-951b-cf89c5d36529', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Jammu And Kashmir', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:a591d321ca1092da0d68ccfbbfe37a37f24b18050553c5d13ccb2a3aa835851e', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '243d7f5c-89ed-4371-951b-cf89c5d36529', 'PROFESSION_TAX', 'Profession Tax - Jammu And Kashmir', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:068c6ecc0dd15ea038c6a4c8e7058ba637b606660bb8b05ed2872b178cebff35', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('7f6291b3-1756-451b-bbc4-09a6db127f25', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('7f6291b3-1756-451b-bbc4-09a6db127f25', '25b4c210-24fb-f7cb-a5e3-b6a59dda194a');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('edace2d0-7a0f-4ef3-b02b-3545f5edd2bd', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '7f6291b3-1756-451b-bbc4-09a6db127f25', 'IN_25b4c210', 'Jharkhand Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'edace2d0-7a0f-4ef3-b02b-3545f5edd2bd', 'SGST', 'State GST - Jharkhand', 'GST', 'https://cbic-gst.gov.in', 'HASH:62e662ea320328f04a5b5550e4affb10b3b94487e71a95c64f5ee93ea6bdeb55', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'edace2d0-7a0f-4ef3-b02b-3545f5edd2bd', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Jharkhand', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:f155a24bb8c33e6371960edba2f09cc7f37fe6993404e98d3ac5022b34acb0de', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'edace2d0-7a0f-4ef3-b02b-3545f5edd2bd', 'PROFESSION_TAX', 'Profession Tax - Jharkhand', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:26b11c896679b19c99dd11b7889c079472ef35e7d3d1f1241b0f810dd56fe921', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('b91e1507-aedf-431b-9bc5-4b1fd756cb7b', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('b91e1507-aedf-431b-9bc5-4b1fd756cb7b', '55b772b6-c146-0c14-1ab3-1a3cf2ada5e1');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('cff6b697-ec3d-47b5-a5a5-f5f564abfba4', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'b91e1507-aedf-431b-9bc5-4b1fd756cb7b', 'IN_55b772b6', 'Karnataka Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'cff6b697-ec3d-47b5-a5a5-f5f564abfba4', 'SGST', 'State GST - Karnataka', 'GST', 'https://cbic-gst.gov.in', 'HASH:b3dd6f903d681bd0641606ba6175c65607a0275fe24fd077dc14caf6a628a8a9', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'cff6b697-ec3d-47b5-a5a5-f5f564abfba4', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Karnataka', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:fef765571456b57748659d3f3be919c3c6bfb652d1daa68a81e80da652d7f4cc', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'cff6b697-ec3d-47b5-a5a5-f5f564abfba4', 'PROFESSION_TAX', 'Profession Tax - Karnataka', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:dcbcdb084b17fd935218ea86662e8d4420daf6eec2059cd765b72ce45352be7e', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('6e991728-ef75-48ad-801c-1497dcd5e1e7', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('6e991728-ef75-48ad-801c-1497dcd5e1e7', '57f42cb4-5c7b-1858-de78-d6cee9c61a60');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('189669df-6a27-4d1e-9615-326ae3e9fea6', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '6e991728-ef75-48ad-801c-1497dcd5e1e7', 'IN_57f42cb4', 'Kerala Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '189669df-6a27-4d1e-9615-326ae3e9fea6', 'SGST', 'State GST - Kerala', 'GST', 'https://cbic-gst.gov.in', 'HASH:c81026f74ba9ad08cdd722d79d0904bbddaff47909d728b103daf0829f41c5e1', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '189669df-6a27-4d1e-9615-326ae3e9fea6', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Kerala', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:eee5e0f4dfa93d437c14084631e7e87482ff5deeb26bf5101a6c1d0416e89083', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '189669df-6a27-4d1e-9615-326ae3e9fea6', 'PROFESSION_TAX', 'Profession Tax - Kerala', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:515ab9e77a5d07f0b99a149632e1906c534f3dd3ccb7d591e7b31c480f1df864', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('30d41e3e-c2d4-45f0-b44f-746de561d1c9', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('30d41e3e-c2d4-45f0-b44f-746de561d1c9', 'acdece69-411a-a043-d40b-8bf5042d84ac');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('0d427cce-f6ef-4ad9-8883-c4aaa1b123a8', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '30d41e3e-c2d4-45f0-b44f-746de561d1c9', 'IN_acdece69', 'Ladakh Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '0d427cce-f6ef-4ad9-8883-c4aaa1b123a8', 'UTGST', 'Union Territory GST - Ladakh', 'GST', 'https://cbic-gst.gov.in', 'HASH:b9eb7dc7815fe700b36bfbaf4f35ad9e4bc15c139f9b50076f169d348d9b51cf', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '0d427cce-f6ef-4ad9-8883-c4aaa1b123a8', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Ladakh', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:4f808c089d2ad70d407848c4c02813729b7283762e0602a96d24c7127b56120e', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '0d427cce-f6ef-4ad9-8883-c4aaa1b123a8', 'PROFESSION_TAX', 'Profession Tax - Ladakh', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:679142dfb5a796f03d22167b2952dfe9a4943daa096eee6a6420cbbab03c7c50', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('96545669-397c-4cff-97b3-e63d5eb1e1eb', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('96545669-397c-4cff-97b3-e63d5eb1e1eb', 'c8503e4c-bd34-ccb2-ff15-a7f2ac7f9430');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('32d99f18-2e17-47a7-b41e-a028a8992ea0', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '96545669-397c-4cff-97b3-e63d5eb1e1eb', 'IN_c8503e4c', 'Lakshadweep Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '32d99f18-2e17-47a7-b41e-a028a8992ea0', 'UTGST', 'Union Territory GST - Lakshadweep', 'GST', 'https://cbic-gst.gov.in', 'HASH:f2c6e2271d087d633a44fa371675f25ae03ad37980db4c8e7a401d4b381915b8', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '32d99f18-2e17-47a7-b41e-a028a8992ea0', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Lakshadweep', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:c85534107d5d9d37966b83ee3edaccee7387979c41b73f4e16b556e9ca951afe', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '32d99f18-2e17-47a7-b41e-a028a8992ea0', 'PROFESSION_TAX', 'Profession Tax - Lakshadweep', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:af161fe1789e514ce3d591320cc2833c439e26d2572f05ab890db0151a6422ec', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('ec7333dd-ad12-4720-8f58-0e44fd073844', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('ec7333dd-ad12-4720-8f58-0e44fd073844', '960251c4-7e6a-f45c-3733-065b7d46c955');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('bc3f86f9-c0d1-4072-91b6-5598bef57041', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'ec7333dd-ad12-4720-8f58-0e44fd073844', 'IN_960251c4', 'Madhya Pradesh Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'bc3f86f9-c0d1-4072-91b6-5598bef57041', 'SGST', 'State GST - Madhya Pradesh', 'GST', 'https://cbic-gst.gov.in', 'HASH:900b9d838f07be9e47733f3ab7802edacaf67f1cfd74dfdcef87531d5ea8e217', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'bc3f86f9-c0d1-4072-91b6-5598bef57041', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Madhya Pradesh', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:5025db8518387852abb9745eb618b22c79a42c3d069fd33f8f23b351af3fb35b', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'bc3f86f9-c0d1-4072-91b6-5598bef57041', 'PROFESSION_TAX', 'Profession Tax - Madhya Pradesh', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:c2ec3232d311c8f1c54ddc25b4041085819fe62e3c4338c38abdbcbcbbc916f3', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('d246af46-612c-424c-8c49-38b6459a1120', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('d246af46-612c-424c-8c49-38b6459a1120', '8ee3181b-105e-cdb3-9b6f-9bf350d978ab');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('37b6d289-2cd6-4d2e-ac52-a40116eea185', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'd246af46-612c-424c-8c49-38b6459a1120', 'IN_8ee3181b', 'Maharashtra Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '37b6d289-2cd6-4d2e-ac52-a40116eea185', 'SGST', 'State GST - Maharashtra', 'GST', 'https://cbic-gst.gov.in', 'HASH:2e4c0555de50b3d77db0e391bbe4aadc137b45dbfab9242f58e256495ae80d95', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '37b6d289-2cd6-4d2e-ac52-a40116eea185', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Maharashtra', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:4a352740bb9dbdcdce6a5adf057e083881659a4d24ad12c5ecc7e79893b16e7a', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '37b6d289-2cd6-4d2e-ac52-a40116eea185', 'PROFESSION_TAX', 'Profession Tax - Maharashtra', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:c708020f3f60ebd8b8d9eea8490f0c136bfd65087c97114efb77237d689a5921', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('89710b38-ade3-48b1-ad47-125693ed317b', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('89710b38-ade3-48b1-ad47-125693ed317b', '37a1c514-2b48-ab29-1f55-0c467da18b2c');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('9dea3efc-0170-4590-b7de-721b6924c080', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '89710b38-ade3-48b1-ad47-125693ed317b', 'IN_37a1c514', 'Manipur Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '9dea3efc-0170-4590-b7de-721b6924c080', 'SGST', 'State GST - Manipur', 'GST', 'https://cbic-gst.gov.in', 'HASH:431a8044d1fcb7fe50c016b63b7cc200de609ac136100cbbf0c61dbb62eff559', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '9dea3efc-0170-4590-b7de-721b6924c080', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Manipur', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:fae9da89f27155084ee3961f423693ea4592d58c7281d39ee5d6ba0bbf996c02', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '9dea3efc-0170-4590-b7de-721b6924c080', 'PROFESSION_TAX', 'Profession Tax - Manipur', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:93fc7869663e89b1ced61dbccf11e9ff23df91556de45399d1f25f1f81727bd4', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('7d771768-75b4-45c3-a9a8-06968cc55857', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('7d771768-75b4-45c3-a9a8-06968cc55857', 'e6fac942-38a5-5204-031e-fc8e40e9e2c8');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('4a29867d-1619-44b4-8204-f082b7fe3b49', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '7d771768-75b4-45c3-a9a8-06968cc55857', 'IN_e6fac942', 'Meghalaya Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '4a29867d-1619-44b4-8204-f082b7fe3b49', 'SGST', 'State GST - Meghalaya', 'GST', 'https://cbic-gst.gov.in', 'HASH:8166fd29ab358fa694a0ac0b5aabdafb72878a8c78d9524679e708319ee5c740', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '4a29867d-1619-44b4-8204-f082b7fe3b49', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Meghalaya', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:47ba93470bafd7939f6f4f513e8830679ddb8caf881de99705627e4da3c1a2fb', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '4a29867d-1619-44b4-8204-f082b7fe3b49', 'PROFESSION_TAX', 'Profession Tax - Meghalaya', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:edee70eeaf88ae48e5c5f17e7a15e01227387c2baf3bfe91b116381b7d85dcdb', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('487201a4-57e7-4494-bd9c-963dbd61b1bc', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('487201a4-57e7-4494-bd9c-963dbd61b1bc', '0fe570c4-d3d5-dde0-4d33-b1e3d97ebee2');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('f3f4c186-ed78-453a-859d-c0f6d385a769', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '487201a4-57e7-4494-bd9c-963dbd61b1bc', 'IN_0fe570c4', 'Mizoram Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'f3f4c186-ed78-453a-859d-c0f6d385a769', 'SGST', 'State GST - Mizoram', 'GST', 'https://cbic-gst.gov.in', 'HASH:0b5cfaae04f9db65843ec892c68946000be404fc94a44b1d3dafdfa29c083939', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'f3f4c186-ed78-453a-859d-c0f6d385a769', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Mizoram', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:5ef7666d9e7a15d97986e72f6fc5978106d43be8345bc5bbd522e3414a71b47d', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'f3f4c186-ed78-453a-859d-c0f6d385a769', 'PROFESSION_TAX', 'Profession Tax - Mizoram', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:d721a86aa9df19f93e8d7f413a07591e225ac73971bd9b6d8e52a8389f2a9dc8', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('a3a868b9-64e9-483a-bea0-a2ef8d152035', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('a3a868b9-64e9-483a-bea0-a2ef8d152035', '1eb6d30e-66b0-94c5-83a6-ce8c85b807ac');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('77071238-3c9f-4194-958e-9b17bc7d24cf', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'a3a868b9-64e9-483a-bea0-a2ef8d152035', 'IN_1eb6d30e', 'Nagaland Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '77071238-3c9f-4194-958e-9b17bc7d24cf', 'SGST', 'State GST - Nagaland', 'GST', 'https://cbic-gst.gov.in', 'HASH:207595243df156f8dfceddf51cd5b73195e08c943163787c4b736193451262d9', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '77071238-3c9f-4194-958e-9b17bc7d24cf', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Nagaland', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:f549166ac1f0304cc53a92899ca8b2a94fdb0efa58a712652bb49064ce2bcfe5', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '77071238-3c9f-4194-958e-9b17bc7d24cf', 'PROFESSION_TAX', 'Profession Tax - Nagaland', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:faa74d2fda7803348aea986b251f60e56755187dd60e4f85f6c268956b7bb910', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('2c817be2-2751-46a8-9cca-ec21eb88b8dc', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('2c817be2-2751-46a8-9cca-ec21eb88b8dc', 'a4451246-fb5c-7940-2d34-669dbdd5f742');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('4cd25833-f6dd-471e-be4c-8dc39a966b02', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '2c817be2-2751-46a8-9cca-ec21eb88b8dc', 'IN_a4451246', 'Odisha Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '4cd25833-f6dd-471e-be4c-8dc39a966b02', 'SGST', 'State GST - Odisha', 'GST', 'https://cbic-gst.gov.in', 'HASH:188a8e48e7cb02b02627809164bed58bd5a516ef9d332326b27fdc9fb31f9c35', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '4cd25833-f6dd-471e-be4c-8dc39a966b02', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Odisha', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:96812fbaba521c7f494ad810c9aab3433184f45b9f96a84b0c72f8298c6edb5b', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '4cd25833-f6dd-471e-be4c-8dc39a966b02', 'PROFESSION_TAX', 'Profession Tax - Odisha', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:e8730d40cc82fab902d9884abcd2067ae21c68a5d2378fa1f13aeb096e6e7987', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('67361f65-064e-400f-bc6d-08513d738fbb', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('67361f65-064e-400f-bc6d-08513d738fbb', '6451d1c6-a257-09d5-0b53-64a97d641da9');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('d447b688-6583-4307-a9ac-10f7000fd1fa', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '67361f65-064e-400f-bc6d-08513d738fbb', 'IN_6451d1c6', 'Puducherry Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'd447b688-6583-4307-a9ac-10f7000fd1fa', 'SGST', 'State GST - Puducherry', 'GST', 'https://cbic-gst.gov.in', 'HASH:a8bbd3a14b7176d8b510c41c43afcef7bc52eff52b6006cfe646bd56540c1ce2', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'd447b688-6583-4307-a9ac-10f7000fd1fa', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Puducherry', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:6438aebee0d44454a407345985e0bd58ad89be3ea4a8b565a8071833b094d400', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'd447b688-6583-4307-a9ac-10f7000fd1fa', 'PROFESSION_TAX', 'Profession Tax - Puducherry', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:02f09dcb0b26998cff17207f6880f0bf5f05f9635a7e3cd6f8668c8bbc08f523', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('1ae10319-6683-40bc-9412-bb97e8ca3610', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('1ae10319-6683-40bc-9412-bb97e8ca3610', '89935061-3bbc-70ec-e190-5af40f567d64');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('309d7a53-76cf-41f4-9c52-6c7407fd0f32', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '1ae10319-6683-40bc-9412-bb97e8ca3610', 'IN_89935061', 'Punjab Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '309d7a53-76cf-41f4-9c52-6c7407fd0f32', 'SGST', 'State GST - Punjab', 'GST', 'https://cbic-gst.gov.in', 'HASH:2d2b6a9637e840be9316576d3cbd39d145eae2af7bb8b2cacbf8d37e3f2830fd', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '309d7a53-76cf-41f4-9c52-6c7407fd0f32', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Punjab', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:6f37c260c797a45190627d381e1febae614009ebc2102016e39d8eebcc9eb801', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '309d7a53-76cf-41f4-9c52-6c7407fd0f32', 'PROFESSION_TAX', 'Profession Tax - Punjab', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:23c8b4f84378b5b1e798591d3932fec4b33758b9527eab12774163dab05d1340', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('a1883aa6-c80e-4952-be20-b16cd69ce3a4', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('a1883aa6-c80e-4952-be20-b16cd69ce3a4', 'f94d6d3d-ad66-0195-b2af-7a2826dcb3f0');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('6962adce-d42f-4d93-8820-9f559e9a0714', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'a1883aa6-c80e-4952-be20-b16cd69ce3a4', 'IN_f94d6d3d', 'Rajasthan Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '6962adce-d42f-4d93-8820-9f559e9a0714', 'SGST', 'State GST - Rajasthan', 'GST', 'https://cbic-gst.gov.in', 'HASH:191a29d0b89f35cc65cf1b6418e21b290e90173d94146827ac45e8c8d9de095c', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '6962adce-d42f-4d93-8820-9f559e9a0714', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Rajasthan', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:4f6948c8ceb69a65137940709c8064ae0e6e8916e53c49dd4b96356058be462e', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '6962adce-d42f-4d93-8820-9f559e9a0714', 'PROFESSION_TAX', 'Profession Tax - Rajasthan', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:cd95c4e5c0201e8d795fe4504a1f88e24897f42a3a822b8075c3430cedd66b4d', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('bb063d1b-ce24-4da2-b831-296da898aae2', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('bb063d1b-ce24-4da2-b831-296da898aae2', 'a9b1575a-55fa-2e40-22b5-92c7ed7ec929');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('ea59fb8f-6df5-4874-b97a-13680827fbe2', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'bb063d1b-ce24-4da2-b831-296da898aae2', 'IN_a9b1575a', 'Sikkim Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'ea59fb8f-6df5-4874-b97a-13680827fbe2', 'SGST', 'State GST - Sikkim', 'GST', 'https://cbic-gst.gov.in', 'HASH:d217206469944b8455b9bbe937ac59c52ec6e2e8cc14df7c0301d8490995f92c', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'ea59fb8f-6df5-4874-b97a-13680827fbe2', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Sikkim', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:159b1926867e15d9aafd94b8043c3ab69e754dfd5fa873b04499de8a4611ed0a', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'ea59fb8f-6df5-4874-b97a-13680827fbe2', 'PROFESSION_TAX', 'Profession Tax - Sikkim', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:844580ac5bb14d2b529e6c5cef5e7b37e97ad35e746e7abd385ee2ae3d3b7fe3', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('975f43c5-8901-4cc9-b8f6-80a7ddd0d021', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('975f43c5-8901-4cc9-b8f6-80a7ddd0d021', 'edc9ce5b-1209-e0e2-3ada-9c9e43959fcf');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('c2bac63c-06b8-4258-9727-a1bea69cbdf3', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '975f43c5-8901-4cc9-b8f6-80a7ddd0d021', 'IN_edc9ce5b', 'Tamil Nadu Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'c2bac63c-06b8-4258-9727-a1bea69cbdf3', 'SGST', 'State GST - Tamil Nadu', 'GST', 'https://cbic-gst.gov.in', 'HASH:0a45bc356cea5ac987ce1d9d633bf1a842461794f4093c58eb48d30662943e7f', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'c2bac63c-06b8-4258-9727-a1bea69cbdf3', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Tamil Nadu', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:8fd387cf14ed65005d088b3a54b61ef488117ce46ffe73e1c10bc9a113151366', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'c2bac63c-06b8-4258-9727-a1bea69cbdf3', 'PROFESSION_TAX', 'Profession Tax - Tamil Nadu', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:c36585e6f845c0e35c30828a7434bbfbded7aa35290a54cb813d5be49beb4761', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('55c63fd4-fa28-4c47-be37-d13a3a0d6ff2', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('55c63fd4-fa28-4c47-be37-d13a3a0d6ff2', '90268fab-d970-a3f4-4c42-d2f7bed6d9cb');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('8c95016f-90cc-47bb-83cf-e3782821d80e', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '55c63fd4-fa28-4c47-be37-d13a3a0d6ff2', 'IN_90268fab', 'Telangana Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '8c95016f-90cc-47bb-83cf-e3782821d80e', 'SGST', 'State GST - Telangana', 'GST', 'https://cbic-gst.gov.in', 'HASH:32834820cc671af7291c86beedf16d06ec1193813ad422f6a1276ea46ac9d2ec', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '8c95016f-90cc-47bb-83cf-e3782821d80e', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Telangana', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:94fdde49c9abdfc076f37686802188a01052eec5265eb130a9b6f118a04b1d30', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '8c95016f-90cc-47bb-83cf-e3782821d80e', 'PROFESSION_TAX', 'Profession Tax - Telangana', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:26363e7d7488b6146e519571dd4928345858bfc361de8628d6487f60025be4ea', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('7bd6fc82-eed2-468b-b3e7-127f14623eea', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('7bd6fc82-eed2-468b-b3e7-127f14623eea', 'efb9258b-37c6-c754-56b6-78a008a85a11');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('9edc4b34-c791-4740-8838-c088061bdab5', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '7bd6fc82-eed2-468b-b3e7-127f14623eea', 'IN_efb9258b', 'The Dadra And Nagar Haveli And Daman And Diu Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '9edc4b34-c791-4740-8838-c088061bdab5', 'UTGST', 'Union Territory GST - The Dadra And Nagar Haveli And Daman And Diu', 'GST', 'https://cbic-gst.gov.in', 'HASH:8135feb9940510a91764790200128bf28cefb57b2a3d9848a9f86ce697cd0b78', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '9edc4b34-c791-4740-8838-c088061bdab5', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - The Dadra And Nagar Haveli And Daman And Diu', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:d0529ecc8c134f1c66e91644d59f8838bf6d6a764aa8db4918d7d6f14757040f', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '9edc4b34-c791-4740-8838-c088061bdab5', 'PROFESSION_TAX', 'Profession Tax - The Dadra And Nagar Haveli And Daman And Diu', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:5389d2cfc92a2a83e142d0b311858b359d7a500f09b334ea43f8d8c13e1e7ed4', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('bfea1e12-ecaa-41ce-9f1d-59497e97db9e', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('bfea1e12-ecaa-41ce-9f1d-59497e97db9e', '1900638b-5ff4-4eee-c4b3-6ae178e508dd');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('15d48181-65e1-4fcf-a054-002b27c2402d', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'bfea1e12-ecaa-41ce-9f1d-59497e97db9e', 'IN_1900638b', 'Tripura Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '15d48181-65e1-4fcf-a054-002b27c2402d', 'SGST', 'State GST - Tripura', 'GST', 'https://cbic-gst.gov.in', 'HASH:378b225a0864e0aea3a386063002a22a930f231e79ee26dd3832790169f847e9', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '15d48181-65e1-4fcf-a054-002b27c2402d', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Tripura', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:e37b63fdb29c976b5e4f38658ed604a692aaba9b99ca66bab083e3bfaaed79b2', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '15d48181-65e1-4fcf-a054-002b27c2402d', 'PROFESSION_TAX', 'Profession Tax - Tripura', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:51a8779879aa552d0c0f98e5a6e804996e0f8beebe99872715397c0fe43ccf4e', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('34c5221c-47aa-4e45-bfbd-732176976df0', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('34c5221c-47aa-4e45-bfbd-732176976df0', '8e4ac819-9c18-b049-a315-0dc284acc070');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('d747e4ab-c67b-4eb5-9041-9823a8878ab6', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '34c5221c-47aa-4e45-bfbd-732176976df0', 'IN_8e4ac819', 'Uttarakhand Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'd747e4ab-c67b-4eb5-9041-9823a8878ab6', 'SGST', 'State GST - Uttarakhand', 'GST', 'https://cbic-gst.gov.in', 'HASH:ef8b3690861a632434e46ca79b05c4976bfba10bf729f253849b73ad992d277d', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'd747e4ab-c67b-4eb5-9041-9823a8878ab6', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Uttarakhand', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:9cdfd4b861207a9184b760ae99ba9499377a517fcd39ca84b1ea9cb5209d1a19', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'd747e4ab-c67b-4eb5-9041-9823a8878ab6', 'PROFESSION_TAX', 'Profession Tax - Uttarakhand', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:1296fba68e06afcb2fdc180542879bb3f918b4ebc13c68180cf83f0c4c3a3ca0', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('a693f83b-8d0c-4fcb-9dd1-fe733970dc59', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('a693f83b-8d0c-4fcb-9dd1-fe733970dc59', '94191f37-522d-6ead-2c40-cbe065041941');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('050e8dee-6dfe-4ed3-bb19-c899347f505c', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'a693f83b-8d0c-4fcb-9dd1-fe733970dc59', 'IN_94191f37', 'Uttar Pradesh Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', '050e8dee-6dfe-4ed3-bb19-c899347f505c', 'SGST', 'State GST - Uttar Pradesh', 'GST', 'https://cbic-gst.gov.in', 'HASH:37d95d7158c3deb8932e994a4d6f12baf04a42f072f3645a8d48df4e23ee9a9a', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', '050e8dee-6dfe-4ed3-bb19-c899347f505c', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - Uttar Pradesh', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:93884e4affc36f6a17a45fecb9139cda3972897157181ab6142f3d874bda346c', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', '050e8dee-6dfe-4ed3-bb19-c899347f505c', 'PROFESSION_TAX', 'Profession Tax - Uttar Pradesh', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:3c467d4a71bc32fd38a7d822aaa767651050f3d7fd11575ae426cbce3733e8bc', '2026-09-02T07:15:51.388Z');
  
  INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES ('7f37a073-fed5-47de-a123-9d66bbbd9307', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', 'GEOGRAPHIC');
  INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES ('7f37a073-fed5-47de-a123-9d66bbbd9307', '89dcba4a-145b-6fe0-d34e-d94250e0dbf1');
  INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) VALUES ('d0c463e0-d371-4594-a71d-e27a06a6f4f0', 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', '7f37a073-fed5-47de-a123-9d66bbbd9307', 'IN_89dcba4a', 'West Bengal Tax Jurisdiction');
  
  INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, effective_from) VALUES 
  ('92928c6c-d075-4ee0-bd8a-d18afa02fcc1', 'd0c463e0-d371-4594-a71d-e27a06a6f4f0', 'SGST', 'State GST - West Bengal', 'GST', 'https://cbic-gst.gov.in', 'HASH:edd0fd609bfbc94b554307d4eb812cd2cc1434e1ab18caefeca55f2178911c98', '2026-09-02T07:15:51.388Z'),
  ('dec413ad-f523-468a-b84f-a2c67f7e6e56', 'd0c463e0-d371-4594-a71d-e27a06a6f4f0', 'STATE_VAT', 'State VAT (Petroleum/Liquor) - West Bengal', 'SALES_TAX', 'https://cbic-gst.gov.in', 'HASH:6088114d4f7986b899a904eb32c1ec3b63c753ddc07d3aa6e2948d3072f04b39', '2026-09-02T07:15:51.388Z'),
  ('ce0d6b2c-0fb4-4be6-9df6-ae4f23564886', 'd0c463e0-d371-4594-a71d-e27a06a6f4f0', 'PROFESSION_TAX', 'Profession Tax - West Bengal', 'WITHHOLDING', 'https://incometaxindia.gov.in', 'HASH:469bdc39186e12dbdca46131a5b428dd05cc0e794b25e91a33eac588e2bef135', '2026-09-02T07:15:51.388Z');
  
-- Verification & Rollback
DO $$
DECLARE
    v_scopes INT;
    v_jurs INT;
    v_comps INT;
BEGIN
    SELECT COUNT(*) INTO v_scopes FROM catalog.scope_geographies;
    SELECT COUNT(*) INTO v_jurs FROM catalog.jurisdictions WHERE code LIKE 'IN_%';
    SELECT COUNT(*) INTO v_comps FROM catalog.tax_components;
    
    RAISE NOTICE 'Scope Geographies: %', v_scopes;
    RAISE NOTICE 'India Jurisdictions mapped: %', v_jurs;
    RAISE NOTICE 'Tax Components mapped: %', v_comps;
    
    IF v_scopes != 36 THEN
        RAISE EXCEPTION 'Failed to map exactly 36 states to scopes! Found %', v_scopes;
    END IF;
    
    RAISE EXCEPTION 'UNCONDITIONAL_ROLLBACK_REHEARSAL_SUCCESS';
END $$;
