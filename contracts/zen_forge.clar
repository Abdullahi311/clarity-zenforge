;; ZenForge Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-meditation (err u102))
(define-constant err-achievement-exists (err u103))

;; Data Variables
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
    price: uint
})

(define-map user-stats principal {
    total-minutes: uint,
    sessions-completed: uint,
    rewards-earned: uint,
    achievements: (list 10 uint)
})

(define-map achievements uint {
    title: (string-ascii 64),
    description: (string-ascii 256),
    requirement: uint,
    achievement-type: (string-ascii 16),
    reward-amount: uint
})

;; Public Functions

;; Mint new meditation NFT
(define-public (mint-meditation (title (string-ascii 64)) (duration uint) (price uint))
    (let
        ((meditation-id (var-get total-meditations)))
        (if (is-eq tx-sender contract-owner)
            (begin
                (try! (nft-mint? meditation meditation-id tx-sender))
                (map-set meditations meditation-id {
                    creator: tx-sender,
                    title: title,
                    duration: duration,
                    price: price
                })
                (var-set total-meditations (+ meditation-id u1))
                (ok meditation-id))
            err-owner-only)))

;; Create new achievement 
(define-public (create-achievement (title (string-ascii 64)) (description (string-ascii 256)) (requirement uint) (achievement-type (string-ascii 16)) (reward-amount uint))
    (let ((achievement-id (var-get total-meditations)))
        (if (is-eq tx-sender contract-owner)
            (begin
                (map-set achievements achievement-id {
                    title: title,
                    description: description,
                    requirement: requirement,
                    achievement-type: achievement-type,
                    reward-amount: reward-amount
                })
                (ok achievement-id))
            err-owner-only)))

;; Record completed meditation session and check achievements
(define-public (complete-session (meditation-id uint))
    (let (
        (meditation-data (unwrap! (map-get? meditations meditation-id) err-invalid-meditation))
        (user-data (default-to {
            total-minutes: u0,
            sessions-completed: u0,
            rewards-earned: u0,
            achievements: (list)
        } (map-get? user-stats tx-sender))))
        (begin
            (map-set user-stats tx-sender {
                total-minutes: (+ (get total-minutes user-data) (get duration meditation-data)),
                sessions-completed: (+ (get sessions-completed user-data) u1),
                rewards-earned: (+ (get rewards-earned user-data) u10),
                achievements: (get achievements user-data)
            })
            (var-set total-sessions (+ (var-get total-sessions) u1))
            (try! (check-achievements tx-sender))
            (ok true))))

;; Check and award achievements
(define-private (check-achievements (user principal))
    (let ((stats (unwrap! (map-get? user-stats user) err-owner-only)))
        (begin
            (if (and
                (>= (get total-minutes stats) u6000)
                (is-none (index-of (get achievements stats) u1)))
                (award-achievement user u1)
                true)
            (if (and
                (>= (get sessions-completed stats) u100) 
                (is-none (index-of (get achievements stats) u2)))
                (award-achievement user u2)
                true)
            (ok true))))

;; Award achievement to user
(define-private (award-achievement (user principal) (achievement-id uint))
    (let (
        (achievement (unwrap! (map-get? achievements achievement-id) err-invalid-meditation))
        (user-data (unwrap! (map-get? user-stats user) err-owner-only)))
        (begin
            (try! (nft-mint? achievement achievement-id user))
            (map-set user-stats user {
                total-minutes: (get total-minutes user-data),
                sessions-completed: (get sessions-completed user-data),
                rewards-earned: (+ (get rewards-earned user-data) (get reward-amount achievement)),
                achievements: (unwrap! (as-max-len? (append (get achievements user-data) achievement-id) u10) err-achievement-exists)
            })
            (ok true))))

;; Read-only functions

(define-read-only (get-meditation-details (id uint))
    (ok (map-get? meditations id)))

(define-read-only (get-user-stats (user principal))
    (ok (map-get? user-stats user)))

(define-read-only (get-total-sessions)
    (ok (var-get total-sessions)))

(define-read-only (get-achievement-details (id uint))
    (ok (map-get? achievements id)))
