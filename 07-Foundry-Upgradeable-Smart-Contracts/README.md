# Upgradeable Smart Contracts — Proxy Concepts
## 1. The Key Players in a Proxy Setup

### A. Proxy Contract
- The contract users actually interact with.
- Has:
  - **Storage** (persistent variables, balances, mappings, etc.).
  - **Upgrade control** (to change the implementation address).
  - A **fallback function** to forward calls to the implementation.
- **Never changes address** — it’s the “front door” of your system.

### B. Implementation Contract (a.k.a. Logic Contract)
- Contains the actual **function code** (business logic).
- Has **no user data stored** in it (its own storage is irrelevant in practice).
- Can be replaced/upgraded without changing the proxy address.
- The proxy uses `delegatecall` to run this contract’s code **as if it’s its own**.

### C. Admin
- The entity (address or multisig) with permission to change the proxy’s implementation pointer.
- In **transparent proxies**, the admin can also make special “upgrade” calls that users can’t.

### D. Beacon Contract *(optional)*
- Holds the address of the current implementation.
- Useful if you have **many proxies** and want to upgrade all of them at once by just updating the beacon.

### E. Delegatecall
- An **EVM instruction** that runs another contract’s code but **uses the storage, balance, and context of the calling contract**.
- This is the magic that makes the implementation’s functions work on the proxy’s data.

---

## 2. How a Call Works

**Example:** A user calls `transfer(address to, uint amount)`.

1. Call hits the **Proxy Contract**.
2. Proxy doesn’t have a `transfer()` function, so it falls into its `fallback()` function.
3. `fallback()` uses `delegatecall` to forward the call to the **Implementation Contract**.
4. The implementation code executes **but reads/writes variables in the Proxy Contract’s storage**.
5. Result is returned to the user as if the proxy did it.

---

## 3. Types of Proxies

- **Transparent Proxy** → Admin functions & user functions are separated to avoid selector clashes.
- **UUPS Proxy** → Upgrade function lives in the implementation itself (simpler proxy).
- **Beacon Proxy** → Implementation address lives in a shared beacon for multiple proxies.
- **Diamond Proxy (EIP-2535)** → Splits logic across many implementation contracts (“facets”).

---

## 4. Common Risks

### A. Storage Clash (a.k.a. Storage Collision)
- The **storage layout** of the proxy’s data **must** match what the implementation expects.
- If you upgrade and reorder or change types of variables, the implementation writes to the wrong slots — **corrupting data**.

**Example:**
```solidity
// v1
uint256 public balance;   // slot 0

// v2
address public owner;     // slot 0  <-- Now overwrites balance!
