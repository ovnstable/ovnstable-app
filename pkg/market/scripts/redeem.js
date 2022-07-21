const {getContract, getPrice, showHedgeM2M} = require("@overnight-contracts/common/utils/script-utils");
const {toUSDC} = require("@overnight-contracts/common/utils/decimals");
async function main() {


    let exchanger = await getContract('HedgeExchangerUsdPlusWmatic' );
    let rebase = await getContract('RebaseTokenUsdPlusWmatic' );

    await showHedgeM2M();

    let price = await getPrice();
    let sum = toUSDC(100);

    await (await rebase.approve(exchanger.address, sum, price)).wait();
    await (await exchanger.redeem(sum, price)).wait();

    await showHedgeM2M();


}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
