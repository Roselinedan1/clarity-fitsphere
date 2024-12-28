;; FitSphere - Fitness Group & Competition Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-competition-ended (err u104))

;; Data Maps
(define-map groups 
    { group-id: uint }
    {
        name: (string-ascii 50),
        admin: principal,
        members: (list 50 principal),
        goals: (list 10 uint),
        created-at: uint
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
        winner: (optional principal)
    }
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
                created-at: block-height
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

;; Competition Functions
(define-public (create-competition (group-id uint) (name (string-ascii 50)) (duration uint) (prize-amount uint))
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
                winner: none
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
        )
        (asserts! (<= block-height (get end-time competition)) err-competition-ended)
        (map-set competitions
            {competition-id: competition-id}
            (merge competition 
                {activities: (append current-activities {participant: tx-sender, activity-type: activity-type, value: value})}
            )
        )
        (ok true)
    )
)

(define-public (end-competition (competition-id uint))
    (let
        (
            (competition (unwrap! (map-get? competitions {competition-id: competition-id}) err-not-found))
            (group (unwrap! (map-get? groups {group-id: (get group-id competition)}) err-not-found))
        )
        (asserts! (is-eq (get admin group) tx-sender) err-unauthorized)
        (asserts! (>= block-height (get end-time competition)) err-competition-ended)
        ;; Calculate winner based on activities
        ;; For simplicity, just takes the first participant
        (let
            (
                (activities (get activities competition))
                (winner (get participant (element-at activities u0)))
            )
            (map-set competitions
                {competition-id: competition-id}
                (merge competition {winner: (some winner)})
            )
            (ok true)
        )
    )
)

;; Read-only Functions
(define-read-only (get-group (group-id uint))
    (map-get? groups {group-id: group-id})
)

(define-read-only (get-competition (competition-id uint))
    (map-get? competitions {competition-id: competition-id})
)