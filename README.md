
* * * * *

PredictoWager
=============

* * * * *

A decentralized prediction market contract that empowers users to create, participate in, and resolve binary outcome markets on the blockchain. This smart contract facilitates a transparent and trustless environment for forecasting events and distributing rewards based on accurate predictions.

Features
--------

-   **Market Creation**: Anyone can create a new prediction market with a defined title, description, and duration by paying a small fee.
-   **Betting**: Users can place bets on either "yes" or "no" outcomes for active markets, with a minimum bet amount enforced. A small fee is collected from each bet to support the platform.
-   **Market Resolution**: Only the market creator can resolve a market once its expiry block has passed, setting the final outcome (true or false).
-   **Reward Distribution**: Participants who bet on the correct outcome can claim their proportionate share of the total pool, minus fees.
-   **Market Analytics**: Comprehensive read-only functions allow users to retrieve detailed market information, including total volume, implied probabilities, liquidity ratios, and individual user positions.
-   **Batch Operations**: Efficiently query analytics and user positions for multiple markets in a single call.

Smart Contract Details
----------------------

This contract is written in Clarity, a decidable smart contract language for the Stacks blockchain.

### Constants

-   `CONTRACT-OWNER`: The principal address of the contract owner.
-   `ERR-NOT-AUTHORIZED`: Error for unauthorized actions.
-   `ERR-MARKET-NOT-FOUND`: Error when a specified market ID does not exist.
-   `ERR-MARKET-EXPIRED`: Error when attempting to interact with an expired market.
-   `ERR-MARKET-NOT-EXPIRED`: Error when attempting to resolve a market before its expiry.
-   `ERR-MARKET-RESOLVED`: Error when attempting to resolve an already resolved market.
-   `ERR-MARKET-NOT-RESOLVED`: Error when attempting to claim winnings from an unresolved market.
-   `ERR-INSUFFICIENT-FUNDS`: Error for bets below the minimum amount.
-   `ERR-INVALID-OUTCOME`: Error for invalid outcome selections.
-   `ERR-NO-POSITION`: Error when a user tries to claim without a position or no winnings.
-   `ERR-ALREADY-CLAIMED`: Error when a user tries to claim winnings already received.
-   `MIN-BET-AMOUNT`: The minimum amount (in uSTX) required for a bet (currently `u1000000` or 1 STX).
-   `MARKET-FEE-RATE`: The fee rate applied to bets (currently `u50` meaning 0.05 or 5%).

### Data Maps and Variables

-   `next-market-id`: A `uint` variable tracking the next available market ID.
-   `total-markets`: A `uint` variable tracking the total number of markets created.
-   `markets`: A map storing details for each market, indexed by `market-id`.
    -   `creator`: `principal`
    -   `title`: `(string-ascii 100)`
    -   `description`: `(string-ascii 500)`
    -   `expiry-block`: `uint`
    -   `resolution-block`: `uint`
    -   `outcome`: `(optional bool)`
    -   `total-yes-amount`: `uint`
    -   `total-no-amount`: `uint`
    -   `is-resolved`: `bool`
    -   `fee-collected`: `uint`
-   `user-positions`: A map storing user's bet positions for each market, indexed by `market-id` and `user` principal.
    -   `yes-amount`: `uint`
    -   `no-amount`: `uint`
    -   `has-claimed`: `bool`
-   `market-creators`: A map to quickly look up the creator of a market, indexed by `market-id`.
    -   `creator`: `principal`

### Public Functions

-   `create-market (title (string-ascii 100)) (description (string-ascii 500)) (duration-blocks uint)`: Creates a new prediction market. Requires a `u1000000` STX fee paid to the `CONTRACT-OWNER`.
-   `place-bet (market-id uint) (outcome bool) (amount uint)`: Allows a user to place a bet on a specified market and outcome.
-   `resolve-market (market-id uint) (outcome bool)`: Allows the market creator to resolve the market with a final `outcome`.
-   `claim-winnings (market-id uint)`: Allows users to claim their winnings from a resolved market.
-   `get-market (market-id uint)`: Reads market details for a given `market-id`.
-   `get-user-position (market-id uint) (user principal)`: Reads a user's position for a specific market.
-   `get-market-analytics-and-batch-positions (market-ids (list 10 uint)) (user principal)`: Provides comprehensive analytics for a list of market IDs and the specified user's positions across them.
-   `get-total-markets`: Returns the total number of markets created.
-   `get-next-market-id`: Returns the ID for the next market to be created.
-   `get-contract-stats`: Returns various contract-level statistics, including owner, min bet, and fee rate.

### Private Functions (Helper Functions)

-   `calculate-fee (amount uint)`: Calculates the fee amount from a given bet amount.
-   `calculate-net-amount (amount uint)`: Calculates the net amount after deducting the fee.
-   `validate-active-market (market-id uint)`: Checks if a market exists, is not resolved, and has not expired.
-   `calculate-winnings (market-id uint) (user principal) (winning-outcome bool)`: Calculates the potential winnings for a user based on the winning outcome.
-   `get-single-market-analytics (market-id uint)`: Gathers analytics for a single market (volume, probabilities, liquidity).
-   `calculate-implied-probability (yes-amount uint) (no-amount uint) (for-yes bool)`: Calculates the implied probability of an outcome based on betting amounts.
-   `calculate-liquidity-ratio (yes-amount uint) (no-amount uint)`: Calculates the liquidity ratio of a market.
-   `calculate-user-total-exposure-for-user (market-id uint) (user principal)`: Calculates a user's total exposure (sum of yes and no bets) in a single market.
-   `is-market-active (market-id uint)`: Checks if a market is active (not expired and not resolved).
-   `is-market-resolved (market-id uint)`: Checks if a market is resolved.
-   `get-market-volume (market-id uint)`: Gets the total volume of bets in a market.
-   `get-market-liquidity (market-id uint)`: Gets the liquidity ratio for a market.
-   `get-user-exposure-for-market (market-id uint) (user principal)`: Alias for `calculate-user-total-exposure-for-user`.
-   `sum-uint-list (numbers (list 10 uint))`: Helper to sum a list of unsigned integers.
-   `count-active-markets (market-ids (list 10 uint))`: Counts active markets from a list of IDs.
-   `count-resolved-markets (market-ids (list 10 uint))`: Counts resolved markets from a list of IDs.
-   `get-user-position-for-id (market-id uint)`: Helper to get user position for `tx-sender`.
-   `calculate-total-user-exposure (market-ids (list 10 uint)) (user principal)`: Calculates total user exposure across multiple markets.
-   `calculate-and-add-exposure (market-id uint) (accumulator uint)`: Helper for folding exposure calculation.

How to Use
----------

### Prerequisites

To interact with this contract, you'll need:

-   A Stacks wallet (e.g., Leather, Xverse).
-   STX tokens for transactions and betting.
-   A Clarity-compatible development environment if you plan to deploy or test locally.

### Interacting with the Contract

You can interact with this contract directly on the Stacks blockchain using a block explorer that supports contract calls, or programmatically via the Stacks.js library.

#### Example Flow:

1.  **Deploy the Contract**: The `CONTRACT-OWNER` would first deploy the contract to the Stacks blockchain.
2.  **Create a Market**: A user calls `create-market` with a title, description, and duration in blocks. They pay the `u1000000` STX market creation fee.
3.  **Place a Bet**: Users call `place-bet` with the `market-id`, their chosen `outcome` (true/false), and the `amount` of STX they wish to bet (must be >= `MIN-BET-AMOUNT`).
4.  **Monitor Market**: Users can use `get-market` or `get-market-analytics-and-batch-positions` to check the current status, volume, and probabilities of markets.
5.  **Resolve Market**: Once the `expiry-block` is reached, the market `creator` calls `resolve-market` with the `market-id` and the final `outcome`.
6.  **Claim Winnings**: After the market is resolved, users who bet on the correct outcome can call `claim-winnings` to receive their share of the prize pool.

Contribution
------------

I welcome contributions to improve this contract! If you have suggestions for new features, bug fixes, or optimizations, please feel free to:

2.  Fork this repository.

4.  Create a new branch for your feature or fix.

6.  Implement your changes.

8.  Submit a pull request^1^ with a clear description of your modifications.

License
-------

This project is licensed under the MIT License. See the `LICENSE` file for details.

Related
-------

-   [Clarity Language Documentation](https://docs.stacks.co/docs/clarity/)
-   [Stacks.js Library](https://www.google.com/search?q=https://docs.stacks.co/docs/stacks.js/overview)
-   [Stacks Blockchain Explorer](https://explorer.stacks.co/)

* * * * *
