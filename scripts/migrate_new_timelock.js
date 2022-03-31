const hre = require("hardhat");
const fs = require("fs");
const {fromE18, fromUSDC, fromOvnGov} = require("../utils/decimals");
const {expect} = require("chai");
const ethers = hre.ethers;

let ERC20 = JSON.parse(fs.readFileSync('./artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json'));
let ERC20Metadata = JSON.parse(fs.readFileSync('./artifacts/@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol/IERC20Metadata.json'));

let UsdPlusToken = JSON.parse(fs.readFileSync('./deployments/polygon/UsdPlusToken.json'));
let OvnGovernor = JSON.parse(fs.readFileSync('./deployments/polygon/OvnGovernor.json'));
let OvnToken = JSON.parse(fs.readFileSync('./deployments/polygon/OvnToken.json'));

let OldTimeLock = JSON.parse(fs.readFileSync('./deployments/polygon/TimelockController.json'));
let NewTimeLock = JSON.parse(fs.readFileSync('./deployments/polygon/OvnTimelockController.json'));

let Exchange = JSON.parse(fs.readFileSync('./deployments/polygon/Exchange.json'));
let PortfolioManager = JSON.parse(fs.readFileSync('./deployments/polygon/PortfolioManager.json'));
let Mark2Market = JSON.parse(fs.readFileSync('./deployments/polygon/Mark2Market.json'));

let StrategyAave = JSON.parse(fs.readFileSync('./deployments/polygon/StrategyAave.json'));
let StrategyCurve = JSON.parse(fs.readFileSync('./deployments/polygon/StrategyCurve.json'));
let StrategyDodoUsdc = JSON.parse(fs.readFileSync('./deployments/polygon/StrategyDodoUsdc.json'));
let StrategyDodoUsdt = JSON.parse(fs.readFileSync('./deployments/polygon/StrategyDodoUsdt.json'));
let StrategyImpermaxQsUsdcUsdt = JSON.parse(fs.readFileSync('./deployments/polygon/StrategyImpermaxQsUsdcUsdt.json'));
let StrategyIzumi = JSON.parse(fs.readFileSync('./deployments/polygon/StrategyIzumi.json'));
let StrategyMStable = JSON.parse(fs.readFileSync('./deployments/polygon/StrategyMStable.json'));


async function main() {
    // need to run inside IDEA via node script running
    await hre.run("compile");

    let wallet = await initWallet();

    let usdPlus = await ethers.getContractAt(UsdPlusToken.abi, UsdPlusToken.address, wallet);
    const governor = await ethers.getContractAt(OvnGovernor.abi, OvnGovernor.address, wallet);
    const ovnToken = await ethers.getContractAt(OvnToken.abi, OvnToken.address, wallet);
    const exchange = await ethers.getContractAt(Exchange.abi, Exchange.address, wallet);
    const pm = await ethers.getContractAt(PortfolioManager.abi, PortfolioManager.address, wallet);
    const m2m = await ethers.getContractAt(Mark2Market.abi, Mark2Market.address, wallet);

    const oldTimeLock = await ethers.getContractAt(OldTimeLock.abi, OldTimeLock.address, wallet);
    const newTimeLock = await ethers.getContractAt(NewTimeLock.abi, NewTimeLock.address, wallet);


    let addresses = [];
    let values = [];
    let abis = [];

    // await grantRevokeRoleByGov();
    // await moveRulesAll();
    await checksRules();

    async function grantRevokeRoleByGov(){

        addresses.push(usdPlus.address);
        values.push(0);
        abis.push(usdPlus.interface.encodeFunctionData('grantRole', [await usdPlus.DEFAULT_ADMIN_ROLE(), newTimeLock.address]));

        addresses.push(usdPlus.address);
        values.push(0);
        abis.push(usdPlus.interface.encodeFunctionData('grantRole', [await usdPlus.UPGRADER_ROLE(), newTimeLock.address]));

        addresses.push(usdPlus.address);
        values.push(0);
        abis.push(usdPlus.interface.encodeFunctionData('revokeRole', [await usdPlus.UPGRADER_ROLE(), oldTimeLock.address]));

        addresses.push(usdPlus.address);
        values.push(0);
        abis.push(usdPlus.interface.encodeFunctionData('revokeRole', [await usdPlus.DEFAULT_ADMIN_ROLE(), oldTimeLock.address]));

        addresses.push(ovnToken.address);
        values.push(0);
        abis.push(ovnToken.interface.encodeFunctionData('grantRole', [await ovnToken.DEFAULT_ADMIN_ROLE(), newTimeLock.address]));

        addresses.push(ovnToken.address);
        values.push(0);
        abis.push(ovnToken.interface.encodeFunctionData('grantRole', [await ovnToken.UPGRADER_ROLE(), newTimeLock.address]));

        addresses.push(ovnToken.address);
        values.push(0);
        abis.push(ovnToken.interface.encodeFunctionData('revokeRole', [await ovnToken.UPGRADER_ROLE(), oldTimeLock.address]));

        addresses.push(ovnToken.address);
        values.push(0);
        abis.push(ovnToken.interface.encodeFunctionData('revokeRole', [await ovnToken.DEFAULT_ADMIN_ROLE(), oldTimeLock.address]));


        console.log('Creating a proposal...')
        const proposeTx = await governor.proposeExec(
            addresses,
            values,
            abis,
            ethers.utils.id("Proposal #22 New core"),
        );

        console.log('Tx ' + proposeTx.hash);
        let tx = await proposeTx.wait();
        const proposalId = tx.events.find((e) => e.event == 'ProposalCreated').args.proposalId;

        console.log('Proposal id ' + proposalId);

        await execProposal(governor, ovnToken, proposalId, wallet);
    }

    async function checksRules() {
        await printRules(exchange, 'Exchange');
        await printRules(m2m, 'M2M');
        await printRules(pm, 'PM');

        await printRules(await ethers.getContractAt(StrategyAave.abi, StrategyAave.address, wallet), 'StrategyAave');
        await printRules(await ethers.getContractAt(StrategyCurve.abi, StrategyCurve.address, wallet), 'StrategyCurve');
        await printRules(await ethers.getContractAt(StrategyDodoUsdc.abi, StrategyDodoUsdc.address, wallet), 'StrategyDodoUsdc');
        await printRules(await ethers.getContractAt(StrategyDodoUsdt.abi, StrategyDodoUsdt.address, wallet), 'StrategyDodoUsdt');
        await printRules(await ethers.getContractAt(StrategyImpermaxQsUsdcUsdt.abi, StrategyImpermaxQsUsdcUsdt.address, wallet), 'StrategyImpermaxQsUsdcUsdt');
        await printRules(await ethers.getContractAt(StrategyIzumi.abi, StrategyIzumi.address, wallet), 'StrategyIzumi');
        await printRules(await ethers.getContractAt(StrategyMStable.abi, StrategyMStable.address, wallet), 'StrategyMStable');


        await printRules(newTimeLock, 'OvnTimelockController');
        await printRules(ovnToken, 'OvnToken');
        await printRules(usdPlus, 'USDPlus');
    }

    async function moveRulesAll(){

        await moveRules(exchange, wallet.address, newTimeLock.address);
        await moveRules(m2m, wallet.address, newTimeLock.address);
        await moveRules(pm, wallet.address, newTimeLock.address);

        await moveRules(await ethers.getContractAt(StrategyAave.abi, StrategyAave.address, wallet), wallet.address, newTimeLock.address);
        await moveRules(await ethers.getContractAt(StrategyCurve.abi, StrategyCurve.address, wallet), wallet.address, newTimeLock.address);
        await moveRules(await ethers.getContractAt(StrategyDodoUsdc.abi, StrategyDodoUsdc.address, wallet), wallet.address, newTimeLock.address);
        await moveRules(await ethers.getContractAt(StrategyDodoUsdt.abi, StrategyDodoUsdt.address, wallet), wallet.address, newTimeLock.address);
        await moveRules(await ethers.getContractAt(StrategyImpermaxQsUsdcUsdt.abi, StrategyImpermaxQsUsdcUsdt.address, wallet), wallet.address, newTimeLock.address);
        await moveRules(await ethers.getContractAt(StrategyIzumi.abi, StrategyIzumi.address, wallet), wallet.address, newTimeLock.address);
        await moveRules(await ethers.getContractAt(StrategyMStable.abi, StrategyMStable.address, wallet), wallet.address, newTimeLock.address);



    }

    async function moveRules(contract, oldAddress, newAddress) {

        await (await contract.grantRole(await contract.DEFAULT_ADMIN_ROLE(), newAddress)).wait();
        await (await contract.grantRole(await contract.UPGRADER_ROLE(), newAddress)).wait();

        await (await contract.revokeRole(await contract.UPGRADER_ROLE(), oldAddress)).wait();
        await (await contract.revokeRole(await contract.DEFAULT_ADMIN_ROLE(), oldAddress)).wait();
    }

    async function printRules(contract, name) {

        try {
            console.log(`\n[${name}]`);
            expect(false, 'hasRole(ADMIN) OLD_TIME_LOCK = false').to.equal(await contract.hasRole(await contract.UPGRADER_ROLE(), oldTimeLock.address));
            expect(false, 'hasRole(ADMIN) WALLET = false').to.equal(await contract.hasRole(await contract.UPGRADER_ROLE(), wallet.address));
            expect(true, 'hasRole(ADMIN) NEW_TIME_LOCK = true').to.equal(await contract.hasRole(await contract.UPGRADER_ROLE(), newTimeLock.address));

            expect(false, 'hasRole(UPGRADED) OLD_TIME_LOCK = false').to.equal(await contract.hasRole(await contract.UPGRADER_ROLE(), oldTimeLock.address));
            expect(false, 'hasRole(UPGRADED) WALLET = false').to.equal(await contract.hasRole(await contract.UPGRADER_ROLE(), wallet.address));
            expect(true, 'hasRole(UPGRADED) NEW_TIME_LOCK = true').to.equal(await contract.hasRole(await contract.UPGRADER_ROLE(), newTimeLock.address));
        } catch (e) {
            console.log('Error test: ' + e)
            return;
        }

        console.log('Done')
    }
}





main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });




async function execProposal(governator, ovn, id, wallet) {

    const proposalStates = ['Pending', 'Active', 'Canceled', 'Defeated', 'Succeeded', 'Queued', 'Expired', 'Executed'];


    let quorum = fromOvnGov(await governator.quorum(await ethers.provider.getBlockNumber() - 1));
    console.log('Quorum: ' + quorum);

    const proposalId = id;

    let votes = ethers.utils.parseUnits("100000100", 9);

    let state = proposalStates[await governator.state(proposalId)];
    if (state === "Executed") {
        return;
    }

    console.log('State status: ' + state)
    await ethers.provider.send('evm_mine'); // wait 1 block before opening voting

    console.log('Votes: ' + votes)
    await governator.castVote(proposalId, 1);

    let item = await governator.proposals(proposalId);
    console.log('Votes for: ' + item.forVotes / 10 ** 18);

    let total = fromOvnGov(await ovn.getVotes(wallet.address));
    console.log('Delegated ' + total)

    let waitBlock = 200;
    const sevenDays = 7 * 24 * 60 * 60;
    for (let i = 0; i < waitBlock; i++) {
        await ethers.provider.send("evm_increaseTime", [sevenDays])
        await ethers.provider.send('evm_mine'); // wait 1 block before opening voting
    }

    state = proposalStates[await governator.state(proposalId)];
    expect(state).to.eq('Succeeded');
    await governator.queueExec(proposalId);
    await ethers.provider.send('evm_mine'); // wait 1 block before opening voting
    await governator.executeExec(proposalId);


    state = proposalStates[await governator.state(proposalId)];
    console.log('State status: ' + state)
    expect(state).to.eq('Executed');
}


async function initWallet(){

    let provider = ethers.provider;

    console.log('Provider: ' + provider.connection.url);
    let wallet = await new ethers.Wallet(process.env.PK_POLYGON, provider);
    console.log('Wallet: ' + wallet.address);
    const balance = await provider.getBalance(wallet.address);
    console.log('Balance wallet: ' + fromE18(balance))

    return wallet;
}