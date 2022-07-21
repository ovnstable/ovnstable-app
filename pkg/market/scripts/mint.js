const {getContract, initWallet, getPrice, showHedgeM2M} = require("@overnight-contracts/common/utils/script-utils");
const {toUSDC} = require("@overnight-contracts/common/utils/decimals");

async function main() {


    let usdPlus = await getContract('UsdPlusToken' );
    let exchanger = await getContract('HedgeExchangerUsdPlusWmatic' );

    await showHedgeM2M();

    let params = await getPrice();

    let sum = toUSDC(100);

    await (await usdPlus.approve(exchanger.address, sum, params)).wait();
    await (await exchanger.buy(sum, params)).wait();


    await showHedgeM2M();


}



main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
