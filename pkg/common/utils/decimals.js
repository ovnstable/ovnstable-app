const BigNumber = require('bignumber.js');

module.exports = {

    toE18: (value) => new BigNumber(value.toString()).times(new BigNumber(10).pow(18)).toFixed(),
    fromE18: (value) => new BigNumber(value.toString()).div(new BigNumber(10).pow(18)).toFixed(),

    toE6: (value) => value * 10 ** 6,
    fromE6: (value) => value / 10 ** 6,

    toUSDC: (value) => value * 10 ** 6,
    fromUSDC: (value) => value / 10 ** 6,

    toOvn: (value) => value * 10 ** 6,
    fromOvn: (value) => value / 10 ** 6,

    toOvnGov: (value) => value * 10 ** 18,
    fromOvnGov: (value) => value / 10 ** 18

}
