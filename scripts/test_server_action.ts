import { getUnits } from '../src/app/(protected)/data-hub/geography/actions';

async function run() {
  try {
    const res = await getUnits({ country_id: 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d' });
    console.log('ALL LEVELS TOTAL:', res.total);
    console.log('ALL LEVELS ROWS:', res.rows.length);
  } catch (err) {
    console.log('ERROR:', err);
  }
}
run();
