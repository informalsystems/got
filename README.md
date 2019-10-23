# Game of Tendermint

The Game of Tendermint (GoT) is an infrastructure framework for research projects.
The infrastructure is based on Amazon's AWS EC2 images and instances.

Documentation can be found here:

- [An example](THESIS.md) - if you want to check out how this works
- [How to run packaged experiments](RUN.md) - if you need to run a set of experiments
- [Quickstart guide](QUICKSTART.md) - if you already know how to do this and you just need reminders
- [How to package a Nightking AMI image](BUILD.md) - if you want to build a new Nightking server from source
- [How to create new experiments](XP.md) - if you want to write your own experiments

## Glossary

### Nightking
Nightking is the master server executing the research experiments. Only one server has to be spawned and it will
automatically create additional servers and services for the experiments. It cleans up the added servers at the end of
the experiments.

### Whitewalker
Whitewalkers are load-testing servers that the Nightking builds.
They run the `tm-load-test` tool configured by the Nightking based on the requested experiment.

A group of Whitewalker servers is called the Army of Whitewalkers.

### Stark
Starks are tendermint node servers. They launch tendermint, searching for other nodes through the Nightking's seed node.

The Whitewalkers run their load tests on the Stark servers.

A group of Stark servers is called the Family of Starks, or simply Winterfell.
