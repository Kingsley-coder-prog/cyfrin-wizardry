// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.18;

// import {Test, console2} from "forge-std/Test.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

// contract HelperConfigTest is Test {
//     HelperConfig helper;

//     function setUp() public {
//         helper = new HelperConfig();
//     }

//     // -------------------------------------------------------------
//     // 1. Constructor (Default Anvil Path)
//     // -------------------------------------------------------------
//     function testConstructorUsesAnvilConfigOnLocalChain() public {
//         // By default, Foundry local chainid is 31337 (not 11155111)
//         HelperConfig.NetworkConfig memory cfg = helper.activeNetworkConfig();
//         assert(cfg.wethUsdPriceFeed != address(0));
//         assert(cfg.wbtcUsdPriceFeed != address(0));
//         assert(cfg.weth != address(0));
//         assert(cfg.wbtc != address(0));
//         assertEq(cfg.deployerKey(), helper.DEFAULT_ANVIL_KEY());
//     }

//     // -------------------------------------------------------------
//     // 2. Sepolia Path (For coverage of getSepoliaEthConfig)
//     // -------------------------------------------------------------
//     function testGetSepoliaEthConfigReturnsCorrectAddresses() public {
//         HelperConfig.NetworkConfig memory sepoliaCfg = helper.getSepoliaEthConfig();

//         // Verify known addresses are correct and non-zero
//         assertEq(sepoliaCfg.wethUsdPriceFeed, 0x694AA1769357215DE4FAC081bf1f309aDC325306);
//         assertEq(sepoliaCfg.wbtcUsdPriceFeed, 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43);
//         assertEq(sepoliaCfg.weth, 0xdd13E55209Fd76AfE204dBda4007C227904f0a81);
//         assertEq(sepoliaCfg.wbtc, 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
//     }

//     // -------------------------------------------------------------
//     // 3. Anvil Config (New Deployment)
//     // -------------------------------------------------------------
//     function testGetOrCreateAnvilEthConfigCreatesNewMocks() public {
//         HelperConfig freshHelper = new HelperConfig();

//         // Manually reset activeNetworkConfig to empty
//         freshHelper.activeNetworkConfig() = HelperConfig.NetworkConfig({
//             wethUsdPriceFeed: address(0),
//             wbtcUsdPriceFeed: address(0),
//             weth: address(0),
//             wbtc: address(0),
//             deployerKey: 0
//         });

//         HelperConfig.NetworkConfig memory cfg = freshHelper.getOrCreateAnvilEthConfig();
//         // All addresses should now be freshly deployed contracts
//         assertTrue(cfg.wethUsdPriceFeed != address(0));
//         assertTrue(cfg.wbtcUsdPriceFeed != address(0));
//         assertTrue(cfg.weth != address(0));
//         assertTrue(cfg.wbtc != address(0));
//     }

//     // -------------------------------------------------------------
//     // 4. Reuse path (Existing Config)
//     // -------------------------------------------------------------
//     function testGetOrCreateAnvilEthConfigReturnsExistingIfAlreadySet() public {
//         HelperConfig.NetworkConfig memory first = helper.activeNetworkConfig();
//         HelperConfig.NetworkConfig memory second = helper.getOrCreateAnvilEthConfig();

//         assertEq(first.wethUsdPriceFeed, second.wethUsdPriceFeed);
//         assertEq(first.wbtcUsdPriceFeed, second.wbtcUsdPriceFeed);
//         assertEq(first.weth, second.weth);
//         assertEq(first.wbtc, second.wbtc);
//     }

//     // -------------------------------------------------------------
//     // 5. Constant Validation
//     // -------------------------------------------------------------
//     function testConstantsAreCorrect() public view {
//         assertEq(helper.DECIMALS(), 8);
//         assertEq(helper.ETH_USD_PRICE(), 2000e8);
//         assertEq(helper.BTC_USD_PRICE(), 1000e8);
//         assertEq(helper.DEFAULT_ANVIL_KEY(), 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
//     }
// }
