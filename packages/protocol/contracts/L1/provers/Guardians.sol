// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "../../common/EssentialContract.sol";
import "../TaikoData.sol";

/// @title Guardians
abstract contract Guardians is EssentialContract {
    uint256 public constant MIN_NUM_GUARDIANS = 5;

    mapping(address guardian => uint256 id) public guardianIds; // slot 1
    mapping(uint32 version => mapping(bytes32 => uint256 approvalBits)) internal _approvals;
    address[] public guardians; // slot 3
    uint32 public version; // slot 4
    uint32 public minGuardians;

    uint256[46] private __gap;

    event GuardiansUpdated(uint32 version, address[] guardians);
    event Approved(uint256 indexed operationId, uint256 approvalBits, bool proofSubmitted);

    error INVALID_GUARDIAN();
    error INVALID_GUARDIAN_SET();
    error INVALID_MIN_GUARDIANS();
    error INVALID_PROOF();

    /// @notice Set the set of guardians
    /// @param _newGuardians The new set of guardians
    /// @param _minGuardians The minimum required to sign
    function setGuardians(
        address[] memory _newGuardians,
        uint8 _minGuardians
    )
        external
        onlyOwner
        nonReentrant
    {
        if (_newGuardians.length < MIN_NUM_GUARDIANS || _newGuardians.length > type(uint8).max) {
            revert INVALID_GUARDIAN_SET();
        }
        if (_minGuardians < _newGuardians.length >> 1 || _minGuardians > _newGuardians.length) {
            revert INVALID_MIN_GUARDIANS();
        }

        // Delete current guardians data
        uint256 guardiansLength = guardians.length;
        for (uint256 i; i < guardiansLength; ++i) {
            delete guardianIds[guardians[i]];
        }
        assembly {
            sstore(guardians.slot, 0)
        }

        for (uint256 i = 0; i < _newGuardians.length;) {
            address guardian = _newGuardians[i];
            if (guardian == address(0)) revert INVALID_GUARDIAN();
            if (guardianIds[guardian] != 0) revert INVALID_GUARDIAN_SET();

            // Save and index the guardian
            guardians.push(guardian);
            guardianIds[guardian] = ++i;
        }

        minGuardians = _minGuardians;
        emit GuardiansUpdated(++version, _newGuardians);
    }

    function isApproved(bytes32 hash) public view returns (bool) {
        return isApproved(_approvals[version][hash]);
    }

    function numGuardians() public view returns (uint256) {
        return guardians.length;
    }

    function approve(uint256 operationId, bytes32 hash) internal returns (bool approved) {
        uint256 id = guardianIds[msg.sender];
        if (id == 0) revert INVALID_GUARDIAN();

        unchecked {
            _approvals[version][hash] |= 1 << (id - 1);
        }

        uint256 _approval = _approvals[version][hash];
        approved = isApproved(_approval);
        emit Approved(operationId, _approval, approved);
    }

    function deleteApproval(bytes32 hash) internal {
        delete _approvals[version][hash];
    }

    function isApproved(uint256 approvalBits) internal view returns (bool) {
        uint256 count;
        uint256 bits = approvalBits;
        uint256 guardiansLength = guardians.length;
        unchecked {
            for (uint256 i; i < guardiansLength; ++i) {
                if (bits & 1 == 1) ++count;
                if (count == minGuardians) return true;
                bits >>= 1;
            }
        }
        return false;
    }
}
