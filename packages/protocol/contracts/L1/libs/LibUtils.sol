// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../common/IAddressResolver.sol";
import "../../common/LibStrings.sol";
import "../../libs/LibMath.sol";
import "../tiers/ITierProvider.sol";
import "../tiers/ITierRouter.sol";
import "../TaikoData.sol";

/// @title LibUtils
/// @notice A library that offers helper functions.
/// @custom:security-contact security@taiko.xyz
library LibUtils {
    using LibMath for uint256;

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_BLOCK_MISMATCH();
    error L1_INVALID_BLOCK_ID();
    error L1_TRANSITION_NOT_FOUND();
    error L1_UNEXPECTED_TRANSITION_ID();

    /// @notice This function will revert if the transition is not found.
    /// @dev Retrieves the transition with a given parentHash.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockId Id of the block.
    /// @param _parentHash Parent hash of the block.
    /// @return The state transition data of the block.
    function getTransition(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        uint64 _blockId,
        bytes32 _parentHash
    )
        internal
        view
        returns (TaikoData.TransitionState storage)
    {
        (TaikoData.Block storage blk, uint64 slot) = getBlock(_state, _config, _blockId);

        uint32 tid = getTransitionId(_state, blk, slot, _parentHash);
        if (tid == 0) revert L1_TRANSITION_NOT_FOUND();

        return _state.transitions[slot][tid];
    }

    /// @notice This function will revert if the transition is not found.
    /// @dev Retrieves the transition with a given parentHash.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockId Id of the block.
    /// @param _tid The transition id.
    /// @return The state transition data of the block.
    function getTransition(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        uint64 _blockId,
        uint32 _tid
    )
        internal
        view
        returns (TaikoData.TransitionState storage)
    {
        (TaikoData.Block storage blk, uint64 slot) = getBlock(_state, _config, _blockId);

        if (_tid == 0 || _tid >= blk.nextTransitionId) revert L1_TRANSITION_NOT_FOUND();
        return _state.transitions[slot][_tid];
    }

    /// @dev Retrieves a block based on its ID.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _blockId Id of the block.
    function getBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        uint64 _blockId
    )
        internal
        view
        returns (TaikoData.Block storage blk_, uint64 slot_)
    {
        slot_ = _blockId % _config.blockRingBufferSize;
        blk_ = _state.blocks[slot_];
        if (blk_.blockId != _blockId) revert L1_INVALID_BLOCK_ID();
    }

    /// @dev Retrieves the ID of the transition with a given parentHash.
    /// This function will return 0 if the transition is not found.
    function getTransitionId(
        TaikoData.State storage _state,
        TaikoData.Block storage _blk,
        uint64 _slot,
        bytes32 _parentHash
    )
        internal
        view
        returns (uint32 tid_)
    {
        if (_state.transitions[_slot][1].key == _parentHash) {
            tid_ = 1;
            if (tid_ >= _blk.nextTransitionId) revert L1_UNEXPECTED_TRANSITION_ID();
        } else {
            tid_ = _state.transitionIds[_blk.blockId][_parentHash];
            if (tid_ != 0 && tid_ >= _blk.nextTransitionId) revert L1_UNEXPECTED_TRANSITION_ID();
        }
    }

    function isPostDeadline(
        uint256 _tsTimestamp,
        uint256 _lastUnpausedAt,
        uint256 _windowMinutes
    )
        internal
        view
        returns (bool)
    {
        unchecked {
            uint256 deadline = _tsTimestamp.max(_lastUnpausedAt) + _windowMinutes * 60;
            return block.timestamp >= deadline;
        }
    }

    function hashMetadata(TaikoData.BlockMetadata memory _meta) internal pure returns (bytes32) {
        return _meta.livenessBond != 0
            ? keccak256(abi.encode(_meta))
            : keccak256(abi.encode(metaV2ToV1(_meta)));
    }

    function metaV1ToV2(TaikoData.BlockMetadataV1 memory _v1)
        internal
        pure
        returns (TaikoData.BlockMetadata memory)
    {
        return TaikoData.BlockMetadata({
            l1Hash: _v1.l1Hash,
            difficulty: _v1.difficulty,
            blobHash: _v1.blobHash,
            extraData: _v1.extraData,
            depositsHash: _v1.depositsHash,
            coinbase: _v1.coinbase,
            id: _v1.id,
            gasLimit: _v1.gasLimit,
            timestamp: _v1.timestamp,
            l1Height: _v1.l1Height,
            minTier: _v1.minTier,
            blobUsed: _v1.blobUsed,
            parentMetaHash: _v1.parentMetaHash,
            sender: _v1.sender,
            livenessBond: 0
        });
    }

    function metaV2ToV1(TaikoData.BlockMetadata memory _v2)
        internal
        pure
        returns (TaikoData.BlockMetadataV1 memory)
    {
        return TaikoData.BlockMetadataV1({
            l1Hash: _v2.l1Hash,
            difficulty: _v2.difficulty,
            blobHash: _v2.blobHash,
            extraData: _v2.extraData,
            depositsHash: _v2.depositsHash,
            coinbase: _v2.coinbase,
            id: _v2.id,
            gasLimit: _v2.gasLimit,
            timestamp: _v2.timestamp,
            l1Height: _v2.l1Height,
            minTier: _v2.minTier,
            blobUsed: _v2.blobUsed,
            parentMetaHash: _v2.parentMetaHash,
            sender: _v2.sender
        });
    }
}
