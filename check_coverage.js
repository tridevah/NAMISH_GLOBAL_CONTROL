const fs = require('fs');
const path = require('path');
const AdmZip = require('adm-zip');

const ROOT = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const STATES = [
    "ANDAMAN AND NICOBAR ISLANDS", "ANDHRA PRADESH", "ARUNACHAL PRADESH", "ASSAM", "BIHAR", 
    "CHANDIGARH", "CHHATTISGARH", "DELHI", "GOA", "GUJARAT", "HARYANA", "HIMACHAL PRADESH", 
    "JAMMU AND KASHMIR", "JHARKHAND", "KARNATAKA", "KERALA", "LADAKH", "LAKSHADWEEP", 
    "MADHYA PRADESH", "MAHARASHTRA", "MANIPUR", "MEGHALAYA", "MIZORAM", "NAGALAND", 
    "ODISHA", "PUDUCHERRY", "PUNJAB", "RAJASTHAN", "SIKKIM", "TAMIL NADU", "TELANGANA", 
    "THE DADRA AND NAGAR HAVELI AND DAMAN AND DIU", "TRIPURA", "UTTAR PRADESH", "UTTARAKHAND", "WEST BENGAL"
];

const stateInventory = {};
STATES.forEach(s => stateInventory[s] = { zips: [], contents: [], missing: [] });

const standaloneFiles = [];

function walk(dir) {
    if (!fs.existsSync(dir)) return;
    const list = fs.readdirSync(dir);
    for (const item of list) {
        const fullPath = path.join(dir, item);
        const stat = fs.statSync(fullPath);
        if (stat.isDirectory()) {
            walk(fullPath);
        } else {
            processFile(fullPath);
        }
    }
}

function processFile(filePath) {
    const ext = path.extname(filePath).toLowerCase();
    const parentDir = path.basename(path.dirname(filePath));
    
    if (STATES.includes(parentDir)) {
        if (ext === '.zip') {
            stateInventory[parentDir].zips.push(filePath);
            try {
                const zip = new AdmZip(filePath);
                zip.getEntries().forEach(entry => {
                    if (!entry.isDirectory) {
                        stateInventory[parentDir].contents.push(entry.entryName);
                    }
                });
            } catch(e) {}
        } else {
            stateInventory[parentDir].contents.push(path.basename(filePath));
        }
    } else {
        standaloneFiles.push(path.basename(filePath));
    }
}

walk(ROOT);

// Required items per state
const requiredPrefixes = [
    { prefix: 'districtofSpecificState', name: 'Districts' },
    { prefix: 'subDistrictofSpecificState', name: 'Sub-Districts/Tehsils' },
    { prefix: 'villageofSpecificState', name: 'Villages' },
    { prefix: 'blockofspecificState', name: 'Development Blocks' },
    { prefix: 'allBlockStateWithCoveredVillage', name: 'Block Village Coverage' },
    { prefix: 'priLbSpecificState', name: 'PRI Local Bodies' },
    { prefix: 'ulbSpecificState', name: 'Urban Local Bodies' },
    { prefix: 'tlbSpecificState', name: 'Traditional Local Bodies' },
    { prefix: 'villageGramPanchayatMapping', name: 'Gram Panchayats Mappings' },
    { prefix: 'uLBWardforState', name: 'ULB Wards' },
    { prefix: 'uLBWardforStateWithCov', name: 'ULB Wards Coverage' },
    { prefix: 'priWards', name: 'PRI Wards' }
];

// Special items (might be standalone or missing)
const globalRequirements = [
    { keyword: 'PIN CODE', name: 'PIN/Post Office master' },
    { keyword: 'Pincodeto_Village_Mapping', name: 'PIN-to-Village mappings' },
    { keyword: 'Pincodeto_Urban_Mapping', name: 'PIN-to-Urban mappings' }
];
const stateSpecialRequirements = [
    { keyword: 'localitiesUrbanLocalbodies', name: 'Urban localities' },
    { keyword: 'constituency', name: 'Parliament/Assembly constituencies' }
];

let globalMissing = [];
globalRequirements.forEach(req => {
    if (!standaloneFiles.find(f => f.includes(req.keyword))) {
        globalMissing.push(req.name);
    }
});

let stateCoverageText = [];
let allMissingEntities = new Set();

STATES.forEach(state => {
    let missing = [];
    const contents = stateInventory[state].contents;
    
    // Check standard prefixes in zip
    requiredPrefixes.forEach(req => {
        if (!contents.find(c => c.startsWith(req.prefix))) {
            missing.push(req.name);
            allMissingEntities.add(req.name);
        }
    });

    // Check special state requirements (either in zip or standalone in state folder)
    stateSpecialRequirements.forEach(req => {
        if (!contents.find(c => c.includes(req.keyword))) {
            missing.push(req.name);
            allMissingEntities.add(req.name);
        }
    });

    stateInventory[state].missing = missing;
    stateCoverageText.push(`${state}: ${missing.length === 0 ? 'COMPLETE' : 'MISSING ' + missing.join(', ')}`);
});

console.log("=== SOURCE GATE RESULT ===");
console.log("MODE: READ-ONLY");
console.log(`TOTAL STATES/UTS: ${STATES.length}`);
console.log(`GLOBAL MISSING: ${globalMissing.length > 0 ? globalMissing.join(', ') : 'NONE'}`);
console.log(`STATE MISSING TYPES: ${Array.from(allMissingEntities).join(', ')}`);

console.log("\n=== MISSING REPORTS (STATE-WISE SUMMARY) ===");
stateCoverageText.filter(t => t.includes("MISSING")).slice(0, 15).forEach(t => console.log(t));
if (stateCoverageText.filter(t => t.includes("MISSING")).length > 15) {
    console.log(`... and ${stateCoverageText.filter(t => t.includes("MISSING")).length - 15} more states.`);
}

console.log("\n=== STANDALONE FILES INVENTORIED ===");
standaloneFiles.forEach(f => console.log(f));
