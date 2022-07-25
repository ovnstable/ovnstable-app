const {getContract, initWallet, getPrice, showHedgeM2M} = require("@overnight-contracts/common/utils/script-utils");

async function main() {

    let strategy = await getContract('StrategyUsdPlusWmatic' );

    await showHedgeM2M();

    let params = await getPrice();

    await (await strategy.balance(params)).wait();

    await showHedgeM2M();

}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

