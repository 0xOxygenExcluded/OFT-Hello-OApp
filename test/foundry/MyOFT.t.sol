// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import { IOFT, SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee } from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";

import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

import { MyOFT } from "../../contracts/MyOFT.sol"; 
import "forge-std/console.sol";


contract MyOFTTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    MyOFT private aOFT;
    MyOFT private bOFT;

    address private userA = address(0x1);
    address private userB = address(0x2);
    uint256 private initialBalance = 30 ether;


    function setUp() public virtual override {
        vm.deal(userA, 100 ether);
        vm.deal(userB, 100 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        aOFT = MyOFT(
            _deployOApp(type(MyOFT).creationCode, abi.encode("aOFT", "aOFT", address(endpoints[aEid]), address(this)))
        );

        bOFT = MyOFT(
            _deployOApp(type(MyOFT).creationCode, abi.encode("bOFT", "bOFT", address(endpoints[bEid]), address(this)))
        );

        address[] memory ofts = new address[](2);
        ofts[0] = address(aOFT);
        ofts[1] = address(bOFT);
        this.wireOApps(ofts);
    }


    function test_Constructor() public {
        assertEq(aOFT.owner(), address(this));
        assertEq(bOFT.owner(), address(this));

        assertEq(aOFT.token(), address(aOFT));
        assertEq(bOFT.token(), address(bOFT));
    }


    function test_Mint() public {
        aOFT.mint(userA, initialBalance);
        bOFT.mint(userB, initialBalance);

        assertEq(aOFT.balanceOf(userA), initialBalance);
        assertEq(bOFT.balanceOf(userB), initialBalance);
    }


    function test_SendOft() public {
        aOFT.mint(userA, initialBalance);
        bOFT.mint(userB, initialBalance);
        uint256 tokensToSend = 10 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userB),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aOFT.quoteSend(sendParam, false);

        assertEq(aOFT.balanceOf(userA), initialBalance);
        assertEq(bOFT.balanceOf(userB), initialBalance);

        vm.prank(userA);
        aOFT.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
        verifyPackets(bEid, addressToBytes32(address(bOFT)));

        console.log("userA balance aOFT", aOFT.balanceOf(userA));

        assertEq(aOFT.balanceOf(userA), initialBalance - tokensToSend);
        assertEq(bOFT.balanceOf(userB), initialBalance + tokensToSend);
    }
}