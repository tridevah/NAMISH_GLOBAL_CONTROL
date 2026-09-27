const { execSync } = require('child_process');
const yauzl = require('yauzl');
const fs = require('fs');
const parse = require('csv-parse').parse;

const ZIP_DIR = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const files = fs.readdirSync(ZIP_DIR, {withFileTypes:true})
    .filter(d => d.isDirectory())
    .map(d => fs.readdirSync(ZIP_DIR + '/' + d.name).filter(f => f.endsWith('.zip')).map(f => ZIP_DIR + '/' + d.name + '/' + f))
    .flat();

let codes = { '1_2': 0, '3_4': 0, '5_6': 0, other: 0 };
let gpEmitted = 0;
let wrongTierEmitted = 0;

// Just checking one file to see if the structure works
console.log('Total zip files:', files.length);
