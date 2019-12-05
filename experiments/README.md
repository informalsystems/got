# Experiment Catalog

## Overview
Each subfolder in this folder contains an experiment that can be executed by the
Nightking node. Experiment names are structured as `XX-YYY-ZZZZ` (e.g.
`01-004-0100`).  Catalog numbers (`XX`) are simply ways of grouping sets of
experiments, and `YYY` are just indicative of the number of nodes that will be
spun up in that experiment.  Transaction rates (`ZZZZ`) indicate the intended
total transaction throughput (in transactions per second) as seen by the
Tendermint network as a whole.

## Catalog Descriptions
The following experiment catalogs are currently available.

* [01](./catalog01.md) - Performance-optimized Tendermint networks using C-based
  LevelDB (instead of the default Go-based LevelDB).

## Contributing Experiment Catalogs
Please submit a pull request with your desired experiment catalog, following the
naming convention outlined in the **Overview** above. Please also include a
Markdown file outlining a description of what the catalog aims to test and how
to test it.

Please see [01](./catalog01.md) for an example of the bare minimum information
required for describing an experiment catalog.

