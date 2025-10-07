// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
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
    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30,000e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view {
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

    // New Tests
    function testHealthFactorExactThreshold() public depositedCollateral {
        uint256 mintAmount = 10000e18; // exactly safe limit
        vm.startPrank(USER);
        dsce.mintDsc(mintAmount);
        uint256 health = dsce.getHealthFactor();
        assertEq(health, 1e18); // exactly at min
    }

    function testCanMintLessThanAllowed() public depositedCollateral {
        uint256 mintAmount = 5000e18; // under safe limit
        vm.startPrank(USER);
        dsce.mintDsc(mintAmount);
        uint256 health = dsce.getHealthFactor();
        assertGt(health, 1e18);
    }

    function testCannotMintIfNoCollateral() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0);
        dsce.mintDsc(1000e18);
        vm.stopPrank();
    }

    /////////////////////////////
    // 🔥 NEW TESTS ADDED     ///
    /////////////////////////////

    // (1) Reverts if minting zero
    function testRevertsIfMintAmountZero() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
        vm.stopPrank();
    }

    // (2) Reverts if burning more DSC than minted
    function testRevertsIfBurnMoreThanMinted() public depositedCollateral {
        uint256 mintAmount = 1000e18;
        vm.startPrank(USER);
        dsce.mintDsc(mintAmount);
        dsc.approve(address(dsce), 2000e18);
        vm.expectRevert();
        dsce.burnDsc(2000e18);
        vm.stopPrank();
    }

    // (3) Event emitted on deposit
    function testEmitsEventOnDeposit() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        vm.expectEmit(true, true, false, true);
        emit DSCEngine.CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    // (4) Health factor increases when collateral added
    function testHealthFactorImprovesAfterMoreCollateral() public depositedCollateral {
        vm.startPrank(USER);
        dsce.mintDsc(5000e18);
        uint256 beforeHealth = dsce.getHealthFactor();

        ERC20Mock(weth).mint(USER, 5 ether);
        ERC20Mock(weth).approve(address(dsce), 5 ether);
        dsce.depositCollateral(weth, 5 ether);
        uint256 afterHealth = dsce.getHealthFactor();
        assertGt(afterHealth, beforeHealth);
        vm.stopPrank();
    }

    // (5) Reverts if redeeming more collateral than owned
    function testRevertsIfRedeemMoreThanDeposited() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectRevert();
        dsce.redeemCollateral(weth, 100 ether);
        vm.stopPrank();
    }

    // (6) Total collateral value in USD matches expected
    function testCollateralValueInUsd() public depositedCollateral {
        ( , uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedUsd = 20000e18; // 10 ETH * $2000
        assertEq(collateralValueInUsd, expectedUsd);
    }

    // (7) Health factor cannot drop below 1 after burning DSC
    function testHealthFactorRemainsSafeAfterBurn() public depositedCollateral {
        vm.startPrank(USER);
        dsce.mintDsc(9000e18);
        dsc.approve(address(dsce), 4000e18);
        dsce.burnDsc(4000e18);
        uint256 health = dsce.getHealthFactor();
        assertGe(health, 1e18);
        vm.stopPrank();
    }

    // (8) Withdraw reduces collateral and affects health factor
    function testRedeemCollateralReducesHealthFactor() public depositedCollateral {
        vm.startPrank(USER);
        dsce.mintDsc(5000e18);
        uint256 beforeHealth = dsce.getHealthFactor();
        dsce.redeemCollateral(weth, 5 ether);
        uint256 afterHealth = dsce.getHealthFactor();
        assertLt(afterHealth, beforeHealth);
        vm.stopPrank();
    }

    // (9) Burning DSC increases health factor
    function testBurnImprovesHealthFactor() public depositedCollateral {
        vm.startPrank(USER);
        dsce.mintDsc(8000e18);
        uint256 beforeHealth = dsce.getHealthFactor();
        dsc.approve(address(dsce), 4000e18);
        dsce.burnDsc(4000e18);
        uint256 afterHealth = dsce.getHealthFactor();
        assertGt(afterHealth, beforeHealth);
        vm.stopPrank();
    }

    // (10) Can handle multiple deposits correctly
    // function testMultipleDepositsAccumulate() public {
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).approve(address(dsce), 20 ether);
    //     dsce.depositCollateral(weth, 10 ether);
    //     dsce.depositCollateral(weth, 10 ether);
    //     vm.stopPrank();

    //     ( , uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
    //     uint256 expectedUsd = 40000e18; // 20 ETH * $2000
    //     assertEq(collateralValueInUsd, expectedUsd);
    // }

     // -------------------------------------------------------------
    // getUsdValue & getTokenAmountFromUsd
    // -------------------------------------------------------------
    function testGetUsdValueWorks() public view {
        // 1 WETH @ $2000 => 2000 * 1e18 = 2000e18
        uint256 usdValue = dsce.getUsdValue(address(weth), 1e18);
        assertEq(usdValue, 2000e18);
    }

    function testGetTokenAmountFromUsdIsInverseOfGetUsdValue() public view {
        uint256 usdValue = 1000e18;
        uint256 tokenAmount = dsce.getTokenAmountFromUsd(address(weth), usdValue);
        // $1000 @ $2000/ETH => 0.5 ETH
        assertApproxEqAbs(tokenAmount, 0.5e18, 1);
    }

    // -------------------------------------------------------------
    // Health Factor Logic
    // -------------------------------------------------------------
    function testHealthFactorIsMaxWhenNoDebt() public view {
        uint256 health = dsce.getHealthFactor();
        assertEq(health, type(uint256).max);
    }

    function testHealthFactorDropsAsDebtIncreases() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(address(weth), AMOUNT_COLLATERAL);

        // Mint small DSC (healthy)
        dsce.mintDsc(1000e18);
        uint256 health1 = dsce.getHealthFactor();

        // Mint more DSC (riskier)
        dsce.mintDsc(5000e18);
        uint256 health2 = dsce.getHealthFactor();

        assertLt(health2, health1);
        vm.stopPrank();
    }

    // -------------------------------------------------------------
    // Redeem Collateral and Burn Logic
    // -------------------------------------------------------------
    function testRedeemCollateralRevertsIfHealthFactorBreaks() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        dsce.mintDsc(4000e18);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0);
        dsce.redeemCollateral(address(weth), 9e18); // too much withdrawal
        vm.stopPrank();
    }

    // function testBurnDscReducesDebt() public {
    //     vm.startPrank(USER);
    //     weth.approve(address(dsce), AMOUNT_COLLATERAL);
    //     dsce.depositCollateral(address(weth), AMOUNT_COLLATERAL);
    //     dsce.mintDsc(2000e18);

    //     uint256 before = dsce.getHealthFactor();
    //     dsc.approve(address(dsce), 2000e18);
    //     dsce.burnDsc(500e18);
    //     uint256 afterHealth = dsce.getHealthFactor();
    //     assertGt(afterHealth, before);
    //     vm.stopPrank();
    // }

    // -------------------------------------------------------------
    // Liquidation Logic
    // -------------------------------------------------------------
    function testCannotLiquidateHealthyUser() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        dsce.mintDsc(1000e18);
        vm.stopPrank();

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(address(weth), USER, 100e18);
    }

    // function testLiquidationImprovesHealthFactor() public {
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
    //     dsce.depositCollateral(address(weth), AMOUNT_COLLATERAL);
    //     dsce.mintDsc(9000e18);
    //     vm.stopPrank();

    //     // Drop ETH price drastically to break health factor
    //     MockV3Aggregator(ethUsdPriceFeed).updateAnswer(500e8); // $500

    //     vm.startPrank(address(dsce));
    //     dsc.mint(LIQUIDATOR, 1000e18);
    //     vm.stopPrank();

    //     vm.startPrank(LIQUIDATOR);
    //     dsc.approve(address(dsce), type(uint256).max);
    //     dsce.liquidate(address(weth), USER, 1000e18);
    //     vm.stopPrank();
    // }

    // -------------------------------------------------------------
    // depositCollateralAndMintDsc
    // -------------------------------------------------------------
    function testDepositAndMintTogetherWorks() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(address(weth), AMOUNT_COLLATERAL, 1000e18);
        uint256 health = dsce.getHealthFactor();
        assertGt(health, 1e18);
        vm.stopPrank();
    }

    // -------------------------------------------------------------
    // getAccountInformation
    // -------------------------------------------------------------
    function testGetAccountInformationMatchesInternalState() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        dsce.mintDsc(2000e18);
        vm.stopPrank();

        (uint256 minted, uint256 collateralUsd) = dsce.getAccountInformation(USER);
        assertEq(minted, 2000e18);
        assertEq(collateralUsd, 20000e18); // 10 ETH * $2000 = $20,000
    }
}