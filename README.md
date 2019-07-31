# Game of Tendermint

The Game of Tendermint (GoT) is an infrastructure framework for research projects.
The infrastructure is based on Amazon's AWS EC2 images and instances.

Documentation is coming soon.

## Nightking
Nightking the master server executing the research experiment.
Only one server has to be spawned and it will automatically create additional
servers and services for the experiment.

## Whitewalker
Whitewalkers are load-testing servers that the Nightking builds.
They run the `tm-load-test` tool configured by the Nightking based on the requested experiment.

A group of Whitewalker servers is called the Army of Whitewalkers.

## Stark
Starks are tendermint node servers. They launch tendermint, searching for other nodes through the Nightking's seed node.

The Whitewalkers run their load tests on the Stark servers.

A group of Stark servers is called the Family of Starks, or simply Winterfell.
