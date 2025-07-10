;; HarvestHub - Decentralized Farm-to-Table Supply Chain Management
;; A smart contract for connecting farmers directly with consumers

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

;; Data Variables
(define-data-var contract-active bool true)
(define-data-var next-farmer-id uint u1)
(define-data-var next-produce-id uint u1)
(define-data-var next-order-id uint u1)

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
    reputation-score: uint
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
    available: bool
  }
)

(define-map orders
  { order-id: uint }
  {
    buyer: principal,
    produce-id: uint,
    quantity: uint,
    total-price: uint,
    order-date: uint,
    status: (string-ascii 20),
    delivery-address: (string-ascii 200)
  }
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
    
    (map-set farmers 
      { farmer-id: farmer-id }
      {
        owner: tx-sender,
        name: name,
        location: location,
        certification: certification,
        active: true,
        total-sales: u0,
        reputation-score: u100
      }
    )
    
    (map-set farmer-principals { owner: tx-sender } { farmer-id: farmer-id })
    (var-set next-farmer-id (+ farmer-id u1))
    (ok farmer-id)
  )
)

;; List new produce
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
    (asserts! (< farmer-id u1000000) err-invalid-input) ;; Validate farmer-id range
    (asserts! (< produce-id u1000000) err-invalid-input) ;; Validate produce-id range
    
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
        available: true
      }
    )
    
    (var-set next-produce-id (+ produce-id u1))
    (ok produce-id)
  )
)

;; Place an order
(define-public (place-order (produce-id uint) (quantity uint) (delivery-address (string-ascii 200)))
  (let (
    (produce-data (unwrap! (map-get? produce-listings { produce-id: produce-id }) err-not-found))
    (order-id (var-get next-order-id))
    (total-price (* quantity (get price-per-unit produce-data)))
    (current-block stacks-block-height)
  )
    (asserts! (var-get contract-active) err-invalid-status)
    (asserts! (get available produce-data) err-invalid-status)
    (asserts! (> quantity u0) err-invalid-input)
    (asserts! (<= quantity (get quantity produce-data)) err-invalid-input)
    (asserts! (> (len delivery-address) u0) err-invalid-input)
    (asserts! (> (get expiry-date produce-data) current-block) err-expired)
    (asserts! (< produce-id u1000000) err-invalid-input) ;; Validate produce-id range
    (asserts! (< order-id u1000000) err-invalid-input) ;; Validate order-id range
    
    (map-set orders
      { order-id: order-id }
      {
        buyer: tx-sender,
        produce-id: produce-id,
        quantity: quantity,
        total-price: total-price,
        order-date: stacks-block-height,
        status: "pending",
        delivery-address: delivery-address
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

;; Confirm order delivery (farmer only)
(define-public (confirm-delivery (order-id uint))
  (let (
    (order-data (unwrap! (map-get? orders { order-id: order-id }) err-not-found))
    (produce-data (unwrap! (map-get? produce-listings { produce-id: (get produce-id order-data) }) err-not-found))
    (farmer-data (unwrap! (map-get? farmer-principals { owner: tx-sender }) err-not-found))
    (farmer-id (get farmer-id farmer-data))
    (farmer-info (unwrap! (map-get? farmers { farmer-id: farmer-id }) err-not-found))
  )
    (asserts! (var-get contract-active) err-invalid-status)
    (asserts! (is-eq farmer-id (get farmer-id produce-data)) err-unauthorized)
    (asserts! (is-eq (get status order-data) "pending") err-invalid-status)
    (asserts! (< order-id u1000000) err-invalid-input) ;; Validate order-id range
    (asserts! (< farmer-id u1000000) err-invalid-input) ;; Validate farmer-id range
    
    (map-set orders
      { order-id: order-id }
      (merge order-data { status: "delivered" })
    )
    
    ;; Update farmer's total sales
    (map-set farmers
      { farmer-id: farmer-id }
      (merge farmer-info { total-sales: (+ (get total-sales farmer-info) (get total-price order-data)) })
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
    (asserts! (< farmer-id u1000000) err-invalid-input) ;; Validate farmer-id range
    
    (map-set farmers
      { farmer-id: farmer-id }
      (merge farmer-data { reputation-score: new-score })
    )
    
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

(define-read-only (get-contract-status)
  (var-get contract-active)
)

(define-read-only (get-next-ids)
  {
    farmer-id: (var-get next-farmer-id),
    produce-id: (var-get next-produce-id),
    order-id: (var-get next-order-id)
  }
)