const BigNumber = require('bignumber.js');



function toE18(value){
    return new BigNumber(value).times(new BigNumber(10).pow(18)).toFixed(0)

}

function fromE18(value){
    return new BigNumber(value).div(new BigNumber(10).pow(18)).toFixed(4)
}

function toE6(value){
    return value * 10 ** 6;
}

function fromE6(value){
    return  value / 10 ** 6;
}

function toAsset(value){
    if (process.env.ETH_NETWORK === 'BSC'){
        return toE18(value);
    }else {
        return toE6(value);
    }
}

function fromAsset(value){
    if (process.env.ETH_NETWORK === 'BSC'){
        return fromE18(value);
    }else {
        return fromE6(value);
    }
}

module.exports = {

    toE18: toE18,
    fromE18: fromE18,

    toE6: toE6,
    fromE6: fromE6,

    toAsset:toAsset,
    fromAsset: fromAsset,
}
