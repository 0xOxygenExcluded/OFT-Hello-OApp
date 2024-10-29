// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


import { MyOApp } from "../../contracts/MyOApp.sol";

import { IOAppOptionsType3, EnforcedOptionParam } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee } from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "forge-std/console.sol";

import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";


contract MyOAppTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    string private aChainName = "A";
    string private bChainName = "B";

    MyOApp private aOApp;
    MyOApp private bOApp;

    address private userA = address(0x1);
    address private userB = address(0x2);
    uint256 private initialBalance = 30 ether;


    function setUp() public virtual override {
        vm.deal(userA, 100 ether);
        vm.deal(userB, 100 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        aOApp = MyOApp(_deployOApp(type(MyOApp).creationCode, abi.encode(address(endpoints[aEid]), address(this), aChainName)));

        bOApp = MyOApp(_deployOApp(type(MyOApp).creationCode, abi.encode(address(endpoints[bEid]), address(this), bChainName)));

        address[] memory oapps = new address[](2);
        oapps[0] = address(aOApp);
        oapps[1] = address(bOApp);
        this.wireOApps(oapps);
    }


    function test_Constructor() public {
        assertEq(aOApp.owner(), address(this));
        assertEq(bOApp.owner(), address(this));

        assertEq(address(aOApp.endpoint()), address(endpoints[aEid]));
        assertEq(address(bOApp.endpoint()), address(endpoints[bEid]));
    }


    function test_SendHelloMessage() public {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        assertEq(bOApp.data(), "Nothing received yet.");

        MessagingFee memory fee = aOApp.quote(bEid, string.concat("Hello ", bOApp.chainName()), options, false);

        vm.prank(userA);
        aOApp.send{value: fee.nativeFee}(bEid, string.concat("Hello ", bOApp.chainName()), options);        
        verifyPackets(bEid, addressToBytes32(address(bOApp)));

        assertEq(bOApp.data(), string.concat("Hello ", bOApp.chainName()));
    }
}
