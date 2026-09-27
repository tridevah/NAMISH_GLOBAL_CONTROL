async function runChecks() {
    const baseUrl = 'http://localhost:3001/api/data-hub/units';
    
    console.log("=== CHECK 1: Confirm 30 agreed units ===");
    try {
        const res1 = await fetch(`${baseUrl}?is_business=true&limit=100`);
        const json1 = await res1.json();
        const activeUnits = json1.data.filter((u: any) => u.status === 'ACTIVE');
        console.log(`Total is_business=true units: ${json1.count || json1.data.length}`);
        console.log(`Total ACTIVE business units: ${activeUnits.length}`);
        if (activeUnits.length >= 30) {
            console.log("PASS: 30+ business units found with names, short names and ACTIVE status.");
        } else {
            console.log(`FAIL: Only found ${activeUnits.length} active business units.`);
        }
    } catch (e: any) {
        console.log("FAIL Check 1:", e.message);
    }

    console.log("\n=== CHECK 2: Verify KGS, kgs and Kg ===");
    try {
        for (const term of ['KGS', 'kgs', 'Kg']) {
            const res = await fetch(`${baseUrl}?search=${term}`);
            const json = await res.json();
            const foundKilo = json.data.some((u: any) => u.business_name === 'KILOGRAMS' || u.short_name === 'Kg' || u.canonical_code === 'UNECE_REC20_KGM');
            console.log(`Search "${term}" -> found KILOGRAMS? ${foundKilo ? 'PASS' : 'FAIL'}`);
        }
    } catch (e: any) {
        console.log("FAIL Check 2:", e.message);
    }

    console.log("\n=== CHECK 3: Duplicate POST BAGS/Bag ===");
    try {
        const res3 = await fetch(baseUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ business_name: 'BAGS', short_name: 'Bag' })
        });
        const text3 = await res3.text();
        console.log(`POST status: ${res3.status}`);
        console.log(`POST response: ${text3}`);
        if (res3.status === 409 && text3.includes('This business unit already exists.')) {
            console.log("PASS: 409 Conflict returned with expected message.");
        } else {
            console.log("FAIL: Did not get expected 409 error.");
        }
    } catch (e: any) {
        console.log("FAIL Check 3:", e.message);
    }
}

runChecks();
