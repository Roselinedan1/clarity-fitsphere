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

;; [Previous trait definition remains the same]

;; Data Maps
[Previous data maps remain the same]

;; Group Management Functions
(define-public (join-group (group-id uint))
    (let
        (
            (group (unwrap! (map-get? groups {group-id: group-id}) err-not-found))
            (current-members (get members group))
        )
        ;; Check if user is already a member
        (asserts! (is-none (index-of current-members tx-sender)) err-already-member)
        ;; Check member limit
        (asserts! (< (len current-members) u50) err-already-exists)
        (map-set groups
            {group-id: group-id}
            (merge group {members: (append current-members tx-sender)})
        )
        (ok true)
    )
)

;; Competition Functions
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
            (points-earned (calculate-points value activity-type))
        )
        ;; Validate user is group member
        (asserts! (is-some (index-of (get members group) tx-sender)) err-not-member)
        (asserts! (<= block-height (get end-time competition)) err-competition-ended)
        
        ;; Update competition
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

;; Enhanced winner determination
(define-private (determine-winner (activities (list 100 {participant: principal, activity-type: (string-ascii 20), value: uint})))
    (let
        (
            (participant-points (fold calculate-participant-points activities (list )))
            (sorted-points (sort participant-points points-greater))
        )
        (get user (unwrap! (element-at sorted-points u0) (get participant (element-at activities u0))))
    )
)

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

(define-private (find-entry 
    (entries (list 50 {user: principal, points: uint}))
    (user principal)
)
    (filter (lambda (entry) (is-eq (get user entry) user)) entries)
)

(define-private (merge-points
    (entries (list 50 {user: principal, points: uint}))
    (user principal)
    (new-points uint)
)
    (map 
        (lambda (entry)
            (if (is-eq (get user entry) user)
                {user: user, points: (+ (get points entry) new-points)}
                entry
            )
        )
        entries
    )
)

;; [Rest of the contract remains the same]
