// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface WithdrawalInterface {
    /**
     * @notice transfer HSO held by the contract belonging to msg.sender to
     * another address
     * @param recipient is the address to send the HSO to
     * @param amount is the amount of HSO to send
     */
    function withdraw(address recipient, uint256 amount) external;

    /**
     * @notice query the available amount of HSO to withdraw by msg.sender
     */
    function withdrawable() external view returns (uint256);
}
