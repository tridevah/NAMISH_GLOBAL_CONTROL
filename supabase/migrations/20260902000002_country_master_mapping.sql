-- Migration 20260902000002: Global Countries and Currency Mappings

BEGIN ISOLATION LEVEL SERIALIZABLE;
SET CONSTRAINTS ALL IMMEDIATE;

-- Advisory lock
DO $$
DECLARE v_lock boolean;
BEGIN
  SELECT pg_try_advisory_xact_lock(hashtext('COUNTRIES_CURRENCY_MASTER')) INTO v_lock;
  IF NOT v_lock THEN
    RAISE EXCEPTION 'Could not obtain advisory lock COUNTRIES_CURRENCY_MASTER.';
  END IF;
END $$;

-- 1. Create mapping table
CREATE TABLE IF NOT EXISTS catalog.country_currencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL REFERENCES catalog.countries(id),
    currency_id UUID NOT NULL REFERENCES catalog.currencies(id),
    is_primary BOOLEAN NOT NULL DEFAULT false,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(country_id, currency_id)
);
ALTER TABLE catalog.country_currencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.country_currencies FORCE ROW LEVEL SECURITY;

-- 2. Upsert Countries
DO $$
DECLARE
  v_id UUID;
BEGIN
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AF');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'AFG',
      numeric_code = '004',
      official_name = 'Afghanistan',
      display_name = 'Afghanistan',
      default_currency_code = 'AFN'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AF', 'AFG', '004', 'Afghanistan', 'Afghanistan', 'AFN', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AX');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ALA',
      numeric_code = '248',
      official_name = 'Åland Islands',
      display_name = 'Åland Islands',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AX', 'ALA', '248', 'Åland Islands', 'Åland Islands', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AL');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ALB',
      numeric_code = '008',
      official_name = 'Albania',
      display_name = 'Albania',
      default_currency_code = 'ALL'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AL', 'ALB', '008', 'Albania', 'Albania', 'ALL', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('DZ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'DZA',
      numeric_code = '012',
      official_name = 'Algeria',
      display_name = 'Algeria',
      default_currency_code = 'DZD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('DZ', 'DZA', '012', 'Algeria', 'Algeria', 'DZD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AS');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ASM',
      numeric_code = '016',
      official_name = 'American Samoa',
      display_name = 'American Samoa',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AS', 'ASM', '016', 'American Samoa', 'American Samoa', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AD');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'AND',
      numeric_code = '020',
      official_name = 'Andorra',
      display_name = 'Andorra',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AD', 'AND', '020', 'Andorra', 'Andorra', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AO');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'AGO',
      numeric_code = '024',
      official_name = 'Angola',
      display_name = 'Angola',
      default_currency_code = 'AOA'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AO', 'AGO', '024', 'Angola', 'Angola', 'AOA', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AI');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'AIA',
      numeric_code = '660',
      official_name = 'Anguilla',
      display_name = 'Anguilla',
      default_currency_code = 'XCD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AI', 'AIA', '660', 'Anguilla', 'Anguilla', 'XCD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AQ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ATA',
      numeric_code = '010',
      official_name = 'Antarctica',
      display_name = 'Antarctica',
      default_currency_code = 'NO_OFFICIAL_CURRENCY'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AQ', 'ATA', '010', 'Antarctica', 'Antarctica', 'NO_OFFICIAL_CURRENCY', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AG');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ATG',
      numeric_code = '028',
      official_name = 'Antigua and Barbuda',
      display_name = 'Antigua and Barbuda',
      default_currency_code = 'XCD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AG', 'ATG', '028', 'Antigua and Barbuda', 'Antigua and Barbuda', 'XCD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ARG',
      numeric_code = '032',
      official_name = 'Argentina',
      display_name = 'Argentina',
      default_currency_code = 'ARS'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AR', 'ARG', '032', 'Argentina', 'Argentina', 'ARS', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ARM',
      numeric_code = '051',
      official_name = 'Armenia',
      display_name = 'Armenia',
      default_currency_code = 'AMD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AM', 'ARM', '051', 'Armenia', 'Armenia', 'AMD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AW');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ABW',
      numeric_code = '533',
      official_name = 'Aruba',
      display_name = 'Aruba',
      default_currency_code = 'AWG'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AW', 'ABW', '533', 'Aruba', 'Aruba', 'AWG', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AU');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'AUS',
      numeric_code = '036',
      official_name = 'Australia',
      display_name = 'Australia',
      default_currency_code = 'AUD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AU', 'AUS', '036', 'Australia', 'Australia', 'AUD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AT');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'AUT',
      numeric_code = '040',
      official_name = 'Austria',
      display_name = 'Austria',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AT', 'AUT', '040', 'Austria', 'Austria', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AZ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'AZE',
      numeric_code = '031',
      official_name = 'Azerbaijan',
      display_name = 'Azerbaijan',
      default_currency_code = 'AZN'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AZ', 'AZE', '031', 'Azerbaijan', 'Azerbaijan', 'AZN', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BS');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BHS',
      numeric_code = '044',
      official_name = 'Bahamas',
      display_name = 'Bahamas',
      default_currency_code = 'BSD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BS', 'BHS', '044', 'Bahamas', 'Bahamas', 'BSD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BH');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BHR',
      numeric_code = '048',
      official_name = 'Bahrain',
      display_name = 'Bahrain',
      default_currency_code = 'BHD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BH', 'BHR', '048', 'Bahrain', 'Bahrain', 'BHD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BD');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BGD',
      numeric_code = '050',
      official_name = 'Bangladesh',
      display_name = 'Bangladesh',
      default_currency_code = 'BDT'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BD', 'BGD', '050', 'Bangladesh', 'Bangladesh', 'BDT', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BB');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BRB',
      numeric_code = '052',
      official_name = 'Barbados',
      display_name = 'Barbados',
      default_currency_code = 'BBD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BB', 'BRB', '052', 'Barbados', 'Barbados', 'BBD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BY');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BLR',
      numeric_code = '112',
      official_name = 'Belarus',
      display_name = 'Belarus',
      default_currency_code = 'BYN'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BY', 'BLR', '112', 'Belarus', 'Belarus', 'BYN', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BEL',
      numeric_code = '056',
      official_name = 'Belgium',
      display_name = 'Belgium',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BE', 'BEL', '056', 'Belgium', 'Belgium', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BZ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BLZ',
      numeric_code = '084',
      official_name = 'Belize',
      display_name = 'Belize',
      default_currency_code = 'BZD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BZ', 'BLZ', '084', 'Belize', 'Belize', 'BZD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BJ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BEN',
      numeric_code = '204',
      official_name = 'Benin',
      display_name = 'Benin',
      default_currency_code = 'XOF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BJ', 'BEN', '204', 'Benin', 'Benin', 'XOF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BMU',
      numeric_code = '060',
      official_name = 'Bermuda',
      display_name = 'Bermuda',
      default_currency_code = 'BMD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BM', 'BMU', '060', 'Bermuda', 'Bermuda', 'BMD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BT');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BTN',
      numeric_code = '064',
      official_name = 'Bhutan',
      display_name = 'Bhutan',
      default_currency_code = 'INR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BT', 'BTN', '064', 'Bhutan', 'Bhutan', 'INR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BO');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BOL',
      numeric_code = '068',
      official_name = 'Bolivia, Plurinational State of',
      display_name = 'Bolivia, Plurinational State of',
      default_currency_code = 'BOB'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BO', 'BOL', '068', 'Bolivia, Plurinational State of', 'Bolivia, Plurinational State of', 'BOB', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BQ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BES',
      numeric_code = '535',
      official_name = 'Bonaire, Sint Eustatius and Saba',
      display_name = 'Bonaire, Sint Eustatius and Saba',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BQ', 'BES', '535', 'Bonaire, Sint Eustatius and Saba', 'Bonaire, Sint Eustatius and Saba', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BA');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BIH',
      numeric_code = '070',
      official_name = 'Bosnia and Herzegovina',
      display_name = 'Bosnia and Herzegovina',
      default_currency_code = 'BAM'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BA', 'BIH', '070', 'Bosnia and Herzegovina', 'Bosnia and Herzegovina', 'BAM', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BW');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BWA',
      numeric_code = '072',
      official_name = 'Botswana',
      display_name = 'Botswana',
      default_currency_code = 'BWP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BW', 'BWA', '072', 'Botswana', 'Botswana', 'BWP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BV');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BVT',
      numeric_code = '074',
      official_name = 'Bouvet Island',
      display_name = 'Bouvet Island',
      default_currency_code = 'NOK'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BV', 'BVT', '074', 'Bouvet Island', 'Bouvet Island', 'NOK', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BRA',
      numeric_code = '076',
      official_name = 'Brazil',
      display_name = 'Brazil',
      default_currency_code = 'BRL'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BR', 'BRA', '076', 'Brazil', 'Brazil', 'BRL', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('IO');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'IOT',
      numeric_code = '086',
      official_name = 'British Indian Ocean Territory',
      display_name = 'British Indian Ocean Territory',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('IO', 'IOT', '086', 'British Indian Ocean Territory', 'British Indian Ocean Territory', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BN');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BRN',
      numeric_code = '096',
      official_name = 'Brunei Darussalam',
      display_name = 'Brunei Darussalam',
      default_currency_code = 'BND'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BN', 'BRN', '096', 'Brunei Darussalam', 'Brunei Darussalam', 'BND', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BG');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BGR',
      numeric_code = '100',
      official_name = 'Bulgaria',
      display_name = 'Bulgaria',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BG', 'BGR', '100', 'Bulgaria', 'Bulgaria', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BF');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BFA',
      numeric_code = '854',
      official_name = 'Burkina Faso',
      display_name = 'Burkina Faso',
      default_currency_code = 'XOF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BF', 'BFA', '854', 'Burkina Faso', 'Burkina Faso', 'XOF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BI');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BDI',
      numeric_code = '108',
      official_name = 'Burundi',
      display_name = 'Burundi',
      default_currency_code = 'BIF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BI', 'BDI', '108', 'Burundi', 'Burundi', 'BIF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CV');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CPV',
      numeric_code = '132',
      official_name = 'Cabo Verde',
      display_name = 'Cabo Verde',
      default_currency_code = 'CVE'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CV', 'CPV', '132', 'Cabo Verde', 'Cabo Verde', 'CVE', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('KH');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'KHM',
      numeric_code = '116',
      official_name = 'Cambodia',
      display_name = 'Cambodia',
      default_currency_code = 'KHR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('KH', 'KHM', '116', 'Cambodia', 'Cambodia', 'KHR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CMR',
      numeric_code = '120',
      official_name = 'Cameroon',
      display_name = 'Cameroon',
      default_currency_code = 'XAF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CM', 'CMR', '120', 'Cameroon', 'Cameroon', 'XAF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CA');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CAN',
      numeric_code = '124',
      official_name = 'Canada',
      display_name = 'Canada',
      default_currency_code = 'CAD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CA', 'CAN', '124', 'Canada', 'Canada', 'CAD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('KY');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CYM',
      numeric_code = '136',
      official_name = 'Cayman Islands',
      display_name = 'Cayman Islands',
      default_currency_code = 'KYD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('KY', 'CYM', '136', 'Cayman Islands', 'Cayman Islands', 'KYD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CF');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CAF',
      numeric_code = '140',
      official_name = 'Central African Republic',
      display_name = 'Central African Republic',
      default_currency_code = 'XAF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CF', 'CAF', '140', 'Central African Republic', 'Central African Republic', 'XAF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TD');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TCD',
      numeric_code = '148',
      official_name = 'Chad',
      display_name = 'Chad',
      default_currency_code = 'XAF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TD', 'TCD', '148', 'Chad', 'Chad', 'XAF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CL');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CHL',
      numeric_code = '152',
      official_name = 'Chile',
      display_name = 'Chile',
      default_currency_code = 'CLP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CL', 'CHL', '152', 'Chile', 'Chile', 'CLP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CN');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CHN',
      numeric_code = '156',
      official_name = 'China',
      display_name = 'China',
      default_currency_code = 'CNY'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CN', 'CHN', '156', 'China', 'China', 'CNY', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CX');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CXR',
      numeric_code = '162',
      official_name = 'Christmas Island',
      display_name = 'Christmas Island',
      default_currency_code = 'AUD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CX', 'CXR', '162', 'Christmas Island', 'Christmas Island', 'AUD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CC');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CCK',
      numeric_code = '166',
      official_name = 'Cocos (Keeling) Islands',
      display_name = 'Cocos (Keeling) Islands',
      default_currency_code = 'AUD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CC', 'CCK', '166', 'Cocos (Keeling) Islands', 'Cocos (Keeling) Islands', 'AUD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CO');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'COL',
      numeric_code = '170',
      official_name = 'Colombia',
      display_name = 'Colombia',
      default_currency_code = 'COP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CO', 'COL', '170', 'Colombia', 'Colombia', 'COP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('KM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'COM',
      numeric_code = '174',
      official_name = 'Comoros',
      display_name = 'Comoros',
      default_currency_code = 'KMF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('KM', 'COM', '174', 'Comoros', 'Comoros', 'KMF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CG');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'COG',
      numeric_code = '178',
      official_name = 'Congo',
      display_name = 'Congo',
      default_currency_code = 'XAF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CG', 'COG', '178', 'Congo', 'Congo', 'XAF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CD');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'COD',
      numeric_code = '180',
      official_name = 'Congo, Democratic Republic of the',
      display_name = 'Congo, Democratic Republic of the',
      default_currency_code = 'CDF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CD', 'COD', '180', 'Congo, Democratic Republic of the', 'Congo, Democratic Republic of the', 'CDF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CK');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'COK',
      numeric_code = '184',
      official_name = 'Cook Islands',
      display_name = 'Cook Islands',
      default_currency_code = 'NZD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CK', 'COK', '184', 'Cook Islands', 'Cook Islands', 'NZD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CRI',
      numeric_code = '188',
      official_name = 'Costa Rica',
      display_name = 'Costa Rica',
      default_currency_code = 'CRC'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CR', 'CRI', '188', 'Costa Rica', 'Costa Rica', 'CRC', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CI');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CIV',
      numeric_code = '384',
      official_name = 'Côte d''Ivoire',
      display_name = 'Côte d''Ivoire',
      default_currency_code = 'XOF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CI', 'CIV', '384', 'Côte d''Ivoire', 'Côte d''Ivoire', 'XOF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('HR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'HRV',
      numeric_code = '191',
      official_name = 'Croatia',
      display_name = 'Croatia',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('HR', 'HRV', '191', 'Croatia', 'Croatia', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CU');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CUB',
      numeric_code = '192',
      official_name = 'Cuba',
      display_name = 'Cuba',
      default_currency_code = 'CUP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CU', 'CUB', '192', 'Cuba', 'Cuba', 'CUP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CW');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CUW',
      numeric_code = '531',
      official_name = 'Curaçao',
      display_name = 'Curaçao',
      default_currency_code = 'XCG'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CW', 'CUW', '531', 'Curaçao', 'Curaçao', 'XCG', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CY');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CYP',
      numeric_code = '196',
      official_name = 'Cyprus',
      display_name = 'Cyprus',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CY', 'CYP', '196', 'Cyprus', 'Cyprus', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CZ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CZE',
      numeric_code = '203',
      official_name = 'Czechia',
      display_name = 'Czechia',
      default_currency_code = 'CZK'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CZ', 'CZE', '203', 'Czechia', 'Czechia', 'CZK', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('DK');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'DNK',
      numeric_code = '208',
      official_name = 'Denmark',
      display_name = 'Denmark',
      default_currency_code = 'DKK'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('DK', 'DNK', '208', 'Denmark', 'Denmark', 'DKK', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('DJ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'DJI',
      numeric_code = '262',
      official_name = 'Djibouti',
      display_name = 'Djibouti',
      default_currency_code = 'DJF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('DJ', 'DJI', '262', 'Djibouti', 'Djibouti', 'DJF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('DM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'DMA',
      numeric_code = '212',
      official_name = 'Dominica',
      display_name = 'Dominica',
      default_currency_code = 'XCD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('DM', 'DMA', '212', 'Dominica', 'Dominica', 'XCD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('DO');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'DOM',
      numeric_code = '214',
      official_name = 'Dominican Republic',
      display_name = 'Dominican Republic',
      default_currency_code = 'DOP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('DO', 'DOM', '214', 'Dominican Republic', 'Dominican Republic', 'DOP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('EC');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ECU',
      numeric_code = '218',
      official_name = 'Ecuador',
      display_name = 'Ecuador',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('EC', 'ECU', '218', 'Ecuador', 'Ecuador', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('EG');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'EGY',
      numeric_code = '818',
      official_name = 'Egypt',
      display_name = 'Egypt',
      default_currency_code = 'EGP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('EG', 'EGY', '818', 'Egypt', 'Egypt', 'EGP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SV');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SLV',
      numeric_code = '222',
      official_name = 'El Salvador',
      display_name = 'El Salvador',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SV', 'SLV', '222', 'El Salvador', 'El Salvador', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GQ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GNQ',
      numeric_code = '226',
      official_name = 'Equatorial Guinea',
      display_name = 'Equatorial Guinea',
      default_currency_code = 'XAF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GQ', 'GNQ', '226', 'Equatorial Guinea', 'Equatorial Guinea', 'XAF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('ER');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ERI',
      numeric_code = '232',
      official_name = 'Eritrea',
      display_name = 'Eritrea',
      default_currency_code = 'ERN'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('ER', 'ERI', '232', 'Eritrea', 'Eritrea', 'ERN', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('EE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'EST',
      numeric_code = '233',
      official_name = 'Estonia',
      display_name = 'Estonia',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('EE', 'EST', '233', 'Estonia', 'Estonia', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SZ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SWZ',
      numeric_code = '748',
      official_name = 'Eswatini',
      display_name = 'Eswatini',
      default_currency_code = 'SZL'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SZ', 'SWZ', '748', 'Eswatini', 'Eswatini', 'SZL', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('ET');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ETH',
      numeric_code = '231',
      official_name = 'Ethiopia',
      display_name = 'Ethiopia',
      default_currency_code = 'ETB'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('ET', 'ETH', '231', 'Ethiopia', 'Ethiopia', 'ETB', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('FK');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'FLK',
      numeric_code = '238',
      official_name = 'Falkland Islands (Malvinas)',
      display_name = 'Falkland Islands (Malvinas)',
      default_currency_code = 'FKP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('FK', 'FLK', '238', 'Falkland Islands (Malvinas)', 'Falkland Islands (Malvinas)', 'FKP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('FO');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'FRO',
      numeric_code = '234',
      official_name = 'Faroe Islands',
      display_name = 'Faroe Islands',
      default_currency_code = 'DKK'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('FO', 'FRO', '234', 'Faroe Islands', 'Faroe Islands', 'DKK', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('FJ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'FJI',
      numeric_code = '242',
      official_name = 'Fiji',
      display_name = 'Fiji',
      default_currency_code = 'FJD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('FJ', 'FJI', '242', 'Fiji', 'Fiji', 'FJD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('FI');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'FIN',
      numeric_code = '246',
      official_name = 'Finland',
      display_name = 'Finland',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('FI', 'FIN', '246', 'Finland', 'Finland', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('FR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'FRA',
      numeric_code = '250',
      official_name = 'France',
      display_name = 'France',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('FR', 'FRA', '250', 'France', 'France', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GF');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GUF',
      numeric_code = '254',
      official_name = 'French Guiana',
      display_name = 'French Guiana',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GF', 'GUF', '254', 'French Guiana', 'French Guiana', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PF');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'PYF',
      numeric_code = '258',
      official_name = 'French Polynesia',
      display_name = 'French Polynesia',
      default_currency_code = 'XPF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PF', 'PYF', '258', 'French Polynesia', 'French Polynesia', 'XPF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TF');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ATF',
      numeric_code = '260',
      official_name = 'French Southern Territories',
      display_name = 'French Southern Territories',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TF', 'ATF', '260', 'French Southern Territories', 'French Southern Territories', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GA');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GAB',
      numeric_code = '266',
      official_name = 'Gabon',
      display_name = 'Gabon',
      default_currency_code = 'XAF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GA', 'GAB', '266', 'Gabon', 'Gabon', 'XAF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GMB',
      numeric_code = '270',
      official_name = 'Gambia',
      display_name = 'Gambia',
      default_currency_code = 'GMD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GM', 'GMB', '270', 'Gambia', 'Gambia', 'GMD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GEO',
      numeric_code = '268',
      official_name = 'Georgia',
      display_name = 'Georgia',
      default_currency_code = 'GEL'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GE', 'GEO', '268', 'Georgia', 'Georgia', 'GEL', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('DE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'DEU',
      numeric_code = '276',
      official_name = 'Germany',
      display_name = 'Germany',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('DE', 'DEU', '276', 'Germany', 'Germany', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GH');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GHA',
      numeric_code = '288',
      official_name = 'Ghana',
      display_name = 'Ghana',
      default_currency_code = 'GHS'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GH', 'GHA', '288', 'Ghana', 'Ghana', 'GHS', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GI');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GIB',
      numeric_code = '292',
      official_name = 'Gibraltar',
      display_name = 'Gibraltar',
      default_currency_code = 'GIP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GI', 'GIB', '292', 'Gibraltar', 'Gibraltar', 'GIP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GRC',
      numeric_code = '300',
      official_name = 'Greece',
      display_name = 'Greece',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GR', 'GRC', '300', 'Greece', 'Greece', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GL');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GRL',
      numeric_code = '304',
      official_name = 'Greenland',
      display_name = 'Greenland',
      default_currency_code = 'DKK'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GL', 'GRL', '304', 'Greenland', 'Greenland', 'DKK', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GD');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GRD',
      numeric_code = '308',
      official_name = 'Grenada',
      display_name = 'Grenada',
      default_currency_code = 'XCD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GD', 'GRD', '308', 'Grenada', 'Grenada', 'XCD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GP');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GLP',
      numeric_code = '312',
      official_name = 'Guadeloupe',
      display_name = 'Guadeloupe',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GP', 'GLP', '312', 'Guadeloupe', 'Guadeloupe', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GU');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GUM',
      numeric_code = '316',
      official_name = 'Guam',
      display_name = 'Guam',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GU', 'GUM', '316', 'Guam', 'Guam', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GT');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GTM',
      numeric_code = '320',
      official_name = 'Guatemala',
      display_name = 'Guatemala',
      default_currency_code = 'GTQ'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GT', 'GTM', '320', 'Guatemala', 'Guatemala', 'GTQ', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GG');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GGY',
      numeric_code = '831',
      official_name = 'Guernsey',
      display_name = 'Guernsey',
      default_currency_code = 'GBP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GG', 'GGY', '831', 'Guernsey', 'Guernsey', 'GBP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GN');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GIN',
      numeric_code = '324',
      official_name = 'Guinea',
      display_name = 'Guinea',
      default_currency_code = 'GNF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GN', 'GIN', '324', 'Guinea', 'Guinea', 'GNF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GW');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GNB',
      numeric_code = '624',
      official_name = 'Guinea-Bissau',
      display_name = 'Guinea-Bissau',
      default_currency_code = 'XOF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GW', 'GNB', '624', 'Guinea-Bissau', 'Guinea-Bissau', 'XOF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GY');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GUY',
      numeric_code = '328',
      official_name = 'Guyana',
      display_name = 'Guyana',
      default_currency_code = 'GYD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GY', 'GUY', '328', 'Guyana', 'Guyana', 'GYD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('HT');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'HTI',
      numeric_code = '332',
      official_name = 'Haiti',
      display_name = 'Haiti',
      default_currency_code = 'HTG'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('HT', 'HTI', '332', 'Haiti', 'Haiti', 'HTG', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('HM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'HMD',
      numeric_code = '334',
      official_name = 'Heard Island and McDonald Islands',
      display_name = 'Heard Island and McDonald Islands',
      default_currency_code = 'AUD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('HM', 'HMD', '334', 'Heard Island and McDonald Islands', 'Heard Island and McDonald Islands', 'AUD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('VA');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'VAT',
      numeric_code = '336',
      official_name = 'Holy See',
      display_name = 'Holy See',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('VA', 'VAT', '336', 'Holy See', 'Holy See', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('HN');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'HND',
      numeric_code = '340',
      official_name = 'Honduras',
      display_name = 'Honduras',
      default_currency_code = 'HNL'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('HN', 'HND', '340', 'Honduras', 'Honduras', 'HNL', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('HK');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'HKG',
      numeric_code = '344',
      official_name = 'Hong Kong',
      display_name = 'Hong Kong',
      default_currency_code = 'HKD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('HK', 'HKG', '344', 'Hong Kong', 'Hong Kong', 'HKD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('HU');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'HUN',
      numeric_code = '348',
      official_name = 'Hungary',
      display_name = 'Hungary',
      default_currency_code = 'HUF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('HU', 'HUN', '348', 'Hungary', 'Hungary', 'HUF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('IS');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ISL',
      numeric_code = '352',
      official_name = 'Iceland',
      display_name = 'Iceland',
      default_currency_code = 'ISK'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('IS', 'ISL', '352', 'Iceland', 'Iceland', 'ISK', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('IN');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'IND',
      numeric_code = '356',
      official_name = 'India',
      display_name = 'India',
      default_currency_code = 'INR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('IN', 'IND', '356', 'India', 'India', 'INR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('ID');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'IDN',
      numeric_code = '360',
      official_name = 'Indonesia',
      display_name = 'Indonesia',
      default_currency_code = 'IDR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('ID', 'IDN', '360', 'Indonesia', 'Indonesia', 'IDR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('IR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'IRN',
      numeric_code = '364',
      official_name = 'Iran, Islamic Republic of',
      display_name = 'Iran, Islamic Republic of',
      default_currency_code = 'IRR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('IR', 'IRN', '364', 'Iran, Islamic Republic of', 'Iran, Islamic Republic of', 'IRR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('IQ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'IRQ',
      numeric_code = '368',
      official_name = 'Iraq',
      display_name = 'Iraq',
      default_currency_code = 'IQD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('IQ', 'IRQ', '368', 'Iraq', 'Iraq', 'IQD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('IE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'IRL',
      numeric_code = '372',
      official_name = 'Ireland',
      display_name = 'Ireland',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('IE', 'IRL', '372', 'Ireland', 'Ireland', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('IM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'IMN',
      numeric_code = '833',
      official_name = 'Isle of Man',
      display_name = 'Isle of Man',
      default_currency_code = 'GBP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('IM', 'IMN', '833', 'Isle of Man', 'Isle of Man', 'GBP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('IL');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ISR',
      numeric_code = '376',
      official_name = 'Israel',
      display_name = 'Israel',
      default_currency_code = 'ILS'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('IL', 'ISR', '376', 'Israel', 'Israel', 'ILS', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('IT');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ITA',
      numeric_code = '380',
      official_name = 'Italy',
      display_name = 'Italy',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('IT', 'ITA', '380', 'Italy', 'Italy', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('JM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'JAM',
      numeric_code = '388',
      official_name = 'Jamaica',
      display_name = 'Jamaica',
      default_currency_code = 'JMD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('JM', 'JAM', '388', 'Jamaica', 'Jamaica', 'JMD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('JP');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'JPN',
      numeric_code = '392',
      official_name = 'Japan',
      display_name = 'Japan',
      default_currency_code = 'JPY'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('JP', 'JPN', '392', 'Japan', 'Japan', 'JPY', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('JE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'JEY',
      numeric_code = '832',
      official_name = 'Jersey',
      display_name = 'Jersey',
      default_currency_code = 'GBP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('JE', 'JEY', '832', 'Jersey', 'Jersey', 'GBP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('JO');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'JOR',
      numeric_code = '400',
      official_name = 'Jordan',
      display_name = 'Jordan',
      default_currency_code = 'JOD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('JO', 'JOR', '400', 'Jordan', 'Jordan', 'JOD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('KZ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'KAZ',
      numeric_code = '398',
      official_name = 'Kazakhstan',
      display_name = 'Kazakhstan',
      default_currency_code = 'KZT'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('KZ', 'KAZ', '398', 'Kazakhstan', 'Kazakhstan', 'KZT', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('KE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'KEN',
      numeric_code = '404',
      official_name = 'Kenya',
      display_name = 'Kenya',
      default_currency_code = 'KES'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('KE', 'KEN', '404', 'Kenya', 'Kenya', 'KES', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('KI');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'KIR',
      numeric_code = '296',
      official_name = 'Kiribati',
      display_name = 'Kiribati',
      default_currency_code = 'AUD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('KI', 'KIR', '296', 'Kiribati', 'Kiribati', 'AUD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('KP');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'PRK',
      numeric_code = '408',
      official_name = 'Korea, Democratic People''s Republic of',
      display_name = 'Korea, Democratic People''s Republic of',
      default_currency_code = 'KPW'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('KP', 'PRK', '408', 'Korea, Democratic People''s Republic of', 'Korea, Democratic People''s Republic of', 'KPW', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('KR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'KOR',
      numeric_code = '410',
      official_name = 'Korea, Republic of',
      display_name = 'Korea, Republic of',
      default_currency_code = 'KRW'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('KR', 'KOR', '410', 'Korea, Republic of', 'Korea, Republic of', 'KRW', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('KW');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'KWT',
      numeric_code = '414',
      official_name = 'Kuwait',
      display_name = 'Kuwait',
      default_currency_code = 'KWD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('KW', 'KWT', '414', 'Kuwait', 'Kuwait', 'KWD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('KG');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'KGZ',
      numeric_code = '417',
      official_name = 'Kyrgyzstan',
      display_name = 'Kyrgyzstan',
      default_currency_code = 'KGS'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('KG', 'KGZ', '417', 'Kyrgyzstan', 'Kyrgyzstan', 'KGS', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('LA');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'LAO',
      numeric_code = '418',
      official_name = 'Lao People''s Democratic Republic',
      display_name = 'Lao People''s Democratic Republic',
      default_currency_code = 'LAK'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('LA', 'LAO', '418', 'Lao People''s Democratic Republic', 'Lao People''s Democratic Republic', 'LAK', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('LV');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'LVA',
      numeric_code = '428',
      official_name = 'Latvia',
      display_name = 'Latvia',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('LV', 'LVA', '428', 'Latvia', 'Latvia', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('LB');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'LBN',
      numeric_code = '422',
      official_name = 'Lebanon',
      display_name = 'Lebanon',
      default_currency_code = 'LBP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('LB', 'LBN', '422', 'Lebanon', 'Lebanon', 'LBP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('LS');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'LSO',
      numeric_code = '426',
      official_name = 'Lesotho',
      display_name = 'Lesotho',
      default_currency_code = 'ZAR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('LS', 'LSO', '426', 'Lesotho', 'Lesotho', 'ZAR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('LR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'LBR',
      numeric_code = '430',
      official_name = 'Liberia',
      display_name = 'Liberia',
      default_currency_code = 'LRD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('LR', 'LBR', '430', 'Liberia', 'Liberia', 'LRD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('LY');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'LBY',
      numeric_code = '434',
      official_name = 'Libya',
      display_name = 'Libya',
      default_currency_code = 'LYD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('LY', 'LBY', '434', 'Libya', 'Libya', 'LYD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('LI');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'LIE',
      numeric_code = '438',
      official_name = 'Liechtenstein',
      display_name = 'Liechtenstein',
      default_currency_code = 'CHF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('LI', 'LIE', '438', 'Liechtenstein', 'Liechtenstein', 'CHF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('LT');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'LTU',
      numeric_code = '440',
      official_name = 'Lithuania',
      display_name = 'Lithuania',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('LT', 'LTU', '440', 'Lithuania', 'Lithuania', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('LU');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'LUX',
      numeric_code = '442',
      official_name = 'Luxembourg',
      display_name = 'Luxembourg',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('LU', 'LUX', '442', 'Luxembourg', 'Luxembourg', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MO');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MAC',
      numeric_code = '446',
      official_name = 'Macao',
      display_name = 'Macao',
      default_currency_code = 'MOP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MO', 'MAC', '446', 'Macao', 'Macao', 'MOP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MG');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MDG',
      numeric_code = '450',
      official_name = 'Madagascar',
      display_name = 'Madagascar',
      default_currency_code = 'MGA'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MG', 'MDG', '450', 'Madagascar', 'Madagascar', 'MGA', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MW');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MWI',
      numeric_code = '454',
      official_name = 'Malawi',
      display_name = 'Malawi',
      default_currency_code = 'MWK'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MW', 'MWI', '454', 'Malawi', 'Malawi', 'MWK', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MY');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MYS',
      numeric_code = '458',
      official_name = 'Malaysia',
      display_name = 'Malaysia',
      default_currency_code = 'MYR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MY', 'MYS', '458', 'Malaysia', 'Malaysia', 'MYR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MV');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MDV',
      numeric_code = '462',
      official_name = 'Maldives',
      display_name = 'Maldives',
      default_currency_code = 'MVR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MV', 'MDV', '462', 'Maldives', 'Maldives', 'MVR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('ML');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MLI',
      numeric_code = '466',
      official_name = 'Mali',
      display_name = 'Mali',
      default_currency_code = 'XOF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('ML', 'MLI', '466', 'Mali', 'Mali', 'XOF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MT');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MLT',
      numeric_code = '470',
      official_name = 'Malta',
      display_name = 'Malta',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MT', 'MLT', '470', 'Malta', 'Malta', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MH');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MHL',
      numeric_code = '584',
      official_name = 'Marshall Islands',
      display_name = 'Marshall Islands',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MH', 'MHL', '584', 'Marshall Islands', 'Marshall Islands', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MQ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MTQ',
      numeric_code = '474',
      official_name = 'Martinique',
      display_name = 'Martinique',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MQ', 'MTQ', '474', 'Martinique', 'Martinique', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MRT',
      numeric_code = '478',
      official_name = 'Mauritania',
      display_name = 'Mauritania',
      default_currency_code = 'MRU'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MR', 'MRT', '478', 'Mauritania', 'Mauritania', 'MRU', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MU');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MUS',
      numeric_code = '480',
      official_name = 'Mauritius',
      display_name = 'Mauritius',
      default_currency_code = 'MUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MU', 'MUS', '480', 'Mauritius', 'Mauritius', 'MUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('YT');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MYT',
      numeric_code = '175',
      official_name = 'Mayotte',
      display_name = 'Mayotte',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('YT', 'MYT', '175', 'Mayotte', 'Mayotte', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MX');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MEX',
      numeric_code = '484',
      official_name = 'Mexico',
      display_name = 'Mexico',
      default_currency_code = 'MXN'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MX', 'MEX', '484', 'Mexico', 'Mexico', 'MXN', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('FM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'FSM',
      numeric_code = '583',
      official_name = 'Micronesia, Federated States of',
      display_name = 'Micronesia, Federated States of',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('FM', 'FSM', '583', 'Micronesia, Federated States of', 'Micronesia, Federated States of', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MD');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MDA',
      numeric_code = '498',
      official_name = 'Moldova, Republic of',
      display_name = 'Moldova, Republic of',
      default_currency_code = 'MDL'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MD', 'MDA', '498', 'Moldova, Republic of', 'Moldova, Republic of', 'MDL', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MC');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MCO',
      numeric_code = '492',
      official_name = 'Monaco',
      display_name = 'Monaco',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MC', 'MCO', '492', 'Monaco', 'Monaco', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MN');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MNG',
      numeric_code = '496',
      official_name = 'Mongolia',
      display_name = 'Mongolia',
      default_currency_code = 'MNT'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MN', 'MNG', '496', 'Mongolia', 'Mongolia', 'MNT', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('ME');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MNE',
      numeric_code = '499',
      official_name = 'Montenegro',
      display_name = 'Montenegro',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('ME', 'MNE', '499', 'Montenegro', 'Montenegro', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MS');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MSR',
      numeric_code = '500',
      official_name = 'Montserrat',
      display_name = 'Montserrat',
      default_currency_code = 'XCD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MS', 'MSR', '500', 'Montserrat', 'Montserrat', 'XCD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MA');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MAR',
      numeric_code = '504',
      official_name = 'Morocco',
      display_name = 'Morocco',
      default_currency_code = 'MAD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MA', 'MAR', '504', 'Morocco', 'Morocco', 'MAD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MZ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MOZ',
      numeric_code = '508',
      official_name = 'Mozambique',
      display_name = 'Mozambique',
      default_currency_code = 'MZN'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MZ', 'MOZ', '508', 'Mozambique', 'Mozambique', 'MZN', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MMR',
      numeric_code = '104',
      official_name = 'Myanmar',
      display_name = 'Myanmar',
      default_currency_code = 'MMK'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MM', 'MMR', '104', 'Myanmar', 'Myanmar', 'MMK', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('NA');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'NAM',
      numeric_code = '516',
      official_name = 'Namibia',
      display_name = 'Namibia',
      default_currency_code = 'ZAR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('NA', 'NAM', '516', 'Namibia', 'Namibia', 'ZAR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('NR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'NRU',
      numeric_code = '520',
      official_name = 'Nauru',
      display_name = 'Nauru',
      default_currency_code = 'AUD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('NR', 'NRU', '520', 'Nauru', 'Nauru', 'AUD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('NP');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'NPL',
      numeric_code = '524',
      official_name = 'Nepal',
      display_name = 'Nepal',
      default_currency_code = 'NPR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('NP', 'NPL', '524', 'Nepal', 'Nepal', 'NPR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('NL');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'NLD',
      numeric_code = '528',
      official_name = 'Netherlands, Kingdom of the',
      display_name = 'Netherlands, Kingdom of the',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('NL', 'NLD', '528', 'Netherlands, Kingdom of the', 'Netherlands, Kingdom of the', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('NC');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'NCL',
      numeric_code = '540',
      official_name = 'New Caledonia',
      display_name = 'New Caledonia',
      default_currency_code = 'XPF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('NC', 'NCL', '540', 'New Caledonia', 'New Caledonia', 'XPF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('NZ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'NZL',
      numeric_code = '554',
      official_name = 'New Zealand',
      display_name = 'New Zealand',
      default_currency_code = 'NZD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('NZ', 'NZL', '554', 'New Zealand', 'New Zealand', 'NZD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('NI');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'NIC',
      numeric_code = '558',
      official_name = 'Nicaragua',
      display_name = 'Nicaragua',
      default_currency_code = 'NIO'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('NI', 'NIC', '558', 'Nicaragua', 'Nicaragua', 'NIO', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('NE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'NER',
      numeric_code = '562',
      official_name = 'Niger',
      display_name = 'Niger',
      default_currency_code = 'XOF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('NE', 'NER', '562', 'Niger', 'Niger', 'XOF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('NG');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'NGA',
      numeric_code = '566',
      official_name = 'Nigeria',
      display_name = 'Nigeria',
      default_currency_code = 'NGN'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('NG', 'NGA', '566', 'Nigeria', 'Nigeria', 'NGN', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('NU');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'NIU',
      numeric_code = '570',
      official_name = 'Niue',
      display_name = 'Niue',
      default_currency_code = 'NZD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('NU', 'NIU', '570', 'Niue', 'Niue', 'NZD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('NF');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'NFK',
      numeric_code = '574',
      official_name = 'Norfolk Island',
      display_name = 'Norfolk Island',
      default_currency_code = 'AUD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('NF', 'NFK', '574', 'Norfolk Island', 'Norfolk Island', 'AUD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MK');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MKD',
      numeric_code = '807',
      official_name = 'North Macedonia',
      display_name = 'North Macedonia',
      default_currency_code = 'MKD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MK', 'MKD', '807', 'North Macedonia', 'North Macedonia', 'MKD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MP');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MNP',
      numeric_code = '580',
      official_name = 'Northern Mariana Islands',
      display_name = 'Northern Mariana Islands',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MP', 'MNP', '580', 'Northern Mariana Islands', 'Northern Mariana Islands', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('NO');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'NOR',
      numeric_code = '578',
      official_name = 'Norway',
      display_name = 'Norway',
      default_currency_code = 'NOK'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('NO', 'NOR', '578', 'Norway', 'Norway', 'NOK', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('OM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'OMN',
      numeric_code = '512',
      official_name = 'Oman',
      display_name = 'Oman',
      default_currency_code = 'OMR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('OM', 'OMN', '512', 'Oman', 'Oman', 'OMR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PK');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'PAK',
      numeric_code = '586',
      official_name = 'Pakistan',
      display_name = 'Pakistan',
      default_currency_code = 'PKR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PK', 'PAK', '586', 'Pakistan', 'Pakistan', 'PKR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PW');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'PLW',
      numeric_code = '585',
      official_name = 'Palau',
      display_name = 'Palau',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PW', 'PLW', '585', 'Palau', 'Palau', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PS');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'PSE',
      numeric_code = '275',
      official_name = 'Palestine, State of',
      display_name = 'Palestine, State of',
      default_currency_code = 'ILS'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PS', 'PSE', '275', 'Palestine, State of', 'Palestine, State of', 'ILS', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PA');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'PAN',
      numeric_code = '591',
      official_name = 'Panama',
      display_name = 'Panama',
      default_currency_code = 'PAB'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PA', 'PAN', '591', 'Panama', 'Panama', 'PAB', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PG');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'PNG',
      numeric_code = '598',
      official_name = 'Papua New Guinea',
      display_name = 'Papua New Guinea',
      default_currency_code = 'PGK'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PG', 'PNG', '598', 'Papua New Guinea', 'Papua New Guinea', 'PGK', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PY');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'PRY',
      numeric_code = '600',
      official_name = 'Paraguay',
      display_name = 'Paraguay',
      default_currency_code = 'PYG'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PY', 'PRY', '600', 'Paraguay', 'Paraguay', 'PYG', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'PER',
      numeric_code = '604',
      official_name = 'Peru',
      display_name = 'Peru',
      default_currency_code = 'PEN'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PE', 'PER', '604', 'Peru', 'Peru', 'PEN', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PH');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'PHL',
      numeric_code = '608',
      official_name = 'Philippines',
      display_name = 'Philippines',
      default_currency_code = 'PHP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PH', 'PHL', '608', 'Philippines', 'Philippines', 'PHP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PN');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'PCN',
      numeric_code = '612',
      official_name = 'Pitcairn',
      display_name = 'Pitcairn',
      default_currency_code = 'NZD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PN', 'PCN', '612', 'Pitcairn', 'Pitcairn', 'NZD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PL');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'POL',
      numeric_code = '616',
      official_name = 'Poland',
      display_name = 'Poland',
      default_currency_code = 'PLN'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PL', 'POL', '616', 'Poland', 'Poland', 'PLN', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PT');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'PRT',
      numeric_code = '620',
      official_name = 'Portugal',
      display_name = 'Portugal',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PT', 'PRT', '620', 'Portugal', 'Portugal', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'PRI',
      numeric_code = '630',
      official_name = 'Puerto Rico',
      display_name = 'Puerto Rico',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PR', 'PRI', '630', 'Puerto Rico', 'Puerto Rico', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('QA');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'QAT',
      numeric_code = '634',
      official_name = 'Qatar',
      display_name = 'Qatar',
      default_currency_code = 'QAR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('QA', 'QAT', '634', 'Qatar', 'Qatar', 'QAR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('RE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'REU',
      numeric_code = '638',
      official_name = 'Réunion',
      display_name = 'Réunion',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('RE', 'REU', '638', 'Réunion', 'Réunion', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('RO');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ROU',
      numeric_code = '642',
      official_name = 'Romania',
      display_name = 'Romania',
      default_currency_code = 'RON'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('RO', 'ROU', '642', 'Romania', 'Romania', 'RON', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('RU');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'RUS',
      numeric_code = '643',
      official_name = 'Russian Federation',
      display_name = 'Russian Federation',
      default_currency_code = 'RUB'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('RU', 'RUS', '643', 'Russian Federation', 'Russian Federation', 'RUB', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('RW');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'RWA',
      numeric_code = '646',
      official_name = 'Rwanda',
      display_name = 'Rwanda',
      default_currency_code = 'RWF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('RW', 'RWA', '646', 'Rwanda', 'Rwanda', 'RWF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('BL');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'BLM',
      numeric_code = '652',
      official_name = 'Saint Barthélemy',
      display_name = 'Saint Barthélemy',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('BL', 'BLM', '652', 'Saint Barthélemy', 'Saint Barthélemy', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SH');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SHN',
      numeric_code = '654',
      official_name = 'Saint Helena, Ascension and Tristan da Cunha',
      display_name = 'Saint Helena, Ascension and Tristan da Cunha',
      default_currency_code = 'SHP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SH', 'SHN', '654', 'Saint Helena, Ascension and Tristan da Cunha', 'Saint Helena, Ascension and Tristan da Cunha', 'SHP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('KN');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'KNA',
      numeric_code = '659',
      official_name = 'Saint Kitts and Nevis',
      display_name = 'Saint Kitts and Nevis',
      default_currency_code = 'XCD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('KN', 'KNA', '659', 'Saint Kitts and Nevis', 'Saint Kitts and Nevis', 'XCD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('LC');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'LCA',
      numeric_code = '662',
      official_name = 'Saint Lucia',
      display_name = 'Saint Lucia',
      default_currency_code = 'XCD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('LC', 'LCA', '662', 'Saint Lucia', 'Saint Lucia', 'XCD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('MF');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'MAF',
      numeric_code = '663',
      official_name = 'Saint Martin (French part)',
      display_name = 'Saint Martin (French part)',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('MF', 'MAF', '663', 'Saint Martin (French part)', 'Saint Martin (French part)', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('PM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SPM',
      numeric_code = '666',
      official_name = 'Saint Pierre and Miquelon',
      display_name = 'Saint Pierre and Miquelon',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('PM', 'SPM', '666', 'Saint Pierre and Miquelon', 'Saint Pierre and Miquelon', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('VC');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'VCT',
      numeric_code = '670',
      official_name = 'Saint Vincent and the Grenadines',
      display_name = 'Saint Vincent and the Grenadines',
      default_currency_code = 'XCD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('VC', 'VCT', '670', 'Saint Vincent and the Grenadines', 'Saint Vincent and the Grenadines', 'XCD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('WS');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'WSM',
      numeric_code = '882',
      official_name = 'Samoa',
      display_name = 'Samoa',
      default_currency_code = 'WST'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('WS', 'WSM', '882', 'Samoa', 'Samoa', 'WST', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SMR',
      numeric_code = '674',
      official_name = 'San Marino',
      display_name = 'San Marino',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SM', 'SMR', '674', 'San Marino', 'San Marino', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('ST');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'STP',
      numeric_code = '678',
      official_name = 'Sao Tome and Principe',
      display_name = 'Sao Tome and Principe',
      default_currency_code = 'STN'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('ST', 'STP', '678', 'Sao Tome and Principe', 'Sao Tome and Principe', 'STN', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SA');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SAU',
      numeric_code = '682',
      official_name = 'Saudi Arabia',
      display_name = 'Saudi Arabia',
      default_currency_code = 'SAR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SA', 'SAU', '682', 'Saudi Arabia', 'Saudi Arabia', 'SAR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SN');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SEN',
      numeric_code = '686',
      official_name = 'Senegal',
      display_name = 'Senegal',
      default_currency_code = 'XOF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SN', 'SEN', '686', 'Senegal', 'Senegal', 'XOF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('RS');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SRB',
      numeric_code = '688',
      official_name = 'Serbia',
      display_name = 'Serbia',
      default_currency_code = 'RSD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('RS', 'SRB', '688', 'Serbia', 'Serbia', 'RSD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SC');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SYC',
      numeric_code = '690',
      official_name = 'Seychelles',
      display_name = 'Seychelles',
      default_currency_code = 'SCR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SC', 'SYC', '690', 'Seychelles', 'Seychelles', 'SCR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SL');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SLE',
      numeric_code = '694',
      official_name = 'Sierra Leone',
      display_name = 'Sierra Leone',
      default_currency_code = 'SLE'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SL', 'SLE', '694', 'Sierra Leone', 'Sierra Leone', 'SLE', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SG');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SGP',
      numeric_code = '702',
      official_name = 'Singapore',
      display_name = 'Singapore',
      default_currency_code = 'SGD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SG', 'SGP', '702', 'Singapore', 'Singapore', 'SGD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SX');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SXM',
      numeric_code = '534',
      official_name = 'Sint Maarten (Dutch part)',
      display_name = 'Sint Maarten (Dutch part)',
      default_currency_code = 'XCG'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SX', 'SXM', '534', 'Sint Maarten (Dutch part)', 'Sint Maarten (Dutch part)', 'XCG', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SK');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SVK',
      numeric_code = '703',
      official_name = 'Slovakia',
      display_name = 'Slovakia',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SK', 'SVK', '703', 'Slovakia', 'Slovakia', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SI');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SVN',
      numeric_code = '705',
      official_name = 'Slovenia',
      display_name = 'Slovenia',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SI', 'SVN', '705', 'Slovenia', 'Slovenia', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SB');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SLB',
      numeric_code = '090',
      official_name = 'Solomon Islands',
      display_name = 'Solomon Islands',
      default_currency_code = 'SBD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SB', 'SLB', '090', 'Solomon Islands', 'Solomon Islands', 'SBD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SO');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SOM',
      numeric_code = '706',
      official_name = 'Somalia',
      display_name = 'Somalia',
      default_currency_code = 'SOS'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SO', 'SOM', '706', 'Somalia', 'Somalia', 'SOS', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('ZA');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ZAF',
      numeric_code = '710',
      official_name = 'South Africa',
      display_name = 'South Africa',
      default_currency_code = 'ZAR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('ZA', 'ZAF', '710', 'South Africa', 'South Africa', 'ZAR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GS');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SGS',
      numeric_code = '239',
      official_name = 'South Georgia and the South Sandwich Islands',
      display_name = 'South Georgia and the South Sandwich Islands',
      default_currency_code = 'GBP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GS', 'SGS', '239', 'South Georgia and the South Sandwich Islands', 'South Georgia and the South Sandwich Islands', 'GBP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SS');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SSD',
      numeric_code = '728',
      official_name = 'South Sudan',
      display_name = 'South Sudan',
      default_currency_code = 'SSP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SS', 'SSD', '728', 'South Sudan', 'South Sudan', 'SSP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('ES');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ESP',
      numeric_code = '724',
      official_name = 'Spain',
      display_name = 'Spain',
      default_currency_code = 'EUR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('ES', 'ESP', '724', 'Spain', 'Spain', 'EUR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('LK');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'LKA',
      numeric_code = '144',
      official_name = 'Sri Lanka',
      display_name = 'Sri Lanka',
      default_currency_code = 'LKR'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('LK', 'LKA', '144', 'Sri Lanka', 'Sri Lanka', 'LKR', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SD');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SDN',
      numeric_code = '729',
      official_name = 'Sudan',
      display_name = 'Sudan',
      default_currency_code = 'SDG'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SD', 'SDN', '729', 'Sudan', 'Sudan', 'SDG', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SUR',
      numeric_code = '740',
      official_name = 'Suriname',
      display_name = 'Suriname',
      default_currency_code = 'SRD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SR', 'SUR', '740', 'Suriname', 'Suriname', 'SRD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SJ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SJM',
      numeric_code = '744',
      official_name = 'Svalbard and Jan Mayen',
      display_name = 'Svalbard and Jan Mayen',
      default_currency_code = 'NOK'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SJ', 'SJM', '744', 'Svalbard and Jan Mayen', 'Svalbard and Jan Mayen', 'NOK', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SWE',
      numeric_code = '752',
      official_name = 'Sweden',
      display_name = 'Sweden',
      default_currency_code = 'SEK'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SE', 'SWE', '752', 'Sweden', 'Sweden', 'SEK', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('CH');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'CHE',
      numeric_code = '756',
      official_name = 'Switzerland',
      display_name = 'Switzerland',
      default_currency_code = 'CHF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('CH', 'CHE', '756', 'Switzerland', 'Switzerland', 'CHF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('SY');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'SYR',
      numeric_code = '760',
      official_name = 'Syrian Arab Republic',
      display_name = 'Syrian Arab Republic',
      default_currency_code = 'SYP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('SY', 'SYR', '760', 'Syrian Arab Republic', 'Syrian Arab Republic', 'SYP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TW');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TWN',
      numeric_code = '158',
      official_name = 'Taiwan, Province of China',
      display_name = 'Taiwan, Province of China',
      default_currency_code = 'TWD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TW', 'TWN', '158', 'Taiwan, Province of China', 'Taiwan, Province of China', 'TWD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TJ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TJK',
      numeric_code = '762',
      official_name = 'Tajikistan',
      display_name = 'Tajikistan',
      default_currency_code = 'TJS'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TJ', 'TJK', '762', 'Tajikistan', 'Tajikistan', 'TJS', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TZ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TZA',
      numeric_code = '834',
      official_name = 'Tanzania, United Republic of',
      display_name = 'Tanzania, United Republic of',
      default_currency_code = 'TZS'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TZ', 'TZA', '834', 'Tanzania, United Republic of', 'Tanzania, United Republic of', 'TZS', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TH');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'THA',
      numeric_code = '764',
      official_name = 'Thailand',
      display_name = 'Thailand',
      default_currency_code = 'THB'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TH', 'THA', '764', 'Thailand', 'Thailand', 'THB', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TL');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TLS',
      numeric_code = '626',
      official_name = 'Timor-Leste',
      display_name = 'Timor-Leste',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TL', 'TLS', '626', 'Timor-Leste', 'Timor-Leste', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TG');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TGO',
      numeric_code = '768',
      official_name = 'Togo',
      display_name = 'Togo',
      default_currency_code = 'XOF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TG', 'TGO', '768', 'Togo', 'Togo', 'XOF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TK');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TKL',
      numeric_code = '772',
      official_name = 'Tokelau',
      display_name = 'Tokelau',
      default_currency_code = 'NZD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TK', 'TKL', '772', 'Tokelau', 'Tokelau', 'NZD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TO');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TON',
      numeric_code = '776',
      official_name = 'Tonga',
      display_name = 'Tonga',
      default_currency_code = 'TOP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TO', 'TON', '776', 'Tonga', 'Tonga', 'TOP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TT');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TTO',
      numeric_code = '780',
      official_name = 'Trinidad and Tobago',
      display_name = 'Trinidad and Tobago',
      default_currency_code = 'TTD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TT', 'TTO', '780', 'Trinidad and Tobago', 'Trinidad and Tobago', 'TTD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TN');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TUN',
      numeric_code = '788',
      official_name = 'Tunisia',
      display_name = 'Tunisia',
      default_currency_code = 'TND'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TN', 'TUN', '788', 'Tunisia', 'Tunisia', 'TND', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TR');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TUR',
      numeric_code = '792',
      official_name = 'Türkiye',
      display_name = 'Türkiye',
      default_currency_code = 'TRY'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TR', 'TUR', '792', 'Türkiye', 'Türkiye', 'TRY', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TKM',
      numeric_code = '795',
      official_name = 'Turkmenistan',
      display_name = 'Turkmenistan',
      default_currency_code = 'TMT'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TM', 'TKM', '795', 'Turkmenistan', 'Turkmenistan', 'TMT', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TC');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TCA',
      numeric_code = '796',
      official_name = 'Turks and Caicos Islands',
      display_name = 'Turks and Caicos Islands',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TC', 'TCA', '796', 'Turks and Caicos Islands', 'Turks and Caicos Islands', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('TV');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'TUV',
      numeric_code = '798',
      official_name = 'Tuvalu',
      display_name = 'Tuvalu',
      default_currency_code = 'AUD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('TV', 'TUV', '798', 'Tuvalu', 'Tuvalu', 'AUD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('UG');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'UGA',
      numeric_code = '800',
      official_name = 'Uganda',
      display_name = 'Uganda',
      default_currency_code = 'UGX'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('UG', 'UGA', '800', 'Uganda', 'Uganda', 'UGX', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('UA');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'UKR',
      numeric_code = '804',
      official_name = 'Ukraine',
      display_name = 'Ukraine',
      default_currency_code = 'UAH'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('UA', 'UKR', '804', 'Ukraine', 'Ukraine', 'UAH', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('AE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ARE',
      numeric_code = '784',
      official_name = 'United Arab Emirates',
      display_name = 'United Arab Emirates',
      default_currency_code = 'AED'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('AE', 'ARE', '784', 'United Arab Emirates', 'United Arab Emirates', 'AED', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('GB');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'GBR',
      numeric_code = '826',
      official_name = 'United Kingdom of Great Britain and Northern Ireland',
      display_name = 'United Kingdom of Great Britain and Northern Ireland',
      default_currency_code = 'GBP'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('GB', 'GBR', '826', 'United Kingdom of Great Britain and Northern Ireland', 'United Kingdom of Great Britain and Northern Ireland', 'GBP', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('US');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'USA',
      numeric_code = '840',
      official_name = 'United States of America',
      display_name = 'United States of America',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('US', 'USA', '840', 'United States of America', 'United States of America', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('UM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'UMI',
      numeric_code = '581',
      official_name = 'United States Minor Outlying Islands',
      display_name = 'United States Minor Outlying Islands',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('UM', 'UMI', '581', 'United States Minor Outlying Islands', 'United States Minor Outlying Islands', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('UY');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'URY',
      numeric_code = '858',
      official_name = 'Uruguay',
      display_name = 'Uruguay',
      default_currency_code = 'UYU'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('UY', 'URY', '858', 'Uruguay', 'Uruguay', 'UYU', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('UZ');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'UZB',
      numeric_code = '860',
      official_name = 'Uzbekistan',
      display_name = 'Uzbekistan',
      default_currency_code = 'UZS'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('UZ', 'UZB', '860', 'Uzbekistan', 'Uzbekistan', 'UZS', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('VU');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'VUT',
      numeric_code = '548',
      official_name = 'Vanuatu',
      display_name = 'Vanuatu',
      default_currency_code = 'VUV'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('VU', 'VUT', '548', 'Vanuatu', 'Vanuatu', 'VUV', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('VE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'VEN',
      numeric_code = '862',
      official_name = 'Venezuela, Bolivarian Republic of',
      display_name = 'Venezuela, Bolivarian Republic of',
      default_currency_code = 'VES'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('VE', 'VEN', '862', 'Venezuela, Bolivarian Republic of', 'Venezuela, Bolivarian Republic of', 'VES', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('VN');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'VNM',
      numeric_code = '704',
      official_name = 'Viet Nam',
      display_name = 'Viet Nam',
      default_currency_code = 'VND'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('VN', 'VNM', '704', 'Viet Nam', 'Viet Nam', 'VND', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('VG');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'VGB',
      numeric_code = '092',
      official_name = 'Virgin Islands (British)',
      display_name = 'Virgin Islands (British)',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('VG', 'VGB', '092', 'Virgin Islands (British)', 'Virgin Islands (British)', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('VI');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'VIR',
      numeric_code = '850',
      official_name = 'Virgin Islands (U.S.)',
      display_name = 'Virgin Islands (U.S.)',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('VI', 'VIR', '850', 'Virgin Islands (U.S.)', 'Virgin Islands (U.S.)', 'USD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('WF');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'WLF',
      numeric_code = '876',
      official_name = 'Wallis and Futuna',
      display_name = 'Wallis and Futuna',
      default_currency_code = 'XPF'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('WF', 'WLF', '876', 'Wallis and Futuna', 'Wallis and Futuna', 'XPF', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('EH');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ESH',
      numeric_code = '732',
      official_name = 'Western Sahara',
      display_name = 'Western Sahara',
      default_currency_code = 'MAD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('EH', 'ESH', '732', 'Western Sahara', 'Western Sahara', 'MAD', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('YE');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'YEM',
      numeric_code = '887',
      official_name = 'Yemen',
      display_name = 'Yemen',
      default_currency_code = 'YER'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('YE', 'YEM', '887', 'Yemen', 'Yemen', 'YER', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('ZM');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ZMB',
      numeric_code = '894',
      official_name = 'Zambia',
      display_name = 'Zambia',
      default_currency_code = 'ZMW'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('ZM', 'ZMB', '894', 'Zambia', 'Zambia', 'ZMW', 'ACTIVE');
  END IF;
  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER('ZW');
  IF v_id IS NOT NULL THEN
    UPDATE catalog.countries SET
      iso3 = 'ZWE',
      numeric_code = '716',
      official_name = 'Zimbabwe',
      display_name = 'Zimbabwe',
      default_currency_code = 'USD'
    WHERE id = v_id;
  ELSE
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)
    VALUES ('ZW', 'ZWE', '716', 'Zimbabwe', 'Zimbabwe', 'USD', 'ACTIVE');
  END IF;
END $$;

-- 3. Upsert Mappings
DO $$
DECLARE
  v_country_id UUID;
  v_currency_id UUID;
BEGIN
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AF';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AFN';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AX';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AL';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'ALL';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'DZ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'DZD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AS';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AD';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AO';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AOA';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AI';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XCD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AG';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XCD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'ARS';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AMD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AW';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AWG';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AU';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AUD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AT';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AZ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AZN';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BS';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BSD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BH';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BHD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BD';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BDT';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BB';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BBD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BY';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BYN';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BZ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BZD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BJ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XOF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BMD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BT';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'INR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BT';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BTN';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, false)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BO';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BOB';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BQ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BAM';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BW';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BWP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BV';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'NOK';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BRL';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IO';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BN';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BND';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BG';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BF';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XOF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BI';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'BIF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CV';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'CVE';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'KH';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'KHR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XAF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'CAD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'KY';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'KYD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CF';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XAF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TD';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XAF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CL';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'CLP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CN';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'CNY';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CX';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AUD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CC';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AUD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CO';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'COP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'KM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'KMF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CG';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XAF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CD';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'CDF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CK';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'NZD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'CRC';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CI';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XOF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'HR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CU';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'CUP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CW';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XCG';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CY';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CZ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'CZK';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'DK';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'DKK';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'DJ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'DJF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'DM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XCD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'DO';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'DOP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'EC';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'EG';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EGP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SV';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GQ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XAF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'ER';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'ERN';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'EE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SZ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'SZL';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'ET';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'ETB';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'FK';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'FKP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'FO';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'DKK';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'FJ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'FJD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'FI';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'FR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GF';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PF';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XPF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TF';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XAF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'GMD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'GEL';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'DE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GH';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'GHS';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GI';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'GIP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GL';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'DKK';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GD';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XCD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GP';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GU';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GT';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'GTQ';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GG';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'GBP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GN';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'GNF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GW';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XOF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GY';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'GYD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'HT';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'HTG';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'HT';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, false)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'HM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AUD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'VA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'HN';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'HNL';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'HK';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'HKD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'HU';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'HUF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IS';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'ISK';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IN';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'INR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'ID';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'IDR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'IRR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IQ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'IQD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'GBP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IL';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'ILS';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IT';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'JM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'JMD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'JP';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'JPY';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'JE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'GBP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'JO';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'JOD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'KZ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'KZT';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'KE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'KES';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'KI';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AUD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'KP';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'KPW';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'KR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'KRW';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'KW';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'KWD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'KG';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'KGS';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'LA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'LAK';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'LV';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'LB';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'LBP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'LS';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'ZAR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'LS';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'LSL';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, false)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'LR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'LRD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'LY';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'LYD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'LI';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'CHF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'LT';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'LU';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MO';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MOP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MG';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MGA';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MW';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MWK';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MY';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MYR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MV';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MVR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'ML';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XOF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MT';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MH';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MQ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MRU';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MU';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'YT';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MX';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MXN';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'FM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MD';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MDL';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MC';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MN';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MNT';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'ME';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MS';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XCD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MAD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MZ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MZN';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MMK';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'NA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'ZAR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'NA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'NAD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, false)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'NR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AUD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'NP';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'NPR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'NL';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'NC';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XPF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'NZ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'NZD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'NI';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'NIO';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'NE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XOF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'NG';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'NGN';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'NU';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'NZD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'NF';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AUD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MK';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MKD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MP';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'NO';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'NOK';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'OM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'OMR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PK';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'PKR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PW';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PS';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'ILS';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PS';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'JOD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, false)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'PAB';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, false)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PG';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'PGK';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PY';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'PYG';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'PEN';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PH';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'PHP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PN';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'NZD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PL';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'PLN';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PT';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'QA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'QAR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'RE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'RO';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'RON';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'RU';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'RUB';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'RW';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'RWF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'BL';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SH';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'SHP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'KN';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XCD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'LC';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XCD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'MF';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'PM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'VC';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XCD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'WS';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'WST';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'ST';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'STN';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'SAR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SN';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XOF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'RS';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'RSD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SC';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'SCR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SL';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'SLE';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SG';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'SGD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SX';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XCG';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SK';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SI';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SB';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'SBD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SO';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'SOS';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'ZA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'ZAR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GS';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'GBP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SS';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'SSP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'ES';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'EUR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'LK';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'LKR';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SD';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'SDG';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'SRD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SJ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'NOK';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'SEK';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'CH';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'CHF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'SY';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'SYP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TW';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'TWD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TJ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'TJS';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TZ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'TZS';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TH';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'THB';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TL';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TG';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XOF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TK';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'NZD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TO';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'TOP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TT';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'TTD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TN';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'TND';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TR';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'TRY';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'TMT';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TC';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'TV';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AUD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'UG';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'UGX';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'UA';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'UAH';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'AE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'AED';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'GB';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'GBP';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'US';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'UM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'UY';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'UYU';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'UZ';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'UZS';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'VU';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'VUV';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'VE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'VES';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'VN';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'VND';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'VG';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'VI';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'WF';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'XPF';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'EH';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'MAD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'YE';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'YER';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'ZM';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'ZMW';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'ZW';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'USD';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, true)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'ZW';
  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = 'ZWG';
  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN
    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)
    VALUES (v_country_id, v_currency_id, false)
    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  END IF;
END $$;

-- 4. Validations
DO $$
DECLARE
  v_state_count INT;
  v_dist_count INT;
  v_subdist_count INT;
  v_village_count INT;
BEGIN
  SELECT COUNT(*) INTO v_state_count FROM catalog.geography_units gu JOIN catalog.geography_levels gl ON gu.geography_level_id = gl.id WHERE gl.level_key = 'STATE_UT';
  SELECT COUNT(*) INTO v_dist_count FROM catalog.geography_units gu JOIN catalog.geography_levels gl ON gu.geography_level_id = gl.id WHERE gl.level_key = 'DISTRICT';
  SELECT COUNT(*) INTO v_subdist_count FROM catalog.geography_units gu JOIN catalog.geography_levels gl ON gu.geography_level_id = gl.id WHERE gl.level_key = 'SUB_DISTRICT';
  SELECT COUNT(*) INTO v_village_count FROM catalog.geography_units gu JOIN catalog.geography_levels gl ON gu.geography_level_id = gl.id WHERE gl.level_key IN ('VILLAGE', 'LOCALITY');
  IF v_state_count != 36 THEN RAISE EXCEPTION 'State count mismatch (expected 36, got %', v_state_count; END IF;
  IF v_dist_count != 784 THEN RAISE EXCEPTION 'District count mismatch (expected 784, got %', v_dist_count; END IF;
  IF v_subdist_count != 7092 THEN RAISE EXCEPTION 'Subdistrict count mismatch (expected 7092, got %', v_subdist_count; END IF;
  IF v_village_count != 0 THEN RAISE EXCEPTION 'Village count mismatch (expected 0, got %', v_village_count; END IF;
END $$;

COMMIT;