;; DeFi Prediction Market Contract
;; A decentralized prediction market where users can create binary outcome markets,
;; place bets on outcomes, and claim rewards based on market resolution.
;; Features include market creation, betting, resolution, and reward distribution.

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-MARKET-NOT-FOUND (err u101))
(define-constant ERR-MARKET-EXPIRED (err u102))
(define-constant ERR-MARKET-NOT-EXPIRED (err u103))
(define-constant ERR-MARKET-RESOLVED (err u104))
(define-constant ERR-MARKET-NOT-RESOLVED (err u105))
(define-constant ERR-INSUFFICIENT-FUNDS (err u106))
(define-constant ERR-INVALID-OUTCOME (err u107))
(define-constant ERR-NO-POSITION (err u108))
(define-constant ERR-ALREADY-CLAIMED (err u109))
(define-constant MIN-BET-AMOUNT u1000000) ;; 1 STX minimum bet
(define-constant MARKET-FEE-RATE u50) ;; 5% fee (50/1000)

;; Data Maps and Variables
(define-data-var next-market-id uint u1)
(define-data-var total-markets uint u0)

;; Market structure: stores all market information
(define-map markets
  { market-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    expiry-block: uint,
    resolution-block: uint,
    outcome: (optional bool), ;; true/false for binary outcomes, none if unresolved
    total-yes-amount: uint,
    total-no-amount: uint,
    is-resolved: bool,
    fee-collected: uint
  }
)

;; User positions in markets
(define-map user-positions
  { market-id: uint, user: principal }
  {
    yes-amount: uint,
    no-amount: uint,
    has-claimed: bool
  }
)

;; Market creators for authorization
(define-map market-creators
  { market-id: uint }
  { creator: principal }
)

;; Private Functions

;; Calculate fee amount from bet
(define-private (calculate-fee (amount uint))
  (/ (* amount MARKET-FEE-RATE) u1000)
)

;; Calculate net amount after fee deduction
(define-private (calculate-net-amount (amount uint))
  (- amount (calculate-fee amount))
)

;; Validate market exists and is active
(define-private (validate-active-market (market-id uint))
  (match (map-get? markets { market-id: market-id })
    market-data 
      (if (get is-resolved market-data)
        ERR-MARKET-RESOLVED
        (if (>= block-height (get expiry-block market-data))
          ERR-MARKET-EXPIRED
          (ok market-data)))
    ERR-MARKET-NOT-FOUND
  )
)

;; Calculate user's potential winnings
(define-private (calculate-winnings (market-id uint) (user principal) (winning-outcome bool))
  (match (map-get? user-positions { market-id: market-id, user: user })
    position
      (match (map-get? markets { market-id: market-id })
        market-data
          (let (
            (user-winning-amount (if winning-outcome (get yes-amount position) (get no-amount position)))
            (total-winning-pool (if winning-outcome (get total-yes-amount market-data) (get total-no-amount market-data)))
            (total-losing-pool (if winning-outcome (get total-no-amount market-data) (get total-yes-amount market-data)))
          )
            (if (is-eq total-winning-pool u0)
              u0
              (+ user-winning-amount (/ (* user-winning-amount total-losing-pool) total-winning-pool))
            )
          )
        u0)
    u0
  )
)

;; Public Functions

;; Create a new prediction market
(define-public (create-market (title (string-ascii 100)) (description (string-ascii 500)) (duration-blocks uint))
  (let (
    (market-id (var-get next-market-id))
    (expiry-block (+ block-height duration-blocks))
  )
    (try! (stx-transfer? u1000000 tx-sender CONTRACT-OWNER)) ;; Market creation fee
    (map-set markets
      { market-id: market-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        expiry-block: expiry-block,
        resolution-block: u0,
        outcome: none,
        total-yes-amount: u0,
        total-no-amount: u0,
        is-resolved: false,
        fee-collected: u0
      }
    )
    (map-set market-creators { market-id: market-id } { creator: tx-sender })
    (var-set next-market-id (+ market-id u1))
    (var-set total-markets (+ (var-get total-markets) u1))
    (ok market-id)
  )
)

;; Place a bet on market outcome
(define-public (place-bet (market-id uint) (outcome bool) (amount uint))
  (let (
    (market-data (try! (validate-active-market market-id)))
    (fee-amount (calculate-fee amount))
    (net-amount (calculate-net-amount amount))
    (current-position (default-to 
      { yes-amount: u0, no-amount: u0, has-claimed: false }
      (map-get? user-positions { market-id: market-id, user: tx-sender })
    ))
  )
    (asserts! (>= amount MIN-BET-AMOUNT) ERR-INSUFFICIENT-FUNDS)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update user position
    (map-set user-positions
      { market-id: market-id, user: tx-sender }
      (if outcome
        (merge current-position { yes-amount: (+ (get yes-amount current-position) net-amount) })
        (merge current-position { no-amount: (+ (get no-amount current-position) net-amount) })
      )
    )
    
    ;; Update market totals
    (map-set markets
      { market-id: market-id }
      (if outcome
        (merge market-data { 
          total-yes-amount: (+ (get total-yes-amount market-data) net-amount),
          fee-collected: (+ (get fee-collected market-data) fee-amount)
        })
        (merge market-data { 
          total-no-amount: (+ (get total-no-amount market-data) net-amount),
          fee-collected: (+ (get fee-collected market-data) fee-amount)
        })
      )
    )
    (ok true)
  )
)

;; Resolve market (only creator can resolve)
(define-public (resolve-market (market-id uint) (outcome bool))
  (match (map-get? markets { market-id: market-id })
    market-data
      (begin
        (asserts! (is-eq tx-sender (get creator market-data)) ERR-NOT-AUTHORIZED)
        (asserts! (>= block-height (get expiry-block market-data)) ERR-MARKET-NOT-EXPIRED)
        (asserts! (not (get is-resolved market-data)) ERR-MARKET-RESOLVED)
        
        (map-set markets
          { market-id: market-id }
          (merge market-data {
            outcome: (some outcome),
            is-resolved: true,
            resolution-block: block-height
          })
        )
        (ok true)
      )
    ERR-MARKET-NOT-FOUND
  )
)

;; Claim winnings from resolved market
(define-public (claim-winnings (market-id uint))
  (match (map-get? markets { market-id: market-id })
    market-data
      (match (get outcome market-data)
        winning-outcome
          (match (map-get? user-positions { market-id: market-id, user: tx-sender })
            position
              (begin
                (asserts! (get is-resolved market-data) ERR-MARKET-NOT-RESOLVED)
                (asserts! (not (get has-claimed position)) ERR-ALREADY-CLAIMED)
                
                (let (
                  (winnings (calculate-winnings market-id tx-sender winning-outcome))
                )
                  (asserts! (> winnings u0) ERR-NO-POSITION)
                  
                  ;; Mark as claimed
                  (map-set user-positions
                    { market-id: market-id, user: tx-sender }
                    (merge position { has-claimed: true })
                  )
                  
                  ;; Transfer winnings
                  (try! (as-contract (stx-transfer? winnings tx-sender tx-sender)))
                  (ok winnings)
                )
              )
            ERR-NO-POSITION)
        ERR-MARKET-NOT-RESOLVED)
    ERR-MARKET-NOT-FOUND
  )
)

;; Get market information
(define-read-only (get-market (market-id uint))
  (map-get? markets { market-id: market-id })
)

;; Get user position in market
(define-read-only (get-user-position (market-id uint) (user principal))
  (map-get? user-positions { market-id: market-id, user: user })
)

;; Helper function for market analytics
(define-private (get-single-market-analytics (market-id uint))
  (match (get-market market-id)
    market-data
      {
        market-id: market-id,
        total-volume: (+ (get total-yes-amount market-data) (get total-no-amount market-data)),
        yes-probability: (calculate-implied-probability (get total-yes-amount market-data) (get total-no-amount market-data) true),
        no-probability: (calculate-implied-probability (get total-yes-amount market-data) (get total-no-amount market-data) false),
        liquidity-ratio: (calculate-liquidity-ratio (get total-yes-amount market-data) (get total-no-amount market-data)),
        is-active: (and (< block-height (get expiry-block market-data)) (not (get is-resolved market-data))),
        blocks-until-expiry: (if (< block-height (get expiry-block market-data)) 
                               (- (get expiry-block market-data) block-height) 
                               u0)
      }
    { market-id: market-id, total-volume: u0, yes-probability: u0, no-probability: u0, 
      liquidity-ratio: u0, is-active: false, blocks-until-expiry: u0 }
  )
)

;; Calculate implied probability based on betting amounts
(define-private (calculate-implied-probability (yes-amount uint) (no-amount uint) (for-yes bool))
  (let ((total-amount (+ yes-amount no-amount)))
    (if (is-eq total-amount u0)
      u500 ;; 50% if no bets
      (if for-yes
        (/ (* yes-amount u1000) total-amount)
        (/ (* no-amount u1000) total-amount)
      )
    )
  )
)

;; Calculate liquidity ratio (balance between yes/no sides)
(define-private (calculate-liquidity-ratio (yes-amount uint) (no-amount uint))
  (if (and (> yes-amount u0) (> no-amount u0))
    (if (> yes-amount no-amount)
      (/ (* no-amount u1000) yes-amount)
      (/ (* yes-amount u1000) no-amount)
    )
    u0
  )
)

;; Calculate user's total exposure across a market
(define-private (calculate-user-total-exposure-for-user (market-id uint) (user principal))
  (match (get-user-position market-id user)
    position (+ (get yes-amount position) (get no-amount position))
    u0
  )
)

;; Check if market is active
(define-private (is-market-active (market-id uint))
  (match (get-market market-id)
    market-data (and (< block-height (get expiry-block market-data)) (not (get is-resolved market-data)))
    false
  )
)

;; Check if market is resolved
(define-private (is-market-resolved (market-id uint))
  (match (get-market market-id)
    market-data (get is-resolved market-data)
    false
  )
)

;; Helper function to get market volume
(define-private (get-market-volume (market-id uint))
  (match (get-market market-id)
    market-data (+ (get total-yes-amount market-data) (get total-no-amount market-data))
    u0
  )
)

;; Helper function to get market liquidity ratio
(define-private (get-market-liquidity (market-id uint))
  (match (get-market market-id)
    market-data (calculate-liquidity-ratio (get total-yes-amount market-data) (get total-no-amount market-data))
    u0
  )
)

;; Helper function to calculate user exposure for a specific market and user
(define-private (get-user-exposure-for-market (market-id uint) (user principal))
  (calculate-user-total-exposure-for-user market-id user)
)

;; Helper function to sum a list of uints
(define-private (sum-uint-list (numbers (list 10 uint)))
  (fold + numbers u0)
)

;; Helper function to count active markets
(define-private (count-active-markets (market-ids (list 10 uint)))
  (len (filter is-market-active market-ids))
)

;; Helper function to count resolved markets
(define-private (count-resolved-markets (market-ids (list 10 uint)))
  (len (filter is-market-resolved market-ids))
)

;; Helper function to get user position for a market id (for mapping)
(define-private (get-user-position-for-id (market-id uint))
  (get-user-position market-id tx-sender)
)

;; Helper function to calculate total user exposure across multiple markets
(define-private (calculate-total-user-exposure (market-ids (list 10 uint)) (user principal))
  (fold calculate-and-add-exposure market-ids u0)
)

;; Helper function for folding exposure calculation
(define-private (calculate-and-add-exposure (market-id uint) (accumulator uint))
  (+ accumulator (calculate-user-total-exposure-for-user market-id tx-sender))
)

;; Get total number of markets - FIXED
(define-read-only (get-total-markets)
  (var-get total-markets)
)

;; Get next market ID - FIXED
(define-read-only (get-next-market-id)
  (var-get next-market-id)
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-markets: (var-get total-markets),
    next-market-id: (var-get next-market-id),
    contract-owner: CONTRACT-OWNER,
    min-bet-amount: MIN-BET-AMOUNT,
    market-fee-rate: MARKET-FEE-RATE
  }
)


