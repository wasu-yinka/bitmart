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