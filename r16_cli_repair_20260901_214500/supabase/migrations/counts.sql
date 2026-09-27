DO $$
DECLARE
    state_lvl uuid; district_lvl uuid; subdistrict_lvl uuid;
    c_state int; c_dist int; c_subdist int; c_total int;
    c_block int; c_rel int; c_bd1 int; c_bd2 int; c_bd_total int;
    c_localities int;
BEGIN
    SELECT id INTO state_lvl FROM catalog.geography_levels WHERE level_key = 'STATE_UT';
    SELECT id INTO district_lvl FROM catalog.geography_levels WHERE level_key = 'DISTRICT';
    SELECT id INTO subdistrict_lvl FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';

    SELECT count(*) INTO c_state FROM catalog.geography_units WHERE geography_level_id = state_lvl;
    SELECT count(*) INTO c_dist FROM catalog.geography_units WHERE geography_level_id = district_lvl;
    SELECT count(*) INTO c_subdist FROM catalog.geography_units WHERE geography_level_id = subdistrict_lvl;
    SELECT count(*) INTO c_total FROM catalog.geography_units WHERE status = 'ACTIVE' AND geography_level_id IN (state_lvl, district_lvl, subdistrict_lvl);
    SELECT count(*) INTO c_block FROM catalog.development_blocks;
    SELECT count(*) INTO c_rel FROM catalog.block_districts;
    SELECT count(*) INTO c_bd1 FROM (SELECT block_id FROM catalog.block_districts GROUP BY block_id HAVING count(*) = 1) sub;
    SELECT count(*) INTO c_bd2 FROM (SELECT block_id FROM catalog.block_districts GROUP BY block_id HAVING count(*) = 2) sub;
    SELECT count(*) INTO c_bd_total FROM (SELECT block_id FROM catalog.block_districts GROUP BY block_id HAVING count(*) = 2) sub2 JOIN catalog.block_districts bd ON bd.block_id = sub2.block_id;
    SELECT count(*) INTO c_localities FROM catalog.geography_units WHERE geography_level_id NOT IN (state_lvl, district_lvl, subdistrict_lvl);

    RAISE EXCEPTION 'COUNTS: state=% dist=% subdist=% total=% block=% rel=% bd1=% bd2=% bd_rels=% loc=%', c_state, c_dist, c_subdist, c_total, c_block, c_rel, c_bd1, c_bd2, c_bd_total, c_localities;
END;
$$
