// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    AggregatorV3Interface
} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard {
    /////////////////
    // Constants & Immutable
    /////////////////

    uint256 private constant LIQUIDATION_BONUS = 10;
    DecentralizedStableCoin immutable i_dsc;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    /////////////////
    // Storage
    /////////////////

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    /////////////////
    // Events
    /////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed from, address indexed to, address indexed token, uint256 amount
    );

    /////////////////
    // Errors
    /////////////////
    error DSCEngine__HealthFactorOk();
    error DSCEngine__BreakHealthFactor(uint256 userHealthFactor);
    error DSCEngine__HealthFactorNotImproving();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenNowAllowed(address);
    error DSCEngine__TransferFailed();
    error DSCEngine__MintDSCFailed();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();

    /////////////////
    // Modifiers
    /////////////////

    modifier moreThanZero(
        uint256 amount
    ) {
        require(amount > 0, DSCEngine__NeedsMoreThanZero());
        _;
    }

    modifier isAllowedToken(
        address tokenCollateralAddress
    ) {
        require(
            s_priceFeeds[tokenCollateralAddress] != address(0),
            DSCEngine__TokenNowAllowed(tokenCollateralAddress)
        );
        _;
    }

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address dscAddress
    ) {
        require(
            tokenAddresses.length == priceFeedAddresses.length,
            DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength()
        );

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /////////////////
    // Public / External functions
    /////////////////

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) public moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) nonReentrant {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress)
            .transferFrom(msg.sender, address(this), amountCollateral);
        require(success, DSCEngine__TransferFailed());
    }

    function mintDsc(
        uint256 amountDscToMint
    ) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;

        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = i_dsc.mint(msg.sender, amountDscToMint);

        require(minted, DSCEngine__MintDSCFailed());
    }

    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    function redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) public moreThanZero(amountCollateral) nonReentrant {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc(
        uint256 amount
    ) public moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateralForDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amount
    ) external nonReentrant {
        burnDsc(amount);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    function liquidate(
        address collateral,
        address user,
        uint256 debtToCover
    ) external moreThanZero(debtToCover) nonReentrant {
        uint256 startingUserHealthFactor = _healthFactor(user);
        require(startingUserHealthFactor < MIN_HEALTH_FACTOR, DSCEngine__HealthFactorOk());

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);

        uint256 bonusCollateral =
            (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 totalCollateralRedeemed = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(collateral, totalCollateralRedeemed, user, msg.sender);

        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        require(
            endingUserHealthFactor > startingUserHealthFactor, DSCEngine__HealthFactorNotImproving()
        );

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /////////////////
    // Private/Internal functions
    /////////////////

    function _burnDsc(
        uint256 amount,
        address onBehalfOf,
        address dscFrom
    ) private {
        s_DSCMinted[onBehalfOf] -= amount;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amount);
        require(success, DSCEngine__TransferFailed());

        i_dsc.burn(amount);
    }

    function _redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        address from,
        address to
    ) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);

        // self-note: this line is different from the code
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        // bool success = IERC20(tokenCollateralAddress).transferFrom(from, to, amountCollateral);
        require(success, DSCEngine__TransferFailed());

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function _revertIfHealthFactorIsBroken(
        address user
    ) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        require(
            userHealthFactor >= MIN_HEALTH_FACTOR, DSCEngine__BreakHealthFactor(userHealthFactor)
        );
    }

    function _healthFactor(
        address user
    ) internal view returns (uint256 healthFactor) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        healthFactor = _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function _getAccountInformation(
        address user
    ) internal view returns (uint256 totalDscMinted, uint256 collateralValueInUsd) {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = _getAccountCollateralValue(user);
    }

    function _getAccountCollateralValue(
        address user
    ) internal view returns (uint256 valueUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            valueUsd += getUsdValue(token, s_collateralDeposited[user][token]);
        }
    }

    function _calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    ) internal pure returns (uint256) {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold =
            (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    /////////////////
    // View/Pure functions
    /////////////////

    function getHealthFactor() external view {}

    function getAccountInformation(
        address user
    ) external view returns (uint256, uint256) {
        return _getAccountInformation(user);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getCollateralTokenPriceFeed(
        address tokenAddr
    ) external view returns (address) {
        return s_priceFeeds[tokenAddr];
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getUsdValue(
        address token,
        uint256 amount
    ) public view returns (uint256 valueUsd) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        // forge-lint: disable-next-line(unsafe-typecast)
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getTokenAmountFromUsd(
        address token,
        uint256 usdAmountInWei
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        // forge-lint: disable-next-line(unsafe-typecast)
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getCollateralBalanceOfUser(
        address user,
        address collateral
    ) external view returns (uint256) {
        return s_collateralDeposited[user][collateral];
    }

    function calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    ) external pure returns (uint256) {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }
}
