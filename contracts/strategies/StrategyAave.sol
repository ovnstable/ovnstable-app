// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./Strategy.sol";
import "../connectors/aave/interfaces/ILendingPoolAddressesProvider.sol";
import "../connectors/aave/interfaces/ILendingPool.sol";


contract StrategyAave is Strategy {

    IERC20 public usdcToken;
    IERC20 public aUsdcToken;

    ILendingPoolAddressesProvider public aaveProvider;


    // --- events

    event StrategyAaveUpdatedTokens(address usdcToken, address aUsdcToken);

    event StrategyAaveUpdatedParams(address aaveProvider);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _aUsdcToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_aUsdcToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        aUsdcToken = IERC20(_aUsdcToken);

        emit StrategyAaveUpdatedTokens(_usdcToken, _aUsdcToken);
    }

    function setParams(
        address _aaveProvider
    ) external onlyAdmin {

        require(_aaveProvider != address(0), "Zero address not allowed");

        aaveProvider = ILendingPoolAddressesProvider(_aaveProvider);

        emit StrategyAaveUpdatedParams(_aaveProvider);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {
        require(_asset == address(usdcToken), "Some token not compatible");

        ILendingPool pool = ILendingPool(aaveProvider.getLendingPool());
        usdcToken.approve(address(pool), _amount);

        SwapInfo memory swapInfo = _logExchangeStart(usdcToken, aUsdcToken);
        pool.deposit(address(usdcToken), _amount, address(this), 0);
        _logExchangeEnd(swapInfo, address(pool), 'deposit');
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        ILendingPool pool = ILendingPool(aaveProvider.getLendingPool());
        aUsdcToken.approve(address(pool), _amount);

        SwapInfo memory swapInfo = _logExchangeStart(usdcToken, aUsdcToken);
        uint256 withdrawAmount = pool.withdraw(_asset, _amount, address(this));
        _logExchangeEnd(swapInfo, address(pool), 'withdraw');
        return withdrawAmount;
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 _amount = aUsdcToken.balanceOf(address(this));

        ILendingPool pool = ILendingPool(aaveProvider.getLendingPool());
        aUsdcToken.approve(address(pool), _amount);

        SwapInfo memory swapInfo = _logExchangeStart(usdcToken, aUsdcToken);

        uint256 withdrawAmount = pool.withdraw(_asset, _amount, address(this));
        _logExchangeEnd(swapInfo, address(pool), 'withdrawFull');

        return withdrawAmount;
    }

    function netAssetValue() external view override returns (uint256) {
        return aUsdcToken.balanceOf(address(this));
    }

    function liquidationValue() external view override returns (uint256) {
        return aUsdcToken.balanceOf(address(this));
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {
        return 0;
    }

}
