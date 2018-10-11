pragma solidity 0.4.24;

import "@aragon/os/contracts/apps/AragonApp.sol";
import "@aragon/apps-vault/contracts/Vault.sol";
import "@aragon/apps-voting/contracts/Voting.sol";

import "./Daemon.sol";


contract VotingDaemon is AragonApp, Daemon {
    Voting public mainVoting;
    Voting public childVoting;
    bool public castingVote;
    address internal rewardToken;
    uint256 internal rewardAmount;
    Vault internal vault_;

    mapping (uint256 => bool) public childProposalCreated;

    event CreateChildProposal(uint256 indexed mainProposalId, uint256 childProposalId);

    function initialize(Voting _mainVoting, Voting _childVoting, bool _castingVote, Vault _vault, address _rewardToken, uint256 _rewardAmount) onlyInit {
        initialized();

        mainVoting = _mainVoting;
        childVoting = _childVoting;
        castingVote = _castingVote;
        vault_ = _vault;
        rewardToken = _rewardToken;
        rewardAmount = _rewardAmount;
    }

    function canExecute(uint256 mainProposalId) public view returns (bool) {
        return !childProposalCreated[mainProposalId] && mainVoting.canVote(mainProposalId, address(childVoting));
    }

    function vault() public view returns (Vault) {
        return vault_;
    }

    function _execute(uint256 mainProposalId) internal {
        bytes memory script = _computeScript(mainVoting, mainProposalId, castingVote, true);
        uint256 childProposalId = childVoting.newVote(script, "", false, false);

        childProposalCreated[mainProposalId] = true; // reentrancy is not a concern, mainVoting and childVoting are trusted

        emit CreateChildProposal(mainProposalId, childProposalId);
    }

    function _computeScript(Voting voting, uint256 proposalId, bool supports, bool executesIfDecided) internal pure returns (bytes memory) {
        bytes4 sig = voting.vote.selector;
        bytes memory calldata = abi.encodeWithSelector(sig, proposalId, supports, executesIfDecided);
        uint32 scriptId = 1;
        uint32 calldataLength = uint32(calldata.length);

        return abi.encodePacked(scriptId, address(voting), calldataLength, calldata);
    }

    function executionReward(uint256) public view returns (address token, uint256 amount) {
        return (rewardToken, rewardAmount);
    }
}