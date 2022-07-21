const {task} = require("hardhat/config");
const fs = require('fs');
const fse = require('fs-extra');

const {
    TASK_NODE,
    TASK_COMPILE,
    TASK_RUN,
    TASK_TEST,
} = require('hardhat/builtin-tasks/task-names');
const {evmCheckpoint, evmRestore} = require("./sharedBeforeEach");
const {node_url} = require("../utils/network");
const {getNodeUrl} = require("./network");

task('deploy', 'deploy')
    .addFlag('noDeploy', 'Deploy contract|Upgrade proxy')
    .addFlag('setting', 'Run setting contract')
    .addFlag('impl', 'Deploy only implementation without upgradeTo')
    .setAction(async (args, hre) => {

        hre.ovn = {
            noDeploy: args.noDeploy,
            setting: args.setting,
            impl: args.impl
        }
        await hre.run('deploy:main', args);
    });


task(TASK_NODE, 'Starts a JSON-RPC server on top of Hardhat EVM')
    .addFlag('reset', 'Reset files')
    .addFlag('deploy', 'Run deploy')
    .addFlag('last', 'Use last block from RPC')
    .setAction(async (args, hre, runSuper) => {

        await fs.copyFile('.openzeppelin/unknown-137.json', '.openzeppelin/unknown-31337.json', (e) => {
            if (e)
                console.error(e)
        });

        const srcDir = `deployments/` + process.env.STAND;
        const destDir = `deployments/localhost`;

        await fse.copySync(srcDir, destDir, {overwrite: true}, function (err) {
            if (err)
                console.error(err);
        });

        await fs.writeFile('deployments/localhost/.chainId', '31337', function (err) {
            if (err) return console.log(err);
        });

        if (args.last) {

            let nodeUrl = getNodeUrl();
            const provider = new hre.ethers.providers.JsonRpcProvider(nodeUrl);
            let block = await provider.getBlockNumber() - 31;

            console.log('Set last block: ' + block);

            await hre.network.provider.request({
                method: "hardhat_reset",
                params: [
                    {
                        forking: {
                            jsonRpcUrl: nodeUrl,
                            blockNumber: block,
                        },
                    },
                ],
            })
        }

        if (args.deploy)
            args.noDeploy = false;
        else
            args.noDeploy = true;

        if (args.reset)
            args.noReset = false;
        else
            args.noReset = true;

        console.log('node', args);


        await runSuper(args);


    });


task(TASK_RUN, 'Run task')
    .addFlag('reset', 'Reset ')
    .setAction(async (args, hre, runSuper) => {


        if (args.reset)
            await evmCheckpoint('task', hre.network.provider);

        await runSuper(args);

        if (args.reset)
            await evmRestore('task', hre.network.provider);
    });


task(TASK_COMPILE, 'Compile')
    .setAction(async (args, hre, runSuper) => {

        args.quiet = true;

        await runSuper(args);

    });


task(TASK_TEST, 'test')
    .setAction(async (args, hre, runSuper) => {


        // enable full deploys
        hre.ovn = {
            impl: false,
            setting: true,
            noDeploy: false
        }

        await evmCheckpoint('task', hre.network.provider);

        await runSuper(args);

        await evmRestore('task', hre.network.provider);
    });
