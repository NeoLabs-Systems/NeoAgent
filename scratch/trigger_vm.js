require('dotenv').config();
const { RuntimeManager } = require('../server/services/runtime/manager.js');
const db = require('../server/db/index.js');
db.init().then(async () => {
    console.log("Triggering VM for user 1...");
    try {
        const result = await RuntimeManager.ensureVM(1);
        console.log("ensureVM result:", result);
    } catch(err) {
        console.error("VM Error:", err);
    }
    process.exit(0);
});
