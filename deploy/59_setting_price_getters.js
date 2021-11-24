let aCurvepoolStake = "0x445FE580eF8d70FF569aB36e80c647af338db351"

const fs = require("fs");
let assets = JSON.parse(fs.readFileSync('./assets.json'));

module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy} = deployments;
    const {deployer} = await getNamedAccounts();

    const usdcPriceGetter = await ethers.getContract('UsdcPriceGetter');
    const aUsdcPriceGetter = await ethers.getContract('AUsdcPriceGetter');
    const a3CrvPriceGetter = await ethers.getContract('A3CrvPriceGetter');
    const a3CrvGaugePriceGetter = await ethers.getContract('A3CrvGaugePriceGetter');
    const crvPriceGetter = await ethers.getContract('CrvPriceGetter');
    const wMaticPriceGetter = await ethers.getContract('WMaticPriceGetter');

    // setup price getters
    await a3CrvPriceGetter.setPool(aCurvepoolStake);
    console.log("a3CrvPriceGetter.setPool done");

    await a3CrvGaugePriceGetter.setA3CrvPriceGetter(a3CrvPriceGetter.address);
    console.log("a3CrvGaugePriceGetter.setA3CrvPriceGetter done");

    // link
    const investmentPortfolio = await ethers.getContract('InvestmentPortfolio');


    // struct AssetInfo {
    //     address asset;
    //     address priceGetter;
    // }


    let usdcAssetInfo = {
        asset: assets.usdc,
        priceGetter: usdcPriceGetter.address
    }
    let aUsdcAssetInfo = {
        asset: assets.amUsdc,
        priceGetter: aUsdcPriceGetter.address
    }
    let a3CrvAssetInfo = {
        asset: assets.am3CRV,
        priceGetter: a3CrvPriceGetter.address
    }
    let a3CrvGaugeAssetInfo = {
        asset: assets.am3CRVgauge,
        priceGetter: a3CrvGaugePriceGetter.address
    }
    let crvAssetInfo = {
        asset: assets.crv,
        priceGetter: crvPriceGetter.address
    }
    let wMaticAssetInfo = {
        asset: assets.wMatic,
        priceGetter: wMaticPriceGetter.address
    }
    let assetInfos = [
        usdcAssetInfo,
        aUsdcAssetInfo,
        a3CrvAssetInfo,
        a3CrvGaugeAssetInfo,
        crvAssetInfo,
        wMaticAssetInfo
    ]
    let result = await investmentPortfolio.setAssetInfos(assetInfos);
    console.log("investmentPortfolio.setAssetInfos done");

};

module.exports.tags = ['base','Setting'];
