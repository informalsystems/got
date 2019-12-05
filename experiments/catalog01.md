# Experiment Catalog 01

## Goal(s)
The goal of this catalog is to try to benchmark the performance of Tendermint
networks while excluding the impact of the transaction gossip mechanism. This
effectively measures the performance of the consensus mechanism.

## Tendermint Network Configuration

* The ABCI proxy application is the `kvstore` (NOTE: no replay protection)
* The mempool is turned off (i.e. no transaction gossip)
* No empty blocks are created
* All other parameters are optimized for the highest performance possible

## Load Testing Client Configuration
Due to the fact that the mempool is turned off, and to maximize the number of
transactions available to be committed each round, we need the load testing
client to continuously transmit transactions to all available endpoints.

## Results
TODO

