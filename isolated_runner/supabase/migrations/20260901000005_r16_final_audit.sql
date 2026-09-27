-- R16 FINAL POST-COMMIT INDEPENDENT READ-ONLY AUDIT
-- Verifies remote canonical state. Uses RAISE NOTICE only (no exception) so migration succeeds.
DO $$
DECLARE
    state_lvl uuid; district_lvl uuid; subdistrict_lvl uuid;
    c_state int; c_dist int; c_subdist int; c_total int;
    c_block int; c_rel int; c_bd1 int; c_bd2 int;
    c_localities int; c_unresolved int;
    release_status text; evidence_count int;
BEGIN
    SELECT id INTO state_lvl FROM catalog.geography_levels WHERE level_key = 'STATE_UT';
    SELECT id INTO district_lvl FROM catalog.geography_levels WHERE level_key = 'DISTRICT';
    SELECT id INTO subdistrict_lvl FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';
    SELECT count(*) INTO c_state FROM catalog.geography_units WHERE geography_level_id = state_lvl;
    SELECT count(*) INTO c_dist FROM catalog.geography_units WHERE geography_level_id = district_lvl;
    SELECT count(*) INTO c_subdist FROM catalog.geography_units WHERE geography_level_id = subdistrict_lvl;
    SELECT count(*) INTO c_total FROM catalog.geography_units WHERE status = 'ACTIVE'
        AND geography_level_id IN (SELECT id FROM catalog.geography_levels WHERE level_key IN ('STATE_UT','DISTRICT','SUB_DISTRICT'));
    SELECT count(*) INTO c_localities FROM catalog.geography_units
        WHERE geography_level_id IN (SELECT id FROM catalog.geography_levels WHERE level_key IN ('LOCALITY','VILLAGE'));
    SELECT count(*) INTO c_block FROM catalog.development_blocks;
    SELECT count(*) INTO c_rel FROM catalog.block_districts;
    SELECT count(*) INTO c_bd1 FROM (SELECT block_id FROM catalog.block_districts GROUP BY block_id HAVING count(*) = 1) sub;
    SELECT count(*) INTO c_bd2 FROM (SELECT block_id FROM catalog.block_districts GROUP BY block_id HAVING count(*) = 2) sub;
    SELECT count(*) INTO c_unresolved FROM catalog.geography_units u
        WHERE u.geography_level_id = subdistrict_lvl AND u.parent_geography_unit_id IS NULL;
    SELECT status INTO release_status FROM data_imports.releases WHERE id = '5fac63d7-0101-43c5-8867-bd75ff609861';
    SELECT count(*) INTO evidence_count FROM data_imports.release_execution_artifacts
        WHERE release_id = '5fac63d7-0101-43c5-8867-bd75ff609861' AND artifact_type = 'PROMOTION_EVIDENCE';

    IF c_state != 36 THEN RAISE EXCEPTION 'AUDIT FAIL: States = %', c_state; END IF;
    IF c_dist != 784 THEN RAISE EXCEPTION 'AUDIT FAIL: Districts = %', c_dist; END IF;
    IF c_subdist != 7092 THEN RAISE EXCEPTION 'AUDIT FAIL: SubDistricts = %', c_subdist; END IF;
    IF c_total != 7912 THEN RAISE EXCEPTION 'AUDIT FAIL: Total units = %', c_total; END IF;
    IF c_block != 7323 THEN RAISE EXCEPTION 'AUDIT FAIL: Blocks = %', c_block; END IF;
    IF c_rel != 7338 THEN RAISE EXCEPTION 'AUDIT FAIL: Rels = %', c_rel; END IF;
    IF c_bd1 != 7308 THEN RAISE EXCEPTION 'AUDIT FAIL: bd1 = %', c_bd1; END IF;
    IF c_bd2 != 15 THEN RAISE EXCEPTION 'AUDIT FAIL: bd2 = %', c_bd2; END IF;
    IF c_localities != 0 THEN RAISE EXCEPTION 'AUDIT FAIL: Localities found = %', c_localities; END IF;
    IF c_unresolved != 0 THEN RAISE EXCEPTION 'AUDIT FAIL: Unresolved sub-districts = %', c_unresolved; END IF;
    IF release_status != 'PROMOTED' THEN RAISE EXCEPTION 'AUDIT FAIL: Release status = %', release_status; END IF;
    IF evidence_count = 0 THEN RAISE EXCEPTION 'AUDIT FAIL: No promotion evidence artifact.'; END IF;

    RAISE NOTICE 'AUDIT_PASS: state=% dist=% subdist=% total=% blocks=% rels=% bd1=% bd2=% localities=% unresolved=% release=% evidence=%',
        c_state, c_dist, c_subdist, c_total, c_block, c_rel, c_bd1, c_bd2, c_localities, c_unresolved, release_status, evidence_count;
END;
$$;
