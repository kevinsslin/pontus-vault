// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC20Minimal} from "../interfaces/IERC20Minimal.sol";

library SafeTransferLib {
    error SafeTransferFailed();
    error SafeApproveFailed();

    function safeTransfer(IERC20Minimal token, address to, uint256 amount) internal {
        _callOptionalReturn(
            token, abi.encodeWithSelector(token.transfer.selector, to, amount), SafeTransferFailed.selector
        );
    }

    function safeTransferFrom(IERC20Minimal token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(
            token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount), SafeTransferFailed.selector
        );
    }

    function forceApprove(IERC20Minimal token, address spender, uint256 amount) internal {
        bytes memory callData = abi.encodeWithSelector(token.approve.selector, spender, amount);
        if (!_callOptionalReturnBool(token, callData)) {
            _callOptionalReturn(
                token, abi.encodeWithSelector(token.approve.selector, spender, 0), SafeApproveFailed.selector
            );
            _callOptionalReturn(token, callData, SafeApproveFailed.selector);
        }
    }

    function _callOptionalReturn(IERC20Minimal token, bytes memory data, bytes4 errorSelector) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success || (returndata.length != 0 && !abi.decode(returndata, (bool)))) {
            assembly {
                mstore(0x00, errorSelector)
                revert(0x00, 0x04)
            }
        }
    }

    function _callOptionalReturnBool(IERC20Minimal token, bytes memory data) private returns (bool) {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            return false;
        }
        if (returndata.length == 0) {
            return true;
        }
        return abi.decode(returndata, (bool));
    }
}
