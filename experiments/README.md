# Experiment Catalog

## Overview
Each subfolder in this folder contains an experiment that can be executed by the
Nightking node. Experiment names are structured as `catalogXXX-xpYYY` (e.g.
`catalog001-xp004`).  Catalog numbers (`XXX`) are simply ways of grouping sets
of experiments, and experiment numbers (`YYY`) are usually just indicative of
the number of nodes that will be spun up in that experiment.

## Catalog Descriptions
The following experiment catalogs are currently available.

* [001](./catalog001.md) - Performance-optimized Tendermint networks using
  C-based LevelDB (instead of the default Go-based LevelDB).

## Contributing Experiment Catalogs
Please submit a pull request with your desired experiment catalog, following the
naming convention outlined in the **Overview** above. Please also include a
Markdown file outlining a description of what the catalog aims to test and how
to test it.

Please see [001](./catalog001.md) for an example of the bare minimum information
required for describing an experiment catalog.

