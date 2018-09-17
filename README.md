# AGP23

Work in progress. See [AGP23](https://github.com/aragon/governance/issues/32)

## Voting Daemon

As explained in the [AGP discussion](https://github.com/aragon/governance/issues/32#issuecomment-420733125) due to current limitations of transaction pathing and in an attempt to just one veto proposal for each main proposal in the Veto voting app, a small daemon app has been implemented that will be able to create veto proposals when a proposal in the Main voting app is created.

This Daemon computes the EVMScript needed for the Veto voting app to cast a vote in the Main voting app, and creates a proposal in the Veto voting app with it. If the proposal passes, then the Veto voting app will cast its vote in the Main voting app.

The Deamon supports connecting to a Vault to incentivize its execution when an action to create a vote can be performed. Because there is no way to run a daemon or a cron job on Ethereum, this is the simplest way to ensure that these actions will be executed in a timely manner.
