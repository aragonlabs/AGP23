pragma solidity 0.4.24;

import "@aragon/apps-vault/contracts/Vault.sol";


contract Daemon {
    function execute(uint256 payload) external {
        require(canExecute(payload));

        _execute(payload);

        address rewardToken;
        uint256 rewardAmount;
        (rewardToken, rewardAmount) = executionReward(payload);

        if (rewardAmount > 0) {
            vault().transfer(rewardToken, msg.sender, rewardAmount);
        }
    }

    function canExecute(uint256) public view returns (bool);
    function vault() public view returns (Vault);
    function executionReward(uint256) public view returns (address token, uint256 amount);

    function _execute(uint256) internal;
}
