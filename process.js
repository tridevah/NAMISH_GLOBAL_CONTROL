const fs = require('fs');
const sql = fs.readFileSync('unit_master_rehearsal.sql', 'utf8');
const searchStr = `v_units JSONB := '[`;
const start = sql.indexOf(searchStr);
if (start > -1) {
    const end = sql.indexOf(`]'::jsonb;`, start);
    const jsonStr = sql.substring(start + 17, end + 1);
    try {
        const units = JSON.parse(jsonStr);
        console.log(`Parsed ${units.length} units.`);
        
        const requested = ["Bag", "Bottle", "Box", "Bundle", "Can", "Carton", "Cubic Meter", "Day", "Dozen", "Gram", "Milligram", "Hour", "Kilogram", "Kilometer", "Litre", "Meter", "Millilitre", "Number", "Pack", "Pair", "Piece", "Quintal", "Roll", "Service", "Set", "Square Feet", "Square Meter", "Tablet", "Metric Ton", "Unit"];
        for (let req of requested) {
            let kw = req.toLowerCase();
            let exacts = units.filter(u => u.name.toLowerCase() === kw);
            if (exacts.length === 0) exacts = units.filter(u => u.name.toLowerCase() === kw + 's' || u.name.toLowerCase() === kw + 'es');
            if (exacts.length === 0) exacts = units.filter(u => u.name.toLowerCase().includes(kw));
            
            let found = exacts.map(u => ({code: u.canonical_code, name: u.name, status: u.status, std: u.standard_code, source: u.source}));
            console.log(`\n--- ${req} ---`);
            console.log(JSON.stringify(found.slice(0, 3), null, 2));
        }
    } catch(e) { console.error("Parse error:", e.message); }
} else {
    console.log("Not found");
}
