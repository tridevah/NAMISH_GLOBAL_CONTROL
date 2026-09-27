SELECT (SELECT count(*) FROM catalog.geography_units) as geo_units, (SELECT count(*) FROM catalog.development_blocks) as dev_blocks;
