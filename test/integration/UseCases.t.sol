// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "@pwn-safe-test/integration/BaseIntegrationTest.sol";

import "@pwn-safe-test/helpers/malicious/DelegatecallContract.sol";
import "@pwn-safe-test/helpers/malicious/HackerWallet.sol";
import "@pwn-safe-test/helpers/token/T20.sol";
import "@pwn-safe-test/helpers/token/T721.sol";
import "@pwn-safe-test/helpers/token/T1155.sol";


// Run Use Cases fork test with `forge t --mp test/integration/UseCases.t.sol -f $RPC_URL`
// PWN Safe deployed addresses have to be in deployments.json file
abstract contract UseCasesTest is BaseIntegrationTest {
	
}


/*----------------------------------------------------------*|
|*  # EIP-1271                                              *|
|*----------------------------------------------------------*/

contract UseCases_EIP1271_Test is UseCasesTest {

	/**
	 * 1: enable whitelist
	 * 2: sign message
	 * 3: check if is valid signature
	 * 4: disable whitelist
	 * 5: check if is not valid signature
	 * 6: remove whitelisted lib
	 * 7: fail to sign message
	 */
	function test_UC_EIP1271_1() external {
		bytes32 dataDigest = keccak256("data digest");

		// 1:
		vm.prank(admin);
		whitelist.setUseWhitelist(true);
		vm.prank(admin);
		whitelist.setIsWhitelistedLib(address(signMessageLib), true);

		// 2:
		_executeTx({
			_safe: safe,
			to: address(signMessageLib),
			value: 0,
			data: abi.encodeWithSelector(signMessageLib.signMessage.selector, abi.encode(dataDigest)),
			operation: Enum.Operation.DelegateCall,
			safeTxGas: 0,
			baseGas: 0,
			gasPrice: 0,
			gasToken: address(0),
			refundReceiver: payable(0)
		});

		// 3:
		(bool success, bytes memory responseBytes) = address(safe).call(
			abi.encodeWithSignature("isValidSignature(bytes32,bytes)", dataDigest, "")
		);
		assertTrue(success);
		assertEq(abi.decode(responseBytes, (bytes4)), bytes4(0x1626ba7e));

		// 4:
		vm.prank(admin);
		whitelist.setUseWhitelist(false);

		// 5:
		(success, responseBytes) = address(safe).call(
			abi.encodeWithSignature("isValidSignature(bytes32,bytes)", dataDigest, "")
		);
		assertTrue(success);
		assertEq(abi.decode(responseBytes, (bytes4)), bytes4(0));

		// 6:
		vm.prank(admin);
		whitelist.setIsWhitelistedLib(address(signMessageLib), false);

		// 7:
		vm.expectRevert("Address is not whitelisted for delegatecalls");
		_executeTx({
			_safe: safe,
			to: address(signMessageLib),
			value: 0,
			data: abi.encodeWithSelector(signMessageLib.signMessage.selector, abi.encode(dataDigest)),
			operation: Enum.Operation.DelegateCall,
			safeTxGas: 0,
			baseGas: 0,
			gasPrice: 0,
			gasToken: address(0),
			refundReceiver: payable(0)
		});
	}

}


/*----------------------------------------------------------*|
|*  # ERC20                                                 *|
|*----------------------------------------------------------*/

contract UseCases_ERC20_Test is UseCasesTest {

	T20 t20;

	function setUp() override public {
		super.setUp();

		t20 = new T20();
		vm.prank(admin);
		whitelist.setIsWhitelisted(address(t20), true);
	}


	/**
	 * 1:  mint asset
	 * 2:  approve 1/3 to first address
	 * 3:  approve 1/3 to second address
	 * 4:  fail to mint ATR token for 1/3
	 * 5:  first address transfers asset
	 * 6:  resolve internal state
	 * 7:  fail to mint ATR token for 1/3
	 * 8:  set approvel of second address to 0
	 * 9:  mint ATR token for 1/3
	 * 10: fail to approve asset
	 */
	function test_UC_ERC20_1() external {
		// 1:
		t20.mint(address(safe), 900e18);

		// 2:
		_executeTx(
			safe, address(t20),
			abi.encodeWithSelector(t20.approve.selector, alice, 300e18)
		);

		// 3:
		_executeTx(
			safe, address(t20),
			abi.encodeWithSelector(t20.approve.selector, bob, 300e18)
		);

		// 4:
		vm.expectRevert("GS013"); // Some asset from collection has an approval
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC20(address(t20), 300e18)
			)
		);

		// 5:
		vm.prank(alice);
		t20.transferFrom(address(safe), alice, 300e18);

		// 6:
		_executeTx(
			safe, address(guard),
			abi.encodeWithSelector(
				guard.resolveInvalidAllowance.selector,
				address(safe), address(t20), alice
			)
		);

		// 7:
		vm.expectRevert("GS013"); // Some asset from collection has an approval
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC20(address(t20), 300e18)
			)
		);

		// 8:
		_executeTx(
			safe, address(t20),
			abi.encodeWithSelector(t20.approve.selector, bob, 0)
		);

		// 9:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC20(address(t20), 300e18)
			)
		);

		// 10:
		vm.expectRevert("Some asset from collection has transfer right token minted");
		_executeTx(
			safe, address(t20),
			abi.encodeWithSelector(t20.approve.selector, bob, 300e18)
		);
	}

	/**
	 * 1:  mint asset
	 * 2:  mint ATR token for 1/3
	 * 3:  fail to approve asset
	 * 4:  transfer ATR token to other wallet
	 * 5:  transfer asset via ATR token
	 * 6:  approve 1/3 to first address
	 * 7:  transfer ATR token back to wallet
	 * 8:  fail to transfer tokenized asset back via ATR token
	 * 9:  first address transfers asset
	 * 10: resolve internal state
	 * 11: transfer tokenized asset back via ATR token
	 */
	function test_UC_ERC20_2() external {
		// 1:
		t20.mint(address(safe), 900e18);

		// 2:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC20(address(t20), 300e18)
			)
		);

		// 3:
		vm.expectRevert("Some asset from collection has transfer right token minted");
		_executeTx(
			safe, address(t20),
			abi.encodeWithSelector(t20.approve.selector, alice, 300e18)
		);

		// 4:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.transferFrom.selector,
				address(safe), address(safeOther), 1
			)
		);

		// 5:
		_executeTx(
			safeOther, address(atr),
			abi.encodeWithSelector(
				atr.claimAssetFrom.selector,
				address(safe), 1, false
			)
		);

		// 6:
		_executeTx(
			safe, address(t20),
			abi.encodeWithSelector(t20.approve.selector, alice, 300e18)
		);

		// 7:
		_executeTx(
			safeOther, address(atr),
			abi.encodeWithSelector(
				atr.transferFrom.selector,
				address(safeOther), address(safe), 1
			)
		);

		// 8:
		vm.expectRevert("GS013"); // Receiver has approvals set for an asset
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.claimAssetFrom.selector,
				address(safeOther), 1, false
			)
		);

		// 9:
		vm.prank(alice);
		t20.transferFrom(address(safe), alice, 300e18);

		// 10:
		_executeTx(
			safe, address(guard),
			abi.encodeWithSelector(
				guard.resolveInvalidAllowance.selector,
				address(safe), address(t20), alice
			)
		);

		// 11:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.claimAssetFrom.selector,
				address(safeOther), 1, false
			)
		);
	}

	/**
	 * 1: mint asset
	 * 2: mint ATR token for 1/3
	 * 3: burn 1/2 of assets
	 * 4: fail to burn 1/2 of assets
	 * 5: burn ATR token for 1/3
	 * 6: burn 1/2 of assets
	 */
	function test_UC_ERC20_3() external {
		// 1:
		t20.mint(address(safe), 600e18);

		// 2:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC20(address(t20), 200e18)
			)
		);

		// 3:
		_executeTx(
			safe, address(t20),
			abi.encodeWithSelector(t20.burn.selector, address(safe), 300e18)
		);

		// 4:
		vm.expectRevert("Insufficient tokenized balance");
		_executeTx(
			safe, address(t20),
			abi.encodeWithSelector(t20.burn.selector, address(safe), 300e18)
		);

		// 5:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(atr.burnAssetTransferRightsToken.selector, 1)
		);

		// 6:
		_executeTx(
			safe, address(t20),
			abi.encodeWithSelector(t20.burn.selector, address(safe), 300e18)
		);
	}

}


/*----------------------------------------------------------*|
|*  # ERC721                                                *|
|*----------------------------------------------------------*/

contract UseCases_ERC721_Test is UseCasesTest {

	T721 t721;

	function setUp() override public {
		super.setUp();

		t721 = new T721();
		vm.prank(admin);
		whitelist.setIsWhitelisted(address(t721), true);
	}


	/**
	 * 1:  mint asset 1
	 * 2:  approve asset 1 to first address
	 * 3:  mint asset 2
	 * 4:  mint asset 3
	 * 5:  mint ATR token for asset 2
	 * 6:  fail to mint ATR token for asset 1
	 * 7:  fail to approve asset 3
	 * 8:  set second address as wallets operator for ATR tokens
	 * 9:  second address transfers ATR token 1 to self
	 * 10: fail to transfer tokenized asset 2 via ATR token 1 to second address without burning ATR token
	 * 11: transfer tokenized asset 2 via ATR token 1 to second address and burn ATR token
	 * 12: approve asset 3 to first address
	 */
	function test_UC_ERC721_1() external {
		// 1:
		t721.mint(address(safe), 1);

		// 2:
		_executeTx(
			safe, address(t721),
			abi.encodeWithSelector(t721.approve.selector, alice, 1)
		);

		// 3:
		t721.mint(address(safe), 2);

		// 4:
		t721.mint(address(safe), 3);

		// 5:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC721(address(t721), 2)
			)
		);

		// 6:
		vm.expectRevert("GS013"); // Asset has an approved address
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC721(address(t721), 1)
			)
		);

		// 7:
		vm.expectRevert("Some asset from collection has transfer right token minted");
		_executeTx(
			safe, address(t721),
			abi.encodeWithSelector(t721.approve.selector, alice, 3)
		);

		// 8:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(atr.setApprovalForAll.selector, bob, true)
		);

		// 9:
		vm.prank(bob);
		atr.transferFrom(address(safe), bob, 1);

		// 10:
		vm.expectRevert("Attempting to transfer asset to non PWNSafe address");
		vm.prank(bob);
		atr.claimAssetFrom(payable(address(safe)), 1, false);

		// 11:
		vm.prank(bob);
		atr.claimAssetFrom(payable(address(safe)), 1, true);

		// 12:
		_executeTx(
			safe, address(t721),
			abi.encodeWithSelector(t721.approve.selector, alice, 3)
		);
	}

	/**
	 * 1:  mint asset id 1
	 * 2:  mint asset id 2
	 * 3:  set first address as wallet operator for asset
	 * 4:  fail to mint ATR token for asset id 1
	 * 5:  remove first address as wallet operator for asset
	 * 6:  mint ATR token 1 for asset id 1
	 * 7:  fail to set first address as wallet operator for asset
	 * 8:  transfer ATR token 1 to first address
	 * 9:  transfer tokenized asset id 1 to first address and burn ATR token
	 * 10: set first address as wallet operator for asset
	 */
	function test_UC_ERC721_2() external {
		// 1:
		t721.mint(address(safe), 1);

		// 2:
		t721.mint(address(safe), 2);

		// 3:
		_executeTx(
			safe, address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, true)
		);

		// 4:
		vm.expectRevert("GS013"); // Some asset from collection has an approval
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC721(address(t721), 1)
			)
		);

		// 5:
		_executeTx(
			safe, address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, false)
		);

		// 6:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC721(address(t721), 1)
			)
		);

		// 7:
		vm.expectRevert("Some asset from collection has transfer right token minted");
		_executeTx(
			safe, address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, true)
		);

		// 8:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(atr.transferFrom.selector, address(safe), alice, 1)
		);

		// 9:
		vm.prank(alice);
		atr.claimAssetFrom(payable(address(safe)), 1, true);

		// 10:
		_executeTx(
			safe, address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, true)
		);
	}

	/**
	 * 1:  deploy multisig safe
	 * 2:  mint asset id 1
	 * 3:  fail to mint ATR token with one owner
	 * 4:  sign tx by second owner
	 * 5:  mint ATR token with both owners signatures
	 */
	function test_UC_ERC721_3() external {
		uint256 owner1PK = 7;
		uint256 owner2PK = 8;
		address owner1 = vm.addr(owner1PK);
		address owner2 = vm.addr(owner2PK);

		address[] memory owners = new address[](2);
		owners[0] = owner1;
		owners[1] = owner2;

		// 1:
		safe = factory.deployProxy(owners, 2);

		// 2:
		t721.mint(address(safe), 1);

		// 3:
		vm.expectRevert("GS020");
		vm.prank(owner1);
		safe.execTransaction(
			address(atr),
			0,
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC721(address(t721), 1)
			),
			Enum.Operation.Call,
			0,
			10,
			0,
			address(0),
			payable(0),
			abi.encodePacked(uint256(uint160(owner1)), bytes32(0), uint8(1))
		);

		// 4:
		bytes memory owner2Signature;
		{
			bytes32 txHash = safe.getTransactionHash(
				address(atr),
				0,
				abi.encodeWithSelector(
					atr.mintAssetTransferRightsToken.selector,
					MultiToken.ERC721(address(t721), 1)
				),
				Enum.Operation.Call,
				0,
				10,
				0,
				address(0),
				payable(0),
				safe.nonce()
			);

			(uint8 v, bytes32 r, bytes32 s) = vm.sign(owner2PK, txHash);
			owner2Signature = abi.encodePacked(r, s, v);
		}

		// 5:
		vm.prank(owner1);
		safe.execTransaction(
			address(atr),
			0,
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC721(address(t721), 1)
			),
			Enum.Operation.Call,
			0,
			10,
			0,
			address(0),
			payable(0),
			abi.encodePacked(uint256(uint160(owner1)), bytes32(0), uint8(1), owner2Signature)
		);
	}

	/**
	 * 1:  init hacker wallet
	 * 2:  deploy new safe with hacker wallet as owner
	 * 3:  mint asset id 42
	 * 4:  mint ATR token id 1
	 * 5:  transfer ATR token to alice
	 * 6:  fail to execute reentrancy hack
	 *     - recoverInvalidTokenizedBalance(uint256) will fail with 'Report block number has to be smaller then current block number'
	 */
	function test_UC_ERC721_4() external {
		// 1:
		HackerWallet hackerWallet = new HackerWallet();

		// 2:
		address[] memory owners = new address[](1);
		owners[0] = address(hackerWallet);
		safe = factory.deployProxy(owners, 1);

		// 3:
		t721.mint(address(safe), 42);

		// 4:
		vm.prank(address(hackerWallet));
		safe.execTransaction(
			address(atr), 0,
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC721(address(t721), 42)
			),
			Enum.Operation.Call, 0, 0, 0, address(0), payable(0),
			abi.encodePacked(uint256(uint160(address(hackerWallet))), bytes32(0), uint8(1))
		);

		// 5:
		vm.prank(address(hackerWallet));
		safe.execTransaction(
			address(atr), 0,
			abi.encodeWithSelector(atr.transferFrom.selector, address(safe), alice, 1),
			Enum.Operation.Call, 0, 0, 0, address(0), payable(0),
			abi.encodePacked(uint256(uint160(address(hackerWallet))), bytes32(0), uint8(1))
		);

		// 6:
		hackerWallet.setupHack(address(atr), 1);

		vm.expectRevert("GS013"); // Insufficient tokenized balance
		vm.prank(address(hackerWallet));
		safe.execTransaction(
			address(t721), 0,
			abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", address(safe), address(hackerWallet), 42),
			Enum.Operation.Call, 0, 0, 0, address(0), payable(0),
			abi.encodePacked(uint256(uint160(address(hackerWallet))), bytes32(0), uint8(1))
		);

	}

	/**
	 * 1: mint asset id 42
	 * 2: mint ATR token 1
	 * 3: transfer ATR token 1 to alice
	 * 4: force transfer asset id 42 from safe
	 * 5: report invalid tokenized balance
	 * 6: recovert invalid tokenized balance
	 * 7: fail to claim asset id 42 via invalid ATR token
	 * 8: burn ATR token 1
	 */
	function test_UC_ERC721_5() external {
		vm.roll(100);

		// 1:
		t721.mint(address(safe), 42);

		// 2:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC721(address(t721), 42)
			)
		);

		// 3:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(atr.transferFrom.selector, address(safe), alice, 1)
		);

		// 4:
		t721.forceTransfer(address(safe), bob, 42);

		// 5:
		atr.reportInvalidTokenizedBalance(1, address(safe));
		vm.roll(200);

		// 6:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.recoverInvalidTokenizedBalance.selector
			)
		);

		// 7:
		vm.expectRevert("ATR token is invalid due to recovered invalid tokenized balance");
		vm.prank(alice);
		atr.claimAssetFrom(payable(safe), 1, false);

		// 8:
		vm.prank(alice);
		atr.burnAssetTransferRightsToken(1);
	}

}


/*----------------------------------------------------------*|
|*  # ERC1155                                               *|
|*----------------------------------------------------------*/

contract UseCases_ERC1155_Test is UseCasesTest {

	T1155 t1155;

	function setUp() override public {
		super.setUp();

		t1155 = new T1155();
		vm.prank(admin);
		whitelist.setIsWhitelisted(address(t1155), true);
	}


	/**
	 * 1:  mint asset id 1 amount 600
	 * 2:  mint asset id 2 amount 100
	 * 3:  set first address as wallet operator for asset
	 * 4:  fail to mint ATR token for asset id 1 amount 600
	 * 5:  remove first address as wallet operator for asset
	 * 6:  mint ATR token 1 for asset id 1 amount 600
	 * 7:  fail to set first address as wallet operator for asset
	 * 8:  transfer ATR token 1 to first address
	 * 9:  transfer tokenized asset id 1 amount 600 to first address and burn ATR token
	 * 10: set first address as wallet operator for asset
	 */
	function test_UC_ERC1155_1() external {
		// 1:
		t1155.mint(address(safe), 1, 600);

		// 2:
		t1155.mint(address(safe), 2, 100);

		// 3:
		_executeTx(
			safe, address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, true)
		);

		// 4:
		vm.expectRevert("GS013"); // Some asset from collection has an approval
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC1155(address(t1155), 1, 600)
			)
		);

		// 5:
		_executeTx(
			safe, address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, false)
		);

		// 6:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC1155(address(t1155), 1, 600)
			)
		);

		// 7:
		vm.expectRevert("Some asset from collection has transfer right token minted");
		_executeTx(
			safe, address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, true)
		);

		// 8:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(atr.transferFrom.selector, address(safe), alice, 1)
		);

		// 9:
		vm.prank(alice);
		atr.claimAssetFrom(payable(address(safe)), 1, true);

		// 10:
		_executeTx(
			safe, address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, true)
		);
	}

	/**
	 * 1:  mint asset id 1 amount 600
	 * 2:  mint ATR token 1 for asset id 1 amount 600
	 * 3:  call malicious contract
	 * 4:  fail to transfer assets
	 */
	function test_UC_ERC1155_2() external {
		// 1:
		t1155.mint(address(safe), 1, 600);

		// 2:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC1155(address(t1155), 1, 600)
			)
		);

		// 3:
		DelegatecallContract delegatecallContract = new DelegatecallContract();
		_executeTx(
			safe, address(delegatecallContract),
			abi.encodeWithSignature(
				"perform(address,bytes)",
				address(t1155), abi.encodeWithSignature("setApprovalForAll(address,bool)", alice, true)
			)
		);

		// 4:
		vm.expectRevert("ERC1155: caller is not token owner nor approved");
		vm.prank(alice);
		t1155.safeTransferFrom(address(safe), alice, 1, 600, "");
	}

	/**
	 * 1:  mint asset id 1 amount 600
	 * 2:  mint ATR token 1 for asset id 1 amount 600
	 * 3:  transfer ATR token 1 to alice
	 * 4:  fail to transfer asset via ATR token to bob
	 * 5:  grant bobs recipient permission to alice
	 * 6:  transfer asset from safe to bob via ATR token held by alice
	 */
	function test_UC_ERC1155_3() external {
		// 1:
		t1155.mint(address(safe), 1, 600);

		// 2:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC1155(address(t1155), 1, 600)
			)
		);

		// 3:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(atr.transferFrom.selector, address(safe), alice, 1)
		);

		// 4:
		RecipientPermissionManager.RecipientPermission memory permission = RecipientPermissionManager.RecipientPermission(
			MultiToken.Category.ERC1155, address(t1155), 1, 600, false,
			bob, alice, 0, false, keccak256("nonce")
		);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(6, atr.recipientPermissionHash(permission));

		vm.expectRevert("Permission signer is not stated as recipient");
		vm.prank(alice);
		atr.transferAssetFrom(payable(address(safe)), 1, true, permission, abi.encodePacked(r, s, v));

		// 5:
		vm.prank(bob);
		atr.grantRecipientPermission(permission);

		// 6:
		vm.prank(alice);
		atr.transferAssetFrom(payable(address(safe)), 1, true, permission, "");
	}

	/**
	 * 1:  mint asset id 1 amount 100
	 * 2:  mint asset id 2 amount 100
	 * 3:  mint ATR token 1 for asset id 1 amount 100
	 * 4:  mint ATR token 2 for asset id 1 amount 100
	 * 5:  transfer ATR token 1 & 2 to alice
	 * 6:  grant bobs recipient permission for asset 1 to alice
	 * 7:  grant bobs recipient permission for asset 2 with same nonce as 1 to alice
	 * 8:  transfer asset 1 from safe to bob via ATR token held by alice
	 * 9:  fail to transfer asset 2 from safe to bob via ATR token held by alice
	 */
	function test_UC_ERC1155_4() external {
		// 1:
		t1155.mint(address(safe), 1, 100);

		// 2:
		t1155.mint(address(safe), 2, 100);

		// 3:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC1155(address(t1155), 1, 100)
			)
		);

		// 4:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC1155(address(t1155), 2, 100)
			)
		);

		// 5:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(atr.transferFrom.selector, address(safe), alice, 1)
		);
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(atr.transferFrom.selector, address(safe), alice, 2)
		);

		// 6:
		RecipientPermissionManager.RecipientPermission memory permission1 = RecipientPermissionManager.RecipientPermission(
			MultiToken.Category.ERC1155, address(t1155), 1, 100, false,
			bob, alice, 0, false, keccak256("nonce")
		);
		vm.prank(bob);
		atr.grantRecipientPermission(permission1);

		// 7:
		RecipientPermissionManager.RecipientPermission memory permission2 = RecipientPermissionManager.RecipientPermission(
			MultiToken.Category.ERC1155, address(t1155), 2, 100, false,
			bob, alice, 0, false, keccak256("nonce")
		);
		vm.prank(bob);
		atr.grantRecipientPermission(permission2);

		// 8:
		vm.prank(alice);
		atr.transferAssetFrom(payable(address(safe)), 1, true, permission1, "");

		// 9:
		vm.expectRevert("Recipient permission nonce is revoked");
		vm.prank(alice);
		atr.transferAssetFrom(payable(address(safe)), 2, true, permission2, "");
	}

	/**
	 * 1:  mint asset id 1 amount 600
	 * 2:  mint ATR token 1 for asset id 1 amount 200
	 * 3:  mint ATR token 2 for asset id 1 amount 200
	 * 4:  mint ATR token 3 for asset id 1 amount 200
	 * 5:  transfer ATR token 1, 2 & 3 to alice
	 * 6:  grant bobs persistent recipient permission to alice
	 * 7:  transfer asset from safe to bob via ATR 1 token held by alice
	 * 8:  transfer asset from safe to bob via ATR 2 token held by alice
	 * 9:  transfer asset from safe to bob via ATR 3 token held by alice
	 */
	function test_UC_ERC1155_5() external {
		// 1:
		t1155.mint(address(safe), 1, 600);

		// 2:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC1155(address(t1155), 1, 200)
			)
		);

		// 3:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC1155(address(t1155), 1, 200)
			)
		);

		// 4:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC1155(address(t1155), 1, 200)
			)
		);

		// 5:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(atr.transferFrom.selector, address(safe), alice, 1)
		);
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(atr.transferFrom.selector, address(safe), alice, 2)
		);
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(atr.transferFrom.selector, address(safe), alice, 3)
		);

		// 6:
		RecipientPermissionManager.RecipientPermission memory permission = RecipientPermissionManager.RecipientPermission(
			MultiToken.Category.ERC1155, address(t1155), 1, 200, false,
			bob, alice, 0, true, keccak256("nonce")
		);
		vm.prank(bob);
		atr.grantRecipientPermission(permission);

		// 7:
		vm.prank(alice);
		atr.transferAssetFrom(payable(address(safe)), 1, true, permission, "");

		// 8:
		vm.prank(alice);
		atr.transferAssetFrom(payable(address(safe)), 2, true, permission, "");

		// 9:
		vm.prank(alice);
		atr.transferAssetFrom(payable(address(safe)), 3, true, permission, "");
	}

	/**
	 * 1:  mint asset id 1 amount 600
	 * 2:  mint ATR token 1 for asset id 1 amount 600
	 * 3:  transfer ATR token 1 to alice
	 * 4:  grant bobs recipient permission to alice with any id and any amount
	 * 5:  transfer asset from safe to bob via ATR 1 token held by alice
	 */
	function test_UC_ERC1155_6() external {
		// 1:
		t1155.mint(address(safe), 1, 600);

		// 2:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC1155(address(t1155), 1, 200)
			)
		);

		// 3:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(atr.transferFrom.selector, address(safe), alice, 1)
		);

		// 4:
		RecipientPermissionManager.RecipientPermission memory permission = RecipientPermissionManager.RecipientPermission(
			MultiToken.Category.ERC1155, address(t1155), 0, 0, true,
			bob, alice, 0, false, keccak256("nonce")
		);
		vm.prank(bob);
		atr.grantRecipientPermission(permission);

		// 5:
		vm.prank(alice);
		atr.transferAssetFrom(payable(address(safe)), 1, true, permission, "");
	}

	/**
	 * 1:  fail to mint ATR token 1 for asset id 1
	 * 2:  mint asset id 1 amount 1
	 * 3:  mint ATR token 1 for asset id 1
	 * 4:  fail to mint ATR token 2 for asset id 1
	 * 5:  fail to transfer asset id 1 from safe
	 * 6:  fail to report invalid tokenized balance of ATR token 1
	 */
	function test_UC_ERC1155_7() external {
		// 1:
		vm.expectRevert("GS013"); // Insufficient balance to tokenize
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC1155(address(t1155), 1, 0)
			)
		);

		// 2:
		t1155.mint(address(safe), 1, 1);

		// 3:
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC1155(address(t1155), 1, 0)
			)
		);

		// 4:
		vm.expectRevert("GS013"); // Insufficient balance to tokenize
		_executeTx(
			safe, address(atr),
			abi.encodeWithSelector(
				atr.mintAssetTransferRightsToken.selector,
				MultiToken.ERC1155(address(t1155), 1, 0)
			)
		);

		// 5:
		vm.expectRevert("Insufficient tokenized balance");
		_executeTx(
			safe, address(t1155),
			abi.encodeWithSignature(
				"safeTransferFrom(address,address,uint256,uint256,bytes)",
				address(safe), alice, 1, 1, ""
			)
		);

		// 6:
		vm.expectRevert("Tokenized balance is not invalid");
		atr.reportInvalidTokenizedBalance(1, address(safe));
	}

}
