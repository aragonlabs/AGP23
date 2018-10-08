const { assertRevert } = require('@aragon/test-helpers/assertThrow')
const { EMPTY_SCRIPT } = require('@aragon/test-helpers/evmScript')
const Voting = artifacts.require('Voting')
const VotingDaemon = artifacts.require('VotingDaemon')

const DAOFactory = artifacts.require('@aragon/os/contracts/factory/DAOFactory')
const EVMScriptRegistryFactory = artifacts.require('@aragon/os/contracts/factory/EVMScriptRegistryFactory')
const ACL = artifacts.require('@aragon/os/contracts/acl/ACL')
const Kernel = artifacts.require('@aragon/os/contracts/kernel/Kernel')

const MiniMeToken = artifacts.require('@aragon/apps-shared-minime/contracts/MiniMeToken')

const NULL_ADDRESS = '0x00'

const bigExp = (x, y) => new web3.BigNumber(x).times(new web3.BigNumber(10).toPower(y))
const pct16 = x => bigExp(x, 16)
const createdVoteId = receipt => receipt.logs.filter(x => x.event == 'StartVote')[0].args.voteId

contract('VotingDaemon', accounts => {
    let mainVoting, childVoting, daemon

    const root = accounts[0]
    const holder51 = accounts[1]
    const holder49 = accounts[2]

    const supportRequired = pct16(50)
    const minAcceptanceQuorum = pct16(50)
    const votingTime = 10000

    let APP_MANAGER_ROLE, CREATE_VOTES_ROLE
    const VOTING_APP_ID = '0x1234'
    const DAEMON_APP_ID = '0x3456'

    before(async () => {
        const kernelBase = await Kernel.new(true) // petrify immediately
        const aclBase = await ACL.new()
        const regFact = await EVMScriptRegistryFactory.new()
        daoFact = await DAOFactory.new(kernelBase.address, aclBase.address, regFact.address)
        votingBase = await Voting.new()
        daemonBase = await VotingDaemon.new()

        // Setup constants
        APP_MANAGER_ROLE = await kernelBase.APP_MANAGER_ROLE()
        CREATE_VOTES_ROLE = await votingBase.CREATE_VOTES_ROLE()
    })

    beforeEach(async () => {
        const r = await daoFact.newDAO(root)
        const dao = Kernel.at(r.logs.filter(l => l.event == 'DeployDAO')[0].args.dao)
        const acl = ACL.at(await dao.acl())

        await acl.createPermission(root, dao.address, APP_MANAGER_ROLE, root, { from: root })

        const receipt1 = await dao.newAppInstance(VOTING_APP_ID, votingBase.address, { from: root })
        mainVoting = Voting.at(receipt1.logs.filter(l => l.event == 'NewAppProxy')[0].args.proxy)

        const receipt2 = await dao.newAppInstance(VOTING_APP_ID, votingBase.address, { from: root })
        childVoting = Voting.at(receipt2.logs.filter(l => l.event == 'NewAppProxy')[0].args.proxy)

        const receipt3 = await dao.newAppInstance(DAEMON_APP_ID, daemonBase.address, { from: root })
        daemon = VotingDaemon.at(receipt3.logs.filter(l => l.event == 'NewAppProxy')[0].args.proxy)

        const childToken = await MiniMeToken.new(NULL_ADDRESS, NULL_ADDRESS, 0, 'n', 0, 'n', true)
        await childToken.generateTokens(holder51, 51)
        await childToken.generateTokens(holder49, 49)

        const mainToken = await MiniMeToken.new(NULL_ADDRESS, NULL_ADDRESS, 0, 'n', 0, 'n', true)
        await mainToken.generateTokens(childVoting.address, 1)

        await mainVoting.initialize(mainToken.address, supportRequired, minAcceptanceQuorum, votingTime)
        await childVoting.initialize(childToken.address, supportRequired, minAcceptanceQuorum, votingTime)

        await acl.createPermission(root, mainVoting.address, CREATE_VOTES_ROLE, root, { from: root })
        await acl.createPermission(daemon.address, childVoting.address, CREATE_VOTES_ROLE, root, { from: root })
    })

    const SETUPS = [
        {
            vote: true,
            open: false,
            executed: true,
            voterState: 1
        },
        {
            vote: false,
            open: true,
            executed: false,
            voterState: 2
        }
    ]

    for (const { vote, open, executed, voterState } of SETUPS) {
        context(`childVoting app votes ${vote ? 'YEA' : 'NAY'}`, () => {
            beforeEach(async () => {
                await daemon.initialize(mainVoting.address, childVoting.address, vote, NULL_ADDRESS, NULL_ADDRESS, 0)
            })

            it('daemon creates vote', async () => {
                const mainProposalId = createdVoteId(await mainVoting.newVote(EMPTY_SCRIPT, 'empty', false, false, { from: root }))
                const receipt = await daemon.execute(mainProposalId)
                const { childProposalId } = receipt.logs.filter(x => x.event == 'CreateChildProposal')[0].args

                await childVoting.vote(childProposalId, true, true, { from: holder51 }) // executes
                const [isOpen, isExecuted] = await mainVoting.getVote(mainProposalId)

                assert.equal(isOpen, open, 'Open state should match')
                assert.equal(isExecuted, executed, 'Executed state should match')
                assert.equal(await mainVoting.getVoterState(mainProposalId, childVoting.address), voterState, 'Voter state should match')
            })
        })
    }
})