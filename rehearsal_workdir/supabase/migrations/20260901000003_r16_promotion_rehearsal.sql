BEGIN ISOLATION LEVEL SERIALIZABLE;
SET LOCAL search_path TO catalog, staging, data_imports, public, pg_catalog;
SET LOCAL statement_timeout = '5min';
SET LOCAL lock_timeout = '10s';
SET LOCAL idle_in_transaction_session_timeout = '5min';
SET CONSTRAINTS ALL IMMEDIATE;

DO $$
DECLARE
    v_lock boolean;
    v_release_id uuid := '5fac63d7-0101-43c5-8867-bd75ff609861';
    v_verify_release uuid;
    india_id uuid;
    state_lvl uuid;
    district_lvl uuid;
    subdistrict_lvl uuid;
    err_rec record;
    
    pre_locality int;
    post_locality int;
    
    c_state int;
    c_dist int;
    c_subdist int;
    c_block int;
    c_rel int;
    
    i_dist int := 0;
    i_subdist int := 0;
    i_block int := 0;
    i_rel int := 0;
BEGIN
    SELECT pg_try_advisory_xact_lock(hashtext('LGD_CORE_PROMOTION')) INTO v_lock;
    IF NOT v_lock THEN RAISE EXCEPTION 'Could not obtain advisory lock.'; END IF;

    SELECT id INTO v_verify_release FROM data_imports.releases WHERE id = v_release_id;
    IF v_verify_release IS NULL THEN RAISE EXCEPTION 'Release % not found', v_release_id; END IF;

    SELECT id INTO india_id FROM catalog.countries WHERE iso3 = 'IND';
    SELECT id INTO state_lvl FROM catalog.geography_levels WHERE level_key = 'STATE_UT';
    SELECT id INTO district_lvl FROM catalog.geography_levels WHERE level_key = 'DISTRICT';
    SELECT id INTO subdistrict_lvl FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';

    SELECT count(*) INTO pre_locality FROM catalog.geography_units 
    WHERE country_id = india_id AND geography_level_id NOT IN (state_lvl, district_lvl, subdistrict_lvl);

    -- 1. Blank & Duplicate Checks
    SELECT id INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'STATE' AND (substring(raw_data->>'TITLE' from 'State Code:(\d+)') IS NULL) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'STATE contains blanks'; END IF;

    SELECT id INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'DISTRICT' AND ((raw_data->>'district code') IS NULL OR COALESCE(raw_data->>'district name (in english)', raw_data->>'district name') IS NULL OR (raw_data->>'state code') IS NULL) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'DISTRICT contains blanks'; END IF;

    SELECT id INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'SUB_DISTRICT' AND (COALESCE(raw_data->>'sub-district code', raw_data->>'subdistrict code') IS NULL OR COALESCE(raw_data->>'sub-district name (in english)', raw_data->>'subdistrict name (in english)') IS NULL OR (raw_data->>'district code') IS NULL) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'SUB_DISTRICT contains blanks'; END IF;

    SELECT id INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'BLOCK' AND (COALESCE(raw_data->>'block code', raw_data->>'development block code') IS NULL OR COALESCE(raw_data->>'block name', raw_data->>'development block name (in english)') IS NULL OR (raw_data->>'district code') IS NULL) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'BLOCK contains blanks'; END IF;

    SELECT (raw_data->>'district code')::text INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'DISTRICT' GROUP BY 1 HAVING count(*) > 1 LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'DISTRICT staging has duplicates: %', row_to_json(err_rec); END IF;

    SELECT COALESCE(raw_data->>'sub-district code', raw_data->>'subdistrict code')::text INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'SUB_DISTRICT' GROUP BY 1 HAVING count(*) > 1 LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'SUB_DISTRICT staging has duplicates: %', row_to_json(err_rec); END IF;

    SELECT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::int INTO err_rec FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'BLOCK' GROUP BY 1 HAVING count(DISTINCT COALESCE(raw_data->>'block name', raw_data->>'development block name (in english)')) > 1 LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'BLOCK staging has conflicting names for same code: %', row_to_json(err_rec); END IF;

    -- 2. State & Parent & Attribute Conflicts Checks
    SELECT u.official_code INTO err_rec FROM staging.geography_imports s LEFT JOIN catalog.geography_units u ON u.official_code = substring(s.raw_data->>'TITLE' from 'State Code:(\d+)') AND u.geography_level_id = state_lvl AND u.country_id = india_id WHERE s.release_id = v_release_id AND s.entity_type = 'STATE' AND (u.id IS NULL OR u.official_name != substring(s.raw_data->>'TITLE' from 'All Districts of (.*?)\(')) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'STATE missing in canonical or attribute conflict: %', row_to_json(err_rec); END IF;

    SELECT (d.raw_data->>'district code')::text INTO err_rec FROM staging.geography_imports d LEFT JOIN catalog.geography_units p ON p.official_code = (d.raw_data->>'state code')::text AND p.geography_level_id = state_lvl AND p.country_id = india_id WHERE d.release_id = v_release_id AND d.entity_type = 'DISTRICT' AND p.id IS NULL LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'DISTRICT has unresolved state parent: %', row_to_json(err_rec); END IF;

    SELECT u.official_code INTO err_rec FROM staging.geography_imports d JOIN catalog.geography_units u ON u.official_code = (d.raw_data->>'district code')::text AND u.geography_level_id = district_lvl AND u.country_id = india_id JOIN catalog.geography_units p ON p.official_code = (d.raw_data->>'state code')::text AND p.geography_level_id = state_lvl AND p.country_id = india_id WHERE d.release_id = v_release_id AND d.entity_type = 'DISTRICT' AND (u.official_name != COALESCE(d.raw_data->>'district name (in english)', d.raw_data->>'district name') OR u.parent_geography_unit_id IS DISTINCT FROM p.id) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'DISTRICT attribute conflict: %', row_to_json(err_rec); END IF;

    WITH valid_districts AS (SELECT (raw_data->>'district code')::text AS code FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'DISTRICT' UNION SELECT official_code FROM catalog.geography_units WHERE geography_level_id = district_lvl AND country_id = india_id)
    SELECT COALESCE(s.raw_data->>'sub-district code', s.raw_data->>'subdistrict code')::text INTO err_rec FROM staging.geography_imports s LEFT JOIN valid_districts p ON p.code = (s.raw_data->>'district code')::text WHERE s.release_id = v_release_id AND s.entity_type = 'SUB_DISTRICT' AND p.code IS NULL LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'SUB_DISTRICT has unresolved district parent: %', row_to_json(err_rec); END IF;

    SELECT u.official_code INTO err_rec FROM staging.geography_imports s JOIN catalog.geography_units u ON u.official_code = COALESCE(s.raw_data->>'sub-district code', s.raw_data->>'subdistrict code')::text AND u.geography_level_id = subdistrict_lvl AND u.country_id = india_id JOIN catalog.geography_units p ON p.official_code = (s.raw_data->>'district code')::text AND p.geography_level_id = district_lvl AND p.country_id = india_id WHERE s.release_id = v_release_id AND s.entity_type = 'SUB_DISTRICT' AND (u.official_name != COALESCE(s.raw_data->>'sub-district name (in english)', s.raw_data->>'subdistrict name (in english)') OR u.parent_geography_unit_id IS DISTINCT FROM p.id) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'SUB_DISTRICT attribute conflict: %', row_to_json(err_rec); END IF;

    SELECT u.official_code INTO err_rec FROM staging.geography_imports b JOIN catalog.development_blocks u ON u.official_code = (COALESCE(b.raw_data->>'block code', b.raw_data->>'development block code'))::text WHERE b.release_id = v_release_id AND b.entity_type = 'BLOCK' AND (u.official_name != COALESCE(b.raw_data->>'block name', b.raw_data->>'development block name (in english)')) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'BLOCK attribute conflict: %', row_to_json(err_rec); END IF;

    -- 3. Inserts (Anti-Joins)
    WITH staged_districts AS (
        SELECT (raw_data->>'district code')::text AS district_code, COALESCE(raw_data->>'district name (in english)', raw_data->>'district name') AS district_name, (raw_data->>'state code')::text AS state_code
        FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'DISTRICT'
    ),
    valid_districts AS (SELECT d.district_code, d.district_name, s.id AS parent_id FROM staged_districts d JOIN catalog.geography_units s ON s.official_code = d.state_code AND s.geography_level_id = state_lvl AND s.country_id = india_id),
    new_districts AS (SELECT v.* FROM valid_districts v LEFT JOIN catalog.geography_units e ON e.official_code = v.district_code AND e.geography_level_id = district_lvl AND e.country_id = india_id WHERE e.id IS NULL),
    inserted_d AS (INSERT INTO catalog.geography_units (country_id, geography_level_id, parent_geography_unit_id, official_code, official_name, display_name, status) SELECT india_id, district_lvl, parent_id, district_code, district_name, district_name, 'ACTIVE' FROM new_districts RETURNING 1)
    SELECT count(*) INTO i_dist FROM inserted_d;

    WITH staged_subdists AS (
        SELECT COALESCE(raw_data->>'sub-district code', raw_data->>'subdistrict code')::text AS sub_code, COALESCE(raw_data->>'sub-district name (in english)', raw_data->>'subdistrict name (in english)') AS sub_name, (raw_data->>'district code')::text AS dist_code
        FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'SUB_DISTRICT'
    ),
    valid_subdists AS (SELECT d.sub_code, d.sub_name, p.id AS parent_id FROM staged_subdists d JOIN catalog.geography_units p ON p.official_code = d.dist_code AND p.geography_level_id = district_lvl AND p.country_id = india_id),
    new_subdists AS (SELECT v.* FROM valid_subdists v LEFT JOIN catalog.geography_units e ON e.official_code = v.sub_code AND e.geography_level_id = subdistrict_lvl AND e.country_id = india_id WHERE e.id IS NULL),
    inserted_s AS (INSERT INTO catalog.geography_units (country_id, geography_level_id, parent_geography_unit_id, official_code, official_name, display_name, status) SELECT india_id, subdistrict_lvl, parent_id, sub_code, sub_name, sub_name, 'ACTIVE' FROM new_subdists RETURNING 1)
    SELECT count(*) INTO i_subdist FROM inserted_s;

    WITH staged_blocks AS (
        SELECT DISTINCT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::int AS block_code, COALESCE(raw_data->>'block name', raw_data->>'development block name (in english)') AS block_name
        FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'BLOCK'
    ),
    new_blocks AS (SELECT s.block_code::text, s.block_name FROM staged_blocks s LEFT JOIN catalog.development_blocks e ON s.block_code::text = e.official_code WHERE e.id IS NULL),
    inserted_b AS (INSERT INTO catalog.development_blocks (id, official_code, official_name, status, district_id) SELECT gen_random_uuid(), block_code, block_name, 'ACTIVE', NULL FROM new_blocks RETURNING 1)
    SELECT count(*) INTO i_block FROM inserted_b;
    
    WITH staged_rels AS (
        SELECT DISTINCT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::text AS block_code, (raw_data->>'district code')::text AS district_code
        FROM staging.geography_imports WHERE release_id = v_release_id AND entity_type = 'BLOCK'
    ),
    valid_rels AS (SELECT b.id AS block_id, d.id AS district_id FROM staged_rels r JOIN catalog.development_blocks b ON r.block_code = b.official_code JOIN catalog.geography_units d ON r.district_code = d.official_code AND d.geography_level_id = district_lvl AND d.country_id = india_id),
    new_rels AS (SELECT v.* FROM valid_rels v LEFT JOIN catalog.block_districts e ON e.block_id = v.block_id AND e.district_id = v.district_id WHERE e.block_id IS NULL),
    inserted_r AS (INSERT INTO catalog.block_districts (block_id, district_id, source_release_id) SELECT block_id, district_id, v_release_id FROM new_rels RETURNING 1)
    SELECT count(*) INTO i_rel FROM inserted_r;

    -- 4. Final Assertions
    SELECT count(*) INTO c_state FROM catalog.geography_units WHERE geography_level_id = state_lvl AND country_id = india_id;
    SELECT count(*) INTO c_dist FROM catalog.geography_units WHERE geography_level_id = district_lvl AND country_id = india_id;
    SELECT count(*) INTO c_subdist FROM catalog.geography_units WHERE geography_level_id = subdistrict_lvl AND country_id = india_id;
    SELECT count(*) INTO c_block FROM catalog.development_blocks;
    SELECT count(*) INTO c_rel FROM catalog.block_districts;

    SELECT count(*) INTO post_locality FROM catalog.geography_units WHERE country_id = india_id AND geography_level_id NOT IN (state_lvl, district_lvl, subdistrict_lvl);

    IF c_state != 36 THEN RAISE EXCEPTION 'Assert Failed: States = % (Expected 36)', c_state; END IF;
    IF c_dist != 784 THEN RAISE EXCEPTION 'Assert Failed: Districts = % (Expected 784)', c_dist; END IF;
    IF c_subdist != 7092 THEN RAISE EXCEPTION 'Assert Failed: SubDistricts = % (Expected 7092)', c_subdist; END IF;
    IF c_block != 7323 THEN RAISE EXCEPTION 'Assert Failed: Blocks = % (Expected 7323)', c_block; END IF;
    IF c_rel != 7338 THEN RAISE EXCEPTION 'Assert Failed: BlockDistricts = % (Expected 7338)', c_rel; END IF;
    IF pre_locality != post_locality THEN RAISE EXCEPTION 'Assert Failed: Locality drift from % to %', pre_locality, post_locality; END IF;

    DECLARE
        bd_1 int;
        bd_2 int;
    BEGIN
        SELECT count(*) INTO bd_1 FROM (SELECT block_id FROM catalog.block_districts GROUP BY block_id HAVING count(*) = 1) sub;
        SELECT count(*) INTO bd_2 FROM (SELECT block_id FROM catalog.block_districts GROUP BY block_id HAVING count(*) = 2) sub;
        IF bd_1 != 7308 THEN RAISE EXCEPTION 'Assert Failed: Single-district blocks = % (Expected 7308)', bd_1; END IF;
        IF bd_2 != 15 THEN RAISE EXCEPTION 'Assert Failed: Two-district blocks = % (Expected 15)', bd_2; END IF;
    END;

    RAISE NOTICE 'SUCCESS! Inserted: % Dists, % SubDists, % Blocks, % Rels.', i_dist, i_subdist, i_block, i_rel;
END;
$$;
ROLLBACK;
