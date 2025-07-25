// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GTERouter} from "contracts/router/GTERouter.sol";

import {WETH} from "solady/tokens/WETH.sol";

import {CLOBTestBase} from "test/clob/utils/CLOBTestBase.sol";
import {ERC20Harness} from "test/harnesses/ERC20Harness.sol";
import {MockUniV2Router} from "test/mocks/MockUniV2Router.sol";
import {MockLaunchpad} from "test/mocks/MockLaunchpad.sol";

import {ICLOBManager, SettingsParams} from "contracts/clob/ICLOBManager.sol";
import {IAllowanceTransfer} from "@permit2/interfaces/IAllowanceTransfer.sol";

import {DeployPermit2} from "../../lib/permit2/test/utils/DeployPermit2.sol";

contract WETHHarness is WETH {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Combines CLOBTestBase & RouterTestBase
contract PoCTestBase is CLOBTestBase, DeployPermit2 {
    ERC20Harness internal weth;
    ERC20Harness internal USDC;
    ERC20Harness internal tokenA;
    ERC20Harness internal tokenB;
    ERC20Harness internal tokenC;
    ERC20Harness internal tokenD;

    uint256 public constant TAKER_FEE_RATE = 200;

    MockUniV2Router internal uniV2Router;
    MockLaunchpad internal launchpad;
    address dummyGteRouter = makeAddr("dummy router");
    address dummyDistributor = makeAddr("dummy distributor");

    address internal wethCLOB;
    address internal wethQuoteCLOB;
    address internal abCLOB;
    address internal acCLOB;
    address internal bcCLOB;
    address internal dcCLOB;
    address internal dbCLOB;

    GTERouter internal router;
    IAllowanceTransfer internal permit2;

    address internal deployer;
    address internal jb;
    address internal rite;
    address internal julien;
    uint256 internal jbKey;
    uint256 internal riteKey;
    uint256 internal julienKey;
    address internal v2Factory;

    bytes32 internal constant _PERMIT_SINGLE_TYPEHASH = keccak256(
        "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

    bytes32 internal constant _PERMIT_DETAILS_TYPEHASH =
        keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");



    function setUp() public override virtual {
        CLOBTestBase.setUp();

        (jb, jbKey) = makeAddrAndKey("jb");
        (rite, riteKey) = makeAddrAndKey("rite");
        (julien, julienKey) = makeAddrAndKey("julien");
        v2Factory = makeAddr("mock univ2 factory address");
        deployer = makeAddr("deployer");

        USDC = new ERC20Harness("MOCK USDC", "USDC");

        bytes32 routerSalt = bytes32(abi.encode("GTE.V1.TESTNET.ROUTER.SALT", deployer));

        weth = ERC20Harness(address(new WETHHarness()));

        _deployUniContracts();
        _deployLaunchpad(routerSalt);
        _deployRouter(routerSalt);

        tokenA = new ERC20Harness("Token A", "TA");
        tokenB = new ERC20Harness("Token B", "TB");
        tokenC = new ERC20Harness("Token C", "TC");
        tokenD = new ERC20Harness("Token D", "TD");

        vm.label(address(weth), "WETH");
        vm.label(address(tokenA), "Token A");
        vm.label(address(tokenB), "Token B");
        vm.label(address(tokenC), "Token C");
        vm.label(address(tokenD), "Token D");

        vm.label(address(router), "Router");

        wethCLOB = _deployClob(address(tokenA), address(weth));
        wethQuoteCLOB = _deployClob(address(weth), address(tokenB));
        abCLOB = _deployClob(address(tokenA), address(tokenB));
        bcCLOB = _deployClob(address(tokenB), address(tokenC));
        acCLOB = _deployClob(address(tokenA), address(tokenC));
        dcCLOB = _deployClob(address(tokenD), address(tokenC));
        dbCLOB = _deployClob(address(tokenD), address(tokenB));
    }

    function _deployUniContracts() internal {
        uniV2Router = new MockUniV2Router(v2Factory);
        permit2 = IAllowanceTransfer(deployPermit2());

        // Mock the factory createPair call to return a mock pair address
        vm.mockCall(
            v2Factory,
            abi.encodeWithSignature("createPair(address,address)"),
            abi.encode(makeAddr("mock pair"))
        );

        // Mock the pair skim call to do nothing
        address mockPair = makeAddr("mock pair");
        vm.mockCall(
            mockPair,
            abi.encodeWithSignature("skim(address)"),
            abi.encode()
        );
    }

    function _deployLaunchpad(bytes32 routerSalt) internal {
        address router_address = factory.predictDeterministicAddress(routerSalt);

        // Deploy mock launchpad
        launchpad = new MockLaunchpad(dummyDistributor);
        
        vm.startPrank(deployer);
        launchpad.initialize(
            deployer,
            address(USDC),
            address(0), // mock bonding curve
            address(0), // mock lp vault
            ""
        );
        
        launchpad.updateQuoteAsset(address(USDC));
        vm.stopPrank();
        
        // Set up mocks for distributor
        vm.mockCall(address(dummyDistributor), abi.encodeWithSignature("createRewardsPair(address,address)"), abi.encode(true));
    }

    function _deployRouter(bytes32 routerSalt) internal {
        assertTrue(address(weth) > address(0), "Weth not initialized!");

        address router_logic = address(
            new GTERouter(
                payable(address(weth)), address(launchpad), address(accountManager), address(clobManager), address(uniV2Router), address(permit2)
            )
        );

        vm.prank(deployer);
        router = GTERouter(
            payable(factory.deployDeterministic({implementation: router_logic, admin: deployer, salt: routerSalt}))
        );
    }

    function _deployClob(address quoteToken, address baseToken) internal returns (address clobAddress) {
        // Max limits defaults to 1 if passed as 0
        SettingsParams memory settings = SettingsParams({
            owner: address(this),
            maxLimitsPerTx: 20,
            minLimitOrderAmountInBase: 0.005 ether,
            tickSize: 0.0001 ether,
            lotSizeInBase: 1
        });

        // Create the market using the factory
        clobAddress = clobManager.createMarket(baseToken, quoteToken, settings);
    }
}
