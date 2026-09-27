const fs = require('fs');

let code = fs.readFileSync('D:/NAMISH_GLOBAL_CONTROL/scripts/lgd_import_r15_core_real.js', 'utf8');

code = code.replace(
    /INSERT INTO staging.geography_imports \\(release_id, batch_id, source_observation_key, logical_entity, physical_source_sha256, internal_member_or_sheet, physical_source_row_number, logical_output_ordinal, emitted_record_ordinal, raw_payload, raw_payload_sha256, observation_identity_version\\)/,
    "INSERT INTO staging.geography_imports (release_id, batch_id, source_observation_key, entity_type, physical_source_sha256, internal_member_or_sheet, physical_row_number, logical_output_ordinal, emitted_record_ordinal, raw_data, raw_payload_sha256, observation_identity_version)"
);

fs.writeFileSync('D:/NAMISH_GLOBAL_CONTROL/scripts/lgd_import_r15_core_real_fixed.js', code);
