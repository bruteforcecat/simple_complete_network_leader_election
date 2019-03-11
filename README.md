# Scnle
A Simple Implementation of Leader Election

Leader Selection is important for distributed system. It's incredibly useful for case like ensuring state consistency.

In this simple algorithm, we will assume all nodes are connected and know each others which means it's a complete network.

Right now, the node id is based on the node atom which means that adding new node will always cause new election as its id is always the greatest.

## Example

```bash
$iex --name node_1@127.0.0.1 -S mix

$iex --name node_2@127.0.0.1 -S mix

$iex --name node_3@127.0.0.1 -S mix

# and then you can see reelection after kill application of the current leader by exiting iex

```

## Test

```bash
# might take a bit time(20s in my 2015 macbook) as one of the test is spawning 20 node in local cluster
mix test
```

## Development

```bash
# Run Credo
$mix credo

# Run Dialyzer
$mix dialyzer

```