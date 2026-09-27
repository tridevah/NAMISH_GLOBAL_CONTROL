grep "INSERT INTO \"catalog\".\"hsn_sac\"" prod_data.sql | grep -o '),' | wc -l
grep "INSERT INTO \"catalog\".\"gst_rate_master\"" prod_data.sql | grep -o '),' | wc -l
grep "INSERT INTO \"catalog\".\"measurement_units\"" prod_data.sql | grep -o '),' | wc -l
