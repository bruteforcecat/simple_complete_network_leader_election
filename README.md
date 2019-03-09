# Scnle
A Simple Implementation of Leader Election

Leader Selection is important for distributed system. It's incredibly useful for case like ensuring state consistency.

In this simple algorithm, we will assume all nodes are connected and know each others which means it's a complete network.

## Example

```bash
$iex --name node_1@127.0.0.1 -S mix

$INITIAL_PEER="node_1@127.0.0.1" iex --name node_2@127.0.0.1 -S mix

$INITIAL_PEER="node_1@127.0.0.1" iex --name node_3@127.0.0.1 -S mix

```