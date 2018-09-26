import "./daemon/VotingDaemon.sol";

import "@aragon/apps-voting/contracts/Voting.sol";
import "@aragon/apps-vault/contracts/Vault.sol";
import "@aragon/apps-token-manager/contracts/TokenManager.sol";
import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";

import "@aragon/kits-bare/contracts/KitBase.sol";

import "@aragon/os/contracts/apm/APMNamehash.sol";
import "@aragon/os/contracts/common/EtherTokenConstant.sol";


contract AGP23Kit is KitBase, APMNamehash, EtherTokenConstant {
    MiniMeTokenFactory tokenFactory;
    uint256 constant public MAIN_VOTING_SUPPORT = 50 * 10**16;
    uint256 constant public MAIN_VOTING_ACCEPTANCE = 33 * 10**16; // not exact but works, quorum of 1 would work as well
    uint64 constant public MAIN_VOTING_VOTE_TIME = 4 weeks;

    uint256 constant public VETO_VOTING_SUPPORT = 50 * 10**16;
    uint256 constant public VETO_VOTING_ACCEPTANCE = 1 * 10**16;
    uint64 constant public VETO_VOTING_VOTE_TIME = 3 weeks;

    uint256 constant public ETH_DAEMON_REWARD = 1 * 10**16; // 0.01 ETH

    bytes32 constant public daemonAppId = apmNamehash("voting-daemon");
    bytes32 constant public votingAppId = apmNamehash("voting");
    bytes32 constant public vaultAppId = apmNamehash("vault");
    bytes32 constant public tokenManagerAppId = apmNamehash("token-manager");

    constructor (ENS _ens)
        KitBase(DAOFactory(0), _ens) {

        tokenFactory = new MiniMeTokenFactory();
        fac = KitBase(latestVersionAppBase(apmNamehash("bare-kit"))).fac();
    }

    function newInstance(MiniMeToken ant, address[] voters) external returns (Kernel dao) {
        require(voters.length == 2);

        dao = fac.newDAO(this);
        ACL acl = ACL(dao.acl());

        acl.createPermission(this, dao, dao.APP_MANAGER_ROLE(), this);

        TokenManager tokenManager = TokenManager(dao.newAppInstance(tokenManagerAppId, latestVersionAppBase(tokenManagerAppId)));
        Voting mainVoting = Voting(dao.newAppInstance(votingAppId, latestVersionAppBase(votingAppId)));
        Voting vetoVoting = Voting(dao.newAppInstance(votingAppId, latestVersionAppBase(votingAppId)));
        Vault vault = Vault(dao.newAppInstance(vaultAppId, latestVersionAppBase(vaultAppId)));
        VotingDaemon votingDaemon = VotingDaemon(dao.newAppInstance(daemonAppId, latestVersionAppBase(daemonAppId)));

        MiniMeToken token = tokenFactory.createCloneToken(MiniMeToken(0), 0, "AGP23", 0, "AGP23", true);
        token.changeController(tokenManager);

        votingDaemon.initialize(
            mainVoting,
            vetoVoting,
            false,
            vault,
            ETH,
            ETH_DAEMON_REWARD
        );
        vetoVoting.initialize(
            ant,
            VETO_VOTING_SUPPORT,
            VETO_VOTING_ACCEPTANCE,
            VETO_VOTING_VOTE_TIME
        );
        mainVoting.initialize(
            token,
            MAIN_VOTING_SUPPORT,
            MAIN_VOTING_ACCEPTANCE,
            MAIN_VOTING_VOTE_TIME
        );

        vault.initialize();
        tokenManager.initialize(token, false, 1);

        acl.createPermission(this, tokenManager, tokenManager.MINT_ROLE(), this);
        tokenManager.mint(voters[0], 1);
        tokenManager.mint(voters[1], 1);
        tokenManager.mint(vetoVoting, 1);
        cleanupPermission(acl, address(1), tokenManager, tokenManager.MINT_ROLE()); // no more minting

        acl.createPermission(mainVoting, vault, vault.TRANSFER_ROLE(), mainVoting);
        acl.createPermission(voters[0], mainVoting, mainVoting.CREATE_VOTES_ROLE(), mainVoting);
        acl.createPermission(votingDaemon, vetoVoting, vetoVoting.CREATE_VOTES_ROLE(), mainVoting);

        cleanupDAOPermissions(dao, acl, mainVoting);

        emit DeployInstance(dao);
    }
}