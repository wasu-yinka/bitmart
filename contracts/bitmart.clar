;; Title: BitMart - Decentralized Bitcoin Commerce Protocol
;;
;; Summary:
;; A comprehensive peer-to-peer marketplace protocol leveraging Bitcoin's security
;; through Stacks Layer 2, enabling trustless commerce with native BTC settlement,
;; automated escrow, and reputation-based brand verification.
;;
;; Description:
;; BitMart revolutionizes decentralized commerce by combining Bitcoin's unparalleled
;; security with smart contract capabilities. Merchants establish verified brands,
;; list products through direct sales or time-based auctions, while customers enjoy
;; transparent pricing and community-driven reviews. All transactions are secured
;; by Bitcoin's proof-of-work consensus through the Stacks blockchain, ensuring
;; immutable transaction records and automated settlement without intermediaries.
;; The protocol features dynamic auction mechanics, reputation scoring, and
;; minimal platform fees to foster a thriving Bitcoin-native economy.
;;

;; CONSTANTS & ERROR CODES

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_BRAND_OWNER (err u101))
(define-constant ERR_INVALID_PRICE (err u102))
(define-constant ERR_PRODUCT_NOT_FOUND (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_AUCTION_EXPIRED (err u105))
(define-constant ERR_BID_TOO_LOW (err u106))
(define-constant ERR_INVALID_AUCTION (err u107))
(define-constant ERR_INVALID_DURATION (err u108))
(define-constant ERR_INVALID_RATING (err u109))
(define-constant ERR_INVALID_INPUT (err u110))

;; DATA VARIABLES

;; Platform fee in basis points (250 = 2.5%)
(define-data-var platform-fee-bps uint u250)

;; Global product counter for unique IDs
(define-data-var product-counter uint u0)

;; DATA STRUCTURES

;; Brand registry with verification status
(define-map brands
  principal
  {
    name: (string-ascii 64),
    is-verified: bool,
    registration-block: uint,
  }
)

;; Product catalog with comprehensive metadata
(define-map products
  uint
  {
    merchant: principal,
    title: (string-ascii 128),
    description: (string-ascii 512),
    price-sats: uint,
    is-available: bool,
    creation-block: uint,
    is-auction-item: bool,
  }
)

;; Auction-specific data
(define-map auctions
  uint
  {
    expiry-block: uint,
    reserve-price: uint,
    top-bid: uint,
    leading-bidder: (optional principal),
    is-live: bool,
  }
)

;; Customer reviews and ratings
(define-map reviews
  {
    product-id: uint,
    customer: principal,
  }
  {
    star-rating: uint,
    review-text: (string-ascii 256),
    review-block: uint,
  }
)

;; INPUT VALIDATION UTILITIES

;; Validate string contains meaningful content
(define-private (is-valid-text (input (string-ascii 512)))
  (let ((text-length (len input)))
    (and
      (> text-length u0)
      (< text-length u513)
      ;; Basic non-empty check
      (not (is-eq input ""))
    )
  )
)

;; Validate brand name meets requirements
(define-private (is-valid-brand-name (name (string-ascii 64)))
  (and
    (>= (len name) u3) ;; Minimum 3 characters
    (<= (len name) u64) ;; Maximum 64 characters
    (is-valid-text (unwrap-panic (as-max-len? name u512)))
  )
)

;; Validate product title
(define-private (is-valid-product-title (title (string-ascii 128)))
  (and
    (>= (len title) u3)
    (<= (len title) u128)
    (is-valid-text (unwrap-panic (as-max-len? title u512)))
  )
)

;; Validate product description
(define-private (is-valid-description (desc (string-ascii 512)))
  (and
    (>= (len desc) u10)
    (<= (len desc) u512)
    (is-valid-text desc)
  )
)

;; BRAND MANAGEMENT

;; Register a new merchant brand
(define-public (register-brand (brand-name (string-ascii 64)))
  (begin
    ;; Validate brand name
    (asserts! (is-valid-brand-name brand-name) ERR_INVALID_INPUT)

    ;; Create brand record
    (ok (map-set brands tx-sender {
      name: brand-name,
      is-verified: false,
      registration-block: stacks-block-height,
    }))
  )
)

;; Verify brand (contract owner only)
(define-public (verify-brand (merchant-address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (let ((brand-info (unwrap! (map-get? brands merchant-address) ERR_INVALID_BRAND_OWNER)))
      (ok (map-set brands merchant-address (merge brand-info { is-verified: true })))
    )
  )
)

;; PRODUCT LISTINGS

;; List product for direct sale
(define-public (list-product
    (title (string-ascii 128))
    (description (string-ascii 512))
    (price-sats uint)
  )
  (let (
      (merchant-brand (unwrap! (map-get? brands tx-sender) ERR_INVALID_BRAND_OWNER))
      (new-product-id (+ (var-get product-counter) u1))
    )
    ;; Validate inputs
    (asserts! (is-valid-product-title title) ERR_INVALID_INPUT)
    (asserts! (is-valid-description description) ERR_INVALID_INPUT)
    (asserts! (> price-sats u0) ERR_INVALID_PRICE)

    ;; Create product listing
    (var-set product-counter new-product-id)
    (ok (map-set products new-product-id {
      merchant: tx-sender,
      title: title,
      description: description,
      price-sats: price-sats,
      is-available: true,
      creation-block: stacks-block-height,
      is-auction-item: false,
    }))
  )
)

;; Purchase product directly
(define-public (buy-product (product-id uint))
  (let (
      (product-info (unwrap! (map-get? products product-id) ERR_PRODUCT_NOT_FOUND))
      (total-price (get price-sats product-info))
      (merchant (get merchant product-info))
      (platform-fee (/ (* total-price (var-get platform-fee-bps)) u10000))
    )
    ;; Validate purchase conditions
    (asserts! (get is-available product-info) ERR_PRODUCT_NOT_FOUND)
    (asserts! (not (get is-auction-item product-info)) ERR_INVALID_AUCTION)
    (asserts! (>= (stx-get-balance tx-sender) total-price)
      ERR_INSUFFICIENT_BALANCE
    )

    ;; Process payment
    (try! (stx-transfer? platform-fee tx-sender CONTRACT_OWNER))
    (try! (stx-transfer? (- total-price platform-fee) tx-sender merchant))

    ;; Mark as sold
    (map-set products product-id (merge product-info { is-available: false }))

    (ok true)
  )
)

;; AUCTION SYSTEM

;; Create auction listing
(define-public (create-auction
    (title (string-ascii 128))
    (description (string-ascii 512))
    (reserve-price uint)
    (auction-blocks uint)
  )
  (let (
      (merchant-brand (unwrap! (map-get? brands tx-sender) ERR_INVALID_BRAND_OWNER))
      (new-product-id (+ (var-get product-counter) u1))
      (auction-end (+ stacks-block-height auction-blocks))
    )
    ;; Validate auction parameters
    (asserts! (is-valid-product-title title) ERR_INVALID_INPUT)
    (asserts! (is-valid-description description) ERR_INVALID_INPUT)
    (asserts! (>= auction-blocks u144) ERR_INVALID_DURATION)
    ;; Min ~24 hours
    (asserts! (> reserve-price u0) ERR_INVALID_PRICE)

    ;; Create product and auction
    (var-set product-counter new-product-id)
    (map-set products new-product-id {
      merchant: tx-sender,
      title: title,
      description: description,
      price-sats: reserve-price,
      is-available: true,
      creation-block: stacks-block-height,
      is-auction-item: true,
    })

    (ok (map-set auctions new-product-id {
      expiry-block: auction-end,
      reserve-price: reserve-price,
      top-bid: u0,
      leading-bidder: none,
      is-live: true,
    }))
  )
)

;; Submit auction bid
(define-public (submit-bid
    (product-id uint)
    (bid-amount uint)
  )
  (let (
      (product-info (unwrap! (map-get? products product-id) ERR_PRODUCT_NOT_FOUND))
      (auction-info (unwrap! (map-get? auctions product-id) ERR_INVALID_AUCTION))
    )
    ;; Validate bid conditions
    (asserts! (get is-live auction-info) ERR_AUCTION_EXPIRED)
    (asserts! (< stacks-block-height (get expiry-block auction-info))
      ERR_AUCTION_EXPIRED
    )
    (asserts! (>= bid-amount (get reserve-price auction-info)) ERR_BID_TOO_LOW)
    (asserts! (> bid-amount (get top-bid auction-info)) ERR_BID_TOO_LOW)
    (asserts! (>= (stx-get-balance tx-sender) bid-amount)
      ERR_INSUFFICIENT_BALANCE
    )

    ;; Refund previous bidder
    (match (get leading-bidder auction-info)
      previous-bidder (try! (stx-transfer? (get top-bid auction-info) CONTRACT_OWNER previous-bidder))
      true
    )

    ;; Accept new bid
    (try! (stx-transfer? bid-amount tx-sender CONTRACT_OWNER))

    ;; Update auction state
    (ok (map-set auctions product-id
      (merge auction-info {
        top-bid: bid-amount,
        leading-bidder: (some tx-sender),
      })
    ))
  )
)

;; Finalize completed auction
(define-public (finalize-auction (product-id uint))
  (let (
      (product-info (unwrap! (map-get? products product-id) ERR_PRODUCT_NOT_FOUND))
      (auction-info (unwrap! (map-get? auctions product-id) ERR_INVALID_AUCTION))
      (merchant (get merchant product-info))
    )
    ;; Validate auction completion
    (asserts! (get is-live auction-info) ERR_AUCTION_EXPIRED)
    (asserts! (>= stacks-block-height (get expiry-block auction-info))
      ERR_AUCTION_EXPIRED
    )

    ;; Process winning bid
    (match (get leading-bidder auction-info)
      winner (let (
          (final-bid (get top-bid auction-info))
          (platform-fee (/ (* final-bid (var-get platform-fee-bps)) u10000))
        )
        ;; Distribute payment
        (try! (stx-transfer? platform-fee CONTRACT_OWNER CONTRACT_OWNER))
        (try! (stx-transfer? (- final-bid platform-fee) CONTRACT_OWNER merchant))

        ;; Close auction
        (map-set products product-id (merge product-info { is-available: false }))
        (ok (map-set auctions product-id (merge auction-info { is-live: false })))
      )
      ERR_INVALID_AUCTION
    )
  )
)

;; REVIEW SYSTEM

;; Submit product review
(define-public (submit-review
    (product-id uint)
    (rating uint)
    (review-comment (string-ascii 256))
  )
  (let ((product-info (unwrap! (map-get? products product-id) ERR_PRODUCT_NOT_FOUND)))
    ;; Validate review parameters
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (asserts! (and (>= (len review-comment) u1) (<= (len review-comment) u256))
      ERR_INVALID_INPUT
    )

    ;; Store review
    (ok (map-set reviews {
      product-id: product-id,
      customer: tx-sender,
    } {
      star-rating: rating,
      review-text: review-comment,
      review-block: stacks-block-height,
    }))
  )
)

;; READ-ONLY FUNCTIONS

;; Get product information
(define-read-only (get-product-info (product-id uint))
  (map-get? products product-id)
)

;; Get brand information
(define-read-only (get-brand-info (merchant principal))
  (map-get? brands merchant)
)

;; Get auction details
(define-read-only (get-auction-info (product-id uint))
  (map-get? auctions product-id)
)

;; Get customer review
(define-read-only (get-product-review
    (product-id uint)
    (customer principal)
  )
  (map-get? reviews {
    product-id: product-id,
    customer: customer,
  })
)

;; Get current platform fee
(define-read-only (get-platform-fee)
  (var-get platform-fee-bps)
)

;; Get total products listed
(define-read-only (get-product-count)
  (var-get product-counter)
)

;; ADMIN FUNCTIONS

;; Update platform fee (owner only)
(define-public (update-platform-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee-bps u1000) ERR_INVALID_INPUT) ;; Max 10%
    (ok (var-set platform-fee-bps new-fee-bps))
  )
)
