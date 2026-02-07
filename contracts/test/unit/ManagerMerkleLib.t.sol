// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {MerkleProofLib} from "../../lib/boring-vault/lib/solmate/src/utils/MerkleProofLib.sol";

import {ManagerMerkleLib} from "../../src/libraries/ManagerMerkleLib.sol";

import {BaseTest} from "../BaseTest.sol";

contract MerkleProofVerifierHarness {
    function verify(bytes32[] calldata _proof, bytes32 _root, bytes32 _leaf) external pure returns (bool _isValid) {
        return MerkleProofLib.verify(_proof, _root, _leaf);
    }
}

contract ManagerMerkleHarness {
    function proof(bytes32[] memory _leafHashes, uint256 _leafIndex) external pure returns (bytes32[] memory _proof) {
        return ManagerMerkleLib.proof(_leafHashes, _leafIndex);
    }
}

contract ManagerMerkleLibTest is BaseTest {
    MerkleProofVerifierHarness internal verifier;
    ManagerMerkleHarness internal managerMerkleHarness;

    function setUp() public override {
        BaseTest.setUp();
        verifier = new MerkleProofVerifierHarness();
        managerMerkleHarness = new ManagerMerkleHarness();
    }

    function test_hash_leaf_from_call_data_matches_canonical_encoding() public pure {
        address decoder = address(0xD1);
        address target = address(0xA1);
        uint256 value = 0;
        bytes memory callData = abi.encodeWithSelector(bytes4(keccak256("foo(address,uint256)")), address(0xB1), 7);
        bytes memory packedAddresses = abi.encodePacked(address(0xB1));

        bytes32 expected =
            keccak256(abi.encodePacked(decoder, target, false, bytes4(callData), abi.encodePacked(address(0xB1))));

        bytes32 actual = ManagerMerkleLib.hashLeafFromCallData(decoder, target, value, callData, packedAddresses);
        assertEq(actual, expected);
    }

    function test_root_and_proof_verify_for_every_leaf_even_and_odd_trees() public {
        bytes32[] memory leaves = new bytes32[](5);
        leaves[0] = keccak256("leaf-0");
        leaves[1] = keccak256("leaf-1");
        leaves[2] = keccak256("leaf-2");
        leaves[3] = keccak256("leaf-3");
        leaves[4] = keccak256("leaf-4");

        bytes32 rootHash = ManagerMerkleLib.root(leaves);

        for (uint256 i; i < leaves.length; ++i) {
            bytes32[] memory proof = ManagerMerkleLib.proof(leaves, i);
            bool isValid = verifier.verify(proof, rootHash, leaves[i]);
            assertTrue(isValid);
        }
    }

    function test_proof_reverts_for_out_of_bounds_leaf_index() public {
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256("leaf");
        vm.expectRevert(ManagerMerkleLib.LeafIndexOutOfBounds.selector);
        managerMerkleHarness.proof(leaves, 1);
    }
}
