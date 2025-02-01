;; FitSphere - Fitness Group & Competition Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101)) 
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-competition-ended (err u104))
(define-constant err-insufficient-balance (err u105))

;; SIP-010 Token Interface
(define-trait ft-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
  )
)

;; Data Maps
(define-map groups 
    { group-id: uint }
    {
        name: (string-ascii 50),
        admin: principal,
        members: (list 50 principal),
        goals: (list 10 uint),
        created-at: uint,
        total-points: uint
    }
)

(define-map competitions
    { competition-id: uint }
    {
        group-id: uint,
        name: (string-ascii 50),
        start-time: uint,
        end-time: uint, 
        prize-pool: uint,
        participants: (list 50 principal),
        activities: (list 100 {participant: principal, activity-type: (string-ascii 20), value: uint}),
        winner: (optional principal),
        token-address: (optional principal)
    }
)

(define-map user-points
    { user: principal }
    { points: uint }
)

(define-map leaderboard
    { group-id: uint }
    { rankings: (list 50 { user: principal, points: uint }) }
)

;; Data Variables  
(define-data-var last-group-id uint u0)
(define-data-var last-competition-id uint u0)

;; Group Management Functions
(define-public (create-group (name (string-ascii 50)))
    (let
        (
            (new-group-id (+ (var-get last-group-id) u1))
        )
        (try! (map-insert groups 
            { group-id: new-group-id }
            {
                name: name,
                admin: tx-sender,
                members: (list tx-sender),
                goals: (list ),
                created-at: block-height,
                total-points: u0
            }
        ))
        (var-set last-group-id new-group-id)
        (ok new-group-id)
    )
)

(define-public (join-group (group-id uint))
    (let
        (
            (group (unwrap! (map-get? groups {group-id: group-id}) err-not-found))
            (current-members (get members group))
        )
        (map-set groups
            {group-id: group-id}
            (merge group {members: (append current-members tx-sender)})
        )
        (ok true)
    )
)

;; Competition Functions with Token Support
(define-public (create-competition 
    (group-id uint) 
    (name (string-ascii 50)) 
    (duration uint) 
    (prize-amount uint)
    (token-contract (optional principal))
)
    (let
        (
            (new-competition-id (+ (var-get last-competition-id) u1))
            (group (unwrap! (map-get? groups {group-id: group-id}) err-not-found))
        )
        (asserts! (is-eq (get admin group) tx-sender) err-unauthorized)
        (try! (map-insert competitions
            {competition-id: new-competition-id}
            {
                group-id: group-id,
                name: name,
                start-time: block-height,
                end-time: (+ block-height duration),
                prize-pool: prize-amount,
                participants: (list ),
                activities: (list ),
                winner: none,
                token-address: token-contract
            }
        ))
        (var-set last-competition-id new-competition-id)
        (ok new-competition-id)
    )
)

(define-public (log-activity 
    (competition-id uint) 
    (activity-type (string-ascii 20)) 
    (value uint)
)
    (let
        (
            (competition (unwrap! (map-get? competitions {competition-id: competition-id}) err-not-found))
            (current-activities (get activities competition))
            (points-earned (calculate-points value activity-type))
        )
        (asserts! (<= block-height (get end-time competition)) err-competition-ended)
        (map-set competitions
            {competition-id: competition-id}
            (merge competition 
                {activities: (append current-activities {participant: tx-sender, activity-type: activity-type, value: value})}
            )
        )
        (try! (add-points tx-sender points-earned (get group-id competition)))
        (ok true)
    )
)

(define-public (end-competition (competition-id uint))
    (let
        (
            (competition (unwrap! (map-get? competitions {competition-id: competition-id}) err-not-found))
            (group (unwrap! (map-get? groups {group-id: (get group-id competition)}) err-not-found))
            (token-contract (get token-address competition))
        )
        (asserts! (is-eq (get admin group) tx-sender) err-unauthorized)
        (asserts! (>= block-height (get end-time competition)) err-competition-ended)
        
        (let
            (
                (winner (determine-winner (get activities competition)))
            )
            ;; Distribute token rewards if configured
            (match token-contract
                token-principal (try! (contract-call? 
                    (unwrap! (contract-of token-principal) err-not-found)
                    transfer
                    (get prize-pool competition)
                    tx-sender
                    winner
                    none
                ))
                none true
            )
            
            (map-set competitions
                {competition-id: competition-id}
                (merge competition {winner: (some winner)})
            )
            (ok true)
        )
    )
)

;; Points and Leaderboard Functions
(define-private (calculate-points (value uint) (activity-type (string-ascii 20)))
    (match activity-type
        "running" (* value u2)
        "cycling" value  
        "swimming" (* value u3)
        u0
    )
)

(define-private (add-points (user principal) (points uint) (group-id uint))
    (let
        (
            (current-points (default-to {points: u0} (map-get? user-points {user: user})))
            (new-points (+ (get points current-points) points))
        )
        (map-set user-points
            {user: user}
            {points: new-points}
        )
        (update-leaderboard user new-points group-id)
        (ok true)
    )
)

(define-private (update-leaderboard (user principal) (points uint) (group-id uint))
    (let
        (
            (current-rankings (default-to {rankings: (list )} (map-get? leaderboard {group-id: group-id})))
            (updated-rankings (sort-rankings (append (get rankings current-rankings) {user: user, points: points})))
        )
        (map-set leaderboard
            {group-id: group-id}
            {rankings: updated-rankings}
        )
        (ok true)
    )
)

(define-private (sort-rankings (rankings (list 50 {user: principal, points: uint})))
    (sort rankings points-greater)
)

(define-private (points-greater (a {user: principal, points: uint}) (b {user: principal, points: uint}))
    (> (get points a) (get points b))
)

(define-private (determine-winner (activities (list 100 {participant: principal, activity-type: (string-ascii 20), value: uint})))
    (get participant (element-at activities u0))
)

;; Read-only Functions
(define-read-only (get-group (group-id uint))
    (map-get? groups {group-id: group-id})
)

(define-read-only (get-competition (competition-id uint))
    (map-get? competitions {competition-id: competition-id})
)

(define-read-only (get-user-points (user principal))
    (map-get? user-points {user: user})
)

(define-read-only (get-leaderboard (group-id uint))
    (map-get? leaderboard {group-id: group-id})
)
