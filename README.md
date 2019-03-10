# Scnle
A Simple Implementation of Leader Election

Leader Selection is important for distributed system. It's incredibly useful for case like ensuring state consistency.

In this simple algorithm, we will assume all nodes are connected and know each others which means it's a complete network.

## Example

```bash
$iex --name node_1@127.0.0.1 -S mix

$iex --name node_2@127.0.0.1 -S mix

$iex --name node_3@127.0.0.1 -S mix

```

## Test

```bash
# might take a bit time(20s in my 2015 macbook) as one of the test is spawning 20 node in local cluster
mix test
```