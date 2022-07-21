const {fromE18, fromUSDC, toE18, toUSDC} = require("@overnight-contracts/common/utils/decimals");
const axios = require('axios');
const hre = require("hardhat");
const path = require('path'),
    fs = require('fs');
const {DEFAULT} = require("./assets");
const {evmCheckpoint, evmRestore} = require("@overnight-contracts/common/utils/sharedBeforeEach");
const BN = require('bn.js');

let ethers = require('hardhat').ethers;

let wallet = undefined;

async function initWallet() {

    if (wallet)
        return wallet;

    let provider = ethers.provider;
    console.log('Provider: ' + provider.connection.url);
    wallet = await new ethers.Wallet(process.env.PK_POLYGON, provider);
    console.log('Wallet: ' + wallet.address);
    const balance = await provider.getBalance(wallet.address);
    console.log('Balance wallet: ' + fromE18(balance));

    return wallet;
}


async function getContract(name, network) {

    if (!network)
        network = process.env.STAND;

    let ethers = hre.ethers;
    let wallet = await initWallet(ethers);

    let searchPath = fromDir(require('app-root-path').path, path.join(network, name + ".json"));
    let contractJson = JSON.parse(fs.readFileSync(searchPath));
    return await ethers.getContractAt(contractJson.abi, contractJson.address, wallet);

}

async function getAbi(name) {

    let searchPath = fromDir(require('app-root-path').path, path.join(name + ".json"));
    return JSON.parse(fs.readFileSync(searchPath)).abi;

}

async function getStrategy(address) {

    let ethers = hre.ethers;
    let wallet = await initWallet(ethers);

    const StrategyJson = require("./abi/Strategy.json");
    return await ethers.getContractAt(StrategyJson.abi, address, wallet);

}

async function getERC20(name) {

    let ethers = hre.ethers;
    let wallet = await initWallet(ethers);

    const ERC20 = require("./abi/IERC20.json");

    return await ethers.getContractAt(ERC20, DEFAULT[name], wallet);

}

function fromDir(startPath, filter) {


    if (!fs.existsSync(startPath)) {
        console.log("no dir ", startPath);
        return;
    }

    let files = fs.readdirSync(startPath);
    for (let i = 0; i < files.length; i++) {
        let filename = path.join(startPath, files[i]);
        let stat = fs.lstatSync(filename);
        if (stat.isDirectory()) {
            let value = fromDir(filename, filter); //recurse
            if (value)
                return value;

        } else if (filename.endsWith(filter)) {
            // console.log('Fond: ' + filename)
            return filename;
        }
    }


}

async function showPlatform(platform, blocknumber) {

    let strategyAssets;
    if (blocknumber) {
        strategyAssets = await platform.getStrategies({blockNumber: blocknumber});
    } else {
        strategyAssets = await platform.getStrategies();
    }

    let strategiesMapping = (await axios.get('https://app.overnight.fi/api/dapp/strategies')).data;

    const StrategyJson = require("./abi/Strategy.json");

    let items = [];
    for (let i = 0; i < strategyAssets.length; i++) {
        let asset = strategyAssets[i];

        let mapping = strategiesMapping.find(value => value.address === asset);

        let contract = await hre.ethers.getContractAt(StrategyJson.abi, asset, wallet);

        let nav = fromUSDC(await contract.netAssetValue());
        let liq = fromUSDC(await contract.liquidationValue());

        items.push({name: mapping ? mapping.name : asset, netAssetValue: nav, liquidationValue: liq});
    }

    console.table(items);
}

async function showHedgeM2M() {

    let wallet = await initWallet();

    let usdPlus = await getContract('UsdPlusToken');
    let rebase = await getContract('RebaseTokenUsdPlusWmatic');
    let strategy = await getContract('StrategyUsdPlusWmatic');

    console.log('User balances')
    let user = [];

    user.push({name: 'ETS', value: fromUSDC(await rebase.balanceOf(wallet.address)) });
    user.push({name: 'UsdPlus', value: fromUSDC(await usdPlus.balanceOf(wallet.address)) });
    console.table(user);

    console.log('ETS:')

    let values = [];
    values.push({name: 'Total ETS', value: fromUSDC(await rebase.totalSupply()) });
    values.push({name: 'Total NAV', value: fromUSDC(await strategy.netAssetValue()) });
    values.push({name: 'HF', value: (await strategy.currentHealthFactor()).toString() });
    values.push({name: 'Liq index', value: (await rebase.liquidityIndex()).toString() });

    console.table(values);


    let items = await strategy.balances();

    let arrays = [];
    for (let i = 0; i < items.length; i++) {

        let item = items[i];

        arrays.push({
            name: item[0],
            amountUSDC: fromUSDC(item[1].toString()),
            amount: fromE18(item[2].toString()),
            borrowed: item[3].toString()
        })

    }

    console.table(arrays);
}

async function showM2M(blocknumber) {

    let m2m = await getContract('Mark2Market', process.env.STAND);
    let usdPlus = await getContract('UsdPlusToken', process.env.STAND);
    let pm = await getContract('PortfolioManager', process.env.STAND);

    let strategyAssets;
    let totalNetAssets;
    let strategyWeights;
    if (blocknumber) {
        strategyAssets = await m2m.strategyAssets({blockTag: blocknumber});
        totalNetAssets = await m2m.totalNetAssets({blockTag: blocknumber});
        strategyWeights = await pm.getAllStrategyWeights({blockTag: blocknumber});
    } else {
        strategyAssets = await m2m.strategyAssets();
        totalNetAssets = await m2m.totalNetAssets();
        strategyWeights = await pm.getAllStrategyWeights();
    }

    let url;
    switch (process.env.STAND) {
        case "avalanche":
            url = "https://avax.overnight.fi/api/dict/strategies";
            break;
        case "bsc":
            url = "https://bnb.overnight.fi/api/dict/strategies";
            break;
        case "polygon":
            url = "https://app.overnight.fi/api/dict/strategies";
            break;
        case "polygon_dev":
            url = "https://dev.overnight.fi/api/dict/strategies";
            break;
        default:
            throw Error('Unknown STAND: ' + process.env.STAND);
    }

    let strategiesMapping = [];
    try {
        strategiesMapping = (await axios.get(url)).data;
    } catch (e) {
        console.log('Error: ' + e.message);
    }

    let sum = 0;

    let items = [];
    for (let i = 0; i < strategyAssets.length; i++) {
        let asset = strategyAssets[i];
        let weight = strategyWeights[i];

        let mapping = strategiesMapping.find(value => value.address === asset.strategy);

        // if (fromUSDC(asset.netAssetValue) === 0){
        //     continue;
        // }

        items.push(
            {
                name: mapping ? mapping.name : asset.strategy,
                netAssetValue: fromUSDC(asset.netAssetValue),
                liquidationValue: fromUSDC(asset.liquidationValue),
                targetWeight: weight.targetWeight.toNumber() / 1000,
                maxWeight: weight.maxWeight.toNumber() / 1000,
                enabled: weight.enabled,
                enabledReward: weight.enabledReward
            });
        sum += fromUSDC(asset.netAssetValue);
    }

    for (let i = 0; i < items.length; i++) {
        items[i].currentWeight = Number((100 * items[i].netAssetValue / sum).toFixed(3));
    }

    console.table(items);
    console.log('Total m2m:  ' + fromUSDC(totalNetAssets.toNumber()));

    if (usdPlus) {

        let totalUsdPlus;
        if (blocknumber) {
            totalUsdPlus = (await usdPlus.totalSupply({blockTag: blocknumber})) / 10 ** 6
        } else {
            totalUsdPlus = (await usdPlus.totalSupply()) / 10 ** 6
        }
        console.log('Total USD+: ' + totalUsdPlus);
    }

    console.log(`current LI: ${(await usdPlus.liquidityIndex()).toString()}`)
}


async function getPrice() {
    let value = process.env.GAS_PRICE.toString() + "000000000";

    let params = {maxFeePerGas: value, maxPriorityFeePerGas: value};

    if (process.env.ETH_NETWORK === 'POLYGON')
        params.gasLimit = 15000000;

    return params;
}


async function upgradeStrategy(strategy, newImplAddress) {

    let timelock = await getContract('OvnTimelockController', 'polygon');


    hre.ethers.provider = new hre.ethers.providers.JsonRpcProvider('http://localhost:8545')
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [timelock.address],
    });

    await checkTimeLockBalance();

    const timelockAccount = await hre.ethers.getSigner(timelock.address);
    await strategy.connect(timelockAccount).upgradeTo(newImplAddress);

    await hre.network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [timelock.address],
    });

}

async function execTimelock(exec) {


    let timelock = await getContract('OvnTimelockController');


    hre.ethers.provider = new hre.ethers.providers.JsonRpcProvider('http://localhost:8545')
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [timelock.address],
    });

    await checkTimeLockBalance();

    const timelockAccount = await hre.ethers.getSigner(timelock.address);

    await exec(timelockAccount);

    await hre.network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [timelock.address],
    });


}

async function changeWeightsAndBalance(weights) {

    await evmCheckpoint('Before');

    let timelock = await getContract('OvnTimelockController');
    let pm = await getContract('PortfolioManager');
    let usdPlus = await getContract('UsdPlusToken');
    let usdc = await getERC20('usdc');
    let exchange = await getContract('Exchange');

    console.log('M2M before:')
    await showM2M();


    hre.ethers.provider = new hre.ethers.providers.JsonRpcProvider('http://localhost:8545')
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [timelock.address],
    });


    await checkTimeLockBalance();

    const timelockAccount = await hre.ethers.getSigner(timelock.address);

    await (await pm.connect(timelockAccount).setStrategyWeights(weights)).wait();
    console.log('setStrategyWeights done()');

    await (await pm.connect(timelockAccount).balance()).wait();
    console.log('balance done()');

    await hre.network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [timelock.address],
    });


    if (fromUSDC(await usdc.balanceOf(wallet.address)) > 10) {
        await usdc.approve(exchange.address, toUSDC(10));
        await exchange.buy(usdc.address, toUSDC(10));

        await usdPlus.approve(exchange.address, toUSDC(10));
        await exchange.redeem(usdc.address, toUSDC(10));
    }

    console.log('M2M after:')
    await showM2M();

    await evmRestore('Before');

}

async function checkTimeLockBalance() {

    let timelock = await getContract('OvnTimelockController');

    const balance = await hre.ethers.provider.getBalance(timelock.address);

    if (new BN(balance.toString()).lt(new BN("10000000000000000000"))) {
        const tx = {
            from: wallet.address,
            to: timelock.address,
            value: toE18(1),
            nonce: await hre.ethers.provider.getTransactionCount(wallet.address, "latest"),
            gasLimit: 229059,
            gasPrice: await hre.ethers.provider.getGasPrice(),
        }
        await wallet.sendTransaction(tx);
    }

}

module.exports = {
    initWallet: initWallet,
    showM2M: showM2M,
    showHedgeM2M: showHedgeM2M,
    showPlatform: showPlatform,
    getPrice: getPrice,
    getContract: getContract,
    getERC20: getERC20,
    getStrategy: getStrategy,
    changeWeightsAndBalance: changeWeightsAndBalance,
    upgradeStrategy: upgradeStrategy,
    execTimelock: execTimelock,
    getAbi: getAbi
}
