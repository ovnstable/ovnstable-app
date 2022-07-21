const {POLYGON} = require('@overnight-contracts/common/utils/assets');
const {strategyTest} = require('@overnight-contracts/common/utils/strategy-hedge-test');
let id = process.env.TEST_STRATEGY;

let arrays = [

    {
        name: 'StrategyUsdPlusWmatic',
        enabledReward: false,
        isRunStrategyLogic: false,
    },

];


if (id !== undefined && id !== "") {
    console.log(`Strategy ID ${id}`);
    arrays = arrays.filter(value => value.name === id);
}

console.log(`Run tests [${arrays.map(value => value.name)}]`);


describe("Polygon", function () {

    arrays.forEach(value => {
        strategyTest(value, 'POLYGON', POLYGON.usdPlus, ()=>{});
    })
});
