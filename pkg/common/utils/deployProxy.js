const {ethers, upgrades} = require("hardhat");
const hre = require("hardhat");
const {getImplementationAddress} = require('@openzeppelin/upgrades-core');
const sampleModule = require('@openzeppelin/hardhat-upgrades/dist/utils/deploy-impl');
const fs = require('fs');


async function deployProxy(contractName, deployments, save, params) {
    return deployProxyMulti(contractName, contractName, deployments, save, params);
}

async function deployProxyMulti(contractName, factoryName, deployments, save, params) {

    let factoryOptions;
    let unsafeAllow;
    let args;
    if (params) {
        factoryOptions = params.factoryOptions;
        unsafeAllow = params.unsafeAllow;
        args = params.args;
    }

    const contractFactory = await ethers.getContractFactory(factoryName, factoryOptions);

    //await upgrades.forceImport('0x5AfF5fF3b0190EC73a956b3aAFE57C3b85d35b37', contractFactory, args, {
    //    kind: 'uups',
    //    unsafeAllow: unsafeAllow
    //});

    let proxy;
    try {
        proxy = await ethers.getContract(contractName);
    } catch (e) {
    }

    if (!proxy) {
        console.log(`Proxy ${contractName} not found`)
        proxy = await upgrades.deployProxy(contractFactory, args, {
            kind: 'uups',
            unsafeAllow: unsafeAllow
        });
        console.log(`Deploy ${contractName} Proxy progress -> ` + proxy.address + " tx: " + proxy.deployTransaction.hash);
        await proxy.deployTransaction.wait();
    } else {
        console.log(`Proxy ${contractName} found -> ` + proxy.address)
    }

    // set false for local testing
    let upgradeTo = process.env.DEPLOY_PROXY == "true" ? true : false;
    let impl;
    if (upgradeTo && (hre.ovn && !hre.ovn.impl)) {
        // Deploy a new implementation and upgradeProxy to new;
        // You need have permission for role UPGRADER_ROLE;

        try {
            impl = await upgrades.upgradeProxy(proxy, contractFactory, {unsafeAllow: unsafeAllow});
        } catch (e) {
            impl = await upgrades.upgradeProxy(proxy, contractFactory, {unsafeAllow: unsafeAllow});
        }
        const currentImplAddress = await getImplementationAddress(ethers.provider, proxy.address);
        console.log(`Deploy ${contractName} Impl  done -> proxy [` + proxy.address + "] impl [" + currentImplAddress + "]");
    } else {

        //Deploy only a new implementation without call upgradeTo
        //For system with Governance
        impl = await sampleModule.deployProxyImpl(hre, contractFactory, {
            kind: 'uups',
            unsafeAllow: unsafeAllow
        }, proxy.address);
        console.log('Deploy impl done without upgradeTo -> impl [' + impl.impl + "]");

    }


    if (impl && impl.deployTransaction)
        await impl.deployTransaction.wait();

    const artifact = await deployments.getExtendedArtifact(factoryName);
    let proxyDeployments = {
        address: proxy.address,
        ...artifact
    }

    await save(contractName, proxyDeployments);
    return proxyDeployments;
}


module.exports = {
    deployProxy: deployProxy,
    deployProxyMulti: deployProxyMulti,
};
