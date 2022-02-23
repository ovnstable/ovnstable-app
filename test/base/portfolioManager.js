const {expect} = require("chai");
const chai = require("chai");
const {deployments, ethers, getNamedAccounts, waffle, upgrades} = require("hardhat");
const {deployContract, deployMockContract} = waffle

const fs = require("fs");
const {toUSDC, fromOvn, toOvn, fromUSDC} = require("../../utils/decimals");
const hre = require("hardhat");
let assets = JSON.parse(fs.readFileSync('./assets.json'));
const BN = require('bignumber.js');
const {resetHardhat} = require("../../utils/tests");
const {constants} = require("@openzeppelin/test-helpers");
const {ZERO_ADDRESS} = constants;
const expectRevert = require("../../utils/expectRevert");
const sampleModule = require("@openzeppelin/hardhat-upgrades/dist/utils/deploy-impl");

chai.use(require('chai-bignumber')());


describe("PortfolioManager set new cash strategy", function () {


    let owner;
    let mockUsdc;
    let mockCashStrategy;
    let mockCashStrategy2;
    let account;
    let pm;

    before(async () => {
        // need to run inside IDEA via node script running
        await hre.run("compile");

        [owner] = await ethers.getSigners();
        const {deployer} = await getNamedAccounts();
        account = deployer;


        // reload after recompile
        let IERC20 = JSON.parse(fs.readFileSync('artifacts/@openzeppelin/contracts/token/ERC20/IERC20.sol/IERC20.json', 'utf-8'));
        let IStrategy = JSON.parse(fs.readFileSync('artifacts/contracts/interfaces/IStrategy.sol/IStrategy.json', 'utf-8'));

        let PortfolioManager = JSON.parse(fs.readFileSync('artifacts/contracts/PortfolioManager.sol/PortfolioManager.json', 'utf-8'));

        mockUsdc = await deployMockContract(owner, IERC20.abi);
        mockCashStrategy = await deployMockContract(owner, IStrategy.abi);
        mockCashStrategy2 = await deployMockContract(owner, IStrategy.abi);

        const contractFactory = await ethers.getContractFactory("PortfolioManager");
        pm = await upgrades.deployProxy(contractFactory, {kind: 'uups'});
        await pm.deployTransaction.wait();
        await sampleModule.deployImpl(hre, contractFactory, {kind: 'uups'}, pm.address);

        await pm.setUsdc(mockUsdc.address);
    });


    it("Set new cash strategy", async function () {
        await expectRevert(pm.setCashStrategy(ZERO_ADDRESS), "Zero address not allowed");

        expect(await pm.cashStrategy()).eq(ZERO_ADDRESS);

        await expect(pm.setCashStrategy(mockCashStrategy2.address))
            .to.emit(pm, "CashStrategyUpdated")
            .withArgs(mockCashStrategy2.address);

        await expect(pm.setCashStrategy(mockCashStrategy2.address))
            .to.emit(pm, "CashStrategyAlreadySet")
            .withArgs(mockCashStrategy2.address);


        await mockCashStrategy2.mock.claimRewards.returns(100);
        await mockCashStrategy2.mock.unstake.returns(100);
        await mockCashStrategy2.mock.stake.returns();

        await mockCashStrategy.mock.claimRewards.returns(100);
        await mockCashStrategy.mock.unstake.returns(100);
        await mockCashStrategy.mock.stake.returns();

        await mockUsdc.mock.balanceOf.withArgs(pm.address).returns(0);
        await mockUsdc.mock.transfer.returns(true);


        await expect(pm.setCashStrategy(mockCashStrategy.address))
            .to.not.emit(pm, "CashStrategyRestaked")
            .withArgs(mockCashStrategy.address);

    });

    it("Set new cash strategy when old have liquidity", async function () {

        await mockCashStrategy.mock.claimRewards.returns(100);
        await mockCashStrategy.mock.unstake.returns(100);
        await mockCashStrategy.mock.stake.returns();

        await mockCashStrategy2.mock.claimRewards.returns(100);
        await mockCashStrategy2.mock.unstake.returns(100);
        await mockCashStrategy2.mock.stake.returns();

        await mockUsdc.mock.balanceOf.withArgs(pm.address).returns(1234);
        await mockUsdc.mock.transfer.returns(true);

        await pm.setCashStrategy(mockCashStrategy.address);

        await expect(pm.setCashStrategy(mockCashStrategy2.address))
            .to.emit(pm, "CashStrategyRestaked")
            .withArgs(1234);

    });

});


describe("PortfolioManager not set cash strategy", function () {

    let pm;

    before(async () => {
        // need to run inside IDEA via node script running
        await hre.run("compile");

        const {deployer} = await getNamedAccounts();

        const contractFactory = await ethers.getContractFactory("PortfolioManager");
        pm = await upgrades.deployProxy(contractFactory, {kind: 'uups'});
        await pm.deployTransaction.wait();
        await sampleModule.deployImpl(hre, contractFactory, {kind: 'uups'}, pm.address);

        await pm.setExchanger(deployer);
    });


    it("Deposit should fail", async function () {
        expect(await pm.cashStrategy()).eq(ZERO_ADDRESS);
        await expectRevert(pm.deposit("0x0000000000000000000000000000000000000001", 1), "Cash strategy not set yet");
    });

    it("Withdraw should fail", async function () {
        expect(await pm.cashStrategy()).eq(ZERO_ADDRESS);
        await expectRevert(pm.withdraw("0x0000000000000000000000000000000000000001", 1), "Cash strategy not set yet");
    });

});


describe("PortfolioManager", function () {


    let exchange;
    let usdPlus;
    let usdc;
    let account;
    let pm;

    before(async () => {
        // need to run inside IDEA via node script running
        await hre.run("compile");
        await resetHardhat();

        await deployments.fixture(['setting', 'base', 'BuyUsdc']);

        const {deployer} = await getNamedAccounts();
        account = deployer;
        exchange = await ethers.getContract("Exchange");
        usdPlus = await ethers.getContract("UsdPlusToken");
        pm = await ethers.getContract("PortfolioManager");

        usdc = await ethers.getContractAt("ERC20", assets.usdc);

        MockStrategy
    });


    it("Deposit less then cash limit", async function () {

    });

    it("Deposit more then cash limit", async function () {

    });

    it("Withdraw less then cash amount", async function () {

    });

    it("Withdraw more then cash amount", async function () {

    });

});
