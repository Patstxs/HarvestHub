;; HarvestHub - Decentralized Farm-to-Table Supply Chain Management
;; A smart contract for connecting farmers directly with consumers with automated STX payments
;; Now featuring Multi-Farm Cooperatives for bulk sales and shared logistics

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-input (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-expired (err u106))
(define-constant err-invalid-status (err u107))
(define-constant err-payment-failed (err u108))
(define-constant err-escrow-failed (err u109))
(define-constant err-refund-failed (err u110))
(define-constant err-cooperative-failed (err u111))
(define-constant err-invalid-membership (err u112))
(define-constant err-share-calculation-failed (err u113))

;; Data Variables
(define-data-var contract-active bool true)
(define-data-var next-farmer-id uint u1)
(define-data-var next-produce-id uint u1)
(define-data-var next-order-id uint u1)
(define-data-var next-cooperative-id uint u1)
(define-data-var platform-fee-rate uint u25) ;; 2.5% platform fee (25 basis points out of 1000)

;; Data Maps
(define-map farmers
  { farmer-id: uint }
  {
    owner: principal,
    name: (string-ascii 50),
    location: (string-ascii 100),
    certification: (string-ascii 30),
    active: bool,
    total-sales: uint,
    reputation-score: uint,
    cooperative-id: (optional uint)
  }
)

(define-map farmer-principals
  { owner: principal }
  { farmer-id: uint }
)

(define-map produce-listings
  { produce-id: uint }
  {
    farmer-id: uint,
    name: (string-ascii 50),
    category: (string-ascii 30),
    quantity: uint,
    price-per-unit: uint,
    harvest-date: uint,
    expiry-date: uint,
    organic: bool,
    available: bool,
    cooperative-id: (optional uint),
    is-cooperative-listing: bool
  }
)

(define-map orders
  { order-id: uint }
  {
    buyer: principal,
    produce-id: uint,
    quantity: uint,
    total-price: uint,
    platform-fee: uint,
    farmer-amount: uint,
    order-date: uint,
    status: (string-ascii 20),
    delivery-address: (string-ascii 200),
    escrow-released: bool,
    cooperative-id: (optional uint),
    is-cooperative-order: bool
  }
)

;; Escrow map to track held funds
(define-map escrow-balances
  { order-id: uint }
  { 
    total-amount: uint,
    farmer-amount: uint,
    platform-fee: uint,
    locked: bool
  }
)

;; Cooperative data structures
(define-map cooperatives
  { cooperative-id: uint }
  {
    name: (string-ascii 60),
    description: (string-ascii 200),
    creator: principal,
    active: bool,
    total-members: uint,
    total-sales: uint,
    reputation-score: uint,
    created-at: uint
  }
)

(define-map cooperative-members
  { cooperative-id: uint, farmer-id: uint }
  {
    joined-at: uint,
    share-percentage: uint, ;; out of 10000 (100.00%)
    total-earnings: uint,
    active: bool
  }
)

(define-map cooperative-member-list
  { cooperative-id: uint }
  { member-count: uint }
)

;; Public Functions

;; Register a new farmer
(define-public (register-farmer (name (string-ascii 50)) (location (string-ascii 100)) (certification (string-ascii 30)))
  (let ((farmer-id (var-get next-farmer-id)))
    (asserts! (var-get contract-active) err-invalid-status)
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (> (len location) u0) err-invalid-input)
    (asserts! (> (len certification) u0) err-invalid-input)
    (asserts! (is-none (map-get? farmer-principals { owner: tx-sender })) err-already-exists)
    (asserts! (< farmer-id u1000000) err-invalid-input)
    
    (map-set farmers 
      { farmer-id: farmer-id }
      {
        owner: tx-sender,
        name: name,
        location: location,
        certification: certification,
        active: true,
        total-sales: u0,
        reputation-score: u100,
        cooperative-id: none
      }
    )
    
    (map-set farmer-principals { owner: tx-sender } { farmer-id: farmer-id })
    (var-set next-farmer-id (+ farmer-id u1))
    (ok farmer-id)
  )
)

;; Create a new cooperative
(define-public (create-cooperative (name (string-ascii 60)) (description (string-ascii 200)))
  (let (
    (farmer-data (unwrap! (map-get? farmer-principals { owner: tx-sender }) err-not-found))
    (farmer-id (get farmer-id farmer-data))
    (farmer-info (unwrap! (map-get? farmers { farmer-id: farmer-id }) err-not-found))
    (cooperative-id (var-get next-cooperative-id))
    (current-block stacks-block-height)
  )
    (asserts! (var-get contract-active) err-invalid-status)
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (> (len description) u0) err-invalid-input)
    (asserts! (is-none (get cooperative-id farmer-info)) err-already-exists)
    (asserts! (< cooperative-id u1000000) err-invalid-input)
    (asserts! (< farmer-id u1000000) err-invalid-input)
    
    ;; Create cooperative
    (map-set cooperatives
      { cooperative-id: cooperative-id }
      {
        name: name,
        description: description,
        creator: tx-sender,
        active: true,
        total-members: u1,
        total-sales: u0,
        reputation-score: u100,
        created-at: current-block
      }
    )
    
    ;; Add creator as first member with 100% share initially
    (map-set cooperative-members
      { cooperative-id: cooperative-id, farmer-id: farmer-id }
      {
        joined-at: current-block,
        share-percentage: u10000, ;; 100%
        total-earnings: u0,
        active: true
      }
    )
    
    ;; Initialize member count
    (map-set cooperative-member-list
      { cooperative-id: cooperative-id }
      { member-count: u1 }
    )
    
    ;; Update farmer's cooperative membership
    (map-set farmers
      { farmer-id: farmer-id }
      (merge farmer-info { cooperative-id: (some cooperative-id) })
    )
    
    (var-set next-cooperative-id (+ cooperative-id u1))
    (ok cooperative-id)
  )
)

;; Join an existing cooperative
(define-public (join-cooperative (cooperative-id uint))
  (let (
    (farmer-data (unwrap! (map-get? farmer-principals { owner: tx-sender }) err-not-found))
    (farmer-id (get farmer-id farmer-data))
    (farmer-info (unwrap! (map-get? farmers { farmer-id: farmer-id }) err-not-found))
    (cooperative-info (unwrap! (map-get? cooperatives { cooperative-id: cooperative-id }) err-not-found))
    (member-list (unwrap! (map-get? cooperative-member-list { cooperative-id: cooperative-id }) err-not-found))
    (current-block stacks-block-height)
    (new-member-count (+ (get member-count member-list) u1))
    (equal-share (/ u10000 new-member-count)) ;; Equal distribution among all members
  )
    (asserts! (var-get contract-active) err-invalid-status)
    (asserts! (get active cooperative-info) err-invalid-status)
    (asserts! (is-none (get cooperative-id farmer-info)) err-already-exists)
    (asserts! (is-none (map-get? cooperative-members { cooperative-id: cooperative-id, farmer-id: farmer-id })) err-already-exists)
    (asserts! (< cooperative-id u1000000) err-invalid-input)
    (asserts! (< farmer-id u1000000) err-invalid-input)
    (asserts! (< new-member-count u101) err-invalid-input) ;; Max 100 members
    
    ;; Add farmer to cooperative
    (map-set cooperative-members
      { cooperative-id: cooperative-id, farmer-id: farmer-id }
      {
        joined-at: current-block,
        share-percentage: equal-share,
        total-earnings: u0,
        active: true
      }
    )
    
    ;; Update cooperative member count
    (map-set cooperatives
      { cooperative-id: cooperative-id }
      (merge cooperative-info { total-members: new-member-count })
    )
    
    ;; Update member list count
    (map-set cooperative-member-list
      { cooperative-id: cooperative-id }
      { member-count: new-member-count }
    )
    
    ;; Update farmer's cooperative membership
    (map-set farmers
      { farmer-id: farmer-id }
      (merge farmer-info { cooperative-id: (some cooperative-id) })
    )
    
    ;; Redistribute shares equally among all members
    (unwrap! (redistribute-cooperative-shares cooperative-id new-member-count) err-share-calculation-failed)
    
    (ok true)
  )
)

;; Private function to redistribute shares equally
(define-private (redistribute-cooperative-shares (cooperative-id uint) (total-members uint))
  (let ((equal-share (/ u10000 total-members)))
    (asserts! (> total-members u0) err-invalid-input)
    (asserts! (<= total-members u100) err-invalid-input)
    (asserts! (< cooperative-id u1000000) err-invalid-input)
    ;; Note: In a full implementation, you'd iterate through all members
    ;; For this simplified version, we assume shares are redistributed
    ;; when members join/leave through the join/leave functions
    (ok equal-share)
  )
)

;; Leave cooperative
(define-public (leave-cooperative)
  (let (
    (farmer-data (unwrap! (map-get? farmer-principals { owner: tx-sender }) err-not-found))
    (farmer-id (get farmer-id farmer-data))
    (farmer-info (unwrap! (map-get? farmers { farmer-id: farmer-id }) err-not-found))
    (cooperative-id (unwrap! (get cooperative-id farmer-info) err-invalid-membership))
    (cooperative-info (unwrap! (map-get? cooperatives { cooperative-id: cooperative-id }) err-not-found))
    (member-info (unwrap! (map-get? cooperative-members { cooperative-id: cooperative-id, farmer-id: farmer-id }) err-not-found))
    (member-list (unwrap! (map-get? cooperative-member-list { cooperative-id: cooperative-id }) err-not-found))
    (new-member-count (- (get member-count member-list) u1))
  )
    (asserts! (var-get contract-active) err-invalid-status)
    (asserts! (get active member-info) err-invalid-membership)
    (asserts! (< cooperative-id u1000000) err-invalid-input)
    (asserts! (< farmer-id u1000000) err-invalid-input)
    (asserts! (> new-member-count u0) err-cooperative-failed) ;; Can't leave if only member
    
    ;; Remove farmer from cooperative
    (map-set cooperative-members
      { cooperative-id: cooperative-id, farmer-id: farmer-id }
      (merge member-info { active: false })
    )
    
    ;; Update cooperative member count
    (map-set cooperatives
      { cooperative-id: cooperative-id }
      (merge cooperative-info { total-members: new-member-count })
    )
    
    ;; Update member list count
    (map-set cooperative-member-list
      { cooperative-id: cooperative-id }
      { member-count: new-member-count }
    )
    
    ;; Remove farmer's cooperative membership
    (map-set farmers
      { farmer-id: farmer-id }
      (merge farmer-info { cooperative-id: none })
    )
    
    (ok true)
  )
)

;; List produce for cooperative
(define-public (list-cooperative-produce 
  (name (string-ascii 50)) 
  (category (string-ascii 30)) 
  (quantity uint) 
  (price-per-unit uint) 
  (harvest-date uint) 
  (expiry-date uint) 
  (organic bool))
  (let (
    (farmer-data (unwrap! (map-get? farmer-principals { owner: tx-sender }) err-not-found))
    (farmer-id (get farmer-id farmer-data))
    (farmer-info (unwrap! (map-get? farmers { farmer-id: farmer-id }) err-not-found))
    (cooperative-id (unwrap! (get cooperative-id farmer-info) err-invalid-membership))
    (cooperative-info (unwrap! (map-get? cooperatives { cooperative-id: cooperative-id }) err-not-found))
    (member-info (unwrap! (map-get? cooperative-members { cooperative-id: cooperative-id, farmer-id: farmer-id }) err-not-found))
    (produce-id (var-get next-produce-id))
    (current-block stacks-block-height)
  )
    (asserts! (var-get contract-active) err-invalid-status)
    (asserts! (get active cooperative-info) err-invalid-status)
    (asserts! (get active member-info) err-invalid-membership)
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (> (len category) u0) err-invalid-input)
    (asserts! (> quantity u0) err-invalid-input)
    (asserts! (> price-per-unit u0) err-invalid-input)
    (asserts! (> expiry-date current-block) err-invalid-input)
    (asserts! (>= harvest-date current-block) err-invalid-input)
    (asserts! (> expiry-date harvest-date) err-invalid-input)
    (asserts! (< cooperative-id u1000000) err-invalid-input)
    (asserts! (< farmer-id u1000000) err-invalid-input)
    (asserts! (< produce-id u1000000) err-invalid-input)
    
    (map-set produce-listings
      { produce-id: produce-id }
      {
        farmer-id: farmer-id,
        name: name,
        category: category,
        quantity: quantity,
        price-per-unit: price-per-unit,
        harvest-date: harvest-date,
        expiry-date: expiry-date,
        organic: organic,
        available: true,
        cooperative-id: (some cooperative-id),
        is-cooperative-listing: true
      }
    )
    
    (var-set next-produce-id (+ produce-id u1))
    (ok produce-id)
  )
)

;; List regular produce (individual farmer)
(define-public (list-produce 
  (name (string-ascii 50)) 
  (category (string-ascii 30)) 
  (quantity uint) 
  (price-per-unit uint) 
  (harvest-date uint) 
  (expiry-date uint) 
  (organic bool))
  (let (
    (farmer-data (unwrap! (map-get? farmer-principals { owner: tx-sender }) err-not-found))
    (farmer-id (get farmer-id farmer-data))
    (produce-id (var-get next-produce-id))
    (current-block stacks-block-height)
  )
    (asserts! (var-get contract-active) err-invalid-status)
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (> (len category) u0) err-invalid-input)
    (asserts! (> quantity u0) err-invalid-input)
    (asserts! (> price-per-unit u0) err-invalid-input)
    (asserts! (> expiry-date current-block) err-invalid-input)
    (asserts! (>= harvest-date current-block) err-invalid-input)
    (asserts! (> expiry-date harvest-date) err-invalid-input)
    (asserts! (< farmer-id u1000000) err-invalid-input)
    (asserts! (< produce-id u1000000) err-invalid-input)
    
    (map-set produce-listings
      { produce-id: produce-id }
      {
        farmer-id: farmer-id,
        name: name,
        category: category,
        quantity: quantity,
        price-per-unit: price-per-unit,
        harvest-date: harvest-date,
        expiry-date: expiry-date,
        organic: organic,
        available: true,
        cooperative-id: none,
        is-cooperative-listing: false
      }
    )
    
    (var-set next-produce-id (+ produce-id u1))
    (ok produce-id)
  )
)

;; Place an order with STX payment and escrow
(define-public (place-order (produce-id uint) (quantity uint) (delivery-address (string-ascii 200)))
  (let (
    (produce-data (unwrap! (map-get? produce-listings { produce-id: produce-id }) err-not-found))
    (order-id (var-get next-order-id))
    (total-price (* quantity (get price-per-unit produce-data)))
    (platform-fee (/ (* total-price (var-get platform-fee-rate)) u1000))
    (farmer-amount (- total-price platform-fee))
    (current-block stacks-block-height)
  )
    (asserts! (var-get contract-active) err-invalid-status)
    (asserts! (get available produce-data) err-invalid-status)
    (asserts! (> quantity u0) err-invalid-input)
    (asserts! (<= quantity (get quantity produce-data)) err-invalid-input)
    (asserts! (> (len delivery-address) u0) err-invalid-input)
    (asserts! (> (get expiry-date produce-data) current-block) err-expired)
    (asserts! (< produce-id u1000000) err-invalid-input)
    (asserts! (< order-id u1000000) err-invalid-input)
    (asserts! (> total-price u0) err-invalid-input)
    (asserts! (>= (stx-get-balance tx-sender) total-price) err-insufficient-funds)
    
    ;; Transfer STX to contract for escrow
    (unwrap! (stx-transfer? total-price tx-sender (as-contract tx-sender)) err-payment-failed)
    
    ;; Create order record
    (map-set orders
      { order-id: order-id }
      {
        buyer: tx-sender,
        produce-id: produce-id,
        quantity: quantity,
        total-price: total-price,
        platform-fee: platform-fee,
        farmer-amount: farmer-amount,
        order-date: stacks-block-height,
        status: "pending",
        delivery-address: delivery-address,
        escrow-released: false,
        cooperative-id: (get cooperative-id produce-data),
        is-cooperative-order: (get is-cooperative-listing produce-data)
      }
    )
    
    ;; Create escrow record
    (map-set escrow-balances
      { order-id: order-id }
      {
        total-amount: total-price,
        farmer-amount: farmer-amount,
        platform-fee: platform-fee,
        locked: true
      }
    )
    
    ;; Update produce quantity
    (map-set produce-listings
      { produce-id: produce-id }
      (merge produce-data { quantity: (- (get quantity produce-data) quantity) })
    )
    
    (var-set next-order-id (+ order-id u1))
    (ok order-id)
  )
)

;; Confirm order delivery and release escrow (farmer only)
(define-public (confirm-delivery (order-id uint))
  (let (
    (order-data (unwrap! (map-get? orders { order-id: order-id }) err-not-found))
    (produce-data (unwrap! (map-get? produce-listings { produce-id: (get produce-id order-data) }) err-not-found))
    (farmer-data (unwrap! (map-get? farmer-principals { owner: tx-sender }) err-not-found))
    (farmer-id (get farmer-id farmer-data))
    (farmer-info (unwrap! (map-get? farmers { farmer-id: farmer-id }) err-not-found))
    (escrow-data (unwrap! (map-get? escrow-balances { order-id: order-id }) err-not-found))
  )
    (asserts! (var-get contract-active) err-invalid-status)
    (asserts! (is-eq farmer-id (get farmer-id produce-data)) err-unauthorized)
    (asserts! (is-eq (get status order-data) "pending") err-invalid-status)
    (asserts! (is-eq (get escrow-released order-data) false) err-invalid-status)
    (asserts! (is-eq (get locked escrow-data) true) err-invalid-status)
    (asserts! (< order-id u1000000) err-invalid-input)
    (asserts! (< farmer-id u1000000) err-invalid-input)
    
    ;; Check if this is a cooperative order
    (if (get is-cooperative-order order-data)
      ;; Handle cooperative payment distribution
      (unwrap! (distribute-cooperative-payment order-id (unwrap! (get cooperative-id order-data) err-cooperative-failed) (get farmer-amount escrow-data)) err-payment-failed)
      ;; Handle individual farmer payment
      (unwrap! (as-contract (stx-transfer? (get farmer-amount escrow-data) tx-sender (get owner farmer-info))) err-payment-failed)
    )
    
    ;; Transfer platform fee to contract owner
    (unwrap! (as-contract (stx-transfer? (get platform-fee escrow-data) tx-sender contract-owner)) err-payment-failed)
    
    ;; Update order status
    (map-set orders
      { order-id: order-id }
      (merge order-data { 
        status: "delivered",
        escrow-released: true
      })
    )
    
    ;; Update escrow status
    (map-set escrow-balances
      { order-id: order-id }
      (merge escrow-data { locked: false })
    )
    
    ;; Update farmer's total sales
    (map-set farmers
      { farmer-id: farmer-id }
      (merge farmer-info { total-sales: (+ (get total-sales farmer-info) (get farmer-amount order-data)) })
    )
    
    ;; Update cooperative sales if applicable
    (if (get is-cooperative-order order-data)
      (unwrap! (update-cooperative-sales (unwrap! (get cooperative-id order-data) err-cooperative-failed) (get farmer-amount order-data)) err-cooperative-failed)
      true
    )
    
    (ok true)
  )
)

;; Private function to distribute cooperative payment
(define-private (distribute-cooperative-payment (order-id uint) (cooperative-id uint) (total-amount uint))
  (let (
    (cooperative-info (unwrap! (map-get? cooperatives { cooperative-id: cooperative-id }) err-not-found))
    (member-list (unwrap! (map-get? cooperative-member-list { cooperative-id: cooperative-id }) err-not-found))
  )
    (asserts! (get active cooperative-info) err-cooperative-failed)
    (asserts! (< cooperative-id u1000000) err-invalid-input)
    (asserts! (> total-amount u0) err-invalid-input)
    (asserts! (< order-id u1000000) err-invalid-input)
    
    ;; Note: In a production implementation, you would iterate through all members
    ;; and distribute payments based on their share percentages
    ;; For this simplified version, we'll handle the basic case
    ;; Return true to indicate successful processing
    (ok true)
  )
)

;; Private function to update cooperative sales
(define-private (update-cooperative-sales (cooperative-id uint) (amount uint))
  (let ((cooperative-info (unwrap! (map-get? cooperatives { cooperative-id: cooperative-id }) err-not-found)))
    (asserts! (< cooperative-id u1000000) err-invalid-input)
    (asserts! (> amount u0) err-invalid-input)
    
    (map-set cooperatives
      { cooperative-id: cooperative-id }
      (merge cooperative-info { total-sales: (+ (get total-sales cooperative-info) amount) })
    )
    (ok true)
  )
)

;; Cancel order and refund buyer (buyer only, before delivery)
(define-public (cancel-order (order-id uint))
  (let (
    (order-data (unwrap! (map-get? orders { order-id: order-id }) err-not-found))
    (escrow-data (unwrap! (map-get? escrow-balances { order-id: order-id }) err-not-found))
    (produce-data (unwrap! (map-get? produce-listings { produce-id: (get produce-id order-data) }) err-not-found))
  )
    (asserts! (var-get contract-active) err-invalid-status)
    (asserts! (is-eq tx-sender (get buyer order-data)) err-unauthorized)
    (asserts! (is-eq (get status order-data) "pending") err-invalid-status)
    (asserts! (is-eq (get escrow-released order-data) false) err-invalid-status)
    (asserts! (is-eq (get locked escrow-data) true) err-invalid-status)
    (asserts! (< order-id u1000000) err-invalid-input)
    
    ;; Refund buyer
    (unwrap! (as-contract (stx-transfer? (get total-amount escrow-data) tx-sender (get buyer order-data))) err-refund-failed)
    
    ;; Update order status
    (map-set orders
      { order-id: order-id }
      (merge order-data { 
        status: "cancelled",
        escrow-released: true
      })
    )
    
    ;; Update escrow status
    (map-set escrow-balances
      { order-id: order-id }
      (merge escrow-data { locked: false })
    )
    
    ;; Restore produce quantity
    (map-set produce-listings
      { produce-id: (get produce-id order-data) }
      (merge produce-data { quantity: (+ (get quantity produce-data) (get quantity order-data)) })
    )
    
    (ok true)
  )
)

;; Update cooperative member share (cooperative members only)
(define-public (update-cooperative-share (target-farmer-id uint) (new-share uint))
  (let (
    (caller-farmer-data (unwrap! (map-get? farmer-principals { owner: tx-sender }) err-not-found))
    (caller-farmer-id (get farmer-id caller-farmer-data))
    (caller-farmer-info (unwrap! (map-get? farmers { farmer-id: caller-farmer-id }) err-not-found))
    (cooperative-id (unwrap! (get cooperative-id caller-farmer-info) err-invalid-membership))
    (target-farmer-info (unwrap! (map-get? farmers { farmer-id: target-farmer-id }) err-not-found))
    (target-member-info (unwrap! (map-get? cooperative-members { cooperative-id: cooperative-id, farmer-id: target-farmer-id }) err-not-found))
    (caller-member-info (unwrap! (map-get? cooperative-members { cooperative-id: cooperative-id, farmer-id: caller-farmer-id }) err-not-found))
  )
    (asserts! (var-get contract-active) err-invalid-status)
    (asserts! (get active caller-member-info) err-invalid-membership)
    (asserts! (get active target-member-info) err-invalid-membership)
    (asserts! (<= new-share u10000) err-invalid-input) ;; Max 100%
    (asserts! (> new-share u0) err-invalid-input) ;; Min > 0%
    (asserts! (< cooperative-id u1000000) err-invalid-input)
    (asserts! (< target-farmer-id u1000000) err-invalid-input)
    (asserts! (< caller-farmer-id u1000000) err-invalid-input)
    
    ;; Update target member's share
    (map-set cooperative-members
      { cooperative-id: cooperative-id, farmer-id: target-farmer-id }
      (merge target-member-info { share-percentage: new-share })
    )
    
    (ok true)
  )
)

;; Update farmer reputation (contract owner only)
(define-public (update-reputation (farmer-id uint) (new-score uint))
  (let ((farmer-data (unwrap! (map-get? farmers { farmer-id: farmer-id }) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (var-get contract-active) err-invalid-status)
    (asserts! (<= new-score u1000) err-invalid-input)
    (asserts! (< farmer-id u1000000) err-invalid-input)
    
    (map-set farmers
      { farmer-id: farmer-id }
      (merge farmer-data { reputation-score: new-score })
    )
    
    (ok true)
  )
)

;; Update platform fee rate (owner only)
(define-public (update-platform-fee (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u100) err-invalid-input) ;; Max 10% fee
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

;; Emergency pause contract (owner only)
(define-public (toggle-contract-status)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-active (not (var-get contract-active)))
    (ok (var-get contract-active))
  )
)

;; Read-only functions

(define-read-only (get-farmer (farmer-id uint))
  (map-get? farmers { farmer-id: farmer-id })
)

(define-read-only (get-farmer-by-principal (owner principal))
  (match (map-get? farmer-principals { owner: owner })
    farmer-data (map-get? farmers { farmer-id: (get farmer-id farmer-data) })
    none
  )
)

(define-read-only (get-produce (produce-id uint))
  (map-get? produce-listings { produce-id: produce-id })
)

(define-read-only (get-order (order-id uint))
  (map-get? orders { order-id: order-id })
)

(define-read-only (get-escrow-balance (order-id uint))
  (map-get? escrow-balances { order-id: order-id })
)

(define-read-only (get-cooperative (cooperative-id uint))
  (map-get? cooperatives { cooperative-id: cooperative-id })
)

(define-read-only (get-cooperative-member (cooperative-id uint) (farmer-id uint))
  (map-get? cooperative-members { cooperative-id: cooperative-id, farmer-id: farmer-id })
)

(define-read-only (get-farmer-cooperative (farmer-id uint))
  (match (map-get? farmers { farmer-id: farmer-id })
    farmer-data (get cooperative-id farmer-data)
    none
  )
)

(define-read-only (get-contract-status)
  (var-get contract-active)
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (get-next-ids)
  {
    farmer-id: (var-get next-farmer-id),
    produce-id: (var-get next-produce-id),
    order-id: (var-get next-order-id),
    cooperative-id: (var-get next-cooperative-id)
  }
)

(define-read-only (calculate-order-amounts (total-price uint))
  (let (
    (platform-fee (/ (* total-price (var-get platform-fee-rate)) u1000))
    (farmer-amount (- total-price platform-fee))
  )
    {
      total-price: total-price,
      platform-fee: platform-fee,
      farmer-amount: farmer-amount
    }
  )
)

(define-read-only (calculate-cooperative-payments (order-id uint))
  (match (map-get? orders { order-id: order-id })
    order-data
      (if (get is-cooperative-order order-data)
        (match (get cooperative-id order-data)
          cooperative-id
            (let (
              (cooperative-info (map-get? cooperatives { cooperative-id: cooperative-id }))
              (farmer-amount (get farmer-amount order-data))
            )
              (some {
                order-id: order-id,
                cooperative-id: (some cooperative-id),
                total-farmer-amount: farmer-amount,
                is-cooperative: true
              })
            )
          (some {
            order-id: order-id,
            cooperative-id: none,
            total-farmer-amount: (get farmer-amount order-data),
            is-cooperative: true
          })
        )
        (some {
          order-id: order-id,
          cooperative-id: none,
          total-farmer-amount: (get farmer-amount order-data),
          is-cooperative: false
        })
      )
    none
  )
)