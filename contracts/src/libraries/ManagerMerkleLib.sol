// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title Manager Merkle Library
/// @author Kevin Lin (@kevinsslin)
/// @notice Builds manager leaf hashes, merkle roots, and proofs compatible with `ManagerWithMerkleVerification`.
library ManagerMerkleLib {
    /// @notice Reverted when leaf set is empty.
    error EmptyLeafSet();
    /// @notice Reverted when requested index is outside leaf array bounds.
    error LeafIndexOutOfBounds();
    /// @notice Reverted when call data does not contain a selector.
    error InvalidTargetData();

    /// @notice Canonical leaf payload used by manager merkle verification.
    struct ManageLeaf {
        /// @notice Decoder and sanitizer contract.
        address decoderAndSanitizer;
        /// @notice Target contract to call from BoringVault.
        address target;
        /// @notice Whether value passed to target call is non-zero.
        bool valueNonZero;
        /// @notice Target function selector.
        bytes4 selector;
        /// @notice Packed address arguments extracted by decoder/sanitizer.
        bytes packedArgumentAddresses;
    }

    /*//////////////////////////////////////////////////////////////
                         LEAF HASHING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Hashes a manager leaf.
    /// @param _leaf Canonical manager leaf payload.
    /// @return _leafHash Hashed leaf.
    function hashLeaf(ManageLeaf memory _leaf) internal pure returns (bytes32 _leafHash) {
        return hashLeaf(
            _leaf.decoderAndSanitizer, _leaf.target, _leaf.valueNonZero, _leaf.selector, _leaf.packedArgumentAddresses
        );
    }

    /// @notice Hashes a manager leaf from leaf components.
    /// @param _decoderAndSanitizer Decoder and sanitizer contract.
    /// @param _target Target contract to call from BoringVault.
    /// @param _valueNonZero True if call value is non-zero.
    /// @param _selector Target selector.
    /// @param _packedArgumentAddresses Packed address arguments from decoder.
    /// @return _leafHash Hashed leaf.
    function hashLeaf(
        address _decoderAndSanitizer,
        address _target,
        bool _valueNonZero,
        bytes4 _selector,
        bytes memory _packedArgumentAddresses
    ) internal pure returns (bytes32 _leafHash) {
        return keccak256(
            abi.encodePacked(_decoderAndSanitizer, _target, _valueNonZero, _selector, _packedArgumentAddresses)
        );
    }

    /// @notice Hashes a manager leaf directly from target calldata.
    /// @param _decoderAndSanitizer Decoder and sanitizer contract.
    /// @param _target Target contract to call from BoringVault.
    /// @param _value Value forwarded to target call.
    /// @param _targetData Target calldata.
    /// @param _packedArgumentAddresses Packed address arguments from decoder.
    /// @return _leafHash Hashed leaf.
    function hashLeafFromCallData(
        address _decoderAndSanitizer,
        address _target,
        uint256 _value,
        bytes memory _targetData,
        bytes memory _packedArgumentAddresses
    ) internal pure returns (bytes32 _leafHash) {
        if (_targetData.length < 4) revert InvalidTargetData();
        return hashLeaf(_decoderAndSanitizer, _target, _value > 0, bytes4(_targetData), _packedArgumentAddresses);
    }

    /*//////////////////////////////////////////////////////////////
                        MERKLE ROOT/PROOF HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Computes merkle root from leaf hashes.
    /// @dev Uses sorted pair hashing and duplicates odd leaves to match solmate verification.
    /// @param _leafHashes Leaf hash array.
    /// @return _root Merkle root.
    function root(bytes32[] memory _leafHashes) internal pure returns (bytes32 _root) {
        uint256 leafCount = _leafHashes.length;
        if (leafCount == 0) revert EmptyLeafSet();
        if (leafCount == 1) return _leafHashes[0];

        bytes32[] memory nodes = _copy(_leafHashes);
        uint256 nodeCount = leafCount;

        while (nodeCount > 1) {
            uint256 nextNodeCount = _nextLayerLength(nodeCount);

            for (uint256 i; i < nextNodeCount; ++i) {
                uint256 leftIndex = i * 2;
                uint256 rightIndex = leftIndex + 1;
                bytes32 leftNode = nodes[leftIndex];
                bytes32 rightNode = rightIndex < nodeCount ? nodes[rightIndex] : leftNode;
                nodes[i] = _hashPair(leftNode, rightNode);
            }

            nodeCount = nextNodeCount;
        }

        return nodes[0];
    }

    /// @notice Computes merkle proof for a leaf index.
    /// @dev Uses sorted pair hashing and duplicates odd leaves to match solmate verification.
    /// @param _leafHashes Leaf hash array.
    /// @param _leafIndex Leaf index to prove.
    /// @return _proof Merkle proof ordered from leaf layer upward.
    function proof(bytes32[] memory _leafHashes, uint256 _leafIndex) internal pure returns (bytes32[] memory _proof) {
        uint256 leafCount = _leafHashes.length;
        if (leafCount == 0) revert EmptyLeafSet();
        if (_leafIndex >= leafCount) revert LeafIndexOutOfBounds();
        if (leafCount == 1) return new bytes32[](0);

        bytes32[] memory nodes = _copy(_leafHashes);
        bytes32[] memory proofBuffer = new bytes32[](_treeHeight(leafCount));

        uint256 nodeCount = leafCount;
        uint256 currentIndex = _leafIndex;
        uint256 proofLength;

        while (nodeCount > 1) {
            uint256 siblingIndex = currentIndex ^ 1;
            bytes32 sibling = siblingIndex < nodeCount ? nodes[siblingIndex] : nodes[currentIndex];
            proofBuffer[proofLength] = sibling;
            proofLength++;

            uint256 nextNodeCount = _nextLayerLength(nodeCount);
            for (uint256 i; i < nextNodeCount; ++i) {
                uint256 leftIndex = i * 2;
                uint256 rightIndex = leftIndex + 1;
                bytes32 leftNode = nodes[leftIndex];
                bytes32 rightNode = rightIndex < nodeCount ? nodes[rightIndex] : leftNode;
                nodes[i] = _hashPair(leftNode, rightNode);
            }

            currentIndex /= 2;
            nodeCount = nextNodeCount;
        }

        _proof = new bytes32[](proofLength);
        for (uint256 i; i < proofLength; ++i) {
            _proof[i] = proofBuffer[i];
        }
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns next layer length when building merkle tree.
    /// @param _nodeCount Current layer node count.
    /// @return _nextNodeCount Next layer node count.
    function _nextLayerLength(uint256 _nodeCount) private pure returns (uint256 _nextNodeCount) {
        return (_nodeCount + 1) / 2;
    }

    /// @notice Returns tree height for a leaf count.
    /// @param _leafCount Leaf count.
    /// @return _height Tree height excluding leaf layer.
    function _treeHeight(uint256 _leafCount) private pure returns (uint256 _height) {
        uint256 nodeCount = _leafCount;
        while (nodeCount > 1) {
            _height++;
            nodeCount = _nextLayerLength(nodeCount);
        }
    }

    /// @notice Copies bytes32 array.
    /// @param _input Source array.
    /// @return _output Copied array.
    function _copy(bytes32[] memory _input) private pure returns (bytes32[] memory _output) {
        uint256 inputLength = _input.length;
        _output = new bytes32[](inputLength);
        for (uint256 i; i < inputLength; ++i) {
            _output[i] = _input[i];
        }
    }

    /// @notice Hashes a pair with deterministic sorting.
    /// @param _left First node.
    /// @param _right Second node.
    /// @return _pairHash Pair hash.
    function _hashPair(bytes32 _left, bytes32 _right) private pure returns (bytes32 _pairHash) {
        return _left < _right ? _efficientHash(_left, _right) : _efficientHash(_right, _left);
    }

    /// @notice Efficient 64-byte keccak hash.
    /// @param _left Left node.
    /// @param _right Right node.
    /// @return _hash Keccak256(_left, _right).
    function _efficientHash(bytes32 _left, bytes32 _right) private pure returns (bytes32 _hash) {
        assembly {
            mstore(0x00, _left)
            mstore(0x20, _right)
            _hash := keccak256(0x00, 0x40)
        }
    }
}
