const hre = require("hardhat");
const {getContract, getPrice, execTimelock, getERC20} = require("@overnight-contracts/common/utils/script-utils");
const {toUSDC} = require("@overnight-contracts/common/utils/decimals");
const ethers = hre.ethers;


async function main() {

    let price = await getPrice();

    let governor = await getContract('OvnGovernor', 'polygon');
    let exchange = await getContract('Exchange', 'polygon');

    let addresses = [];
    let values = [];
    let abis = [];



    // await execTimelock(async (timelock)=>{
    //
    //     await exchange.connect(timelock).upgradeTo('0x461B064cd66598e3d2Bc99cdBC07fC5bf3251959')
    //
    //     let usdc = await getERC20('usdc' );
    //
    //     await usdc.approve(exchange.address, toUSDC(10));
    //     await exchange.buy(usdc.address, toUSDC(10));
    //
    //
    // });


    addresses.push(exchange.address);
    values.push(0);
    abis.push(exchange.interface.encodeFunctionData('upgradeTo', ['0x461B064cd66598e3d2Bc99cdBC07fC5bf3251959']));

    console.log('Creating a proposal...')
    const proposeTx = await governor.proposeExec(
        addresses,
        values,
        abis,
        ethers.utils.id("Proposal 2: Upgrade Strategies"),
        price
    );
    let tx = await proposeTx.wait();
    const proposalId = tx.events.find((e) => e.event === 'ProposalCreated').args.proposalId;
    console.log('Proposal id ' + proposalId)
}




main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
