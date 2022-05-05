// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./core/Strategy.sol";
import "./connectors/meshswap/interfaces/IMeshSwapUsdc.sol";
import "./exchanges/QuickSwapExchange.sol";


contract StrategyMeshSwapUsdc is Strategy, QuickSwapExchange {

    IERC20 public usdcToken;
    IERC20 public meshToken;

    IMeshSwapUsdc public meshSwapUsdc;
    address public recipient;


    // --- events

    event StrategyMeshSwapUsdcUpdatedTokens(address usdcToken, address meshToken);

    event StrategyMeshSwapUsdcUpdatedParams(address meshSwapUsdc, address meshSwapRouter, address recipient);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _meshToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_meshToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        meshToken = IERC20(_meshToken);

        emit StrategyMeshSwapUsdcUpdatedTokens(_usdcToken, _meshToken);
    }

    function setParams(
        address _meshSwapUsdc,
        address _meshSwapRouter,
        address _recipient
    ) external onlyAdmin {

        require(_meshSwapUsdc != address(0), "Zero address not allowed");
        require(_meshSwapRouter != address(0), "Zero address not allowed");
        require(_recipient != address(0), "Zero address not allowed");

        meshSwapUsdc = IMeshSwapUsdc(_meshSwapUsdc);
        setUniswapRouter(_meshSwapRouter);
        recipient = _recipient;

        emit StrategyMeshSwapUsdcUpdatedParams(_meshSwapUsdc, _meshSwapRouter, _recipient);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        usdcToken.approve(address(meshSwapUsdc), _amount);
        meshSwapUsdc.depositToken(_amount);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        meshSwapUsdc.withdrawToken(_amount);

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 amount = IERC20(address(meshSwapUsdc)).balanceOf(address(this)) * 2;

        meshSwapUsdc.withdrawToken(amount);

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return IERC20(address(meshSwapUsdc)).balanceOf(address(this)) * 2;
    }

    function liquidationValue() external view override returns (uint256) {
        return IERC20(address(meshSwapUsdc)).balanceOf(address(this)) * 2;
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        // claim rewards
        uint256 meshBalanceBefore = meshToken.balanceOf(address(this));
        meshSwapUsdc.claimReward();
        uint256 meshBalanceAfter = meshToken.balanceOf(address(this));

        // sell rewards
        uint256 totalUsdc;

        uint256 meshBalance = meshBalanceAfter - meshBalanceBefore;
        if (meshBalance > 0) {
            uint256 meshUsdc = swapTokenToUsdc(
                address(meshToken),
                address(usdcToken),
                10 ** 18,
                address(this),
                address(this),
                meshBalance / 2
            );
            totalUsdc += meshUsdc;
        }

        usdcToken.transfer(_to, usdcToken.balanceOf(address(this)));
        meshToken.transfer(recipient, meshToken.balanceOf(address(this)));

        return totalUsdc;
    }

}
