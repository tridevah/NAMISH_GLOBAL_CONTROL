BEGIN READ ONLY;
SET LOCAL search_path TO catalog, staging, data_imports, public, pg_catalog;
SET LOCAL statement_timeout = '1min';
SET LOCAL lock_timeout = '10s';
SET LOCAL idle_in_transaction_session_timeout = '1min';

DO $$
DECLARE
    v_release_id uuid := '5fac63d7-0101-43c5-8867-bd75ff609861';
    v_verify_release uuid;
    india_id uuid;
    state_lvl uuid;
    district_lvl uuid;
    subdistrict_lvl uuid;
    err_rec record;
    
    baseline_states int;
    baseline_dists int;
    baseline_subdists int;
    baseline_blocks int;
    baseline_rels int;
    
    expected_dist_inserts int;
    expected_subdist_inserts int;
    expected_block_inserts int;
    expected_rel_inserts int;
BEGIN
    SELECT id INTO v_verify_release FROM data_imports.releases WHERE id = v_release_id;
    IF v_verify_release IS NULL THEN RAISE EXCEPTION 'Release % not found', v_release_id; END IF;

    SELECT id INTO india_id FROM catalog.countries WHERE iso3 = 'IND';
    SELECT id INTO state_lvl FROM catalog.geography_levels WHERE level_key = 'STATE_UT';
    SELECT id INTO district_lvl FROM catalog.geography_levels WHERE level_key = 'DISTRICT';
    SELECT id INTO subdistrict_lvl FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';

    -- 1. Blank Checks
    SELECT id INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'STATE' AND (substring(raw_data->>'TITLE' from 'State Code:(\d+)') IS NULL) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'STATE contains blanks'; END IF;

    SELECT id INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'DISTRICT' AND ((raw_data->>'district code') IS NULL OR COALESCE(raw_data->>'district name (in english)', raw_data->>'district name') IS NULL OR (raw_data->>'state code') IS NULL) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'DISTRICT contains blanks'; END IF;

    SELECT id INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'SUB_DISTRICT' AND (COALESCE(raw_data->>'sub-district code', raw_data->>'subdistrict code') IS NULL OR COALESCE(raw_data->>'sub-district name (in english)', raw_data->>'subdistrict name (in english)') IS NULL OR (raw_data->>'district code') IS NULL) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'SUB_DISTRICT contains blanks'; END IF;

    SELECT id INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'BLOCK' AND (COALESCE(raw_data->>'block code', raw_data->>'development block code') IS NULL OR COALESCE(raw_data->>'block name', raw_data->>'development block name (in english)') IS NULL OR (raw_data->>'district code') IS NULL) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'BLOCK contains blanks'; END IF;

    -- 2. Duplicates in staging
    SELECT (raw_data->>'district code')::text INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'DISTRICT' GROUP BY 1 HAVING count(*) > 1 LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'DISTRICT staging has duplicates: %', row_to_json(err_rec); END IF;

    SELECT COALESCE(raw_data->>'sub-district code', raw_data->>'subdistrict code')::text INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'SUB_DISTRICT' GROUP BY 1 HAVING count(*) > 1 LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'SUB_DISTRICT staging has duplicates: %', row_to_json(err_rec); END IF;

    SELECT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::int INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'BLOCK' GROUP BY 1 HAVING count(DISTINCT COALESCE(raw_data->>'block name', raw_data->>'development block name (in english)')) > 1 LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'BLOCK staging has conflicting names for same code: %', row_to_json(err_rec); END IF;

    -- 3. Unresolved Parents
    SELECT (d.raw_data->>'district code')::text INTO err_rec FROM staging.geography_imports d LEFT JOIN catalog.geography_units p ON p.official_code = (d.raw_data->>'state code')::text AND p.geography_level_id = state_lvl AND p.country_id = india_id WHERE d.release_id = v_release_id AND d.entity_type = 'DISTRICT' AND p.id IS NULL LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'DISTRICT has unresolved state parent: %', row_to_json(err_rec); END IF;

    WITH valid_districts AS (
        SELECT (raw_data->>'district code')::text AS code FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'DISTRICT'
        UNION
        SELECT official_code FROM catalog.geography_units WHERE geography_level_id = district_lvl AND country_id = india_id
    )
    SELECT COALESCE(s.raw_data->>'sub-district code', s.raw_data->>'subdistrict code')::text INTO err_rec FROM staging.geography_imports s LEFT JOIN valid_districts p ON p.code = (s.raw_data->>'district code')::text WHERE s.release_id = v_release_id AND s.entity_type = 'SUB_DISTRICT' AND p.code IS NULL LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'SUB_DISTRICT has unresolved district parent: %', row_to_json(err_rec); END IF;

    -- 4. Attribute Conflicts (Staging vs Canonical)
    SELECT u.official_code INTO err_rec FROM staging.geography_imports s JOIN catalog.geography_units u ON u.official_code = substring(s.raw_data->>'TITLE' from 'State Code:(\d+)') AND u.geography_level_id = state_lvl AND u.country_id = india_id WHERE s.release_id = v_release_id AND s.entity_type = 'STATE' AND (u.official_name != substring(s.raw_data->>'TITLE' from 'All Districts of (.*?)\(')) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'STATE attribute conflict: %', row_to_json(err_rec); END IF;

    SELECT u.official_code INTO err_rec FROM staging.geography_imports d JOIN catalog.geography_units u ON u.official_code = (d.raw_data->>'district code')::text AND u.geography_level_id = district_lvl AND u.country_id = india_id JOIN catalog.geography_units p ON p.official_code = (d.raw_data->>'state code')::text AND p.geography_level_id = state_lvl AND p.country_id = india_id WHERE d.release_id = v_release_id AND d.entity_type = 'DISTRICT' AND (u.official_name != COALESCE(d.raw_data->>'district name (in english)', d.raw_data->>'district name') OR u.parent_geography_unit_id IS DISTINCT FROM p.id) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'DISTRICT attribute conflict: %', row_to_json(err_rec); END IF;

    SELECT u.official_code INTO err_rec FROM staging.geography_imports s JOIN catalog.geography_units u ON u.official_code = COALESCE(s.raw_data->>'sub-district code', s.raw_data->>'subdistrict code')::text AND u.geography_level_id = subdistrict_lvl AND u.country_id = india_id JOIN catalog.geography_units p ON p.official_code = (s.raw_data->>'district code')::text AND p.geography_level_id = district_lvl AND p.country_id = india_id WHERE s.release_id = v_release_id AND s.entity_type = 'SUB_DISTRICT' AND (u.official_name != COALESCE(s.raw_data->>'sub-district name (in english)', s.raw_data->>'subdistrict name (in english)') OR u.parent_geography_unit_id IS DISTINCT FROM p.id) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'SUB_DISTRICT attribute conflict: %', row_to_json(err_rec); END IF;

    SELECT u.official_code INTO err_rec FROM staging.geography_imports b JOIN catalog.development_blocks u ON u.official_code = (COALESCE(b.raw_data->>'block code', b.raw_data->>'development block code'))::text WHERE b.release_id = v_release_id AND b.entity_type = 'BLOCK' AND (u.official_name != COALESCE(b.raw_data->>'block name', b.raw_data->>'development block name (in english)')) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'BLOCK attribute conflict: %', row_to_json(err_rec); END IF;

    -- 5. Baseline Counts
    SELECT count(*) INTO baseline_states FROM catalog.geography_units WHERE geography_level_id = state_lvl AND country_id = india_id;
    SELECT count(*) INTO baseline_dists FROM catalog.geography_units WHERE geography_level_id = district_lvl AND country_id = india_id;
    SELECT count(*) INTO baseline_subdists FROM catalog.geography_units WHERE geography_level_id = subdistrict_lvl AND country_id = india_id;
    SELECT count(*) INTO baseline_blocks FROM catalog.development_blocks;
    SELECT count(*) INTO baseline_rels FROM catalog.block_districts;

    -- 6. Expected Inserts
    SELECT count(*) INTO expected_dist_inserts FROM staging.geography_imports d LEFT JOIN catalog.geography_units e ON e.official_code = (d.raw_data->>'district code')::text AND e.geography_level_id = district_lvl AND e.country_id = india_id WHERE d.release_id = v_release_id AND d.entity_type = 'DISTRICT' AND e.id IS NULL;
    
    SELECT count(*) INTO expected_subdist_inserts FROM staging.geography_imports d LEFT JOIN catalog.geography_units e ON e.official_code = COALESCE(d.raw_data->>'sub-district code', d.raw_data->>'subdistrict code')::text AND e.geography_level_id = subdistrict_lvl AND e.country_id = india_id WHERE d.release_id = v_release_id AND d.entity_type = 'SUB_DISTRICT' AND e.id IS NULL;

    WITH unique_blocks AS (SELECT DISTINCT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::int AS code FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'BLOCK')
    SELECT count(*) INTO expected_block_inserts FROM unique_blocks b LEFT JOIN catalog.development_blocks e ON e.official_code = b.code::text WHERE e.id IS NULL;

    WITH unique_rels AS (SELECT DISTINCT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::text AS b_code, (raw_data->>'district code')::text AS d_code FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'BLOCK'),
    valid_rels AS (SELECT b.id AS block_id, d.id AS dist_id FROM unique_rels r JOIN (SELECT official_code, id FROM catalog.development_blocks UNION SELECT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::text, gen_random_uuid() FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'BLOCK') b ON b.official_code = r.b_code JOIN (SELECT official_code, id FROM catalog.geography_units WHERE geography_level_id = district_lvl AND country_id = india_id UNION SELECT (raw_data->>'district code')::text, gen_random_uuid() FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'DISTRICT') d ON d.official_code = r.d_code)
    SELECT count(*) INTO expected_rel_inserts FROM valid_rels v LEFT JOIN catalog.block_districts e ON e.block_id = v.block_id AND e.district_id = v.dist_id WHERE e.block_id IS NULL;

    RAISE NOTICE 'PREFLIGHT SUCCESS: No conflicts found.';
    RAISE NOTICE 'Baseline: % States, % Dists, % SubDists, % Blocks, % Rels', baseline_states, baseline_dists, baseline_subdists, baseline_blocks, baseline_rels;
    RAISE NOTICE 'Expected Inserts: % Dists, % SubDists, % Blocks', expected_dist_inserts, expected_subdist_inserts, expected_block_inserts;
END;
$$;
ROLLBACK;
