const {expect} = require("chai");
const chai = require("chai");
const {deployments, ethers, getNamedAccounts} = require('hardhat');
const {smock} = require("@defi-wonderland/smock");
const expectRevert = require("../../utils/expectRevert");

const hre = require("hardhat");

const {fromOvnGov} = require("../../utils/decimals");

chai.use(smock.matchers);

let againstVotes = 0;
let forVotes = 1;
let abstainVotes = 2;

const proposalStates = ['Pending', 'Active', 'Canceled', 'Defeated', 'Succeeded', 'Queued', 'Expired', 'Executed'];

describe("TimelockController", function () {


    let ovnToken;
    let account;
    let governator;
    let timeLock;
    let exchange;
    let user1;
    let waitBlock = 200;

    beforeEach(async () => {
        await hre.run("compile");

        await deployments.fixture(['OvnToken','OvnGovernor']);

        const {deployer } = await getNamedAccounts();
        account = deployer;


        ovnToken = await ethers.getContract('OvnToken');
        governator = await ethers.getContract('OvnGovernor');
        timeLock = await ethers.getContract('OvnTimelockController');

        let addresses = await ethers.getSigners();
        user1 = addresses[1];
    });

    it("setGovernor -> revert is missing role", async function () {
        await expectRevert(timeLock.connect(user1).setGovernor(user1.address), 'AccessControl: account 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000');
    });

    it("hasRole(PROPOSER_ROLE, governor) = true", async function () {
        expect(await timeLock.hasRole(await timeLock.PROPOSER_ROLE(), governator.address)).to.true;
    });

    it("hasRole(PROPOSER_ROLE, account) = false", async function () {
        expect(await timeLock.hasRole(await timeLock.PROPOSER_ROLE(), account)).to.false;
    });


    it("setGovernor -> success", async function () {
        await timeLock.setGovernor(user1.address);

        expect(await timeLock.hasRole(await timeLock.PROPOSER_ROLE(), user1.address)).to.true;
        expect(await timeLock.hasRole(await timeLock.PROPOSER_ROLE(), governator.address)).to.false;

        await timeLock.setGovernor(governator.address);

        expect(await timeLock.hasRole(await timeLock.PROPOSER_ROLE(), user1.address)).to.false;
        expect(await timeLock.hasRole(await timeLock.PROPOSER_ROLE(), governator.address)).to.true;
    });




});
