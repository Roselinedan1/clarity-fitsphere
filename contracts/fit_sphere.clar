;; FitSphere - Fitness Group & Competition Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101)) 
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-competition-ended (err u104))
(define-constant err-insufficient-balance (err u105))
(define-constant err-already-member (err u106))
(define-constant err-not-member (err u107))
(define-constant err-invalid-value (err u108))
(define-constant err-competition-not-started (err u109))

;; Activity value limits
(define-constant max-activity-value u100000)
(define-constant min-participants u1)

;; [Previous data maps remain the same]

(define-public (log-activity 
    (competition-id uint) 
    (activity-type (string-ascii 20)) 
    (value uint)
)
    (let
        (
            (competition (unwrap! (map-get? competitions {competition-id: competition-id}) err-not-found))
            (group (unwrap! (map-get? groups {group-id: (get group-id competition)}) err-not-found))
            (current-activities (get activities competition))
        )
        ;; Enhanced validation
        (asserts! (is-some (index-of (get members group) tx-sender)) err-not-member)
        (asserts! (<= value max-activity-value) err-invalid-value)
        (asserts! (>= block-height (get start-time competition)) err-competition-not-started)
        (asserts! (<= block-height (get end-time competition)) err-competition-ended)
        
        (let
            ((points-earned (calculate-points value activity-type)))
            (map-set competitions
                {competition-id: competition-id}
                (merge competition 
                    {
                        activities: (append current-activities {participant: tx-sender, activity-type: activity-type, value: value}),
                        participants: (unwrap! (as-max-len? 
                            (append (get participants competition) tx-sender)
                            u50
                        ) err-already-exists)
                    }
                )
            )
            (try! (add-points tx-sender points-earned (get group-id competition)))
            (ok true)
        )
    )
)

;; Enhanced winner determination
(define-private (determine-winner (activities (list 100 {participant: principal, activity-type: (string-ascii 20), value: uint})))
    (let
        (
            (activity-count (len activities))
        )
        (asserts! (>= activity-count min-participants) err-insufficient-balance)
        (let
            (
                (participant-points (fold calculate-participant-points activities (list)))
                (sorted-points (sort participant-points points-greater))
            )
            (match (element-at sorted-points u0)
                winner (ok (get user winner))
                err-not-found
            )
        )
    )
)

;; Optimized point calculation
(define-private (calculate-participant-points 
    (activity {participant: principal, activity-type: (string-ascii 20), value: uint})
    (acc (list 50 {user: principal, points: uint}))
)
    (let
        (
            (points (calculate-points (get value activity) (get activity-type activity)))
            (participant (get participant activity))
            (existing-entry (find-entry acc participant))
        )
        (match existing-entry
            prev-entry (merge-points acc participant points)
            (append acc {user: participant, points: points})
        )
    )
)
