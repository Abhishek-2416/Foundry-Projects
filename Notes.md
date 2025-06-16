# External Vs Public

In external call your function reads x directly from calldata—no extra steps, no memory allocation
while in public Your function body then reads x from memory.
That copy costs a few extra gas units (for the memory allocation and the copy)

# How to call functions inside of Foundry using Cast

```
cast call <contract-address> "functionName(argType)(returnType)" <arg1> --rpc-url <url>
```
Invaraint Testing
 * //So Invariants are properties of our system which should always hold true for the system
 * 
 * Stateless Fuzzing: Where the state of the previous run is discarded for every new run
 * Stateful fuzzing: Where the ending state of previous run is the starting state of the next run
 * 
 * Foundry Fuzz Test: Where Random data is given to one function
 * Invariant Test: Random data is provided to all the functions over the whole contract
 * 
 * Foundry Fuzzing = Stateless Fuzzing
 * Foundry Invariants = Stateful fuzzing