// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../connectors/dystopia/interfaces/IDystopiaRouter.sol";
import "../connectors/dystopia/interfaces/IDystopiaLP.sol";
import "../connectors/aave/interfaces/IPriceFeed.sol";
import "../connectors/aave/interfaces/IPool.sol";
import "../connectors/aave/interfaces/IPoolAddressesProvider.sol";
import "../connectors/penrose/interface/IUserProxy.sol";
import "../connectors/penrose/interface/IPenLens.sol";
import "../libraries/WadRayMath.sol";
import "../interfaces/IExchange.sol";
import "../core/HedgeStrategy.sol";

import {AaveBorrowLibrary} from "../libraries/AaveBorrowLibrary.sol";
import {OvnMath} from "../libraries/OvnMath.sol";
import {UsdPlusWmaticLibrary} from "./libraries/UsdPlusWmaticLibrary.sol";

import "hardhat/console.sol";

contract StrategyUsdPlusWmatic is HedgeStrategy {
    using WadRayMath for uint256;
    using UsdPlusWmaticLibrary for StrategyUsdPlusWmatic;

    uint8 public constant E_MODE_CATEGORY_ID = 0;
    uint256 public constant INTEREST_RATE_MODE = 2; // InterestRateMode.VARIABLE
    uint16 public constant REFERRAL_CODE = 0;
    uint256 public constant BASIS_POINTS_FOR_STORAGE = 100; // 1%
    uint256 public constant BASIS_POINTS_FOR_SLIPPAGE = 400; // 4%
    uint256 public constant MAX_UINT_VALUE = type(uint256).max;

    IExchange public exchange;

    IERC20 public usdPlus;
    IERC20 public usdc;
    IERC20 public aUsdc;
    IERC20 public wmatic;
    IERC20 public dyst;

    uint256 public usdcDm;
    uint256 public wmaticDm;

    IDystopiaRouter public dystRouter;
    IDystopiaLP public dystRewards;
    IDystopiaLP public dystVault;


    IERC20 public penToken;
    IUserProxy public penProxy;
    IPenLens public penLens;


    // Aave
    IPoolAddressesProvider public aavePoolAddressesProvider;
    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleWmatic;

    uint256 public usdcStorage;

    // in e18
    uint256 public liquidationThreshold;
    uint256 public healthFactor;
    uint256 public balancingDelta;
    uint256 public realHealthFactor;


    // method 0--nothing, 1--stake, 2--unstake
    struct BalanceContext {
        uint256 caseNumber;
        uint256 aaveCollateralUsdNeeded;
        uint256 aaveBorrowUsdNeeded;
        uint256 poolUsdpUsdDelta;
        Method method;
        uint256 amount;
    }

    enum Method {
        NOTHING,
        STAKE,
        UNSTAKE
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }

    function setTokens(
        address _usdc,
        address _aUsdc,
        address _wmatic,
        address _usdPlus,
        address _penToken,
        address _dyst
    ) external onlyAdmin {
        usdc = IERC20(_usdc);
        aUsdc = IERC20(_aUsdc);
        wmatic = IERC20(_wmatic);
        usdcDm = 10 ** IERC20Metadata(_usdc).decimals();
        wmaticDm = 10 ** IERC20Metadata(_wmatic).decimals();

        usdPlus = IERC20(_usdPlus);
        setAsset(_usdPlus);

        penToken = IERC20(_penToken);
        dyst = IERC20(_dyst);

    }


    function setParams(
        address _exchanger,
        address _dystRewards,
        address _dystVault,
        address _dystRouter,
        address _penProxy,
        address _penLens
    ) external onlyAdmin {

        dystRewards = IDystopiaLP(_dystRewards);
        dystVault = IDystopiaLP(_dystVault);
        dystRouter = IDystopiaRouter(_dystRouter);

        penProxy = IUserProxy(_penProxy);
        penLens = IPenLens(_penLens);

        exchange = IExchange(_exchanger);
    }

    function setAaveParams(
        address _aavePoolAddressesProvider,
        address _oracleUsdc,
        address _oracleWmatic,
        uint256 _liquidationThreshold,
        uint256 _healthFactor,
        uint256 _balancingDelta
    ) external onlyAdmin {

        aavePoolAddressesProvider = IPoolAddressesProvider(_aavePoolAddressesProvider);
        oracleUsdc = IPriceFeed(_oracleUsdc);
        oracleWmatic = IPriceFeed(_oracleWmatic);

        liquidationThreshold = _liquidationThreshold * 10 ** 15;
        healthFactor = _healthFactor * 10 ** 15;
        realHealthFactor = 0;
        balancingDelta = _balancingDelta * 10 ** 15;
    }

    function _stake(uint256 _amount) internal override {
        _updateEMode();

        BalanceContext memory ctx = makeContext(Method.STAKE, _amount);

        console.log("stake case", ctx.caseNumber);

        _execBalance(ctx);
    }


    function _unstake(
        uint256 _amount
    ) internal override returns (uint256) {
        _updateEMode();

        BalanceContext memory ctx = makeContext(Method.UNSTAKE, _amount);

        console.log("unstake case", ctx.caseNumber);

        _execBalance(ctx);

        return _amount;
    }

    function _execBalance(BalanceContext memory ctx) internal {
        //TODO: try to use readable enums and readable method names
        if (ctx.caseNumber == 1) {
            this._caseNumber1(ctx);
        } else if (ctx.caseNumber == 2) {
            this._caseNumber2(ctx);
        } else if (ctx.caseNumber == 3) {
            this._caseNumber3(ctx);
        } else if (ctx.caseNumber == 4) {
            this._caseNumber4(ctx);
        } else if (ctx.caseNumber == 5) {
            this._caseNumber5(ctx);
        } else if (ctx.caseNumber == 6) {
            this._caseNumber6(ctx);
        }

        (,,,,, realHealthFactor) = aavePool().getUserAccountData(address(this));

        console.log("realHealthFactor", realHealthFactor);

    }

    function aavePool() public view returns (IPool){
        return IPool(AaveBorrowLibrary.getAavePool(address(aavePoolAddressesProvider)));
    }

    function _updateEMode() internal {
        AaveBorrowLibrary.getAavePool(address(aavePoolAddressesProvider), E_MODE_CATEGORY_ID);
    }


    function balances() external view override returns (BalanceItem[] memory){

        // debt base (USD) convert to Wmatic amount
        (, uint256 debtBase,,,,) = aavePool().getUserAccountData(address(this));
        uint256 aaveWmatic = AaveBorrowLibrary.convertUsdToTokenAmount(debtBase, wmaticDm, uint256(oracleWmatic.latestAnswer()));
        uint256 aaveWmaticInUsdc = AaveBorrowLibrary.convertUsdToTokenAmount(debtBase, usdcDm, uint256(oracleUsdc.latestAnswer()));

        BalanceItem[] memory items = new BalanceItem[](4);
        items[0] = BalanceItem(address(wmatic), aaveWmaticInUsdc, aaveWmatic, true);

        uint256 amountAusdc = aUsdc.balanceOf(address(this)) + usdc.balanceOf(address(this));
        items[1] = BalanceItem(address(aUsdc), amountAusdc, amountAusdc, false);

        (uint256 poolWmatic, uint256 poolUsdPlus) = this._getLiquidity();

        poolUsdPlus += usdPlus.balanceOf(address(this));

        uint256 poolWmaticInUsdc = AaveBorrowLibrary.convertTokenAmountToTokenAmount(
            poolWmatic,
            wmaticDm,
            usdcDm,
            uint256(oracleWmatic.latestAnswer()),
            uint256(oracleUsdc.latestAnswer())
        );

        items[2] = BalanceItem(address(wmatic), poolWmaticInUsdc, poolWmatic, false);
        items[3] = BalanceItem(address(usdPlus), poolUsdPlus, poolUsdPlus, false);

        return items;
    }


    function netAssetValue() external view override returns (uint256){


        (uint256 poolWmatic, uint256 poolUsdPlus) = this._getLiquidity();
        uint256 totalUsdPlus = poolUsdPlus + usdPlus.balanceOf(address(this));
        uint256 totalUsdc = usdc.balanceOf(address(this)) + aUsdc.balanceOf(address(this));


        // debt base (USD) convert to Wmatic amount
        (, uint256 debtBase,,,,) = aavePool().getUserAccountData(address(this));
        uint256 aaveWmatic = AaveBorrowLibrary.convertUsdToTokenAmount(debtBase, wmaticDm, uint256(oracleWmatic.latestAnswer()));

        if (aaveWmatic < poolWmatic) {
            uint256 deltaWmatic = poolWmatic - aaveWmatic;
            totalUsdc += AaveBorrowLibrary.convertTokenAmountToTokenAmount(
                deltaWmatic,
                wmaticDm,
                usdcDm,
                uint256(oracleWmatic.latestAnswer()),
                uint256(oracleUsdc.latestAnswer())
            );

        } else {
            uint256 deltaWmatic = aaveWmatic - poolWmatic;
            totalUsdc -= AaveBorrowLibrary.convertTokenAmountToTokenAmount(
                deltaWmatic,
                wmaticDm,
                usdcDm,
                uint256(oracleWmatic.latestAnswer()),
                uint256(oracleUsdc.latestAnswer())
            );
        }

        return totalUsdPlus + totalUsdc;

        // TODO: back later to choose right way
//        (
//        uint256 aaveCollateralUsdc,
//        uint256 aaveBorrowUsdc,
//        uint256 poolMaticUsdc,
//        uint256 poolUsdpUsdc
//        ) = currentLiquidity();
//
//        uint256 NAV = poolMaticUsdc + poolUsdpUsdc + aaveCollateralUsdc - aaveBorrowUsdc;
//
//        uint256 usdPlusBalance = usdPlus.balanceOf(address(this));
//        uint256 usdcBalance = usdc.balanceOf(address(this));
//        uint256 aUsdcBalance = aUsdc.balanceOf(address(this));
//        uint256 wmaticBalance = wmatic.balanceOf(address(this));
//
//        uint256 wmaticBalanceUsd = AaveBorrowLibrary.convertTokenAmountToUsd(wmaticBalance, wmaticDm, uint256(oracleWmatic.latestAnswer()));
//        uint256 wmaticBalanceUsdc = wmaticBalanceUsd / 100;
//
//
//        console.log("----------------- netAssetValue");
//        console.log("usdPlusBalance       ", usdPlusBalance);
//        console.log("usdcBalance          ", usdcBalance);
//        console.log("aUsdcBalance         ", aUsdcBalance);
//        console.log("wmaticBalance        ", wmaticBalance);
//        console.log("wmaticBalanceUsdc    ", wmaticBalanceUsdc);
//        console.log("aaveCollateralUsdc   ", aaveCollateralUsdc);
//        console.log("aaveBorrowUsdc       ", aaveBorrowUsdc);
//        console.log("poolMaticUsdc        ", poolMaticUsdc);
//        console.log("poolUsdpUsdc         ", poolUsdpUsdc);
//        console.log("-----------------");
//        return NAV + usdPlusBalance + usdcBalance + wmaticBalanceUsdc;

    }


    function _claimRewards(address _to) internal override returns (uint256){
        //FIXME: recursion? rename method in lib
        return this.claimRewards();
    }

    function _balance() internal override returns (uint256) {
        _updateEMode();

        BalanceContext memory ctx = makeContext(Method.NOTHING, 0);

        console.log("case", ctx.caseNumber);

        _execBalance(ctx);

        return realHealthFactor;
    }


    function currentHealthFactor() external view override returns (uint256){
        return realHealthFactor;
    }

    /**
     * Current price in dyst pool with e+2
     */
    function priceInDystUsdpMaticPool() internal view returns (uint256){
        // on another pools tokens order may be another and calc price in pool should changed
        (uint256 amount0Current, uint256 amount1Current,) = dystVault.getReserves();
        // 10^20 because of 10^18 plus additional 2 digits to be comparable to USD price from oracles
        return amount1Current * 10 ** 20 / amount0Current;
    }

    /**
     * Calculate needed distribution. Returns shares in e18
     */
    function calcDistribution() internal view returns (uint256, uint256, uint256){

        // e+2
        uint256 priceUsdcInUsd = uint256(oracleUsdc.latestAnswer());
        uint256 priceMaticInUsd = uint256(oracleWmatic.latestAnswer());
        uint256 priceInDystUsdpMaticPoolInUsd = priceInDystUsdpMaticPool();

        console.log("----------------- calcPercents()");
        console.log("priceUsdcInUsd                 ", priceUsdcInUsd);
        console.log("priceMaticInUsd                ", priceMaticInUsd);
        console.log("priceInDystUsdpMaticPoolInUsd  ", priceInDystUsdpMaticPoolInUsd);
        console.log("-----------------");
        console.log("healthFactor                   ", healthFactor);
        console.log("liquidationThreshold           ", liquidationThreshold);
        console.log("-----------------");

        //TODO: calc digits, is percent with extra 2 digits?
        // 18 + 8 + 8 + 18 => 52
        // 18 + 8 + 8 => 34
        // 18 + 8 + 8 = 34
        // 52 - 34 = 18
        uint256 aaveCollateralPercent = (healthFactor * priceUsdcInUsd * priceMaticInUsd * 10 ** 18)
        / (
        healthFactor * priceUsdcInUsd * priceMaticInUsd +
        liquidationThreshold * priceInDystUsdpMaticPoolInUsd * 10 ** 8
        );
        // 18 + 18 - 18 = 18
        uint256 aaveBorrowAndPoolMaticPercent = aaveCollateralPercent * liquidationThreshold / healthFactor;
        // 18 + 8 + 8 - 8 - 8 = 18
        uint256 poolUsdpPercent = aaveBorrowAndPoolMaticPercent * priceInDystUsdpMaticPoolInUsd * 10 ** 8 / (priceUsdcInUsd * priceMaticInUsd);

        console.log("aaveCollateralPercent          ", aaveCollateralPercent);
        console.log("aaveBorrowAndPoolMaticPercent  ", aaveBorrowAndPoolMaticPercent);
        console.log("poolUsdpPercent                ", poolUsdpPercent);
        console.log("-----------------");

        return (
        aaveCollateralPercent,
        aaveBorrowAndPoolMaticPercent,
        poolUsdpPercent
        );
    }

    /**
     * Get current liquidity in USDC e6
     */
    function currentLiquidity() internal view returns (uint256, uint256, uint256, uint256){

        (uint256 poolWmatic,  uint256 poolUsdPlus) = this._getLiquidity();

        uint256 poolMaticUsd = AaveBorrowLibrary.convertTokenAmountToUsd(poolWmatic, wmaticDm, uint256(oracleWmatic.latestAnswer()));
        uint256 poolUsdpUsd = AaveBorrowLibrary.convertTokenAmountToUsd(poolUsdPlus, usdcDm, uint256(oracleUsdc.latestAnswer()));

        // E6+2
        (uint256 aaveCollateralUsd, uint256 aaveBorrowUsd,,,,) = aavePool().getUserAccountData(address(this));

        console.log("----------------- currentLiquidity()");
        console.log("aaveCollateralUsd ", aaveCollateralUsd);
        console.log("aaveBorrowUsd     ", aaveBorrowUsd);
        console.log("poolMaticUsd      ", poolMaticUsd);
        console.log("poolUsdpUsd       ", poolUsdpUsd);
        console.log("-----------------");

        //TODO: add free wmatic calc amount

        return (
        aaveCollateralUsd / 100,
        aaveBorrowUsd / 100,
        poolMaticUsd / 100,
        poolUsdpUsd / 100
        );
    }

    /**
     * Get expected liquidity distribution in USD e+2
     */
    function expectedLiquidity(uint256 nav) internal view returns (uint256, uint256, uint256){

        (
        uint256 aaveCollateralPercent,
        uint256 aaveBorrowAndPoolMaticPercent,
        uint256 poolUsdpPercent
        ) = calcDistribution();

        uint256 __poolUsdpNew = nav * poolUsdpPercent / 10 ** 18;
        uint256 __aaveBorrowAndPoolMaticNew = nav * aaveBorrowAndPoolMaticPercent / 10 ** 18;
        uint256 __aaveCollateralNew = nav * aaveCollateralPercent / 10 ** 18;

        console.log("-----------------");
        console.log("aaveCollateralUsdNeeded ", __aaveCollateralNew);
        console.log("aaveBorrowUsdNeeded     ", __aaveBorrowAndPoolMaticNew);
        console.log("poolMaticUsdNeeded      ", __aaveBorrowAndPoolMaticNew);
        console.log("poolUsdpUsdNeeded       ", __poolUsdpNew);
        console.log("-----------------");

        return (
        __aaveCollateralNew,
        __aaveBorrowAndPoolMaticNew,
        __poolUsdpNew
        );
    }


    function makeContext(Method method, uint256 amount) public view returns (BalanceContext memory ctx){

        (
        uint256 aaveCollateralUsdc,
        uint256 aaveBorrowUsdc,
        uint256 poolMaticUsdc,
        uint256 poolUsdpUsdc
        ) = currentLiquidity();

        uint256 NAV = poolMaticUsdc + poolUsdpUsdc + aaveCollateralUsdc - aaveBorrowUsdc;

        // correct NAV by stake/unstake amount
        if (method == Method.STAKE) {
            NAV += amount;
        } else if (method == Method.UNSTAKE) {
            require(NAV >= amount, "Not enough NAV for payback");
            NAV -= amount;
        }
        console.log("NAV              ", NAV);

        (
        uint256 __aaveCollateralNew,
        uint256 __aaveBorrowAndPoolMaticNew,
        uint256 __poolUsdpNew
        ) = expectedLiquidity(NAV);

        // prepare context variable
        ctx = BalanceContext(
            0,
            0,
            0,
            0,
            method,
            amount
        );

        // set cases and deltas
        if (aaveCollateralUsdc > __aaveCollateralNew) {
            if (aaveBorrowUsdc > __aaveBorrowAndPoolMaticNew) {
                if (poolUsdpUsdc > __poolUsdpNew) {
                    ctx.caseNumber = 1;
                    ctx.poolUsdpUsdDelta = poolUsdpUsdc - __poolUsdpNew;
                    ctx.aaveBorrowUsdNeeded = aaveBorrowUsdc - __aaveBorrowAndPoolMaticNew;
                    ctx.aaveCollateralUsdNeeded = aaveCollateralUsdc - __aaveCollateralNew;
                } else {
                    ctx.caseNumber = 2;
                    ctx.poolUsdpUsdDelta = __poolUsdpNew - poolUsdpUsdc;
                    ctx.aaveBorrowUsdNeeded = aaveBorrowUsdc - __aaveBorrowAndPoolMaticNew;
                    ctx.aaveCollateralUsdNeeded = aaveCollateralUsdc - __aaveCollateralNew;
                }
            } else {
                if (poolUsdpUsdc > __poolUsdpNew) {
                    revert("Unpredictable case -1");
                } else {
                    ctx.caseNumber = 1;
                    ctx.poolUsdpUsdDelta = __poolUsdpNew - poolUsdpUsdc;
                    ctx.aaveBorrowUsdNeeded = __aaveBorrowAndPoolMaticNew - aaveBorrowUsdc;
                    ctx.aaveCollateralUsdNeeded = aaveCollateralUsdc - __aaveCollateralNew;
                }
            }
        } else {
            if (aaveBorrowUsdc > __aaveBorrowAndPoolMaticNew) {
                if (poolUsdpUsdc > __poolUsdpNew) {
                    ctx.caseNumber = 4;
                    ctx.poolUsdpUsdDelta = poolUsdpUsdc - __poolUsdpNew;
                    ctx.aaveBorrowUsdNeeded = aaveBorrowUsdc - __aaveBorrowAndPoolMaticNew;
                    ctx.aaveCollateralUsdNeeded = __aaveCollateralNew - aaveCollateralUsdc;
                } else {
                    revert("Unpredictable case -2");
                }
            } else {
                if (poolUsdpUsdc > __poolUsdpNew) {
                    ctx.caseNumber = 5;
                    ctx.poolUsdpUsdDelta = poolUsdpUsdc - __poolUsdpNew;
                    ctx.aaveBorrowUsdNeeded = __aaveBorrowAndPoolMaticNew - aaveBorrowUsdc;
                    ctx.aaveCollateralUsdNeeded = __aaveCollateralNew - aaveCollateralUsdc;
                } else {
                    ctx.caseNumber = 6;
                    ctx.poolUsdpUsdDelta = __poolUsdpNew - poolUsdpUsdc;
                    ctx.aaveBorrowUsdNeeded = __aaveBorrowAndPoolMaticNew - aaveBorrowUsdc;
                    ctx.aaveCollateralUsdNeeded = __aaveCollateralNew - aaveCollateralUsdc;
                }
            }
        }

        console.log("ctx.caseNumber", ctx.caseNumber);
        console.log("ctx.poolUsdpUsdDelta        ", ctx.poolUsdpUsdDelta);
        console.log("ctx.aaveBorrowUsdNeeded     ", ctx.aaveBorrowUsdNeeded);
        console.log("ctx.aaveCollateralUsdNeeded ", ctx.aaveCollateralUsdNeeded);
        console.log("-----------------");

    }
}
