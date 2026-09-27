const fs = require('fs');
const lines = fs.readFileSync('india_states.json', 'utf8').split('\n');
let jsonLines = [];
let inRows = false;
for (const line of lines) {
  if (line.includes('"rows": [')) { inRows = true; jsonLines.push('['); continue; }
  if (inRows) {
    if (line.includes('],')) { jsonLines.push(']'); break; }
    jsonLines.push(line);
  }
}
const data = JSON.parse(jsonLines.join('\n'));
fs.writeFileSync('india_states_clean.json', JSON.stringify(data, null, 2));
console.log('Cleaned ' + data.length + ' states.');
