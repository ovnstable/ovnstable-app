const {deployProxy} = require("../../../common/utils/deployProxy");

module.exports = async ({getNamedAccounts, deployments}) => {
    const {save} = deployments;

    await deployProxy('StrategyBeethovenxDeiUsdc', deployments, save);
};

module.exports.tags = ['base', 'StrategyBeethovenxDeiUsdc'];