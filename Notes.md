# External Vs Public

In external call your function reads x directly from calldata—no extra steps, no memory allocation
while in public Your function body then reads x from memory.
That copy costs a few extra gas units (for the memory allocation and the copy)

# How to call functions inside of Foundry using Cast

```
cast call <contract-address> "functionName(argType)(returnType)" <arg1> --rpc-url <url>
```