const {showHedgeM2M} = require("@overnight-contracts/common/utils/script-utils");

async function main() {

   await showHedgeM2M();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
