-- R16 PROMOTION COMMIT - Post-Verification and Evidence Recording
-- Canonical DML already committed (784 districts, 7092 sub-districts, 7323 blocks, 7338 rels).
-- This migration verifies those counts, records the immutable promotion-evidence artifact,
-- and transitions the release status to PROMOTED.
DO $$
DECLARE
    v_release_id uuid := '5fac63d7-0101-43c5-8867-bd75ff609861';
    state_lvl uuid; district_lvl uuid; subdistrict_lvl uuid;
    c_state int; c_dist int; c_subdist int; c_block int; c_rel int;
    c_bd1 int; c_bd2 int;
    evidence_exists int;
BEGIN
    SELECT id INTO state_lvl FROM catalog.geography_levels WHERE level_key = 'STATE_UT';
    SELECT id INTO district_lvl FROM catalog.geography_levels WHERE level_key = 'DISTRICT';
    SELECT id INTO subdistrict_lvl FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';

    SELECT count(*) INTO c_state FROM catalog.geography_units WHERE geography_level_id = state_lvl;
    SELECT count(*) INTO c_dist FROM catalog.geography_units WHERE geography_level_id = district_lvl;
    SELECT count(*) INTO c_subdist FROM catalog.geography_units WHERE geography_level_id = subdistrict_lvl;
    SELECT count(*) INTO c_block FROM catalog.development_blocks;
    SELECT count(*) INTO c_rel FROM catalog.block_districts;
    SELECT count(*) INTO c_bd1 FROM (SELECT block_id FROM catalog.block_districts GROUP BY block_id HAVING count(*) = 1) sub;
    SELECT count(*) INTO c_bd2 FROM (SELECT block_id FROM catalog.block_districts GROUP BY block_id HAVING count(*) = 2) sub;

    IF c_state != 36 THEN RAISE EXCEPTION 'Post-verify: States = %', c_state; END IF;
    IF c_dist != 784 THEN RAISE EXCEPTION 'Post-verify: Districts = %', c_dist; END IF;
    IF c_subdist != 7092 THEN RAISE EXCEPTION 'Post-verify: SubDistricts = %', c_subdist; END IF;
    IF c_block != 7323 THEN RAISE EXCEPTION 'Post-verify: Blocks = %', c_block; END IF;
    IF c_rel != 7338 THEN RAISE EXCEPTION 'Post-verify: Rels = %', c_rel; END IF;
    IF c_bd1 != 7308 THEN RAISE EXCEPTION 'Post-verify: bd1-district blocks = %', c_bd1; END IF;
    IF c_bd2 != 15 THEN RAISE EXCEPTION 'Post-verify: bd2-district blocks = %', c_bd2; END IF;

    SELECT count(*) INTO evidence_exists FROM data_imports.release_execution_artifacts
        WHERE release_id = v_release_id AND artifact_type = 'PROMOTION_EVIDENCE';

    IF evidence_exists = 0 THEN
        INSERT INTO data_imports.release_execution_artifacts
            (release_id, artifact_type, artifact_payload)
        VALUES (
            v_release_id,
            'PROMOTION_EVIDENCE',
            jsonb_build_object(
                'timestamp', now(),
                'districts_inserted', 784,
                'subdistricts_inserted', 7092,
                'blocks_inserted', 7323,
                'block_districts_inserted', 7338,
                'bd1_district_blocks', 7308,
                'bd2_district_blocks', 15,
                'total_geography_units', c_state + c_dist + c_subdist,
                'rehearsal_sha256', 'CC61A483644F966E420B2753447311495EB2E12F13B36A4551D06D18DEFC0F17'
            )
        );
    END IF;

    UPDATE data_imports.releases SET status = 'PROMOTED', completed_at = now()
        WHERE id = v_release_id AND status IN ('STAGED', 'PENDING');

    RAISE NOTICE 'R16 POST-VERIFY OK: state=% dist=% subdist=% blocks=% rels=% bd1=% bd2=%',
        c_state, c_dist, c_subdist, c_block, c_rel, c_bd1, c_bd2;
END;
$$;
