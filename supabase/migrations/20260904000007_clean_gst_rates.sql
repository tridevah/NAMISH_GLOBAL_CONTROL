-- Migration 20260904000007: Clean GST Rate Names
BEGIN;

UPDATE catalog.gst_rate_master SET rate_name = 'Nil Rated' WHERE rate_percent = 0.00;
UPDATE catalog.gst_rate_master SET rate_name = 'Special Rate 0.25%' WHERE rate_percent = 0.25;
UPDATE catalog.gst_rate_master SET rate_name = 'Special Rate 1.5%' WHERE rate_percent = 1.50;
UPDATE catalog.gst_rate_master SET rate_name = 'Standard Rate 3%' WHERE rate_percent = 3.00;
UPDATE catalog.gst_rate_master SET rate_name = 'Standard Rate 5%' WHERE rate_percent = 5.00 AND category = 'STANDARD';
UPDATE catalog.gst_rate_master SET rate_name = 'Standard Rate 12%' WHERE rate_percent = 12.00;
UPDATE catalog.gst_rate_master SET rate_name = 'Standard Rate 18%' WHERE rate_percent = 18.00;
UPDATE catalog.gst_rate_master SET rate_name = 'Standard Rate 40%' WHERE rate_percent = 40.00;

UPDATE catalog.gst_rate_master SET rate_name = 'Composition Rate 1%' WHERE rate_percent = 1.00 AND category = 'COMPOSITION';
UPDATE catalog.gst_rate_master SET rate_name = 'Composition Rate 5%' WHERE rate_percent = 5.00 AND category = 'COMPOSITION';
UPDATE catalog.gst_rate_master SET rate_name = 'Composition Rate 6%' WHERE rate_percent = 6.00 AND category = 'COMPOSITION';

UPDATE catalog.gst_rate_master SET rate_name = 'Standard Rate 28% (Historical)' WHERE rate_percent = 28.00 AND category = 'HISTORICAL';

COMMIT;
