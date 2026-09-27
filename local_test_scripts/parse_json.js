const fs = require('fs');

function parse(file) {
    const data = fs.readFileSync(file, 'utf8');
    const json = JSON.parse(data);
    const rows = json.rows;
    for (const row of rows) {
        console.log(JSON.stringify(row.row_to_json));
    }
}

parse(process.argv[2]);
