# Game of Tendermint

## How to create new experiments

- [General overview](#general-overview)
- [How to configure the Tendermint nodes](#how-to-configure-the-tendermint-nodes)
- [How to configure the seed node `config.toml`](#how-to-configure-the-seed-node-configtoml)
- [How to configure the global `config.toml`](#how-to-configure-the-global-configtoml)

### General overview
- Create a folder under the `experiments` folder. We'll call this the `demoxp` folder.
- Run the `tendermint testnet` command in the `demoxp` folder. (E.g.: `tendermint testnet --v 4 --n 1 --o .` for 4
validator nodes and 1 non-validator node)
  - Make sure you set the correct parameters (number of validators, etc).
  - Read through the [How to configure the Tendermint nodes](#how-to-configure-the-tendermint-nodes) section.
- Create a `seed` folder under `demoxp`.
  - If you add an extra non-validator node in the `testnet` command in the previous step, you can easily reconfigure
  that node as the seed node for the Nightking server by renaming the folder name to `seed`. (E.g.: `mv node4 seed` in
  the previous example.)
  - Read through the [How to configure the seed node `config.toml`](#how-to-configure-the-seed-node-configtoml) section.
- [optional] Copy the `genesis.json` to the `demoxp` folder and remove it from the subfolders.
  - This way, if you decide to change the genesis.json, you only have to do it in one place.
  - The `genesis.json` in the subfolders have precedence over this "experiment-global" `genesis.json` in the `demoxp` folder.
- Create `config.toml` in the `demoxp` folder.
  - Read through the [How to configure the global `config.toml`](#how-to-configure-the-global-configtoml) section.

All files are considered templates parsed by the [Go text/template package](https://golang.org/pkg/text/template/) using
[stemplate](https://github.com/freshautomations/stemplate). If you want to programmatically add variables
to any of these files, you will need to get yourself familiar with the template schema and the tool. The most common
usage is described below.

### How to configure the Tendermint nodes
- `moniker`: Set it to `"node{{.ID}}"` or similar. Use the `{{.ID}}` template variable to add an ID number.
- `persistent_peers`: Set it to `""`. (empty value)
- `seeds`: Set it to `"{{.NIGHTKING_SEED_NODE_ID}}@{{.NIGHTKING_IP}}:26656"`. Mandatory.
- `prometheus`: Set it to `true`. Mandatory.
- `laddr`: Set it to `"tcp://0.0.0.0:26657"`. Mandatory.
- `proxy_app`: Set it to `"kvstore"`, if you have nothing running on top of Tendermint.
- Unfortunately, there's no way to set persistent peers (yet), because the IP address of the peers are unknown at the
time of writing the experiment configuration.
- The original configurations only differ in the moniker (which you set to a generic one with the `{{.ID}}` template
variable). If all configs are the same, it is enough to create one `node/config` folder and copy the `config.toml` there.
It's advisable to remove the `config.toml`s from the previous `node0`,`node1`, etc folders (that were created by the
`testnet` command) because the specific `nodeX` folder takes precedence over the generic `node` folder files.

### How to configure the seed node `config.toml`
- Use the steps from [How to configure the Tendermint nodes](#how-to-configure-the-tendermint-nodes) with these changes:
  - `moniker`: do NOT use the `{{.ID}}` template variable. (Call it "Nightking seed node" or similar instead.)
  - `seeds`: keep it empty.
  - At the time of writing, disabling seed mode on the seed server achieved better results in connecting all nodes, so
  do NOT enable `seed_mode`.

### How to configure the global `config.toml`
The global `config.toml` has several parameters that describe the experiment.

#### starks
Definition: (int) Number of Stark servers to spawn. (This includes validator and non-validator servers both. Do NOT
include the seed node in this number.)

#### starks_zones
Definition: (list) List of AWS regions to put the Stark servers into. It should have exactly as many elements as the
number defined in `starks`. The possible values are listed in [How to package a Nightking AMI image](BUILD.md) under
`The build process` section.

#### whitewalkers
Definition: (int) Number of Whitewalker servers to spawn.

#### whitewalkers_zones
Definition: (list) List of AWS regions to put the Whitewalker servers into. It should have exactly as many elements as
the number defined in `whitewalkers`. The possible values are listed in [How to package a Nightking AMI image](BUILD.md)
under `The build process` section.

#### instance_type
Definition: (string) AWS EC2 Instance type for both Starks and Whitewalkers.

#### [tm_load_test] section

All variables in the `tm_load_test` section are described by the
[TM-Load-Test application](https://github.com/interchainio/tm-load-test).
