grep "INSERT INTO \"catalog\".\"hsn_sac\"" prod_data.sql | awk -F'),(' '{print NF-1}'
grep "INSERT INTO \"catalog\".\"gst_rate_master\"" prod_data.sql | awk -F'),(' '{print NF-1}'
grep "INSERT INTO \"catalog\".\"measurement_units\"" prod_data.sql | awk -F'),(' '{print NF-1}'
