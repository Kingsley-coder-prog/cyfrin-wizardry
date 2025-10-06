// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, ,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ///////////////////////
    // Constructor Tests///
    ///////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses,priceFeedAddresses,address(dsc));
    }

    /////////////////
    // Price Tests///
    /////////////////
    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30,000e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether; // 100e18
        // $2,000 / ETH, $100
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth,usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    //////////////////////////////
    // depositCollateral Tests  //
    //////////////////////////////
    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth,0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth,collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

        /* --------------------------
       Additional Tests (add below)
       -------------------------- */

    function testUserCanDepositAndMintDsc() public depositedCollateral {
        // USER already deposited AMOUNT_COLLATERAL via modifier

        // choose a safe mint amount (well below collateral-adjusted limit)
        // With 10 WETH @ $2000 = $20,000 collateral value
        // liquidation threshold 50% -> adjusted collateral = $10,000
        // mint 1,000 DSC = $1000 is safe
        uint256 mintAmount = 1000e18; // 1_000 ether

        vm.startPrank(USER);
        dsce.mintDsc(mintAmount);
        vm.stopPrank();

        // verify the account information reflects the minted DSC
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        assertEq(totalDscMinted, mintAmount);

        // DSC token balance of user should equal minted amount
        assertEq(dsc.balanceOf(USER), mintAmount);

        // collateralValueInUsd should be > 0 and consistent with token->USD mapping
        uint256 tokenAmountFromUsd = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        // Should equal AMOUNT_COLLATERAL (rounding aside), since user deposited that amount
        assertEq(tokenAmountFromUsd, AMOUNT_COLLATERAL);
    }

    function testCannotMintTooMuch() public depositedCollateral {
        // if user tries to mint too much (exceeding adjusted collateral), it should revert
        // For 10 WETH @ $2000 => adjusted collateral = $10,000
        // Try minting 11,000 DSC -> should revert
        uint256 tooMuch = 11000e18;

        vm.startPrank(USER);
        // uint256 expectedHealthFactor = dsce.getHealthFactor();
        bytes memory expectedRevert = abi.encodeWithSelector(
        DSCEngine.DSCEngine__BreaksHealthFactor.selector,
        909090909090909090  // the actual health factor value
    );
        vm.expectRevert(expectedRevert);
        dsce.mintDsc(tooMuch);
        vm.stopPrank();
    }

    function testBurnDscReducesDebt() public depositedCollateral {
        uint256 mintAmount = 2000e18; // safe to mint (<= adjusted collateral)
        vm.startPrank(USER);
        dsce.mintDsc(mintAmount);
        vm.stopPrank();

        // confirm minted
        (uint256 beforeMintDebt,) = dsce.getAccountInformation(USER);
        assertEq(beforeMintDebt, mintAmount);

        // Approve DSCEngine to pull user's DSC so _burnDsc's transferFrom succeeds
        vm.startPrank(USER);
        dsc.approve(address(dsce), mintAmount);
        vm.stopPrank();

        // Now burn half
        uint256 burnAmount = 1000e18;
        vm.startPrank(USER);
        dsce.burnDsc(burnAmount);
        vm.stopPrank();

        // After burn, debt should be reduced and user's DSC balance should be reduced
        (uint256 afterBurnDebt, ) = dsce.getAccountInformation(USER);
        assertEq(afterBurnDebt, mintAmount - burnAmount);
        assertEq(dsc.balanceOf(USER), mintAmount - burnAmount);
    }

    function testRedeemCollateralForDsc() public depositedCollateral {
        // deposit already done by modifier
        uint256 mintAmount = 1000e18; // mint $1000 worth of DSC
        vm.startPrank(USER);
        dsce.mintDsc(mintAmount);
        vm.stopPrank();

        // Approve DSCEngine to pull DSC from user in redeemCollateralForDsc
        vm.startPrank(USER);
        dsc.approve(address(dsce), mintAmount);
        vm.stopPrank();

        // Record user's WETH balance before redeem
        uint256 wethBalanceBefore = ERC20Mock(weth).balanceOf(USER);

        // Redeem part of collateral back (redeemCollateralForDsc burns DSC and returns collateral)
        // Compute how much collateral token corresponds to mintAmount (should be <= deposited)
        uint256 collateralToRedeem = dsce.getTokenAmountFromUsd(weth, mintAmount);

        // Call redeemCollateralForDsc to burn mintAmount DSC and get `collateralToRedeem` back
        vm.startPrank(USER);
        dsce.redeemCollateralForDsc(weth, collateralToRedeem, mintAmount);
        vm.stopPrank();

        // After redeem, user's weth balance should have increased by collateralToRedeem
        uint256 wethBalanceAfter = ERC20Mock(weth).balanceOf(USER);
        assertEq(wethBalanceAfter, wethBalanceBefore + collateralToRedeem);

        // And user's DSC debt should be zero
        (uint256 totalDscMinted, ) = dsce.getAccountInformation(USER);
        assertEq(totalDscMinted, 0);
    }


}