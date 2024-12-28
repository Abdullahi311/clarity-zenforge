;; ZenForge Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-meditation (err u102))

;; Data Variables
(define-data-var total-meditations uint u0)
(define-data-var total-sessions uint u0)

;; Define meditation NFT
(define-non-fungible-token meditation uint)

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
    rewards-earned: uint
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

;; Record completed meditation session
(define-public (complete-session (meditation-id uint))
    (let (
        (meditation-data (unwrap! (map-get? meditations meditation-id) err-invalid-meditation))
        (user-data (default-to {
            total-minutes: u0,
            sessions-completed: u0,
            rewards-earned: u0
        } (map-get? user-stats tx-sender))))
        (begin
            (map-set user-stats tx-sender {
                total-minutes: (+ (get total-minutes user-data) (get duration meditation-data)),
                sessions-completed: (+ (get sessions-completed user-data) u1),
                rewards-earned: (+ (get rewards-earned user-data) u10)
            })
            (var-set total-sessions (+ (var-get total-sessions) u1))
            (ok true))))

;; Read-only functions

(define-read-only (get-meditation-details (id uint))
    (ok (map-get? meditations id)))

(define-read-only (get-user-stats (user principal))
    (ok (map-get? user-stats user)))

(define-read-only (get-total-sessions)
    (ok (var-get total-sessions)))