// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/AssetTransferRights.sol";
import "../src/PWNWallet.sol";
import "../src/IPWNWallet.sol";
import "../src/test/T20.sol";
import "../src/test/T721.sol";
import "../src/test/T777.sol";
import "../src/test/T1155.sol";
import "../src/test/T1363.sol";
import "../src/test/ContractWallet.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import "MultiToken/MultiToken.sol";


abstract contract PWNWalletTest is Test {

	PWNWallet wallet;
	PWNWallet walletOther;
	T20 t20;
	T721 t721;
	T777 t777;
	T1155 t1155;
	T1363 t1363;
	address constant atr = address(0x0a15);
	address constant alice = address(0xa11ce);
	address constant bob = address(0xb0b);
	address constant notOwner = address(0xffff);
	address constant erc1820Registry = address(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

	constructor() {
		// ERC1820 Registry
		vm.etch(erc1820Registry, bytes("data"));
		vm.mockCall(
			erc1820Registry,
			abi.encodeWithSignature("getInterfaceImplementer(address,bytes32)"),
			abi.encode(address(0))
		);

		vm.etch(atr, bytes("data"));
	}

	function superSetUp() internal {
		wallet = new PWNWallet();
		wallet.initialize(address(this), atr);

		walletOther = new PWNWallet();
		walletOther.initialize(address(this), atr);

		t20 = new T20();
		t721 = new T721();
		address[] memory defaultOperators;
		t777 = new T777(defaultOperators);
		t1155 = new T1155();
		t1363 = new T1363();
	}


	function _operatorsSlotFor(address collection) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				collection, // Collection address as a mapping key
				uint256(2) // _operators mapping position
			)
		);
	}

	function _operatorsValuesSlotFor(address collection) internal pure returns (bytes32) {
		// Hash array position to get position of a first item
		return keccak256(
			abi.encode(
				_operatorsSlotFor(collection)
			)
		);
	}

	function _operatorsIndexSlotFor(address collection, address value) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				bytes32(uint256(uint160(value))),
				bytes32(uint256(_operatorsSlotFor(collection)) + 1)
			)
		);
	}


	function _mockOwnedFromCollection(uint256 value) internal {
		vm.mockCall(
			address(atr),
			abi.encodeWithSelector(AssetTransferRights.ownedFromCollection.selector),
			abi.encode(value)
		);
	}

	function _mockOperator(address walletAddr, address collection, address operator) internal {
		// Mock stored operator
		vm.store( // Operators set size
			walletAddr, _operatorsSlotFor(collection), bytes32(uint256(1))
		);
		vm.store( // Operator value
			walletAddr, _operatorsValuesSlotFor(collection), bytes32(uint256(uint160(operator)))
		);
		vm.store( // Operator index
			walletAddr, _operatorsIndexSlotFor(collection, operator), bytes32(uint256(1))
		);
	}

	function _checkOperator(address walletAddr, address collection, address operator) internal {
		bytes32 operatorsCount = vm.load(
			walletAddr, _operatorsSlotFor(collection)
		);
		bytes32 operators = vm.load(
			walletAddr, _operatorsValuesSlotFor(collection)
		);
		assertEq(uint256(operatorsCount), operator == address(0) ? 0 : 1);
		assertEq(address(uint160(uint256(operators) + 0)), operator);
	}

}

/*----------------------------------------------------------*|
|*  # EXECUTE                                               *|
|*----------------------------------------------------------*/

contract PWNWallet_Execute_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}

	// ---> Basic checks
	function test_shouldFail_whenSenderIsNotWalletOwner() external {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.transferFrom.selector, alice, bob, 42)
		);
	}

	function test_shouldFailWithExecutionRevertMessage() external {
		vm.expectRevert("50m3 6u5t0m err0r m3ssag3");
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.revertWithMessage.selector)
		);
	}

	function test_shouldTransferEthValue() external {
		vm.expectCall(
			address(t721),
			1.3 ether,
			abi.encodeWithSelector(t721.foo.selector)
		);
		wallet.execute{ value: 1.3 ether }(
			address(t721),
			abi.encodeWithSelector(t721.foo.selector)
		);
	}

	function test_shouldCallTokenizedBalanceCheck() external {
		vm.expectCall(
			address(atr),
			0,
			abi.encodeWithSelector(AssetTransferRights.checkTokenizedBalance.selector, address(wallet))
		);
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.foo.selector)
		);
	}
	// <--- Basic checks

	// ---> Approvals when not tokenized
	function test_shouldApproveERC20_whenNotTokenized() external {
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector),
			abi.encode(true)
		);

		vm.expectCall(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector, alice, 300e18)
		);
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector, alice, 300e18)
		);
	}

	function test_shouldIncreaseAllowanceERC20_whenNotTokenized() external {
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.increaseAllowance.selector),
			abi.encode(true)
		);

		vm.expectCall(
			address(t20),
			abi.encodeWithSelector(t20.increaseAllowance.selector, alice, 300e18)
		);
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.increaseAllowance.selector, alice, 300e18)
		);
	}

	function test_shouldDecreaseAllowanceERC20_whenNotTokenized() external {
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.decreaseAllowance.selector),
			abi.encode(true)
		);

		vm.expectCall(
			address(t20),
			abi.encodeWithSelector(t20.decreaseAllowance.selector, alice, 300e18)
		);
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.decreaseAllowance.selector, alice, 300e18)
		);
	}

	function test_shouldAuthorizeOperatorERC777_whenNotTokenized() external {
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t777),
			abi.encodeWithSelector(t777.authorizeOperator.selector),
			abi.encode("")
		);

		vm.expectCall(
			address(t777),
			abi.encodeWithSelector(t777.authorizeOperator.selector, alice)
		);
		wallet.execute(
			address(t777),
			abi.encodeWithSelector(t777.authorizeOperator.selector, alice)
		);
	}

	function test_shouldRevokeOperatorERC777_whenNotTokenized() external {
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t777),
			abi.encodeWithSelector(t777.revokeOperator.selector),
			abi.encode("")
		);

		vm.expectCall(
			address(t777),
			abi.encodeWithSelector(t777.revokeOperator.selector, alice)
		);
		wallet.execute(
			address(t777),
			abi.encodeWithSelector(t777.revokeOperator.selector, alice)
		);
	}

	function test_shouldApproveAndCallERC1363_whenNotTokenized() external {
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256)"),
			abi.encode(true)
		);

		vm.expectCall(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256)", alice, 300e18)
		);
		wallet.execute(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256)", alice, 300e18)
		);
	}

	function test_shouldApproveAndCallWithBytesERC1363_whenNotTokenized() external {
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256,bytes)"),
			abi.encode(true)
		);

		vm.expectCall(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256,bytes)", alice, 300e18, "some data")
		);
		wallet.execute(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256,bytes)", alice, 300e18, "some data")
		);
	}

	function test_shouldApproveERC721_whenNotTokenized() external {
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t721),
			abi.encodeWithSelector(t721.approve.selector),
			abi.encode("")
		);

		vm.expectCall(
			address(t721),
			abi.encodeWithSelector(t721.approve.selector, alice, 42)
		);
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.approve.selector, alice, 42)
		);
	}

	function test_shouldApproveForAllERC721_whenNotTokenized() external {
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector),
			abi.encode("")
		);

		vm.expectCall(
			address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, true)
		);
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, true)
		);
	}

	function test_shouldApproveForAllERC1155_whenNotTokenized() external {
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector),
			abi.encode("")
		);

		vm.expectCall(
			address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, true)
		);
		wallet.execute(
			address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, true)
		);
	}
	// <--- Approvals when not tokenized

	// ---> Approvals when tokenized
	function test_shouldFailToApproveERC20_whenTokenized() external {
		_mockOwnedFromCollection(1);

		vm.expectRevert("Some asset from collection has transfer right token minted");
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector, alice, 300e18)
		);
	}

	function test_shouldFailToIncreaseAllowanceERC20_whenTokenized() external {
		_mockOwnedFromCollection(1);

		vm.expectRevert("Some asset from collection has transfer right token minted");
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.increaseAllowance.selector, alice, 300e18)
		);
	}

	function test_shouldDecreaseAllowanceERC20_whenTokenized() external {
		_mockOwnedFromCollection(1);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.decreaseAllowance.selector),
			abi.encode(true)
		);

		vm.expectCall(
			address(t20),
			abi.encodeWithSelector(t20.decreaseAllowance.selector, alice, 300e18)
		);
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.decreaseAllowance.selector, alice, 300e18)
		);
	}

	function test_shouldFailToAuthorizeOperatorERC777_whenTokenized() external {
		_mockOwnedFromCollection(1);

		vm.expectRevert("Some asset from collection has transfer right token minted");
		wallet.execute(
			address(t777),
			abi.encodeWithSelector(t777.authorizeOperator.selector, alice)
		);
	}

	function test_shouldRevokeOperatorERC777_whenTokenized() external {
		_mockOwnedFromCollection(1);
		vm.mockCall(
			address(t777),
			abi.encodeWithSelector(t777.revokeOperator.selector),
			abi.encode("")
		);

		vm.expectCall(
			address(t777),
			abi.encodeWithSelector(t777.revokeOperator.selector, alice)
		);
		wallet.execute(
			address(t777),
			abi.encodeWithSelector(t777.revokeOperator.selector, alice)
		);
	}

	function test_shouldFailToApproveAndCallERC1363_whenTokenized() external {
		_mockOwnedFromCollection(1);

		vm.expectRevert("Some asset from collection has transfer right token minted");
		wallet.execute(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256)", alice, 300e18)
		);
	}

	function test_shouldFailToApproveAndCallWithBytesERC1363_whenTokenized() external {
		_mockOwnedFromCollection(1);

		vm.expectRevert("Some asset from collection has transfer right token minted");
		wallet.execute(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256,bytes)", alice, 300e18, "some data")
		);
	}

	function test_shouldFailToApproveERC721_whenTokenized() external {
		_mockOwnedFromCollection(1);

		vm.expectRevert("Some asset from collection has transfer right token minted");
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.approve.selector, alice, 42)
		);
	}

	function test_shouldFailToApproveForAllERC721_whenTokenized() external {
		_mockOwnedFromCollection(1);

		vm.expectRevert("Some asset from collection has transfer right token minted");
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, true)
		);
	}

	function test_shouldFailToApproveForAllERC1155_whenTokenized() external {
		_mockOwnedFromCollection(1);

		vm.expectRevert("Some asset from collection has transfer right token minted");
		wallet.execute(
			address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, true)
		);
	}
	// <--- Approvals when tokenized

	// ---> Set / remove operator
	function test_shouldSetOperator_whenGiveApprovalERC20() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector),
			abi.encode(true)
		);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.allowance.selector),
			abi.encode(uint256(0))
		);

		// Execute
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector, alice, 300e18)
		);

		// Check final state
		_checkOperator(address(wallet), address(t20), alice);
	}

	function test_shouldRemoveOperator_whenRevokApprovalERC20() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector),
			abi.encode(true)
		);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.allowance.selector),
			abi.encode(uint256(300e18))
		);

		// Mock stored operator
		_mockOperator(address(wallet), address(t20), alice);

		// Execute
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector, alice, 0)
		);

		// Check final state
		_checkOperator(address(wallet), address(t20), address(0));
	}

	function test_shouldSetOperator_whenAllowanceIncreaseERC20() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.increaseAllowance.selector),
			abi.encode(true)
		);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.allowance.selector),
			abi.encode(uint256(0))
		);

		// Execute
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.increaseAllowance.selector, alice, 300e18)
		);

		// Check final state
		_checkOperator(address(wallet), address(t20), alice);
	}

	function test_shouldKeepOperator_whenPartialAllowanceIncreaseERC20() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.increaseAllowance.selector),
			abi.encode(true)
		);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.allowance.selector),
			abi.encode(uint256(300e18))
		);

		// Mock stored operator
		_mockOperator(address(wallet), address(t20), alice);

		// Execute
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.increaseAllowance.selector, alice, 100e18)
		);

		// Check final state
		_checkOperator(address(wallet), address(t20), alice);
	}

	function test_shouldKeepOperator_whenPartialAllowanceDecreaseERC20() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.decreaseAllowance.selector),
			abi.encode(true)
		);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.allowance.selector),
			abi.encode(uint256(300e18))
		);

		// Mock stored operator
		_mockOperator(address(wallet), address(t20), alice);

		// Execute
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.decreaseAllowance.selector, alice, 100e18)
		);

		// Check final state
		_checkOperator(address(wallet), address(t20), alice);
	}

	function test_shouldRemoveOperator_whenFullAllowanceDecreaseERC20() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.decreaseAllowance.selector),
			abi.encode(true)
		);
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.allowance.selector),
			abi.encode(uint256(300e18))
		);

		// Mock stored operator
		_mockOperator(address(wallet), address(t20), alice);

		// Execute
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.decreaseAllowance.selector, alice, 300e18)
		);

		// Check final state
		_checkOperator(address(wallet), address(t20), address(0));
	}

	function test_shouldSetOperator_whenAuthorizeOperatorERC777() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t777),
			abi.encodeWithSelector(t777.authorizeOperator.selector),
			abi.encode("")
		);

		// Execute
		wallet.execute(
			address(t777),
			abi.encodeWithSelector(t777.authorizeOperator.selector, alice)
		);

		// Check final state
		_checkOperator(address(wallet), address(t777), alice);
	}

	function test_shouldRemoveOperator_whenRevokeOperatorERC777() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t777),
			abi.encodeWithSelector(t777.revokeOperator.selector),
			abi.encode("")
		);

		// Mock stored operator
		_mockOperator(address(wallet), address(t20), alice);

		// Execute
		wallet.execute(
			address(t777),
			abi.encodeWithSelector(t777.revokeOperator.selector, alice)
		);

		// Check final state
		_checkOperator(address(wallet), address(t777), address(0));
	}

	function test_shouldSetOperator_whenGiveApproveAndCallERC1363() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256)"),
			abi.encode(true)
		);
		vm.mockCall(
			address(t1363),
			abi.encodeWithSelector(t1363.allowance.selector),
			abi.encode(uint256(0))
		);

		// Execute
		wallet.execute(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256)", alice, 300e18)
		);

		// Check final state
		_checkOperator(address(wallet), address(t1363), alice);
	}

	function test_shouldRemoveOperator_whenRevokeApproveAndCallERC1363() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256)"),
			abi.encode(true)
		);
		vm.mockCall(
			address(t1363),
			abi.encodeWithSelector(t1363.allowance.selector),
			abi.encode(uint256(300e18))
		);

		// Mock stored operator
		_mockOperator(address(wallet), address(t1363), alice);

		// Execute
		wallet.execute(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256)", alice, 0)
		);

		// Check final state
		_checkOperator(address(wallet), address(t1363), address(0));
	}

	function test_shouldSetOperator_whenGiveApproveAndCallWithBytesERC1363() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256,bytes)"),
			abi.encode(true)
		);
		vm.mockCall(
			address(t1363),
			abi.encodeWithSelector(t1363.allowance.selector),
			abi.encode(uint256(0))
		);

		// Execute
		wallet.execute(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256,bytes)", alice, 300e18, "some data")
		);

		// Check final state
		_checkOperator(address(wallet), address(t1363), alice);
	}

	function test_shouldRemoveOperator_whenRevokeApproveAndCallWithBytesERC1363() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256,bytes)"),
			abi.encode(true)
		);
		vm.mockCall(
			address(t1363),
			abi.encodeWithSelector(t1363.allowance.selector),
			abi.encode(uint256(300e18))
		);

		// Mock stored operator
		_mockOperator(address(wallet), address(t1363), alice);

		// Execute
		wallet.execute(
			address(t1363),
			abi.encodeWithSignature("approveAndCall(address,uint256,bytes)", alice, 0, "some data")
		);

		// Check final state
		_checkOperator(address(wallet), address(t1363), address(0));
	}

	function test_shouldNotSetOperator_whenGiveApprovalERC721() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t721),
			abi.encodeWithSelector(t721.approve.selector),
			abi.encode("")
		);

		// Execute
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.approve.selector, alice, 42)
		);

		// Check final state
		_checkOperator(address(wallet), address(t721), address(0));
	}

	function test_shouldNotRemoveOperator_whenRevokeApprovalERC721() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t721),
			abi.encodeWithSelector(t721.approve.selector),
			abi.encode("")
		);

		// Mock stored operator
		_mockOperator(address(wallet), address(t721), alice);

		// Execute
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.approve.selector, address(0), 42)
		);

		// Check final state
		_checkOperator(address(wallet), address(t721), alice);
	}

	function test_shouldSetOperator_whenGiveApprovalForAllERC721() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector),
			abi.encode("")
		);

		// Execute
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, true)
		);

		// Check final state
		_checkOperator(address(wallet), address(t721), alice);
	}

	function test_shouldRemoveOperator_whenRevokeApprovalForAllERC721() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector),
			abi.encode("")
		);

		// Mock stored operator
		_mockOperator(address(wallet), address(t721), alice);

		// Execute
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, false)
		);

		// Check final state
		_checkOperator(address(wallet), address(t721), address(0));
	}

	function test_shouldSetOperator_whenGiveApprovalForAllERC1155() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector),
			abi.encode("")
		);

		// Execute
		wallet.execute(
			address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, true)
		);

		// Check final state
		_checkOperator(address(wallet), address(t1155), alice);
	}

	function test_shouldRemoveOperator_whenRevokeApprovalForAllERC1155() external {
		// Mock calls
		_mockOwnedFromCollection(0);
		vm.mockCall(
			address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector),
			abi.encode("")
		);

		// Mock stored operator
		_mockOperator(address(wallet), address(t1155), alice);

		// Execute
		wallet.execute(
			address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, false)
		);

		// Check final state
		_checkOperator(address(wallet), address(t1155), address(0));
	}
	// <--- Set / remove operator
}


/*----------------------------------------------------------*|
|*  # MINT ATR TOKEN                                        *|
|*----------------------------------------------------------*/

contract PWNWallet_MintATRToken_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenSenderIsNotWalletOwner() external {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		wallet.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 2, 1)
		);
	}

	function test_shouldCallMintOnATRContract() external {
		vm.mockCall(
			address(atr),
			abi.encodeWithSelector(AssetTransferRights.mintAssetTransferRightsToken.selector),
			abi.encode(4)
		);

		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 2, 1);
		vm.expectCall(
			address(atr),
			abi.encodeWithSelector(AssetTransferRights.mintAssetTransferRightsToken.selector, asset)
		);
		wallet.mintAssetTransferRightsToken(asset);
	}

}


/*----------------------------------------------------------*|
|*  # MINT ATR TOKEN BATCH                                  *|
|*----------------------------------------------------------*/

contract PWNWallet_MintATRTokenBatch_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenSenderIsNotWalletOwner() external {
		MultiToken.Asset[] memory assets = new MultiToken.Asset[](3);
		assets[0] = MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 2, 1);
		assets[1] = MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 3, 1);
		assets[2] = MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 4, 1);

		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		wallet.mintAssetTransferRightsTokenBatch(assets);
	}

	function test_shouldCallMintBatchOnATRContract() external {
		MultiToken.Asset[] memory assets = new MultiToken.Asset[](3);
		assets[0] = MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 2, 1);
		assets[1] = MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 3, 1);
		assets[2] = MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 4, 1);

		vm.mockCall(
			address(atr),
			abi.encodeWithSelector(AssetTransferRights.mintAssetTransferRightsTokenBatch.selector),
			abi.encode("")
		);

		vm.expectCall(
			address(atr),
			abi.encodeWithSelector(AssetTransferRights.mintAssetTransferRightsTokenBatch.selector, assets)
		);
		wallet.mintAssetTransferRightsTokenBatch(assets);
	}

}


/*----------------------------------------------------------*|
|*  # BURN ATR TOKEN                                        *|
|*----------------------------------------------------------*/

contract PWNWallet_BurnATRToken_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenSenderIsNotWalletOwner() external {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		wallet.burnAssetTransferRightsToken(102);
	}

	function test_shouldCallBurnOnATRContract() external {
		vm.mockCall(
			address(atr),
			abi.encodeWithSelector(AssetTransferRights.burnAssetTransferRightsToken.selector),
			abi.encode("")
		);

		vm.expectCall(
			address(atr),
			abi.encodeWithSelector(AssetTransferRights.burnAssetTransferRightsToken.selector, 102)
		);
		wallet.burnAssetTransferRightsToken(102);
	}

}


/*----------------------------------------------------------*|
|*  # BURN ATR TOKEN BATCH                                  *|
|*----------------------------------------------------------*/

contract PWNWallet_BurnATRTokenBatch_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenSenderIsNotWalletOwner() external {
		uint256[] memory ids = new uint256[](3);
		ids[0] = 392;
		ids[1] = 1;
		ids[2] = 9391023;

		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		wallet.burnAssetTransferRightsTokenBatch(ids);
	}

	function test_shouldCallBurnBatchOnATRContract() external {
		uint256[] memory ids = new uint256[](3);
		ids[0] = 392;
		ids[1] = 1;
		ids[2] = 9391023;

		vm.mockCall(
			address(atr),
			abi.encodeWithSelector(AssetTransferRights.burnAssetTransferRightsTokenBatch.selector),
			abi.encode("")
		);

		vm.expectCall(
			address(atr),
			abi.encodeWithSelector(AssetTransferRights.burnAssetTransferRightsTokenBatch.selector, ids)
		);
		wallet.burnAssetTransferRightsTokenBatch(ids);
	}

}


/*----------------------------------------------------------*|
|*  # TRANSFER ASSET FROM                                   *|
|*----------------------------------------------------------*/

contract PWNWallet_TransferAssetFrom_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenSenderIsNotWalletOwner() external {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		wallet.transferAssetFrom(address(walletOther), 42, true);
	}

	function test_shouldCallTransferAssetFromOnATRContract() external {
		vm.mockCall(
			address(atr),
			abi.encodeWithSelector(AssetTransferRights.transferAssetFrom.selector),
			abi.encode("")
		);

		vm.expectCall(
			address(atr),
			abi.encodeWithSelector(AssetTransferRights.transferAssetFrom.selector, address(walletOther), 42, true)
		);
		wallet.transferAssetFrom(address(walletOther), 42, true);
	}

}


/*----------------------------------------------------------*|
|*  # TRANSFER ATR TOKEN FROM                               *|
|*----------------------------------------------------------*/

contract PWNWallet_TransferATRTokenFrom_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenSenderIsNotWalletOwner() external {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		wallet.transferAtrTokenFrom(address(walletOther), address(wallet), 42);
	}

	function test_shouldCallTransferFromOnATRContract() external {
		vm.mockCall(
			address(atr),
			abi.encodeWithSignature("transferFrom(address,address,uint256)"),
			abi.encode("")
		);

		vm.expectCall(
			address(atr),
			abi.encodeWithSignature("transferFrom(address,address,uint256)", address(walletOther), address(wallet), 42)
		);
		wallet.transferAtrTokenFrom(address(walletOther), address(wallet), 42);
	}

}


/*----------------------------------------------------------*|
|*  # SAFE TRANSFER ATR TOKEN FROM                          *|
|*----------------------------------------------------------*/

contract PWNWallet_SafeTransferATRTokenFrom_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenSenderIsNotWalletOwner() external {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		wallet.safeTransferAtrTokenFrom(address(walletOther), address(wallet), 42);
	}

	function test_shouldCallSafeTransferFromOnATRContract() external {
		vm.mockCall(
			address(atr),
			abi.encodeWithSignature("safeTransferFrom(address,address,uint256)"),
			abi.encode("")
		);

		vm.expectCall(
			address(atr),
			abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", address(walletOther), address(wallet), 42)
		);
		wallet.safeTransferAtrTokenFrom(address(walletOther), address(wallet), 42);
	}
}


/*----------------------------------------------------------*|
|*  # SAFE TRANSFER ATR TOKEN FROM WITH BYTES               *|
|*----------------------------------------------------------*/

contract PWNWallet_SafeTransferATRTokenFromWithBytes_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenSenderIsNotWalletOwner() external {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		wallet.safeTransferAtrTokenFrom(address(walletOther), address(wallet), 42, "some data");
	}

	function test_shouldCallSafeTransferFromWithBytesOnATRContract() external {
		vm.mockCall(
			address(atr),
			abi.encodeWithSignature("safeTransferFrom(address,address,uint256,bytes)"),
			abi.encode("")
		);

		vm.expectCall(
			address(atr),
			abi.encodeWithSignature("safeTransferFrom(address,address,uint256,bytes)", address(walletOther), address(wallet), 42, "bytes bro")
		);
		wallet.safeTransferAtrTokenFrom(address(walletOther), address(wallet), 42, "bytes bro");
	}

}


/*----------------------------------------------------------*|
|*  # RESOLVE INVALID APPROVAL                              *|
|*----------------------------------------------------------*/

contract PWNWallet_ResolveInvalidApproval_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldRemoveOperator_whenERC20AllowanceIsZero() external {
		_mockOperator(address(wallet), address(t20), alice);

		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.allowance.selector),
			abi.encode(uint256(0))
		);

		wallet.resolveInvalidApproval(address(t20), alice);

		_checkOperator(address(wallet), address(t20), address(0));
	}

	function test_shouldKeepOperator_whenERC20AllowanceIsNotZero() external {
		_mockOperator(address(wallet), address(t20), alice);

		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.allowance.selector),
			abi.encode(uint256(10))
		);

		wallet.resolveInvalidApproval(address(t20), alice);

		_checkOperator(address(wallet), address(t20), alice);
	}

}


/*----------------------------------------------------------*|
|*  # RECOVER INVALID TOKENIZED BALANCE                     *|
|*----------------------------------------------------------*/

contract PWNWallet_RecoverInvalidTokenizedBalance_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldCallRecoverInvalidTokenizedBalanceOnATRContract() external {
		vm.mockCall(
			address(atr),
			abi.encodeWithSelector(AssetTransferRights.recoverInvalidTokenizedBalance.selector),
			abi.encode("")
		);

		vm.expectCall(
			address(atr),
			abi.encodeWithSelector(AssetTransferRights.recoverInvalidTokenizedBalance.selector, address(wallet), 42)
		);
		wallet.recoverInvalidTokenizedBalance(42);
	}

}


/*----------------------------------------------------------*|
|*  # TRANSFER ASSET                                        *|
|*----------------------------------------------------------*/

contract PWNWallet_TransferAsset_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenSenderIsNotATRContract() external {
		vm.expectRevert("Caller is not asset transfer rights contract");
		wallet.transferAsset(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1),
			alice
		);
	}

	function test_shouldTransferERC20() external {
		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.transfer.selector),
			abi.encode(true)
		);

		vm.expectCall(
			address(t20),
			abi.encodeWithSelector(t20.transfer.selector, alice, 100e18)
		);
		vm.prank(atr);
		wallet.transferAsset(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 100e18),
			alice
		);
	}

	function test_shouldTransferERC777() external {
		vm.mockCall(
			address(t777),
			abi.encodeWithSelector(t777.transfer.selector),
			abi.encode(true)
		);

		vm.expectCall(
			address(t777),
			abi.encodeWithSelector(t777.transfer.selector, alice, 100e18)
		);
		vm.prank(atr);
		wallet.transferAsset(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t777), 0, 100e18),
			alice
		);
	}

	function test_shouldTransferERC1363() external {
		vm.mockCall(
			address(t1363),
			abi.encodeWithSelector(t1363.transfer.selector),
			abi.encode(true)
		);

		vm.expectCall(
			address(t1363),
			abi.encodeWithSelector(t1363.transfer.selector, alice, 100e18)
		);
		vm.prank(atr);
		wallet.transferAsset(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t1363), 0, 100e18),
			alice
		);
	}

	function test_shouldTransferERC721() external {
		vm.mockCall(
			address(t721),
			abi.encodeWithSignature("safeTransferFrom(address,address,uint256)"),
			abi.encode("")
		);

		vm.expectCall(
			address(t721),
			abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", address(wallet), alice, 42)
		);
		vm.prank(atr);
		wallet.transferAsset(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1),
			alice
		);
	}

	function test_shouldTransferERC1155() external {
		vm.mockCall(
			address(t1155),
			abi.encodeWithSignature("safeTransferFrom(address,address,uint256,uint256,bytes)"),
			abi.encode("")
		);

		vm.expectCall(
			address(t1155),
			abi.encodeWithSignature("safeTransferFrom(address,address,uint256,uint256,bytes)", address(wallet), alice, 42, 100, "")
		);
		vm.prank(atr);
		wallet.transferAsset(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 42, 100),
			alice
		);
	}

}


/*----------------------------------------------------------*|
|*  # HAS OPERATOR FOR                                      *|
|*----------------------------------------------------------*/

contract PWNWallet_HasApprovalsFor_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldReturnTrue_whenCollectionHasOperator() external {
		_mockOperator(address(wallet), address(t20), alice);

		bool hasApproval = wallet.hasApprovalsFor(address(t20));

		assertEq(hasApproval, true);
	}

	function test_shouldReturnTrue_whenERC777WithDefaultOperator() external {
		address[] memory defaultOperators = new address[](1);
		defaultOperators[0] = alice;
		t777 = new T777(defaultOperators);

		vm.mockCall(
			erc1820Registry,
			abi.encodeWithSignature("getInterfaceImplementer(address,bytes32)"),
			abi.encode(address(t777))
		);

		bool hasApproval = wallet.hasApprovalsFor(address(t777));

		assertEq(hasApproval, true);
	}

	function test_shouldReturnFalse_whenCollectionHasNoOperator() external {
		bool hasApproval = wallet.hasApprovalsFor(address(t20));

		assertEq(hasApproval, false);
	}

}


/*----------------------------------------------------------*|
|*  # IERC721 RECEIVER                                      *|
|*----------------------------------------------------------*/

contract PWNWallet_IERC721Receiver_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldReturnCorrectValue_whenOnERC721Received() external {
		bytes4 value = wallet.onERC721Received(address(0), address(0), 123, "");

		assertEq(value, IERC721Receiver.onERC721Received.selector);
	}

}


/*----------------------------------------------------------*|
|*  # IERC1155 RECEIVER                                     *|
|*----------------------------------------------------------*/

contract PWNWallet_IERC1155Receiver_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldReturnCorrectValue_whenOnERC1155Received() external {
		bytes4 value = wallet.onERC1155Received(address(0), address(0), 123, 3300, "");

		assertEq(value, IERC1155Receiver.onERC1155Received.selector);
	}

	function test_shouldReturnCorrectValue_whenOnERC1155BatchReceived() external {
		uint256[] memory ids;
		uint256[] memory values;
		bytes4 value = wallet.onERC1155BatchReceived(address(0), address(0), ids, values, "");

		assertEq(value, IERC1155Receiver.onERC1155BatchReceived.selector);
	}

}


/*----------------------------------------------------------*|
|*  # SUPPORTS INTERFACE                                    *|
|*----------------------------------------------------------*/

contract PWNWallet_SupportsInterface_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldSupport_IPWNWallet() external {
		assertEq(
			wallet.supportsInterface(type(IPWNWallet).interfaceId),
			true
		);
	}

	function test_shouldSupport_IERC721Receiver() external {
		assertEq(
			wallet.supportsInterface(type(IERC721Receiver).interfaceId),
			true
		);
	}

	function test_shouldSupport_IERC1155Receiver() external {
		assertEq(
			wallet.supportsInterface(type(IERC1155Receiver).interfaceId),
			true
		);
	}

	function test_shouldSupport_IERC165() external {
		assertEq(
			wallet.supportsInterface(type(IERC165).interfaceId),
			true
		);
	}

}
