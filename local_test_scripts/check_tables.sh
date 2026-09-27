#!/bin/bash
npx supabase db query "SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema IN ('public', 'catalog') AND table_name IN ('gst_rate_master', 'hsn_sac', 'india_hsn_sac_master', 'global_unit_master', 'measurement_units');" --linked
