(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-MARKET-CLOSED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-NO-STAKE (err u103))
(define-constant ERR-ALREADY-SETTLED (err u104))

(define-data-var oracle-address principal tx-sender)
(define-data-var min-stake uint u100)
(define-data-var market-status bool true)
(define-data-var next-market-id uint u1)

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
    )
        (asserts! (>= amount (var-get min-stake)) ERR-INVALID-AMOUNT)
        (asserts! (not (get settled market)) ERR-MARKET-CLOSED)
        (asserts! (<= burn-block-height (get end-block market)) ERR-MARKET-CLOSED)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set markets market-id
            (merge market { total-yes-amount: (+ (get total-yes-amount market) amount) })
        )
        (map-set user-stakes 
            { market-id: market-id, user: tx-sender }
            { yes-amount: (+ (get yes-amount current-stake) amount), no-amount: (get no-amount current-stake), claimed: (get claimed current-stake) }
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
    )
        (asserts! (>= amount (var-get min-stake)) ERR-INVALID-AMOUNT)
        (asserts! (not (get settled market)) ERR-MARKET-CLOSED)
        (asserts! (<= burn-block-height (get end-block market)) ERR-MARKET-CLOSED)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set markets market-id
            (merge market { total-no-amount: (+ (get total-no-amount market) amount) })
        )
        (map-set user-stakes 
            { market-id: market-id, user: tx-sender }
            { yes-amount: (get yes-amount current-stake), no-amount: (+ (get no-amount current-stake) amount), claimed: (get claimed current-stake) }
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