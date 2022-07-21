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
    uint256 public constant INTEREST_RATE_MODE = 2;
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

    uint256 public liquidationThreshold;
    uint256 public healthFactor;
    uint256 public balancingDelta;
    uint256 public realHealthFactor;


    // method 0--nothing, 1--stake, 2--unstake
    struct Delta {
        uint256 aaveCollateralUsdNeeded;
        uint256 aaveBorrowUsdNeeded;
        uint256 poolUsdpUsdDelta;
        uint256 method;
        uint256 amount;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }

    //TODO: clean comments
    //    function setTokens(
    //        address _usdc,
    //        address _aUsdc,
    //        address _wmatic,
    //        address _usdPlus,
    //        address _penToken,
    //        address _dyst
    //    ) external onlyAdmin {
    //        usdc = IERC20(_usdc);
    //        aUsdc = IERC20(_aUsdc);
    //        wmatic = IERC20(_wmatic);
    //        usdcDm = 10 ** IERC20Metadata(_usdc).decimals();
    //        wmaticDm = 10 ** IERC20Metadata(_wmatic).decimals();
    //
    //        usdPlus = IERC20(_usdPlus);
    //        setAsset(_usdPlus);
    //
    //        penToken = IERC20(_penToken);
    //        dyst = IERC20(_dyst);
    //
    //    }
    //
    //
    //    function setParams(
    //        address _exchanger,
    //        address _dystRewards,
    //        address _dystVault,
    //        address _dystRouter,
    //        address _penProxy,
    //        address _penLens
    //    ) external onlyAdmin {
    //
    //        dystRewards = IDystopiaLP(_dystRewards);
    //        dystVault = IDystopiaLP(_dystVault);
    //        dystRouter = IDystopiaRouter(_dystRouter);
    //
    //        penProxy = IUserProxy(_penProxy);
    //        penLens = IPenLens(_penLens);
    //
    //        exchange = IExchange(_exchanger);
    //    }
    //
    //    function setAaveParams(
    //        address _aavePoolAddressesProvider,
    //        address _oracleUsdc,
    //        address _oracleWmatic,
    //        uint256 _liquidationThreshold,
    //        uint256 _healthFactor,
    //        uint256 _balancingDelta
    //    ) external onlyAdmin {
    //
    //        aavePoolAddressesProvider = IPoolAddressesProvider(_aavePoolAddressesProvider);
    //        oracleUsdc = IPriceFeed(_oracleUsdc);
    //        oracleWmatic = IPriceFeed(_oracleWmatic);
    //
    //        liquidationThreshold = _liquidationThreshold * 10 ** 15;
    //        healthFactor = _healthFactor * 10 ** 15;
    //        realHealthFactor = 0;
    //        balancingDelta = _balancingDelta * 10 ** 15;
    //    }

    function _stake(uint256 _amount) internal override {

        (uint256 caseNumber, uint256 aaveCollateralUsdNeeded, uint256 aaveBorrowUsdNeeded, uint256 poolUsdpUsdDelta) = getDeltas(1, _amount);

        console.log("stake case", caseNumber);

        Delta memory delta = Delta(
            aaveCollateralUsdNeeded,
            aaveBorrowUsdNeeded,
            poolUsdpUsdDelta, 1, _amount
        );

        if (caseNumber == 1) {
            this._caseNumber1(delta);
        }

        if (caseNumber == 2) {
            this._caseNumber2(delta);
        }

        if (caseNumber == 3) {
            this._caseNumber3(delta);
        }

        if (caseNumber == 4) {
            this._caseNumber4(delta);
        }

        if (caseNumber == 5) {
            this._caseNumber5(delta);
        }

        if (caseNumber == 6) {
            this._caseNumber6(delta);
        }

        // TODO: set realHealthFactor instead useless healthFactorCurrent
        (,,,,,uint256 healthFactorCurrent) = IPool(_aavePool()).getUserAccountData(address(this));
        realHealthFactor = healthFactorCurrent;
    }


    function _unstake(
        uint256 _amount
    ) internal override returns (uint256) {

        (uint256 caseNumber, uint256 aaveCollateralUsdNeeded, uint256 aaveBorrowUsdNeeded, uint256 poolUsdpUsdDelta) = getDeltas(2, _amount);

        console.log("unstake case", caseNumber);

        Delta memory delta = Delta(
            aaveCollateralUsdNeeded,
            aaveBorrowUsdNeeded,
            poolUsdpUsdDelta, 2, _amount
        );

        if (caseNumber == 1) {
            this._caseNumber1(delta);
        }

        if (caseNumber == 2) {
            this._caseNumber2(delta);
        }

        if (caseNumber == 3) {
            this._caseNumber3(delta);
        }

        if (caseNumber == 4) {
            this._caseNumber4(delta);
        }

        if (caseNumber == 5) {
            this._caseNumber5(delta);
        }

        if (caseNumber == 6) {
            this._caseNumber6(delta);
        }

        // TODO: set realHealthFactor instead useless healthFactorCurrent
        (,,,,,uint256 healthFactorCurrent) = IPool(_aavePool()).getUserAccountData(address(this));
        realHealthFactor = healthFactorCurrent;

        return _amount;
    }

    //TODO: remove underscore if public
    function _aavePool() public returns (IPool aavePool){
        aavePool = IPool(AaveBorrowLibrary.getAavePool(address(aavePoolAddressesProvider), E_MODE_CATEGORY_ID));
    }


    function balances() external view override returns (BalanceItem[] memory){

        // debt base (USD) convert to Wmatic amount
        //TODO: use _aavePool method if same
        (, uint256 debtBase,,,,) = IPool(AaveBorrowLibrary.getAavePool(address(aavePoolAddressesProvider))).getUserAccountData(address(this));
        uint256 aaveWmatic = AaveBorrowLibrary.convertUsdToTokenAmount(debtBase, wmaticDm, uint256(oracleWmatic.latestAnswer()));
        uint256 usdcWmatic = AaveBorrowLibrary.convertUsdToTokenAmount(debtBase, usdcDm, uint256(oracleUsdc.latestAnswer()));

        BalanceItem[] memory items = new BalanceItem[](4);
        items[0] = BalanceItem(address(wmatic), usdcWmatic, aaveWmatic, true);

        uint256 amountAusdc = aUsdc.balanceOf(address(this)) + usdc.balanceOf(address(this));
        items[1] = BalanceItem(address(aUsdc), amountAusdc, amountAusdc, false);

        (uint256 poolWmatic, uint256 poolUsdPlus) = this._getLiquidity();

        poolUsdPlus += usdPlus.balanceOf(address(this));

        usdcWmatic = AaveBorrowLibrary.convertTokenAmountToTokenAmount(
            poolWmatic,
            wmaticDm,
            usdcDm,
            uint256(oracleWmatic.latestAnswer()),
            uint256(oracleUsdc.latestAnswer())
        );

        items[2] = BalanceItem(address(wmatic), usdcWmatic, poolWmatic, false);
        items[3] = BalanceItem(address(usdPlus), poolUsdPlus, poolUsdPlus, false);

        return items;
    }


    function netAssetValue() external view override returns (uint256){


        (uint256 poolWmatic, uint256 poolUsdPlus) = this._getLiquidity();
        uint256 totalUsdPlus = poolUsdPlus + usdPlus.balanceOf(address(this));
        uint256 totalUsdc = usdc.balanceOf(address(this)) + aUsdc.balanceOf(address(this));


        // debt base (USD) convert to Wmatic amount
        (, uint256 debtBase,,,,) = IPool(AaveBorrowLibrary.getAavePool(address(aavePoolAddressesProvider))).getUserAccountData(address(this));
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
    }





    function _claimRewards(address _to) internal override returns (uint256){
       return this.claimRewards();
    }

    function _balance() internal override returns (uint256) {

        (uint256 caseNumber, uint256 aaveCollateralUsdNeeded, uint256 aaveBorrowUsdNeeded, uint256 poolUsdpUsdDelta) = getDeltas(0, 0);

        console.log("case", caseNumber);

        Delta memory delta = Delta(
            aaveCollateralUsdNeeded,
            aaveBorrowUsdNeeded,
            poolUsdpUsdDelta, 0, 0
        );

        //TODO: try to use readable enums and readable method names
        if (caseNumber == 1) {
            this._caseNumber1(delta);
        }

        if (caseNumber == 2) {
            this._caseNumber2(delta);
        }

        if (caseNumber == 3) {
            this._caseNumber3(delta);
        }

        if (caseNumber == 4) {
            this._caseNumber4(delta);
        }

        if (caseNumber == 5) {
            this._caseNumber5(delta);
        }

        if (caseNumber == 6) {
            this._caseNumber6(delta);
        }

        (,,,,,uint256 healthFactorCurrent) = IPool(_aavePool()).getUserAccountData(address(this));
        realHealthFactor = healthFactorCurrent;

        return healthFactorCurrent;
    }


    function currentHealthFactor() external view override returns (uint256){
        return realHealthFactor;
    }


    function getDeltas(uint256 method, uint256 amount) public view returns (uint256, uint256, uint256, uint256){
        //TODO: make getDeltas return Delta struct

        uint256 aaveCollateralPercent;
        uint256 aaveBorrowAndPoolMaticPercent;
        uint256 poolUsdpPercent;

        //TODO: may be extract to method
        {
            uint256 chainlinkUsdUsdc = uint256(oracleUsdc.latestAnswer());
            uint256 chainlinkUsdMatic = uint256(oracleWmatic.latestAnswer());
            (uint256 amount0Current, uint256 amount1Current,) = dystVault.getReserves();
            uint256 dystUsdpMatic = amount1Current * 10**20 / amount0Current;

            // console.log(chainlinkUsdUsdc);
            // console.log(chainlinkUsdMatic);
            // console.log(dystUsdpMatic);

            aaveCollateralPercent = (healthFactor * chainlinkUsdUsdc * chainlinkUsdMatic * 10 ** 18) / (healthFactor * chainlinkUsdUsdc * chainlinkUsdMatic + liquidationThreshold * dystUsdpMatic * 10 ** 8);
            aaveBorrowAndPoolMaticPercent = aaveCollateralPercent * liquidationThreshold / healthFactor;

            poolUsdpPercent = aaveBorrowAndPoolMaticPercent * dystUsdpMatic * 10 ** 8 / (chainlinkUsdUsdc * chainlinkUsdMatic);
        }

        // console.log("aaveCollateralPercent", aaveCollateralPercent);
        // console.log("aaveBorrowAndPoolMaticPercent", aaveBorrowAndPoolMaticPercent);
        // console.log("poolUsdpPercent", poolUsdpPercent);

        // TODO: use method _aavePool if same
        (uint256 aaveCollateralUsd, uint256 aaveBorrowUsd,,,,) = IPool(AaveBorrowLibrary.getAavePool(address(aavePoolAddressesProvider))).getUserAccountData(address(this));
        uint256 poolWmatic;
        uint256 poolUsdPlus;

        //TODO: extract to method
        {
            address userProxyThis = penLens.userProxyByAccount(address(this));
            address stakingAddress = penLens.stakingRewardsByDystPool(address(dystVault));
            uint256 balanceLp = IERC20(stakingAddress).balanceOf(userProxyThis);
            (poolWmatic, poolUsdPlus) = this._getLiquidityByLp(balanceLp);
        }

        // TODO: move definition to usage
        uint256 NAV;
        uint256 poolMaticUsd = AaveBorrowLibrary.convertTokenAmountToUsd(poolWmatic, wmaticDm, uint256(oracleWmatic.latestAnswer()));
        uint256 poolUsdpUsd = AaveBorrowLibrary.convertTokenAmountToUsd(poolUsdPlus, usdcDm, uint256(oracleUsdc.latestAnswer()));
        // console.log("aaveCollateralUsd", aaveCollateralUsd);
        // console.log("aaveBorrowUsd", aaveBorrowUsd);
        // console.log("poolMaticUsd", poolMaticUsd);
        // console.log("poolUsdpUsd", poolUsdpUsd);
        NAV = poolMaticUsd + poolUsdpUsd + aaveCollateralUsd - aaveBorrowUsd;

        if (method == 1) {
            NAV += amount;
        } else if (method == 2) {
            NAV -= amount;
        }
        // console.log("NAV", NAV);


        // console.log("aaveCollateralUsdNeeded", NAV*aaveCollateralPercent/10**18);
        // console.log("aaveBorrowUsdNeeded", NAV*aaveBorrowAndPoolMaticPercent/10**18);
        // console.log("poolMaticUsdNeeded", NAV*aaveBorrowAndPoolMaticPercent/10**18);
        // console.log("poolUsdpUsdNeeded", NAV*poolUsdpPercent/10**18);
        console.log("");
        // console.log("aaveCollateralUsdDelta", NAV*aaveCollateralPercent/10**18 - aaveCollateralUsd);
        // console.log("aaveBorrowUsdDelta", aaveBorrowUsd - NAV*aaveBorrowAndPoolMaticPercent/10**18);
        // console.log("poolMaticUsdDelta", poolMaticUsd - NAV*aaveBorrowAndPoolMaticPercent/10**18);
        // console.log("poolUsdpUsdDelta", poolUsdpUsd - NAV*poolUsdpPercent/10**18);
        // console.log("");

        //TODO: split by bracnches
        //TODO: add revert for unexpected branches
        //TODO: move computations out to vars or context struct for readability
        if (poolUsdpUsd > NAV*poolUsdpPercent/10**18 && aaveBorrowUsd > NAV*aaveBorrowAndPoolMaticPercent/10**18 && aaveCollateralUsd > NAV*aaveCollateralPercent/10**18) {
            return (1, aaveCollateralUsd - NAV*aaveCollateralPercent/10**18,
            aaveBorrowUsd - NAV*aaveBorrowAndPoolMaticPercent/10**18,
            poolUsdpUsd - NAV*poolUsdpPercent/10**18
            );
        } else if (aaveCollateralUsd > NAV*aaveCollateralPercent/10**18 && aaveBorrowUsd > NAV*aaveBorrowAndPoolMaticPercent/10**18 && NAV*poolUsdpPercent/10**18 > poolUsdpUsd){
            return (2, aaveCollateralUsd - NAV*aaveCollateralPercent/10**18,
            aaveBorrowUsd - NAV*aaveBorrowAndPoolMaticPercent/10**18,
            NAV*poolUsdpPercent/10**18 - poolUsdpUsd
            );
        } else if (aaveCollateralUsd > NAV*aaveCollateralPercent/10**18 && NAV*aaveBorrowAndPoolMaticPercent/10**18 > aaveBorrowUsd && NAV*poolUsdpPercent/10**18 > poolUsdpUsd) {
            return (3, aaveCollateralUsd - NAV*aaveCollateralPercent/10**18,
            NAV*aaveBorrowAndPoolMaticPercent/10**18 - aaveBorrowUsd,
            NAV*poolUsdpPercent/10**18 - poolUsdpUsd
            );
        } else if (NAV*aaveCollateralPercent/10**18 > aaveCollateralUsd && aaveBorrowUsd > NAV*aaveBorrowAndPoolMaticPercent/10**18 && poolUsdpUsd > NAV*poolUsdpPercent/10**18) {
            return (4, NAV*aaveCollateralPercent/10**18 - aaveCollateralUsd,
            aaveBorrowUsd - NAV*aaveBorrowAndPoolMaticPercent/10**18,
            poolUsdpUsd - NAV*poolUsdpPercent/10**18
            );
        } else if (NAV*aaveCollateralPercent/10**18 > aaveCollateralUsd && NAV*aaveBorrowAndPoolMaticPercent/10**18 > aaveBorrowUsd && poolUsdpUsd > NAV*poolUsdpPercent/10**18) {
            return (5, NAV*aaveCollateralPercent/10**18 - aaveCollateralUsd,
            NAV*aaveBorrowAndPoolMaticPercent/10**18 - aaveBorrowUsd,
            poolUsdpUsd - NAV*poolUsdpPercent/10**18
            );
        } else if (NAV*aaveCollateralPercent/10**18 > aaveCollateralUsd && NAV*aaveBorrowAndPoolMaticPercent/10**18 > aaveBorrowUsd && NAV*poolUsdpPercent/10**18 > poolUsdpUsd) {
            return (6, NAV*aaveCollateralPercent/10**18 - aaveCollateralUsd,
            NAV*aaveBorrowAndPoolMaticPercent/10**18 - aaveBorrowUsd,
            NAV*poolUsdpPercent/10**18 - poolUsdpUsd
            );
        }
    }
}
