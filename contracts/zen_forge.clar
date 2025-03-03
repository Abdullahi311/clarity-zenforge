;; ZenForge Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-meditation (err u102))
(define-constant err-achievement-exists (err u103))
(define-constant err-invalid-input (err u104))
(define-constant err-contract-paused (err u105))
(define-constant err-rate-limit (err u106))

;; Contract status
(define-data-var contract-paused bool false)
(define-data-var total-meditations uint u0)
(define-data-var total-sessions uint u0)

;; Define meditation NFT
(define-non-fungible-token meditation uint)
(define-non-fungible-token achievement uint)

;; Data Maps
(define-map meditations uint {
    creator: principal,
    title: (string-ascii 64),
    duration: uint,
    price: uint,
    category: (string-ascii 32),
    metadata-uri: (optional (string-ascii 256))
})

(define-map user-stats principal {
    total-minutes: uint,
    sessions-completed: uint,
    rewards-earned: uint,
    achievements: (list 10 uint),
    current-streak: uint,
    last-session: uint,
    last-session-timestamp: uint
})

(define-map achievements uint {
    title: (string-ascii 64),
    description: (string-ascii 256),
    requirement: uint,
    achievement-type: (string-ascii 16),
    reward-amount: uint,
    tier: uint,
    metadata-uri: (optional (string-ascii 256))
})

;; Rate limiting map
(define-map user-session-timestamps principal uint)

;; Admin Functions
(define-public (set-contract-pause (paused bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set contract-paused paused))))

;; Public Functions
(define-public (mint-meditation 
    (title (string-ascii 64)) 
    (duration uint) 
    (price uint) 
    (category (string-ascii 32))
    (metadata-uri (optional (string-ascii 256))))
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (> duration u0) err-invalid-input)
        (asserts! (<= price u1000000) err-invalid-input)
        (asserts! (>= (len title) u1) err-invalid-input)
        (let ((meditation-id (var-get total-meditations)))
            (if (is-eq tx-sender contract-owner)
                (begin
                    (try! (nft-mint? meditation meditation-id tx-sender))
                    (map-set meditations meditation-id {
                        creator: tx-sender,
                        title: title,
                        duration: duration,
                        price: price,
                        category: category,
                        metadata-uri: metadata-uri
                    })
                    (var-set total-meditations (+ meditation-id u1))
                    (ok meditation-id))
                err-owner-only))))

;; Record completed meditation session and check achievements
(define-public (complete-session (meditation-id uint))
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (check-rate-limit) err-rate-limit)
        (let (
            (meditation-data (unwrap! (map-get? meditations meditation-id) err-invalid-meditation))
            (user-data (default-to {
                total-minutes: u0,
                sessions-completed: u0,
                rewards-earned: u0,
                achievements: (list),
                current-streak: u0,
                last-session: u0,
                last-session-timestamp: u0
            } (map-get? user-stats tx-sender)))
            (current-block-height block-height))
            (begin
                (map-set user-stats tx-sender {
                    total-minutes: (+ (get total-minutes user-data) (get duration meditation-data)),
                    sessions-completed: (+ (get sessions-completed user-data) u1),
                    rewards-earned: (+ (get rewards-earned user-data) (calculate-rewards user-data)),
                    achievements: (get achievements user-data),
                    current-streak: (if (< (- current-block-height (get last-session user-data)) u144)
                                    (+ (get current-streak user-data) u1)
                                    u1),
                    last-session: current-block-height,
                    last-session-timestamp: block-height
                })
                (var-set total-sessions (+ (var-get total-sessions) u1))
                (try! (check-achievements tx-sender))
                (ok true))))

;; Helper function to calculate rewards based on user stats
(define-private (calculate-rewards (user-data {
    total-minutes: uint,
    sessions-completed: uint,
    rewards-earned: uint,
    achievements: (list 10 uint),
    current-streak: uint,
    last-session: uint,
    last-session-timestamp: uint
}))
    (let ((base-reward u10)
          (streak-bonus (/ (get current-streak user-data) u5)))
        (+ base-reward streak-bonus)))

;; Rate limiting check
(define-private (check-rate-limit)
    (let ((last-timestamp (default-to u0 (map-get? user-session-timestamps tx-sender)))
          (current-time block-height))
        (if (> (- current-time last-timestamp) u10)
            (begin
                (map-set user-session-timestamps tx-sender current-time)
                true)
            false)))
