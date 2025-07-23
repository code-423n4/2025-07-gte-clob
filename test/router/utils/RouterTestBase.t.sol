// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {GTERouter} from "contracts/router/GTERouter.sol";

import {CLOBManager} from "contracts/clob/CLOBManager.sol";
import {UpgradeableBeacon} from "@openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import {AccountManager} from "contracts/account-manager/AccountManager.sol";

import {MockUniV2Router} from "../../mocks/MockUniV2Router.sol";
import {ERC20Harness} from "test/harnesses/ERC20Harness.sol";
import {WETH} from "solady/tokens/WETH.sol";
import {MockLaunchpad} from "test/mocks/MockLaunchpad.sol";
import {ILaunchpad} from "contracts/launchpad/interfaces/ILaunchpad.sol";

import {Side} from "contracts/clob/types/Order.sol";

import {CLOB} from "contracts/clob/CLOB.sol";

import {ICLOB} from "contracts/clob/ICLOB.sol";
import {ICLOBManager, SettingsParams} from "contracts/clob/ICLOBManager.sol";

import {IAllowanceTransfer} from "@permit2/interfaces/IAllowanceTransfer.sol";

import {DeployPermit2} from "../../../lib/permit2/test/utils/DeployPermit2.sol";

import {Create2} from "@openzeppelin/utils/Create2.sol";

import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";

import "forge-std/Test.sol";

contract WETHHarness is WETH {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract RouterTestBase is Test, DeployPermit2 {
    ERC20Harness internal weth;
    ERC20Harness internal USDC;
    ERC20Harness internal tokenA;
    ERC20Harness internal tokenB;
    ERC20Harness internal tokenC;
    ERC20Harness internal tokenD;

    uint256 public constant TAKER_FEE_RATE = 200;

    MockUniV2Router internal uniV2Router;
    CLOBManager internal clobManager;
    MockLaunchpad internal launchpad;
    address dummyGteRouter = makeAddr("dummy router");
    address dummyDistributor = makeAddr("dummy distributor");
    AccountManager internal accountManager;

    address internal wethCLOB;
    address internal wethQuoteCLOB;
    address internal abCLOB;
    address internal acCLOB;
    address internal bcCLOB;
    address internal dcCLOB;
    address internal dbCLOB;

    ERC1967Factory internal factory;
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

    function setUp() public virtual {
        (jb, jbKey) = makeAddrAndKey("jb");
        (rite, riteKey) = makeAddrAndKey("rite");
        (julien, julienKey) = makeAddrAndKey("julien");
        v2Factory = makeAddr("mock univ2 factory address");
        deployer = makeAddr("deployer");

        factory = new ERC1967Factory();

        USDC = new ERC20Harness("MOCK USDC", "USDC");

        bytes32 routerSalt = bytes32(abi.encode("GTE.V1.TESTNET.ROUTER.SALT", deployer));

        weth = ERC20Harness(address(new WETHHarness()));

        // Deploy AccountManager which now serves as both AccountManager and Operator
        // Use predicted router address so AccountManager knows the correct router
        address predictedRouter = factory.predictDeterministicAddress(routerSalt);
        
        uint16[] memory makerFees;
        uint16[] memory takerFees = new uint16[](1);
        takerFees[0] = uint16(TAKER_FEE_RATE);
        
        address tempAccountManagerImpl = address(new AccountManager(predictedRouter, address(0), makerFees, takerFees));
        accountManager = AccountManager(
            factory.deployAndCall(
                tempAccountManagerImpl,
                address(this),
                abi.encodeCall(AccountManager.initialize, (address(this)))
            )
        );
        vm.label(address(accountManager), "accountManager");

        _deployUniContracts();
        _deployCLOBContracts(routerSalt);
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

    function _deployCLOBContracts(bytes32 routerSalt) internal {
        address predictedRouter = factory.predictDeterministicAddress(routerSalt);
        vm.label(predictedRouter, "predicted router");

        // Deploy CLOB implementation with new constructor signature
        CLOB clobImplementation = new CLOB(address(0), predictedRouter, address(accountManager), 1000);

        UpgradeableBeacon beacon = new UpgradeableBeacon(address(clobImplementation), address(this));

        uint16[] memory clobMakerFees;
        uint16[] memory clobTakerFees = new uint16[](1);
        clobTakerFees[0] = uint16(TAKER_FEE_RATE);

        // Deploy CLOBManager with AccountManager
        address clobManagerImplementation =
            address(new CLOBManager(address(beacon), address(accountManager)));
        clobManager = CLOBManager(
            factory.deployAndCall({
                implementation: clobManagerImplementation,
                admin: deployer,
                data: abi.encodeWithSelector(CLOBManager.initialize.selector, address(this))
            })
        );
        
        // Step 2: Upgrade AccountManager with correct CLOBManager address
        uint16[] memory accountManagerMakerFees;
        uint16[] memory accountManagerTakerFees = new uint16[](1);
        accountManagerTakerFees[0] = uint16(TAKER_FEE_RATE);
        
        address correctAccountManagerImpl = address(new AccountManager(predictedRouter, address(clobManager), accountManagerMakerFees, accountManagerTakerFees));
        factory.upgrade(address(accountManager), correctAccountManagerImpl);
        
        // Step 3: Update beacon with correct CLOB implementation
        CLOB correctClobImplementation = new CLOB(address(clobManager), predictedRouter, address(accountManager), 1000);
        beacon.upgradeTo(address(correctClobImplementation));
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

    function _setupOrder(
        address clob,
        Side side,
        address user,
        uint256 amountInBase,
        uint256 price
    ) internal returns (ICLOB.PostLimitOrderResult memory) {
        _setupTokens(clob, side, user, amountInBase, price);

        // Post a limit order
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price,
            cancelTimestamp: 0,
            side: side,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        vm.prank(user);
        return ICLOB(clob).postLimitOrder(user, args);
    }

    function _setupTokens(
        address clob,
        Side side,
        address user,
        uint256 amountInBase,
        uint256 price
    ) internal returns (uint256) {
        vm.startPrank(user);

        ERC20Harness quoteToken = ERC20Harness(address(ICLOB(clob).getQuoteToken()));
        ERC20Harness baseToken = ERC20Harness(address(ICLOB(clob).getBaseToken()));

        // Deposit or mint tokens based on the side
        uint256 amountDeposited;
        if (side == Side.BUY) {
            // Deposit quote tokens into the CLOB contract
            uint256 depositAmount = ICLOB(clob).getQuoteTokenAmount(price, amountInBase);

            quoteToken.mint(user, depositAmount);
            quoteToken.approve(address(clobManager.accountManager()), depositAmount);
            clobManager.accountManager().deposit(user, address(quoteToken), depositAmount);
            amountDeposited = depositAmount;
        } else {
            // Deposit base tokens into the CLOB contract
            uint256 depositAmount = amountInBase;

            baseToken.mint(user, depositAmount);
            baseToken.approve(address(clobManager.accountManager()), depositAmount);
            clobManager.accountManager().deposit(user, address(baseToken), depositAmount);
            amountDeposited = depositAmount;
        }

        vm.stopPrank();

        return amountDeposited;
    }

    function _defaultERC20PermitAllowance(address token0, uint160 amount, uint48 expiration, uint48 nonce)
        internal
        view
        returns (IAllowanceTransfer.PermitSingle memory)
    {
        IAllowanceTransfer.PermitDetails memory details =
            IAllowanceTransfer.PermitDetails({token: token0, amount: amount, expiration: expiration, nonce: nonce});
        return IAllowanceTransfer.PermitSingle({
            details: details,
            spender: address(router),
            sigDeadline: block.timestamp + 100
        });
    }

    function _getPermitSignature(
        IAllowanceTransfer.PermitSingle memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        bytes32 permitHash = keccak256(abi.encode(_PERMIT_DETAILS_TYPEHASH, permit.details));

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(_PERMIT_SINGLE_TYPEHASH, permitHash, permit.spender, permit.sigDeadline))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);

        return bytes.concat(r, s, bytes1(v));
    }

}
