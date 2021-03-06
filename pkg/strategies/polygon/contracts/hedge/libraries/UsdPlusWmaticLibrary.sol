pragma solidity ^0.8.0;

import "../StrategyUsdPlusWmatic.sol";
import "../../libraries/AaveBorrowLibrary.sol";
import "../../connectors/dystopia/interfaces/IDystopiaLP.sol";
import "../../connectors/dystopia/interfaces/IDystopiaRouter.sol";
import {OvnMath} from "../../libraries/OvnMath.sol";
import {DystopiaLibrary} from "../../libraries/DystopiaLibrary.sol";

import "hardhat/console.sol";

library UsdPlusWmaticLibrary {


    function _addLiquidity(StrategyUsdPlusWmatic self, uint256 wmaticAmount, uint256 usdPlusAmount) public {

        self.usdPlus().approve(address(self.dystRouter()), type(uint256).max);
        self.wmatic().approve(address(self.dystRouter()), wmaticAmount);

        self.dystRouter().addLiquidity(
            address(self.wmatic()),
            address(self.usdPlus()),
            false,
            wmaticAmount,
            usdPlusAmount,
            (wmaticAmount < 10000) ? 0 : (OvnMath.subBasisPoints(wmaticAmount, self.BASIS_POINTS_FOR_SLIPPAGE())),
            (usdPlusAmount < 10000) ? 0 : (OvnMath.subBasisPoints(usdPlusAmount, self.BASIS_POINTS_FOR_SLIPPAGE())),
            address(self),
            block.timestamp + 600
        );


        uint256 lpTokenBalance = self.dystVault().balanceOf(address(self));
        self.dystVault().approve(address(self.penProxy()), lpTokenBalance);
        self.penProxy().depositLpAndStake(address(self.dystVault()), lpTokenBalance);
    }

    function _aavePool(StrategyUsdPlusWmatic self) public returns (IPool aavePool){
        aavePool = IPool(AaveBorrowLibrary.getAavePool(address(self.aavePoolAddressesProvider()), self.E_MODE_CATEGORY_ID()));
    }


    function _removeLiquidity(StrategyUsdPlusWmatic self, uint256 amountLp) public returns (uint256 amountWmatic, uint256 amountUsdPlus) {

        (uint256 amountLiq0, uint256 amountLiq1) = _getLiquidityByLp(self, amountLp);
        (amountWmatic, amountUsdPlus) = self.dystRouter().removeLiquidity(
            address(self.wmatic()),
            address(self.usdPlus()),
            false,
            amountLp,
            (amountLiq0 == 0) ? 0 : OvnMath.subBasisPoints(amountLiq0, self.BASIS_POINTS_FOR_SLIPPAGE()),
            (amountLiq1 == 0) ? 0 : OvnMath.subBasisPoints(amountLiq1, self.BASIS_POINTS_FOR_SLIPPAGE()),
            address(self),
            block.timestamp + 600
        );

    }


    function _getLiquidityForToken(StrategyUsdPlusWmatic self, uint256 token0Borrow) public view returns (uint256) {
        (uint256 amount0, uint256 amount1,) = self.dystVault().getReserves();
        uint256 amountLp = token0Borrow * self.dystVault().totalSupply() / amount0;
        return amountLp;
    }


    function _convertTokensToUsdPlus(StrategyUsdPlusWmatic self) public {

        IERC20 wmatic = self.wmatic();
        IERC20 usdc = self.usdc();
        IERC20 usdPlus = self.usdPlus();

        if (wmatic.balanceOf(address(self)) > 0) {
            DystopiaLibrary._swap(
                self.dystRouter(),
                address(wmatic),
                address(usdPlus),
                false,
                wmatic.balanceOf(address(self)),
                address(self)
            );
        }

        usdc.approve(address(self.exchange()), usdc.balanceOf(address(self)));
        self.exchange().buy(address(usdc), usdc.balanceOf(address(self)));
    }


    function _getAmountToken0(
        StrategyUsdPlusWmatic self,
        uint256 amount0Total,
        uint256 reserve0,
        uint256 reserve1,
        uint256 denominator0,
        uint256 denominator1,
        uint256 precision,
        address token0,
        address token1
    ) public view returns (uint256) {
        uint256 amount0 = (amount0Total * reserve1) / (reserve0 * denominator1 / denominator0 + reserve1);
        for (uint i = 0; i < precision; i++) {
            uint256 amount1 = DystopiaLibrary._getAmountOut(self.dystRouter(), token0, token1, false, amount0);
            amount0 = (amount0Total * reserve1) / (reserve0 * amount1 / amount0 + reserve1);
        }

        return amount0;
    }

    function _getLiquidity(StrategyUsdPlusWmatic self) public view returns (uint256, uint256){

        address userProxyThis = self.penLens().userProxyByAccount(address(self));
        address stakingAddress = self.penLens().stakingRewardsByDystPool(address(self.dystVault()));
        uint256 balanceLp = IERC20(stakingAddress).balanceOf(userProxyThis);

        return _getLiquidityByLp(self, balanceLp);
    }

    function _getLiquidityByLp(StrategyUsdPlusWmatic self, uint256 balanceLp) public view returns (uint256, uint256){

        (uint256 amount0Current, uint256 amount1Current,) = self.dystVault().getReserves();

        uint256 amountLiq0 = amount0Current * balanceLp / self.dystVault().totalSupply();
        uint256 amountLiq1 = amount1Current * balanceLp / self.dystVault().totalSupply();
        return (amountLiq0, amountLiq1);
    }

    function _getAmountLpTokensToWithdraw(
        StrategyUsdPlusWmatic self,
        uint256 amount0Total,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalLpBalance,
        uint256 denominator0,
        uint256 denominator1,
        address token0,
        address token1
    ) public view returns (uint256) {
        uint256 lpBalance = (totalLpBalance * amount0Total * denominator1) / (reserve0 * denominator1 + reserve1 * denominator0);
        uint256 amount1 = reserve1 * lpBalance / totalLpBalance;

        IDystopiaRouter.Route[] memory route = new IDystopiaRouter.Route[](2);
        route[0].from = token1;
        route[0].to = token0;
        route[0].stable = true;
        uint256 amount0 = self.dystRouter().getAmountsOut(amount1, route)[2];

        lpBalance = (totalLpBalance * amount0Total * amount1) / (reserve0 * amount1 + reserve1 * amount0);

        return lpBalance;
    }


    function _pushAllUsdpToPool(StrategyUsdPlusWmatic self, StrategyUsdPlusWmatic.Delta memory delta) public {

        IERC20 usdPlus = self.usdPlus();
        IERC20 wmatic = self.wmatic();

        (uint256 amount0Current, uint256 amount1Current,) = self.dystVault().getReserves();

        uint256 allowedAmount = usdPlus.balanceOf(address(self)) - (delta.method == 2 ? delta.amount : 0);
        console.log("allowedAmount", allowedAmount);
        uint256 amountUsdcToSwap = _getAmountToken0(
            self,
            allowedAmount,
            amount1Current,
            amount0Current,
            self.usdcDm(),
            self.wmaticDm(),
            1,
            address(usdPlus),
            address(wmatic)
        );

        DystopiaLibrary._swap(
            self.dystRouter(),
            address(usdPlus),
            address(wmatic),
            false,
            amountUsdcToSwap,
            address(self));

        uint256 usdPlusAmount = usdPlus.balanceOf(address(self)) - (delta.method == 2 ? delta.amount : 0);
        uint256 wmaticAmount = wmatic.balanceOf(address(self));

        _addLiquidity(self, wmaticAmount, usdPlusAmount);
    }

    function _removeLiq(StrategyUsdPlusWmatic self, StrategyUsdPlusWmatic.Delta memory delta) public {
        delta.poolUsdpUsdDelta = AaveBorrowLibrary.convertUsdToTokenAmount(delta.poolUsdpUsdDelta, self.usdcDm(), uint256(self.oracleUsdc().latestAnswer()));
        IPool aave = _aavePool(self);

        {
            address userProxyThis = self.penLens().userProxyByAccount(address(self));
            address stakingAddress = self.penLens().stakingRewardsByDystPool(address(self.dystVault()));
            uint256 balanceLp = IERC20(stakingAddress).balanceOf(userProxyThis);
            (, uint256 poolUsdPlus) = _getLiquidityByLp(self, balanceLp);
            uint256 lpforusdp = delta.poolUsdpUsdDelta * balanceLp / poolUsdPlus;

            self.penProxy().unstakeLpAndWithdraw(address(self.dystVault()), lpforusdp);
            self.dystVault().approve(address(self.dystRouter()), lpforusdp);
            _removeLiquidity(self, lpforusdp);
        }
    }

    function _repayAllWmatic(StrategyUsdPlusWmatic self) public {
        self.wmatic().approve(address(_aavePool(self)), self.wmatic().balanceOf(address(self)));
        _aavePool(self).repay(address(self.wmatic()), self.wmatic().balanceOf(address(self)), self.INTEREST_RATE_MODE(), address(self));
    }

    function _withdrawNeededUsdcInUsd(StrategyUsdPlusWmatic self, StrategyUsdPlusWmatic.Delta memory delta) public {
        uint256 aaveUsdc = AaveBorrowLibrary.convertUsdToTokenAmount(delta.aaveCollateralUsdNeeded, self.usdcDm(), uint256(self.oracleUsdc().latestAnswer()));
        _aavePool(self).withdraw(address(self.usdc()), aaveUsdc, address(self));
    }

    function _supplyCurrentUsdcAmount(StrategyUsdPlusWmatic self, StrategyUsdPlusWmatic.Delta memory delta, uint256 amount) public {
        self.usdc().approve(address(_aavePool(self)), amount);
        _aavePool(self).supply(address(self.usdc()), amount, address(this), self.REFERRAL_CODE());

    }

    function _borrowNeededWmatic(StrategyUsdPlusWmatic self, StrategyUsdPlusWmatic.Delta memory delta) public {
        uint256 aaveMatic = AaveBorrowLibrary.convertUsdToTokenAmount(delta.aaveBorrowUsdNeeded, self.wmaticDm(), uint256(self.oracleWmatic().latestAnswer()));
        _aavePool(self).borrow(address(self.wmatic()), aaveMatic, self.INTEREST_RATE_MODE(), self.REFERRAL_CODE(), address(self));
    }

    function _swapUspPlusToToken(StrategyUsdPlusWmatic self, StrategyUsdPlusWmatic.Delta memory delta, address _to, uint256 amount, bool stable) public {
        DystopiaLibrary._swap(
            self.dystRouter(),
            address(self.usdPlus()),
            _to,
            stable,
            amount,
            address(self));
    }

    function _swapUsdcToWmatic(StrategyUsdPlusWmatic self, StrategyUsdPlusWmatic.Delta memory delta, uint256 amount) public {
        DystopiaLibrary._swap(
            self.dystRouter(),
            address(self.usdc()),
            address(self.wmatic()),
            false,
            amount,
            address(self));
    }

    function _caseNumber1(StrategyUsdPlusWmatic self, StrategyUsdPlusWmatic.Delta memory delta) public {

        _removeLiq(self, delta);
        _withdrawNeededUsdcInUsd(self, delta);

        _convertTokensToUsdPlus(self);

        _swapUspPlusToToken(self, delta, address(self.wmatic()), self.usdPlus().balanceOf(address(self)) - (delta.method == 2 ? delta.amount : 0), false);
        _repayAllWmatic(self);
    }

    function _caseNumber2(StrategyUsdPlusWmatic self, StrategyUsdPlusWmatic.Delta memory delta) public {

        _withdrawNeededUsdcInUsd(self, delta);

        _convertTokensToUsdPlus(self);

        _swapUsdcToWmatic(self, delta, delta.aaveBorrowUsdNeeded / 100);
        _repayAllWmatic(self);
        _pushAllUsdpToPool(self, delta);
    }


    function _caseNumber3(StrategyUsdPlusWmatic self, StrategyUsdPlusWmatic.Delta memory delta) public {

        _withdrawNeededUsdcInUsd(self, delta);
        _borrowNeededWmatic(self, delta);

        _convertTokensToUsdPlus(self);

        _pushAllUsdpToPool(self, delta);
    }

    function _caseNumber4(StrategyUsdPlusWmatic self, StrategyUsdPlusWmatic.Delta memory delta) public {

        _removeLiq(self, delta);

        _convertTokensToUsdPlus(self);

        _swapUspPlusToToken(self, delta, address(self.usdc()), self.usdPlus().balanceOf(address(self)) - (delta.method == 2 ? delta.amount : 0), true);
        _supplyCurrentUsdcAmount(self, delta, delta.aaveCollateralUsdNeeded / 100);
        _swapUsdcToWmatic(self, delta, self.usdc().balanceOf(address(self)));

        _repayAllWmatic(self);
    }


    function _caseNumber5(StrategyUsdPlusWmatic self, StrategyUsdPlusWmatic.Delta memory delta) public {

        _removeLiq(self, delta);
        _borrowNeededWmatic(self, delta);

        _convertTokensToUsdPlus(self);

        _swapUspPlusToToken(self, delta, address(self.usdc()), self.usdPlus().balanceOf(address(self)) - (delta.method == 2 ? delta.amount : 0), true);
        _supplyCurrentUsdcAmount(self, delta, self.usdc().balanceOf(address(self)));
    }


    function _caseNumber6(StrategyUsdPlusWmatic self, StrategyUsdPlusWmatic.Delta memory delta) public {

        _borrowNeededWmatic(self, delta);

        _convertTokensToUsdPlus(self);

        _swapUspPlusToToken(self, delta, address(self.usdc()), delta.aaveCollateralUsdNeeded / 100, true);
        _supplyCurrentUsdcAmount(self, delta, self.usdc().balanceOf(address(self)));
        _pushAllUsdpToPool(self, delta);
    }


    function claimRewards(StrategyUsdPlusWmatic self) public returns (uint256){

        // claim rewards
        self.penProxy().claimStakingRewards();

        // sell rewards
        uint256 totalUsdc = 0;

        uint256 dystBalance = self.dyst().balanceOf(address(self));
        if (dystBalance > 0) {
            uint256 dystUsdc = DystopiaLibrary._swapExactTokensForTokens(
                self.dystRouter(),
                address(self.dyst()),
                address(self.wmatic()),
                address(self.usdPlus()),
                false,
                false,
                dystBalance,
                address(self)
            );
            totalUsdc += dystUsdc;
        }

        uint256 penBalance = self.penToken().balanceOf(address(self));
        if (penBalance > 0) {
            uint256 penUsdc = DystopiaLibrary._swapExactTokensForTokens(
                self.dystRouter(),
                address(self.penToken()),
                address(self.wmatic()),
                address(self.usdPlus()),
                false,
                false,
                penBalance,
                address(self)
            );
            totalUsdc += penUsdc;
        }

        return totalUsdc;
    }

}
