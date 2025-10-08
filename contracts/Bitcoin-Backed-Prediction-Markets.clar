(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-MARKET-CLOSED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-NO-STAKE (err u103))
(define-constant ERR-ALREADY-SETTLED (err u104))
(define-constant ERR-INVALID-FEE (err u105))
(define-constant ERR-PAUSED (err u106))

(define-data-var oracle-address principal tx-sender)
(define-data-var min-stake uint u100)
(define-data-var market-status bool true)
(define-data-var next-market-id uint u1)
(define-data-var protocol-fee-bps uint u250)
(define-data-var protocol-admin principal tx-sender)
(define-data-var total-fees-collected uint u0)
(define-data-var protocol-paused bool false)
(define-data-var early-withdrawal-penalty-bps uint u500)

(define-map markets
    uint 
    {
        question: (string-ascii 256),
        end-block: uint,
        total-yes-amount: uint,
        total-no-amount: uint,
        outcome: (optional bool),
        settled: bool
    }
)

(define-map user-stakes
    { market-id: uint, user: principal }
    { yes-amount: uint, no-amount: uint, claimed: bool }
)

(define-public (create-market (question (string-ascii 256)) (blocks uint))
    (let ((market-id (var-get next-market-id)))
        (map-set markets 
            market-id
            {
                question: question,
                end-block: (+ burn-block-height blocks),
                total-yes-amount: u0,
                total-no-amount: u0,
                outcome: none,
                settled: false
            }
        )
        (var-set next-market-id (+ market-id u1))
        (ok market-id)
    )
)

(define-public (stake-yes (market-id uint) (amount uint))
    (let (
        (market (unwrap! (map-get? markets market-id) ERR-MARKET-CLOSED))
        (current-stake (default-to 
            { yes-amount: u0, no-amount: u0, claimed: false }
            (map-get? user-stakes { market-id: market-id, user: tx-sender })))
        (fee-amount (/ (* amount (var-get protocol-fee-bps)) u10000))
        (net-amount (- amount fee-amount))
    )
        (asserts! (>= amount (var-get min-stake)) ERR-INVALID-AMOUNT)
        (asserts! (not (var-get protocol-paused)) ERR-PAUSED)
        (asserts! (not (get settled market)) ERR-MARKET-CLOSED)
        (asserts! (<= burn-block-height (get end-block market)) ERR-MARKET-CLOSED)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set total-fees-collected (+ (var-get total-fees-collected) fee-amount))
        (map-set markets market-id
            (merge market { total-yes-amount: (+ (get total-yes-amount market) net-amount) })
        )
        (map-set user-stakes 
            { market-id: market-id, user: tx-sender }
            { yes-amount: (+ (get yes-amount current-stake) net-amount), no-amount: (get no-amount current-stake), claimed: (get claimed current-stake) }
        )
        (ok true)
    )
)

(define-public (stake-no (market-id uint) (amount uint))
    (let (
        (market (unwrap! (map-get? markets market-id) ERR-MARKET-CLOSED))
        (current-stake (default-to 
            { yes-amount: u0, no-amount: u0, claimed: false }
            (map-get? user-stakes { market-id: market-id, user: tx-sender })))
        (fee-amount (/ (* amount (var-get protocol-fee-bps)) u10000))
        (net-amount (- amount fee-amount))
    )
        (asserts! (>= amount (var-get min-stake)) ERR-INVALID-AMOUNT)
        (asserts! (not (var-get protocol-paused)) ERR-PAUSED)
        (asserts! (not (get settled market)) ERR-MARKET-CLOSED)
        (asserts! (<= burn-block-height (get end-block market)) ERR-MARKET-CLOSED)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set total-fees-collected (+ (var-get total-fees-collected) fee-amount))
        (map-set markets market-id
            (merge market { total-no-amount: (+ (get total-no-amount market) net-amount) })
        )
        (map-set user-stakes 
            { market-id: market-id, user: tx-sender }
            { yes-amount: (get yes-amount current-stake), no-amount: (+ (get no-amount current-stake) net-amount), claimed: (get claimed current-stake) }
        )
        (ok true)
    )
)

(define-public (settle-market (market-id uint) (outcome bool))
    (let ((market (unwrap! (map-get? markets market-id) ERR-MARKET-CLOSED)))
        (asserts! (is-eq tx-sender (var-get oracle-address)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get settled market)) ERR-ALREADY-SETTLED)
        (map-set markets market-id
            (merge market { outcome: (some outcome), settled: true })
        )
        (ok true)
    )
)

(define-public (claim-reward (market-id uint))
    (let (
        (market (unwrap! (map-get? markets market-id) ERR-MARKET-CLOSED))
        (stake (unwrap! (map-get? user-stakes { market-id: market-id, user: tx-sender }) ERR-NO-STAKE))
        (outcome (unwrap! (get outcome market) ERR-MARKET-CLOSED))
        (total-pool (+ (get total-yes-amount market) (get total-no-amount market)))
    )
        (asserts! (get settled market) ERR-MARKET-CLOSED)
        (asserts! (not (var-get protocol-paused)) ERR-PAUSED)
        (asserts! (not (get claimed stake)) ERR-ALREADY-SETTLED)
        (asserts! (> total-pool u0) ERR-NO-STAKE)
        
        (map-set user-stakes 
            { market-id: market-id, user: tx-sender }
            (merge stake { claimed: true })
        )
        
        (if outcome
            (if (> (get yes-amount stake) u0)
                (let ((reward (/ (* (get yes-amount stake) total-pool) (get total-yes-amount market))))
                    (try! (as-contract (stx-transfer? reward (as-contract tx-sender) tx-sender)))
                    (ok reward))
                (ok u0))
            (if (> (get no-amount stake) u0)
                (let ((reward (/ (* (get no-amount stake) total-pool) (get total-no-amount market))))
                    (try! (as-contract (stx-transfer? reward (as-contract tx-sender) tx-sender)))
                    (ok reward))
                (ok u0))
        )
    )
)

(define-read-only (get-market (market-id uint))
    (map-get? markets market-id)
)

(define-read-only (get-user-stake (market-id uint) (user principal))
    (map-get? user-stakes { market-id: market-id, user: user })
)

(define-public (set-protocol-fee (new-fee-bps uint))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-fee-bps u1000) ERR-INVALID-FEE)
        (var-set protocol-fee-bps new-fee-bps)
        (ok true)
    )
)

(define-public (withdraw-protocol-fees (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (var-get total-fees-collected)) ERR-INVALID-AMOUNT)
        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) (var-get protocol-admin))))
        (var-set total-fees-collected (- (var-get total-fees-collected) amount))
        (ok amount)
    )
)

(define-public (transfer-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) ERR-NOT-AUTHORIZED)
        (var-set protocol-admin new-admin)
        (ok true)
    )
)

(define-public (pause-protocol)
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) ERR-NOT-AUTHORIZED)
        (var-set protocol-paused true)
        (ok true)
    )
)

(define-public (unpause-protocol)
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) ERR-NOT-AUTHORIZED)
        (var-set protocol-paused false)
        (ok true)
    )
)

(define-public (withdraw-early-yes (market-id uint))
    (let (
        (market (unwrap! (map-get? markets market-id) ERR-MARKET-CLOSED))
        (stake (unwrap! (map-get? user-stakes { market-id: market-id, user: tx-sender }) ERR-NO-STAKE))
        (yes-amount (get yes-amount stake))
        (penalty (/ (* yes-amount (var-get early-withdrawal-penalty-bps)) u10000))
        (refund (- yes-amount penalty))
    )
        (asserts! (not (get settled market)) ERR-MARKET-CLOSED)
        (asserts! (<= burn-block-height (get end-block market)) ERR-MARKET-CLOSED)
        (asserts! (> yes-amount u0) ERR-NO-STAKE)
        (asserts! (not (var-get protocol-paused)) ERR-PAUSED)
        (try! (as-contract (stx-transfer? refund (as-contract tx-sender) tx-sender)))
        (var-set total-fees-collected (+ (var-get total-fees-collected) penalty))
        (map-set markets market-id
            (merge market { total-yes-amount: (- (get total-yes-amount market) yes-amount) })
        )
        (map-set user-stakes
            { market-id: market-id, user: tx-sender }
            { yes-amount: u0, no-amount: (get no-amount stake), claimed: (get claimed stake) }
        )
        (ok refund)
    )
)

(define-public (withdraw-early-no (market-id uint))
    (let (
        (market (unwrap! (map-get? markets market-id) ERR-MARKET-CLOSED))
        (stake (unwrap! (map-get? user-stakes { market-id: market-id, user: tx-sender }) ERR-NO-STAKE))
        (no-amount (get no-amount stake))
        (penalty (/ (* no-amount (var-get early-withdrawal-penalty-bps)) u10000))
        (refund (- no-amount penalty))
    )
        (asserts! (not (get settled market)) ERR-MARKET-CLOSED)
        (asserts! (<= burn-block-height (get end-block market)) ERR-MARKET-CLOSED)
        (asserts! (> no-amount u0) ERR-NO-STAKE)
        (asserts! (not (var-get protocol-paused)) ERR-PAUSED)
        (try! (as-contract (stx-transfer? refund (as-contract tx-sender) tx-sender)))
        (var-set total-fees-collected (+ (var-get total-fees-collected) penalty))
        (map-set markets market-id
            (merge market { total-no-amount: (- (get total-no-amount market) no-amount) })
        )
        (map-set user-stakes
            { market-id: market-id, user: tx-sender }
            { yes-amount: (get yes-amount stake), no-amount: u0, claimed: (get claimed stake) }
        )
        (ok refund)
    )
)

(define-read-only (get-protocol-info)
    {
        fee-bps: (var-get protocol-fee-bps),
        admin: (var-get protocol-admin),
        total-fees: (var-get total-fees-collected)
    }
)