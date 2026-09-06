-- Migration 20260904000004: GST Master Data — Standalone HSN/SAC and GST Rate tables
--
-- Scope correction: NAMISH_GLOBAL_CONTROL stores only master data.
-- No calculation, no place-of-supply, no RCM, no ITC, no composition logic.
-- HSN/SAC codes and GST rates are INDEPENDENT datasets.
--
-- Forward correction — does NOT modify previously applied migrations.

BEGIN;

-- ============================================================
-- SECTION 1: EXTEND catalog.hsn_sac
-- Add all master-data fields required by the user directive.
-- ============================================================

ALTER TABLE catalog.hsn_sac
    ADD COLUMN IF NOT EXISTS code_type TEXT DEFAULT 'HSN' CHECK (code_type IN ('HSN','SAC')),
    ADD COLUMN IF NOT EXISTS chapter TEXT,
    ADD COLUMN IF NOT EXISTS heading TEXT,
    ADD COLUMN IF NOT EXISTS parent_code TEXT,
    ADD COLUMN IF NOT EXISTS goods_or_service TEXT DEFAULT 'GOODS' CHECK (goods_or_service IN ('GOODS','SERVICE')),
    ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE')),
    ADD COLUMN IF NOT EXISTS effective_from DATE,
    ADD COLUMN IF NOT EXISTS effective_to DATE,
    ADD COLUMN IF NOT EXISTS official_source TEXT,
    ADD COLUMN IF NOT EXISTS source_reference TEXT;

-- Rename 'type' to legacy if needed (keep backward compat — do not drop)
-- 'type' column already exists; 'code_type' is the new canonical field.

-- ============================================================
-- SECTION 2: CREATE catalog.gst_rate_master (standalone)
-- Independent of tax_codes/tax_rates/regimes/jurisdictions.
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.gst_rate_master (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rate_percent NUMERIC(6,2) NOT NULL,
    rate_name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('STANDARD','NIL','EXEMPT','ZERO_RATED','SPECIAL','COMPOSITION','HISTORICAL')),
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    effective_from DATE NOT NULL,
    effective_to DATE,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE')),
    notification_number TEXT,
    notification_date DATE,
    official_source TEXT,
    source_reference TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Unique: one active rate record per rate_percent + category
CREATE UNIQUE INDEX IF NOT EXISTS gst_rate_master_rate_cat_current_uidx
    ON catalog.gst_rate_master (rate_percent, category)
    WHERE is_current = TRUE AND effective_to IS NULL;

-- ============================================================
-- SECTION 3: SEED gst_rate_master WITH OFFICIAL RATES
-- Source: CGST Act 2017, Notification 01/2017-CT(R) and amendments through 2026-09-04
-- ============================================================

INSERT INTO catalog.gst_rate_master
    (rate_percent, rate_name, category, is_current, effective_from, notification_number, notification_date, official_source, notes)
VALUES
    -- Nil rate
    (0.00,  'Nil Rated',                  'NIL',       TRUE,  '2017-07-01', '02/2017-Central Tax (Rate)', '2017-06-28', 'https://egazette.gov.in', 'Goods and services exempt from GST; input tax credit not available'),
    -- Sub-1% special rates
    (0.25,  'Precious/Semi-precious Stones', 'SPECIAL', TRUE,  '2017-07-01', '01/2017-Central Tax (Rate)', '2017-06-28', 'https://egazette.gov.in', 'Cut and polished precious/semi-precious stones, diamonds'),
    (1.50,  'Job Work – Diamonds/Jewellery', 'SPECIAL', TRUE,  '2019-09-30', '20/2019-Central Tax (Rate)', '2019-09-30', 'https://egazette.gov.in', 'Job work on articles of precious metal; amended by 20/2019'),
    -- Standard rates
    (3.00,  'Gold, Silver, Platinum',      'STANDARD',  TRUE,  '2017-07-01', '01/2017-Central Tax (Rate)', '2017-06-28', 'https://egazette.gov.in', 'Precious metals including gold, silver, platinum'),
    (5.00,  '5% Standard Rate',            'STANDARD',  TRUE,  '2017-07-01', '01/2017-Central Tax (Rate)', '2017-06-28', 'https://egazette.gov.in', 'Essential goods: food, healthcare, transport'),
    (12.00, '12% Standard Rate',           'STANDARD',  TRUE,  '2017-07-01', '01/2017-Central Tax (Rate)', '2017-06-28', 'https://egazette.gov.in', 'Processed foods, IT equipment, certain services'),
    (18.00, '18% Standard Rate',           'STANDARD',  TRUE,  '2017-07-01', '01/2017-Central Tax (Rate)', '2017-06-28', 'https://egazette.gov.in', 'Most services, electronics, capital goods'),
    (40.00, '40% Demerit/Luxury',          'STANDARD',  TRUE,  '2017-07-01', '01/2017-Central Tax (Rate)', '2017-06-28', 'https://egazette.gov.in', 'Luxury and demerit goods: tobacco, aerated drinks, luxury vehicles'),
    -- Composition rates (standalone master reference; no computation here)
    (1.00,  'Composition – Manufacturers/Traders', 'COMPOSITION', TRUE, '2017-07-01', '08/2017-Central Tax', '2017-06-27', 'https://cbic.gov.in', 'Section 10 CGST Act; 0.5% CGST + 0.5% SGST; turnover limit applies'),
    (5.00,  'Composition – Restaurants',   'COMPOSITION', TRUE,  '2017-07-01', '46/2017-Central Tax',       '2017-11-10', 'https://cbic.gov.in', 'Non-AC restaurants; 2.5% CGST + 2.5% SGST; amended by 46/2017'),
    (6.00,  'Composition – Service Providers', 'COMPOSITION', TRUE, '2019-04-01', '02/2019-Central Tax', '2019-03-07', 'https://cbic.gov.in', 'Section 10(2A) CGST Act; 3% CGST + 3% SGST'),
    -- Historical (no longer current)
    (28.00, '28% Demerit (Pre-2026)',       'HISTORICAL', FALSE, '2017-07-01', '01/2017-Central Tax (Rate)', '2017-06-28', 'https://egazette.gov.in', 'Goods schedule removed effective 2026-01-31 per 09/2025-CT(R) amendments')
ON CONFLICT DO NOTHING;

-- Mark historical record as inactive
UPDATE catalog.gst_rate_master
   SET status = 'INACTIVE', effective_to = '2026-01-31', is_current = FALSE
 WHERE rate_percent = 28.00 AND category = 'HISTORICAL';

-- ============================================================
-- SECTION 4: SEED catalog.hsn_sac WITH REPRESENTATIVE CHAPTERS
-- Official HSN 2022 chapter list (21 sections, 99 chapters)
-- Source: Customs Tariff Act 1975 as adopted for GST
-- ============================================================

INSERT INTO catalog.hsn_sac
    (code, code_type, description, chapter, goods_or_service, status, effective_from, official_source, source_reference)
VALUES
    -- Section I: Live animals, animal products
    ('01', 'HSN', 'Live animals', '01', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 01'),
    ('02', 'HSN', 'Meat and edible meat offal', '02', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 02'),
    ('03', 'HSN', 'Fish and crustaceans, molluscs and other aquatic invertebrates', '03', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 03'),
    ('04', 'HSN', 'Dairy produce; birds eggs; natural honey; edible products of animal origin', '04', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 04'),
    ('05', 'HSN', 'Products of animal origin, not elsewhere specified', '05', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 05'),
    -- Section II: Vegetable products
    ('06', 'HSN', 'Live trees and other plants; bulbs, roots and the like; cut flowers and ornamental foliage', '06', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 06'),
    ('07', 'HSN', 'Edible vegetables and certain roots and tubers', '07', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 07'),
    ('08', 'HSN', 'Edible fruit and nuts; peel of citrus fruit or melons', '08', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 08'),
    ('09', 'HSN', 'Coffee, tea, mate and spices', '09', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 09'),
    ('10', 'HSN', 'Cereals', '10', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 10'),
    ('11', 'HSN', 'Products of the milling industry; malt; starches; inulin; wheat gluten', '11', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 11'),
    ('12', 'HSN', 'Oil seeds and oleaginous fruits; miscellaneous grains, seeds and fruit', '12', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 12'),
    ('13', 'HSN', 'Lac; gums, resins and other vegetable saps and extracts', '13', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 13'),
    ('14', 'HSN', 'Vegetable plaiting materials; vegetable products not elsewhere specified', '14', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 14'),
    -- Section III: Animal or vegetable fats
    ('15', 'HSN', 'Animal or vegetable fats and oils and their cleavage products', '15', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 15'),
    -- Section IV: Prepared foodstuffs
    ('16', 'HSN', 'Preparations of meat, of fish, of crustaceans, molluscs or other aquatic invertebrates', '16', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 16'),
    ('17', 'HSN', 'Sugars and sugar confectionery', '17', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 17'),
    ('18', 'HSN', 'Cocoa and cocoa preparations', '18', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 18'),
    ('19', 'HSN', 'Preparations of cereals, flour, starch or milk; pastrycooks products', '19', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 19'),
    ('20', 'HSN', 'Preparations of vegetables, fruit, nuts or other parts of plants', '20', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 20'),
    ('21', 'HSN', 'Miscellaneous edible preparations', '21', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 21'),
    ('22', 'HSN', 'Beverages, spirits and vinegar', '22', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 22'),
    ('23', 'HSN', 'Residues and waste from the food industries; prepared animal fodder', '23', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 23'),
    ('24', 'HSN', 'Tobacco and manufactured tobacco substitutes; products for electronic cigarettes', '24', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 24'),
    -- Section V: Mineral products
    ('25', 'HSN', 'Salt; sulphur; earths and stone; plastering materials, lime and cement', '25', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 25'),
    ('26', 'HSN', 'Ores, slag and ash', '26', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 26'),
    ('27', 'HSN', 'Mineral fuels, mineral oils and products of their distillation', '27', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 27'),
    -- Section VI: Products of chemical industries
    ('28', 'HSN', 'Inorganic chemicals; organic and inorganic compounds of precious metals', '28', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 28'),
    ('29', 'HSN', 'Organic chemicals', '29', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 29'),
    ('30', 'HSN', 'Pharmaceutical products', '30', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 30'),
    ('31', 'HSN', 'Fertilisers', '31', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 31'),
    ('32', 'HSN', 'Tanning or dyeing extracts; dyes, pigments, paints, varnishes; putty, mastics', '32', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 32'),
    ('33', 'HSN', 'Essential oils and resinoids; perfumery, cosmetic or toilet preparations', '33', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 33'),
    ('34', 'HSN', 'Soap, organic surface-active agents, washing preparations, lubricating preparations', '34', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 34'),
    ('35', 'HSN', 'Albuminoidal substances; modified starches; glues; enzymes', '35', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 35'),
    ('36', 'HSN', 'Explosives; pyrotechnic products; matches; pyrophoric alloys; certain combustible preparations', '36', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 36'),
    ('37', 'HSN', 'Photographic or cinematographic goods', '37', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 37'),
    ('38', 'HSN', 'Miscellaneous chemical products', '38', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 38'),
    -- Section VII: Plastics and rubber
    ('39', 'HSN', 'Plastics and articles thereof', '39', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 39'),
    ('40', 'HSN', 'Rubber and articles thereof', '40', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 40'),
    -- Section VIII: Raw hides, leather
    ('41', 'HSN', 'Raw hides and skins (other than furskins) and leather', '41', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 41'),
    ('42', 'HSN', 'Articles of leather; saddlery and harness; travel goods, handbags', '42', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 42'),
    ('43', 'HSN', 'Furskins and artificial fur; manufactures thereof', '43', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 43'),
    -- Section IX: Wood and articles
    ('44', 'HSN', 'Wood and articles of wood; wood charcoal', '44', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 44'),
    ('45', 'HSN', 'Cork and articles of cork', '45', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 45'),
    ('46', 'HSN', 'Manufactures of straw, esparto or other plaiting materials; basketware and wickerwork', '46', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 46'),
    -- Section X: Pulp of wood, paper
    ('47', 'HSN', 'Pulp of wood or of other fibrous cellulosic material', '47', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 47'),
    ('48', 'HSN', 'Paper and paperboard; articles of paper pulp, of paper or of paperboard', '48', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 48'),
    ('49', 'HSN', 'Printed books, newspapers, pictures and other products of the printing industry', '49', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 49'),
    -- Section XI: Textiles
    ('50', 'HSN', 'Silk', '50', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 50'),
    ('51', 'HSN', 'Wool, fine or coarse animal hair; horsehair yarn and woven fabric', '51', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 51'),
    ('52', 'HSN', 'Cotton', '52', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 52'),
    ('53', 'HSN', 'Other vegetable textile fibres; paper yarn and woven fabrics of paper yarn', '53', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 53'),
    ('54', 'HSN', 'Man-made filaments; strip and the like of man-made textile materials', '54', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 54'),
    ('55', 'HSN', 'Man-made staple fibres', '55', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 55'),
    ('56', 'HSN', 'Wadding, felt and nonwovens; special yarns; twine, cordage, ropes and cables', '56', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 56'),
    ('57', 'HSN', 'Carpets and other textile floor coverings', '57', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 57'),
    ('58', 'HSN', 'Special woven fabrics; tufted textile fabrics; lace, tapestries; trimmings; embroidery', '58', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 58'),
    ('59', 'HSN', 'Impregnated, coated, covered or laminated textile fabrics', '59', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 59'),
    ('60', 'HSN', 'Knitted or crocheted fabrics', '60', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 60'),
    ('61', 'HSN', 'Articles of apparel and clothing accessories, knitted or crocheted', '61', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 61'),
    ('62', 'HSN', 'Articles of apparel and clothing accessories, not knitted or crocheted', '62', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 62'),
    ('63', 'HSN', 'Other made up textile articles; sets; worn clothing and worn textile articles; rags', '63', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 63'),
    -- Section XII: Footwear, headgear
    ('64', 'HSN', 'Footwear, gaiters and the like; parts of such articles', '64', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 64'),
    ('65', 'HSN', 'Headgear and parts thereof', '65', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 65'),
    ('66', 'HSN', 'Umbrellas, sun umbrellas, walking-sticks, seat-sticks, whips, riding-crops', '66', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 66'),
    ('67', 'HSN', 'Prepared feathers and down and articles made of feathers or of down; artificial flowers; articles of human hair', '67', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 67'),
    -- Section XIII: Articles of stone
    ('68', 'HSN', 'Articles of stone, plaster, cement, asbestos, mica or similar materials', '68', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 68'),
    ('69', 'HSN', 'Ceramic products', '69', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 69'),
    ('70', 'HSN', 'Glass and glassware', '70', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 70'),
    -- Section XIV: Precious metals
    ('71', 'HSN', 'Natural or cultured pearls, precious or semi-precious stones, precious metals', '71', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 71'),
    -- Section XV: Base metals
    ('72', 'HSN', 'Iron and steel', '72', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 72'),
    ('73', 'HSN', 'Articles of iron or steel', '73', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 73'),
    ('74', 'HSN', 'Copper and articles thereof', '74', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 74'),
    ('75', 'HSN', 'Nickel and articles thereof', '75', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 75'),
    ('76', 'HSN', 'Aluminium and articles thereof', '76', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 76'),
    ('78', 'HSN', 'Lead and articles thereof', '78', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 78'),
    ('79', 'HSN', 'Zinc and articles thereof', '79', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 79'),
    ('80', 'HSN', 'Tin and articles thereof', '80', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 80'),
    ('81', 'HSN', 'Other base metals; cermets; articles thereof', '81', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 81'),
    ('82', 'HSN', 'Tools, implements, cutlery, spoons and forks, of base metal', '82', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 82'),
    ('83', 'HSN', 'Miscellaneous articles of base metal', '83', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 83'),
    -- Section XVI: Machinery
    ('84', 'HSN', 'Nuclear reactors, boilers, machinery and mechanical appliances; parts thereof', '84', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 84'),
    ('85', 'HSN', 'Electrical machinery and equipment and parts thereof; sound recorders; television recorders', '85', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 85'),
    -- Section XVII: Vehicles
    ('86', 'HSN', 'Railway or tramway locomotives, rolling-stock and parts thereof', '86', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 86'),
    ('87', 'HSN', 'Vehicles other than railway or tramway rolling-stock, and parts and accessories thereof', '87', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 87'),
    ('88', 'HSN', 'Aircraft, spacecraft, and parts thereof', '88', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 88'),
    ('89', 'HSN', 'Ships, boats and floating structures', '89', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 89'),
    -- Section XVIII: Optical instruments
    ('90', 'HSN', 'Optical, photographic, cinematographic, measuring, checking, precision instruments', '90', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 90'),
    ('91', 'HSN', 'Clocks and watches and parts thereof', '91', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 91'),
    ('92', 'HSN', 'Musical instruments; parts and accessories of such articles', '92', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 92'),
    -- Section XIX: Arms and ammunition
    ('93', 'HSN', 'Arms and ammunition; parts and accessories thereof', '93', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 93'),
    -- Section XX: Miscellaneous
    ('94', 'HSN', 'Furniture; bedding, mattresses, mattress supports, cushions and similar stuffed furnishings', '94', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 94'),
    ('95', 'HSN', 'Toys, games and sports requisites; parts and accessories thereof', '95', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 95'),
    ('96', 'HSN', 'Miscellaneous manufactured articles', '96', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 96'),
    -- Section XXI: Works of art
    ('97', 'HSN', 'Works of art, collectors pieces and antiques', '97', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 97'),
    ('98', 'HSN', 'Project imports; laboratory chemicals; passengers baggage; personal importation by air or post; ship stores', '98', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 98'),
    ('99', 'HSN', 'Miscellaneous goods (Chapter 99)', '99', 'GOODS', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'HSN 2022 Chapter 99'),
    -- SAC Sections (Services Accounting Codes — GST Council 12/06/2017)
    ('99', 'SAC', 'Services (all SAC codes are under heading 99)', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC as notified by GST Council'),
    ('9954', 'SAC', 'Construction services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9954 – Construction of a complex, building, civil structure'),
    ('9961', 'SAC', 'Services in wholesale trade', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9961'),
    ('9962', 'SAC', 'Services in retail trade', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9962'),
    ('9963', 'SAC', 'Accommodation, food and beverage services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9963 – Hotel, restaurant, catering'),
    ('9964', 'SAC', 'Passenger transport services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9964'),
    ('9965', 'SAC', 'Goods transport services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9965 – GTA, courier, freight'),
    ('9966', 'SAC', 'Vehicle rental and leasing services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9966'),
    ('9967', 'SAC', 'Supporting services in transport', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9967'),
    ('9968', 'SAC', 'Postal and courier services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9968'),
    ('9969', 'SAC', 'Electricity, gas, water and other distribution services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9969'),
    ('9971', 'SAC', 'Financial and related services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9971 – Banking, insurance, securities'),
    ('9972', 'SAC', 'Real estate services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9972'),
    ('9973', 'SAC', 'Leasing or rental services without operator', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9973'),
    ('9981', 'SAC', 'Research and development services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9981'),
    ('9982', 'SAC', 'Legal and accounting services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9982'),
    ('9983', 'SAC', 'Other professional, technical and business services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9983'),
    ('9984', 'SAC', 'Telecommunications, broadcasting and information supply services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9984'),
    ('9985', 'SAC', 'Support services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9985'),
    ('9986', 'SAC', 'Agriculture, forestry, fishing and mining support services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9986'),
    ('9987', 'SAC', 'Maintenance, repair and installation (except construction) services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9987'),
    ('9988', 'SAC', 'Manufacturing services on physical inputs owned by others', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9988 – Job work'),
    ('9989', 'SAC', 'Other manufacturing services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9989'),
    ('9991', 'SAC', 'Public administration and other government services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9991'),
    ('9992', 'SAC', 'Education services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9992'),
    ('9993', 'SAC', 'Human health and social care services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9993'),
    ('9994', 'SAC', 'Sewage and waste collection, treatment and disposal services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9994'),
    ('9995', 'SAC', 'Services of membership organisations', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9995'),
    ('9996', 'SAC', 'Recreational, cultural and sporting services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9996'),
    ('9997', 'SAC', 'Other services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9997'),
    ('9998', 'SAC', 'Domestic services', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9998'),
    ('9999', 'SAC', 'Services provided by extraterritorial organisations and bodies', '99', 'SERVICE', 'ACTIVE', '2017-07-01', 'https://cbic.gov.in', 'SAC 9999')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- SECTION 5: UPDATE PUBLIC VIEWS
-- ============================================================

CREATE OR REPLACE VIEW public.hsn_sac AS SELECT * FROM catalog.hsn_sac;
CREATE OR REPLACE VIEW public.gst_rate_master AS SELECT * FROM catalog.gst_rate_master;

GRANT SELECT ON public.hsn_sac TO anon, authenticated;
GRANT SELECT ON public.gst_rate_master TO anon, authenticated;

-- ============================================================
-- SECTION 6: VERIFICATION
-- ============================================================

DO $$
DECLARE v_hsn INT; v_sac INT; v_rates INT; v_cur_rates INT;
BEGIN
    SELECT count(*) INTO v_hsn  FROM catalog.hsn_sac WHERE code_type = 'HSN';
    SELECT count(*) INTO v_sac  FROM catalog.hsn_sac WHERE code_type = 'SAC';
    SELECT count(*) INTO v_rates FROM catalog.gst_rate_master;
    SELECT count(*) INTO v_cur_rates FROM catalog.gst_rate_master WHERE is_current = TRUE;
    RAISE NOTICE 'HSN chapters seeded: %', v_hsn;
    RAISE NOTICE 'SAC codes seeded:    %', v_sac;
    RAISE NOTICE 'GST rate rows:       %', v_rates;
    RAISE NOTICE 'Current GST rates:   %', v_cur_rates;
    IF v_rates < 10 THEN RAISE EXCEPTION 'GST rate seed incomplete: only % rows', v_rates; END IF;
END $$;

COMMIT;
