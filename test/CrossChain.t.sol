//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IERC20} from "@ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";

contract CrossChainTest is Test {
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    CCIPLocalSimulatorFork private ccipLocalSimulator;
    RebaseToken private sepoliaToken;
    RebaseToken private arbSepoliaToken;

    RebaseTokenPool private sepoliaTokenPool;
    RebaseTokenPool private arbSepoliaTokenPool;

    Register.NetworkDetails private sepoliaNetworkDetails;
    Register.NetworkDetails private arbSepoliaNetworkDetails;

    Vault private vault;

    function setUp() public {
        // Setup code can be added here if needed
        sepoliaFork = vm.createSelectFork("sepolia-eth");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        ccipLocalSimulator = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulator));

        // Deploy and configure RebaseToken on sepolia
        sepoliaNetworkDetails = ccipLocalSimulator.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        vm.deal(owner, 1 ether); // Give owner some ether to deploy contracts
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaTokenPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        sepoliaToken.grantMintAndBurnRole(address(vault));
        sepoliaToken.grantMintAndBurnRole(address(sepoliaTokenPool));
        vm.stopPrank();

        // Deploy and configure RebaseToken on arb-sepolia
        vm.selectFork(arbSepoliaFork);
        arbSepoliaNetworkDetails = ccipLocalSimulator.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        arbSepoliaTokenPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaTokenPool));
        vm.stopPrank();
    }
}
