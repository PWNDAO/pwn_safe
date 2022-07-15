// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/AssetTransferRights.sol";
import "../src/PWNWallet.sol";
import "../src/PWNWalletFactory.sol";
import "../src/test/T20.sol";
import "../src/test/T721.sol";
import "../src/test/T777.sol";
import "../src/test/T1155.sol";
import "../src/test/T1363.sol";
import "../src/test/ContractWallet.sol";
import "MultiToken/MultiToken.sol";


abstract contract PWNWalletTest is Test {

	AssetTransferRights atr;
	PWNWalletFactory factory;
	PWNWallet wallet;
	PWNWallet walletOther;
	T20 t20;
	T721 t721;
	T777 t777;
	T1155 t1155;
	T1363 t11363;
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
	}

	function superSetUp() internal {
		atr = new AssetTransferRights();
		factory = PWNWalletFactory(atr.walletFactory());
		wallet = PWNWallet(factory.newWallet());
		walletOther = PWNWallet(factory.newWallet());

		t20 = new T20();
		t721 = new T721();
		address[] memory defaultOperators;
		t777 = new T777(defaultOperators);
		t1155 = new T1155();
		t11363 = new T1363();
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

	}

	function test_shouldFailWithExecutionRevertMessage() external {

	}

	function test_shouldCallTokenizedBalanceCheck() external {

	}
	// <--- Basic checks

	// ---> Approvals when not tokenized
	function test_shouldApproveERC20_whenNotTokenized() external {

	}

	function test_shouldIncreaseAllowanceERC20_whenNotTokenized() external {

	}

	function test_shouldDecreaseAllowanceERC20_whenNotTokenized() external {

	}

	function test_shouldAuthorizeOperatorERC777_whenNotTokenized() external {

	}

	function test_shouldRevokeOperatorERC777_whenNotTokenized() external {

	}

	function test_shouldApproveAndCallERC1363_whenNotTokenized() external {

	}

	function test_shouldApproveAndCallWithBytesERC1363_whenNotTokenized() external {

	}

	function test_shouldApproveERC721_whenNotTokenized() external {

	}

	function test_shouldApproveForAllERC721_whenNotTokenized() external {

	}

	function test_shouldApproveForAllERC1155_whenNotTokenized() external {

	}
	// <--- Approvals when not tokenized

	// ---> Approvals when tokenized
	function test_shouldFailToApproveERC20_whenTokenized() external {

	}

	function test_shouldFailToIncreaseAllowanceERC20_whenTokenized() external {

	}

	function test_shouldDecreaseAllowanceERC20_whenTokenized() external {

	}

	function test_shouldFailToAuthorizeOperatorERC777_whenTokenized() external {

	}

	function test_shouldRevokeOperatorERC777_whenTokenized() external {

	}

	function test_shouldFailToApproveAndCallERC1363_whenTokenized() external {

	}

	function test_shouldFailToApproveAndCallWithBytesERC1363_whenTokenized() external {

	}

	function test_shouldFailToApproveERC721_whenTokenized() external {

	}

	function test_shouldFailToApproveForAllERC721_whenTokenized() external {

	}

	function test_shouldFailToApproveForAllERC1155_whenTokenized() external {

	}
	// <--- Approvals when tokenized

	// ---> Set / remove operator
	function test_shouldSetOperator_whenGiveApprovalERC20() external {

	}

	function test_shouldRemoveOperator_whenRevokApprovalERC20() external {

	}

	function test_shouldSetOperator_whenAllowanceIncreaseERC20() external {

	}

	function test_shouldKeepOperator_whenPartialAllowanceDecreaseERC20() external {

	}

	function test_shouldRemoveOperator_whenFullAllowanceDecreaseERC20() external {

	}

	function test_shouldSetOperator_whenAuthorizeOperatorERC777() external {

	}

	function test_shouldRemoveOperator_whenRevokeOperatorERC777() external {

	}

	function test_shouldSetOperator_whenGiveApproveAndCallERC1363() external {

	}

	function test_shouldSetOperator_whenRevokeApproveAndCallERC1363() external {

	}

	function test_shouldSetOperator_whenGiveApproveAndCallWithBytesERC1363() external {

	}

	function test_shouldSetOperator_whenRevokeApproveAndCallWithBytesERC1363() external {

	}

	function test_shouldNotSetOperator_whenGiveApprovalERC721() external {

	}

	function test_shouldNotRemoveOperator_whenRevokeApprovalERC721() external {

	}

	function test_shouldSetOperator_whenGiveApprovalForAllERC721() external {

	}

	function test_shouldRemoveOperator_whenRevokeApprovalForAllERC721() external {

	}

	function test_shouldSetOperator_whenGiveApprovalForAllERC1155() external {

	}

	function test_shouldRemoveOperator_whenRevokeApprovalForAllERC1155() external {

	}
	// <--- Set / remove operator

	// ---> Transfers not tokenized transfer rights
	function test_shouldTransferERC20_whenNotTokenized() external {

	}

	function test_shouldTransferERC777_whenNotTokenized() external {

	}

	function test_shouldTransferERC1363_whenNotTokenized() external {

	}

	function test_shouldTransferERC721_whenNotTokenized() external {

	}

	function test_shouldTransferERC1155_whenNotTokenized() external {

	}
	// <--- Transfers not tokenized transfer rights

	// ---> Transfers tokenized transfer rights
	function test_shouldTransferERC20_whenEnoughUntokenized() external {

	}

	function test_shouldFailToTransferERC20_whenNotEnoughUntokenized() external {

	}

	function test_shouldTransferERC777_whenEnoughUntokenized() external {

	}

	function test_shouldFailToTransferERC777_whenNotEnoughUntokenized() external {

	}

	function test_shouldTransferERC1363_whenEnoughUntokenized() external {

	}

	function test_shouldFailToTransferERC1363_whenNotEnoughUntokenized() external {

	}

	function test_shouldFailToTransferERC721_whenTokenized() external {

	}

	function test_shouldTransferERC1155_whenEnoughUntokenizedForId() external {

	}

	function test_shouldFailToTransferERC1155_whenNotEnoughUntokenizedForId() external {

	}
	// <--- Transfers tokenized transfer rights
}


/*----------------------------------------------------------*|
|*  # MINT ATR TOKEN                                        *|
|*----------------------------------------------------------*/

contract PWNWallet_MintATRToken_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenSenderIsNotWalletOwner() external {

	}

	function test_shouldCallMintOnATRContract() external {

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

	}

	function test_shouldCallMintBatchOnATRContract() external {

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

	}

	function test_shouldCallBurnOnATRContract() external {

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

	}

	function test_shouldCallBurnBatchOnATRContract() external {

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

	}

	function test_shouldCallTransferAssetFromOnATRContract() external {

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

	}

	function test_shouldCallTransferFromOnATRContract() external {

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

	}

	function test_shouldCallSafeTransferFromOnATRContract() external {

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

	}

	function test_shouldCallSafeTransferFromWithBytesOnATRContract() external {

	}

}


/*----------------------------------------------------------*|
|*  # RESOLVE INVALID APPROVAL                              *|
|*----------------------------------------------------------*/

contract PWNWallet_ResolveInvalidApproval_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldResolveInvalidApproval_whenERC20TransferredByApprovedAddress() external {

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

	}

	function test_shouldTransferERC20() external {

	}

	function test_shouldTransferERC777() external {

	}

	function test_shouldTransferERC1363() external {

	}

	function test_shouldTransferERC721() external {

	}

	function test_shouldTransferERC1155() external {

	}

}


/*----------------------------------------------------------*|
|*  # HAS OPERATOR FOR                                      *|
|*----------------------------------------------------------*/

contract PWNWallet_HasOperatorFor_Test is PWNWalletTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldReturnTrue_whenCollectionHasOperator() external {

	}

	function test_shouldReturnTrue_whenERC77WithDefaultOperator() external {

	}

	function test_shouldReturnFalse_whenCollectionHasNoOperator() external {

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

	}

	function test_shouldReturnCorrectValue_whenOnERC1155BatchReceived() external {

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

	}

	function test_shouldSupport_IERC721Receiver() external {

	}

	function test_shouldSupport_IERC1155Receiver() external {

	}

	function test_shouldSupport_IERC165() external {

	}

}
