const hre = require("hardhat");
const {deployments, getNamedAccounts, ethers} = require("hardhat");
const {resetHardhat} = require("./tests");
const ERC20 = require("./abi/IERC20.json");
const {logStrategyGasUsage} = require("./strategyCommon");
const {toE6, toE18} = require("./decimals");
const {expect} = require("chai");
const {evmCheckpoint, evmRestore, sharedBeforeEach} = require("./sharedBeforeEach");
const BigNumber = require('bignumber.js');
const chai = require("chai");
chai.use(require('chai-bignumber')());

const {waffle} = require("hardhat");
const {getContract, execTimelock} = require("@overnight-contracts/common/utils/script-utils");
const {toUSDC} = require("@overnight-contracts/common/utils/decimals");
const {transferETH, transferUSDPlus} = require("./script-utils");
const {provider} = waffle;


function strategyTest(strategyParams, network, assetAddress, runStrategyLogic) {

    let values = [
        // {
        //     value: 0.002,
        //     deltaPercent: 50,
        // },
        // {
        //     value: 0.02,
        //     deltaPercent: 10,
        // },
        // {
        //     value: 0.2,
        //     deltaPercent: 5,
        // },
        // {
        //     value: 2,
        //     deltaPercent: 5,
        // },
        // {
        //     value: 20,
        //     deltaPercent: 1,
        // },
        // {
        //     value: 200,
        //     deltaPercent: 1,
        // },
        {
            value: 2000,
            deltaPercent: 1,
        },
        // {
        //     value: 20000,
        //     deltaPercent: 1,
        // },
        // {
        //     value: 200000,
        //     deltaPercent: 0.1,
        // },
        // {
        //     value: 2000000,
        //     deltaPercent: 0.1,
        // },
    ]

    describe(`${strategyParams.name}`, function () {
        stakeUnstake(strategyParams, network, assetAddress, values, runStrategyLogic);
    });
}

function stakeUnstake(strategyParams, network, assetAddress, values, runStrategyLogic) {

    describe(`Stake/unstake`, function () {

        let account;
        let recipient;

        let strategy;
        let strategyName;

        let asset;
        let toAsset = function() {};

        sharedBeforeEach("deploy", async () => {
            await hre.run("compile");

            const signers = await ethers.getSigners();
            account = signers[0];
            recipient = provider.createEmptyWallet();

            await transferETH(1, recipient.address);
            await transferUSDPlus(100000, account.address);

            strategyName = strategyParams.name;
            await deployments.fixture([strategyName, `${strategyName}Setting` ]);


            strategy = await ethers.getContract(strategyName);
            await strategy.setExchanger(recipient.address);

            asset = await ethers.getContractAt("ERC20", assetAddress);
            let decimals = await asset.decimals();
            if (decimals === 18) {
                toAsset = toE18;
            } else {
                toAsset = toE6;
            }

        });

        values.forEach(item => {

            let stakeValue = item.value;
            let deltaPercent = item.deltaPercent ? item.deltaPercent : 5;
            let unstakeValue = stakeValue / 2;

            describe(`Stake ${stakeValue}`, function () {

                let balanceAsset;
                let expectedNetAsset;

                let VALUE;
                let DELTA;

                let netAssetValueCheck;

                sharedBeforeEach(`Stake ${stakeValue}`, async () => {

                    try {
                        let assetValue = toAsset(stakeValue);
                        VALUE = new BigNumber(assetValue);
                        DELTA = VALUE.times(new BigNumber(deltaPercent)).div(100);

                        await asset.connect(account).transfer(recipient.address, assetValue);

                        let balanceAssetBefore = new BigNumber(await asset.balanceOf(recipient.address).toString());
                        expectedNetAsset = new BigNumber((await strategy.netAssetValue()).toString()).plus(VALUE);

                        await asset.connect(recipient).transfer(strategy.address, assetValue);
                        await strategy.connect(recipient).stake(assetValue);

                        let balanceAssetAfter = new BigNumber(await asset.balanceOf(recipient.address).toString());

                        balanceAsset = balanceAssetBefore.minus(balanceAssetAfter);
                        netAssetValueCheck = new BigNumber(await strategy.netAssetValue()).toString();
                    } catch (e) {
                        console.log(e)
                        throw e;
                    }

                });

                it(`Balance asset is in range`, async function () {
                    greatLess(balanceAsset, VALUE, DELTA);
                });

                it(`NetAssetValue asset is in range`, async function () {
                    greatLess(netAssetValueCheck, expectedNetAsset, DELTA);
                });


                describe(`UnStake ${unstakeValue}`, function () {

                    let balanceAsset;
                    let expectedNetAsset;
                    let expectedLiquidation;

                    let VALUE;
                    let DELTA;

                    let netAssetValueCheck;
                    let liquidationValueCheck;

                    sharedBeforeEach(`Unstake ${unstakeValue}`, async () => {

                        let assetValue = toAsset(unstakeValue);
                        VALUE = new BigNumber(assetValue);
                        DELTA = VALUE.times(new BigNumber(deltaPercent)).div(100);

                        let balanceAssetBefore = new BigNumber((await asset.balanceOf(recipient.address)).toString());

                        expectedNetAsset = new BigNumber((await strategy.netAssetValue()).toString()).minus(VALUE);
                        expectedLiquidation = new BigNumber((await strategy.liquidationValue()).toString()).minus(VALUE);

                        await strategy.connect(recipient).unstake( assetValue, recipient.address);

                        let balanceAssetAfter = new BigNumber((await asset.balanceOf(recipient.address)).toString());

                        balanceAsset = balanceAssetAfter.minus(balanceAssetBefore);

                        netAssetValueCheck = new BigNumber((await strategy.netAssetValue()).toString());
                        liquidationValueCheck = new BigNumber((await strategy.liquidationValue()).toString());

                    });

                    it(`Balance asset is in range`, async function () {
                        greatLess(balanceAsset, VALUE, DELTA);
                    });

                    it(`NetAssetValue asset is in range`, async function () {
                        greatLess(netAssetValueCheck, expectedNetAsset, DELTA);
                    });

                    it(`LiquidationValue asset is in range`, async function () {
                        greatLess(liquidationValueCheck, expectedLiquidation, DELTA);
                    });

                });

            });

        });

    });
}


function claimRewards(strategyParams, network, assetAddress, values, runStrategyLogic) {

    describe(`Stake/ClaimRewards`, function () {

        let account;
        let recipient;

        let strategy;
        let strategyName;

        let asset;
        let toAsset = function() {};

        sharedBeforeEach(`deploy`, async () => {
            await hre.run("compile");
            await resetHardhat(network);

            strategyName = strategyParams.name;
            await deployments.fixture([strategyName, `${strategyName}Setting`, 'BuyUsdPlus']);

            const signers = await ethers.getSigners();
            account = signers[0];
            recipient = signers[1];

            strategy = await ethers.getContract(strategyName);
            await strategy.setPortfolioManager(recipient.address);
            if (strategyParams.isRunStrategyLogic) {
                await runStrategyLogic(strategyName, strategy.address);
            }

            asset = await ethers.getContractAt("ERC20", assetAddress);
            let decimals = await asset.decimals();
            if (decimals === 18) {
                toAsset = toE18;
            } else {
                toAsset = toE6;
            }
        });

        values.forEach(item => {

            let stakeValue = item.value;

            describe(`Stake ${stakeValue} => ClaimRewards`, function () {

                let balanceAsset;

                sharedBeforeEach(`Rewards ${stakeValue}`, async () => {

                    let assetValue = toAsset(stakeValue);

                    await asset.transfer(recipient.address, assetValue);
                    await asset.connect(recipient).transfer(strategy.address, assetValue);
                    await strategy.connect(recipient).stake(asset.address, assetValue);

                    const sevenDays = 7 * 24 * 60 * 60 * 1000;
                    await ethers.provider.send("evm_increaseTime", [sevenDays])
                    await ethers.provider.send('evm_mine');

                    if (strategyParams.doubleStakeReward) {
                        await asset.transfer(recipient.address, assetValue);
                        await asset.connect(recipient).transfer(strategy.address, assetValue);
                        await strategy.connect(recipient).stake(asset.address, assetValue);
                    }

                    await strategy.connect(recipient).claimRewards(recipient.address);

                    balanceAsset = new BigNumber((await asset.balanceOf(recipient.address)).toString());

                });

                it(`Balance asset is not 0`, async function () {
                    expect(balanceAsset.toNumber()).to.greaterThan(0);
                });

            });

        });
    });
}


function greatLess(value, expected, delta) {

    value = new BigNumber(value.toString());

    let maxValue = expected.plus(delta);
    let minValue = expected.minus(delta);

    let lte = value.lte(maxValue);
    let gte = value.gte(minValue);

    let valueNumber = value.div(new BigNumber(10).pow(6)).toFixed();
    let minValueNumber = minValue.div(new BigNumber(10).pow((6)).toFixed());
    let maxValueNumber = maxValue.div(new BigNumber(10).pow(6)).toFixed();

    let minSub = (value.minus(minValue)).div(new BigNumber(10).pow(6)).toFixed();
    let maxSub = (value.minus(maxValue)).div(new BigNumber(10).pow(6)).toFixed();

    expect(gte).to.equal(true, `Value[${valueNumber}] less than Min Value[${minValueNumber}] dif:[${minSub}]`);
    expect(lte).to.equal(true, `Value[${valueNumber}] great than Max Value[${maxValueNumber}] dif:[${maxSub}]`);
}

module.exports = {
    strategyTest: strategyTest,
}
