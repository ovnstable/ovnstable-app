// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/IWrappedUsdPlusToken.sol";
import "./interfaces/IUsdPlusToken.sol";
import "./libraries/WadRayMath.sol";


contract WrappedUsdPlusToken is IWrappedUsdPlusToken, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using WadRayMath for uint256;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    IUsdPlusToken public usdPlusToken;


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address usdPlusTokenAddress) initializer public {
        __ERC20_init("Wrapped USD+", "WUSD+");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        usdPlusToken = IUsdPlusToken(usdPlusTokenAddress);
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(UPGRADER_ROLE)
    override
    {}


    /// @inheritdoc ERC20Upgradeable
    function decimals() public view override(ERC20Upgradeable) returns (uint8) {
        return 6;
    }

    /// @inheritdoc IERC4626
    function asset() external view override returns (address) {
        return address(usdPlusToken);
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view override returns (uint256) {
        return convertToAssets(totalSupply());
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets) public view override returns (uint256) {
        return assets.rayDiv(usdPlusToken.liquidityIndex());
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        return shares.rayMul(usdPlusToken.liquidityIndex());
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address receiver) external view override returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) external view override returns (uint256) {
        return convertToShares(assets);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) external override returns (uint256) {
        require(assets != 0, "Zero assets not allowed");
        require(receiver != address(0), "Zero address for receiver not allowed");

        usdPlusToken.transferFrom(msg.sender, address(this), assets);

        uint256 shares = convertToShares(assets);
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        return shares;
    }

    /// @inheritdoc IERC4626
    function maxMint(address receiver) external view override returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares) external view override returns (uint256) {
        return convertToAssets(shares);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) external override returns (uint256) {
        require(shares != 0, "Zero shares not allowed");
        require(receiver != address(0), "Zero address for receiver not allowed");

        transferFrom(msg.sender, address(this), shares);

        _mint(receiver, shares);
        uint256 assets = convertToAssets(shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        return assets;
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner) external view override returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 assets) external view override returns (uint256) {
        return convertToShares(assets);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner) external override returns (uint256) {
        require(assets != 0, "Zero assets not allowed");
        require(receiver != address(0), "Zero address for receiver not allowed");
        require(owner != address(0), "Zero address for owner not allowed");

        uint256 shares = convertToShares(assets);
        if (owner != msg.sender) {
            uint256 currentAllowance = allowance(owner, msg.sender);
            require(currentAllowance >= shares, "Redeem amount exceeds allowance");
            _approve(owner, msg.sender, currentAllowance - shares);
        }

        _burn(owner, shares);

        usdPlusToken.transfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return assets;
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) external view override returns (uint256) {
        return balanceOf(owner);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares) external view override returns (uint256) {
        return convertToAssets(shares);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner) external override returns (uint256) {
        require(shares != 0, "Zero shares not allowed");
        require(receiver != address(0), "Zero address for receiver not allowed");
        require(owner != address(0), "Zero address for owner not allowed");

        if (owner != msg.sender) {
            uint256 currentAllowance = allowance(owner, msg.sender);
            require(currentAllowance >= shares, "Redeem amount exceeds allowance");
            _approve(owner, msg.sender, currentAllowance - shares);
        }

        _burn(owner, shares);

        uint256 assets = convertToAssets(shares);
        usdPlusToken.transfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return assets;
    }

    /// @inheritdoc IWrappedUsdPlusToken
    function assetBalanceOf(address owner) external view override returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    /// @inheritdoc IWrappedUsdPlusToken
    function rate() external view override returns (uint256) {
        return usdPlusToken.liquidityIndex();
    }

}