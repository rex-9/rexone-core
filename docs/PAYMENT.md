# Universal Payment & In-App Purchase Architecture (`rexone-core`)

## 1. Executive Summary & Philosophy

RexOne implements a **Universal Payment System** supporting multiple payment gateways and app store in-app purchase ecosystems under a unified, provider-agnostic domain model:

1. **Stripe**: Web checkout sessions, recurring customer subscriptions, card payments, promo coupons, and bidirectional webhooks.
2. **Google Play Store**: Android in-app purchases and subscriptions verified against Google Play Developer APIs.
3. **Apple App Store**: iOS in-app purchases and auto-renewable subscriptions verified against StoreKit 2 JWS / App Store Server API.
4. **Free Products**: Zero-cost tiers (`unit_amount: 0`) that operate natively with `provider: nil`, requiring no external third-party calls while granting immediate entitlements via `AccessService.grant`.

All transactions, regardless of origin, resolve deterministically to cohesive domain entities:
- Purchases: [`Payment::Purchase`](file:///Users/rex/Desktop/Dev/rexone/rexone-core/app/models/payment/purchase.rb)
- Subscriptions: [`Payment::Subscription`](file:///Users/rex/Desktop/Dev/rexone/rexone-core/app/models/payment/subscription.rb)
- Entitlements: [`Access`](file:///Users/rex/Desktop/Dev/rexone/rexone-core/app/models/access.rb) via [`AccessService.grant`](file:///Users/rex/Desktop/Dev/rexone/rexone-core/app/services/access_service.rb)

---

## 2. Architecture & Provider Pattern

Modeled after the modular `Payment` domain models and controllers, the payment subsystem isolates swappable providers directly under `app/services/payment/`:

```
app/services/payment/
├── iap_service.rb               # High-level In-App Purchase verifier (with coupon attribution)
└── providers/
    ├── base.rb                  # Abstract provider interface (Payment::Providers::Base)
    ├── client.rb                # Provider multiplexer & lifecycle coordinator (Payment::Providers::Client)
    ├── error.rb                 # Provider error hierarchy (Payment::Providers::Error)
    ├── stripe.rb                # Stripe checkout, subscription & webhook implementation
    ├── google_play.rb           # Google Play verification & webhook handling
    └── app_store.rb             # Apple App Store verification & webhook handling
```

### 2.1. Provider Contract (`Payment::Providers::Base`)

Every payment provider inherits from `Payment::Providers::Base` and implements:
- `create_product(product)`: Registers product / price in external provider (or no-op for internal/free).
- `update_product(product, params)`: Synchronizes title, description, or price alterations.
- `discard_product(product)`: Archives/deactivates the item in the provider.
- `undiscard_product(product)`: Restores the item in the provider.
- `verify_purchase(payload)`: Validates receipt/token and grants access.
- `verify_subscription(payload)`: Validates subscription token/JWS and manages subscription state.

### 2.2. Provider Multiplexing (`Payment::Providers::Client`)

The client multiplexer determines the target provider dynamically:
- Free Products (`unit_amount == 0`): Stored locally with `provider: nil`; bypasses external provider calls.
- In-App Products (`google_play` or `app_store`): Catalog items created directly in RexOne database with their respective store product identifiers.
- Stripe Products: Synchronized bi-directionally with Stripe's Product and Price APIs.

---

## 3. Database Schema: Unified Omnichannel Catalog & Universal Transactions

RexOne uses a **Unified Product Tier Model** for catalog offerings and universal provider tracking for transactions:

1. **`Payment::Product` (Catalog Tier / Entitlement)**:
   A single tier (e.g., "Pro Monthly", $9/month) maps to multiple external storefronts simultaneously:
   - `stripe_product_id` & `stripe_price_id`: Stripe Product and Price objects for Web and direct card checkout.
   - `google_play_product_id`: Google Play Console in-app / subscription product ID (e.g. `com.rexone.pro.monthly`).
   - `app_store_product_id`: Apple App Store / StoreKit in-app / subscription product ID (e.g. `com.rexone.pro.monthly`).
   - Free products (`unit_amount: 0`) have all store IDs as `nil` and grant immediate access.

2. **Transactional Models (`Payment::Purchase`, `Payment::Subscription`, `Payment::WebhookEvent`)**:
   Transactions occur on a specific payment channel, so they retain a clean, universal `provider` column (`stripe`, `google_play`, `app_store`):

| Table | Column | Type | Nullable | Description |
| :--- | :--- | :--- | :---: | :--- |
| `payment_products` | `stripe_product_id` | `string` | ✔️ | Stripe product identifier (`prod_...`) |
| `payment_products` | `stripe_price_id` | `string` | ✔️ | Stripe price/plan identifier (`price_...`) |
| `payment_products` | `google_play_product_id` | `string` | ✔️ | Google Play SKU (unique index) |
| `payment_products` | `app_store_product_id` | `string` | ✔️ | Apple App Store SKU (unique index) |
| `payment_purchases` | `provider` | `string` | ❌ | Provider name (`stripe`, `google_play`, `app_store`) |
| `payment_purchases` | `provider_payment_id` | `string` | ❌ | External transaction / PaymentIntent ID (unique index) |
| `payment_purchases` | `provider_charge_id` | `string` | ✔️ | External charge ID |
| `payment_purchases` | `provider_customer_id` | `string` | ✔️ | External customer ID |
| `payment_subscriptions` | `provider` | `string` | ❌ | Provider name (`stripe`, `google_play`, `app_store`) |
| `payment_subscriptions` | `provider_subscription_id` | `string` | ❌ | External subscription ID (unique index) |
| `payment_subscriptions` | `provider_price_id` | `string` | ✔️ | External price / plan snapshot ID |
| `payment_subscriptions` | `provider_customer_id` | `string` | ✔️ | External customer ID |
| `payment_subscriptions` | `provider_subscription_item_id` | `string` | ✔️ | External subscription item ID |
| `payment_webhook_events` | `provider` | `string` | ❌ | Provider name (`stripe`, `google_play`, `app_store`) |
| `payment_webhook_events` | `provider_event_id` | `string` | ❌ | External event ID (unique index) |
| `coupons` | `provider` | `string` | ❌ | Provider name (default: `stripe`) |
| `coupons` | `provider_coupon_id` | `string` | ✔️ | External coupon identifier |

### 3.1. Free Product Invariants

1. **Zero Amount (`unit_amount: 0`)**:
   - `interval` is normalized to `nil` (always lifetime access).
   - Can exist natively in local database or be synced from Stripe zero-dollar tiers.
2. **Immediate Access**:
   - Calling `POST /v1/payment/session` for a free product skips Stripe checkout entirely.
   - It grants lifetime access directly via `AccessService.grant` and returns `{ free_access_granted: true, access_id: ... }`.

### 3.2. Bi-Directional Catalog & In-App Store SKU Synchronization

RexOne supports 100% bi-directional synchronization between the Stripe catalog and RexOne database, including mobile in-app store IDs:

1. **Approach A (Stripe Dashboard $\rightarrow$ RexOne DB via Webhooks)**:
   - When creating or modifying a product in the Stripe Dashboard, specify `google_play_product_id` and `app_store_product_id` in Stripe's product metadata.
   - Stripe emits `product.created`, `product.updated`, or `price.created` webhooks.
   - `Payment::Providers::Stripe` automatically extracts `google_play_product_id` and `app_store_product_id` from `stripe_product.metadata` and populates the database `Payment::Product` row.

2. **Approach B (RexOne Admin Portal $\rightarrow$ Stripe API & Local DB)**:
   - When creating or updating a product via RexOne Admin API or Web Portal, provide `name`, `unit_amount`, `interval`, `google_play_product_id`, and `app_store_product_id`.
   - RexOne persists the record locally and automatically transmits `google_play_product_id` and `app_store_product_id` into `Stripe::Product` metadata via the Stripe API.
   - Any subsequent updates from either side remain in continuous, bidirectional parity.

---

## 4. API Endpoints

### 4.1. Client Endpoints (`/v1/payment`)

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/v1/payment/products` | Lists active products (supports `?recurring=true\|false` filter and search). |
| `POST` | `/v1/payment/session` | Initiates checkout (or grants instant access for free products). |
| `GET` | `/v1/payment/session/:id` | Polls checkout session status. |
| `GET` | `/v1/payment/subscriptions` | Lists current user's subscriptions. |
| `POST` | `/v1/payment/subscriptions/:id/cancel` | Requests cancellation at period end. |
| `POST` | `/v1/payment/subscriptions/:id/resume` | Resumes a subscription scheduled for cancellation. |
| `GET` | `/v1/payment/purchases` | Lists current user's one-time purchase receipts. |
| `POST` | `/v1/payment/coupons/validate` | Validates promo/referral coupon code. |
| `POST` | `/v1/payment/verify` | **In-App Purchase verification endpoint** (Google Play & App Store). |

#### Payload: `POST /v1/payment/verify`
```json
{
  "provider": "google_play", // or "app_store"
  "product_id": "81ab5c7b-2677-451a-adb5-763985260086",
  "purchase_token": "inapp:...", // for Google Play
  "package_name": "com.rex9.rexone", // for Google Play
  "receipt_data": "MIIT...", // for Apple App Store
  "transaction_id": "GPA.1234-5678-9012",
  "coupon_code": "SUMMER50" // optional: server-side promo coupon
}
```

#### Coupon Handling with In-App Purchases:
1. **Without Coupon (`coupon_code: nil`)**:
   - The token/receipt is verified directly with Google Play or Apple App Store.
   - Domain purchase/subscription records and entitlements are provisioned immediately.
   - Zero coupon redemptions recorded (`used_count` untouched).
2. **With Valid Coupon**:
   - Upfront validation ensures the coupon exists, is active, within date range, within redemption limits, and matches product restrictions.
   - Following successful store verification, `CouponService.apply_to_checkout!` records redemption under `user.lock!`, creating `Payment::UserCoupon`, incrementing `used_count`, and attaching discount metadata to the response.
3. **With Invalid/Expired Coupon**:
   - Verification fails fast with `422 Unprocessable Entity` before contacting external app stores, preventing invalid redemptions.
4. **100% Free Coupon**:
   - If a coupon discounts 100% of the price, clients route directly to server entitlement grant without invoking native app store sheets.

### 4.2. Admin Endpoints (`/v1/admin/payment`)

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/v1/admin/payment/products` | Admin list with soft-deleted items. |
| `POST` | `/v1/admin/payment/products` | Create product (supports `provider`, `provider_product_id`, `provider_price_id`, or free). |
| `PUT` | `/v1/admin/payment/products/:id` | Update product details. |
| `DELETE` | `/v1/admin/payment/products/:id` | Soft-deletes product and deactivates provider entry. |
| `POST` | `/v1/admin/payment/products/:id/undiscard` | Restores soft-deleted product and reactivates provider entry. |

---

## 5. Mobile Integration (`rexone_mobile`)

### 5.1. Silent Feature Decoupling
To ensure zero friction for developers working without mobile store developer accounts:
```dart
// lib/constants/payment.constants.dart
class PaymentConfig {
  const PaymentConfig._();

  /// Set to true to enable In-App Purchases (Google Play & Apple App Store).
  /// Defaults to false so developers can proceed without native store setups.
  static bool enableInAppPurchases = false;

  /// Prefer IAP over web checkout when both options are available.
  static bool preferInAppPurchases = false;
}
```

When `enableInAppPurchases` is `false`:
- `InAppPurchaseService` remains completely inert: zero native Pigeon channel calls, zero store connection attempts.
- UI renders standard, clean Stripe web checkout flows.

### 5.2. Native Store Flow When Enabled
When `PaymentConfig.enableInAppPurchases = true`:
1. `InAppPurchaseService` connects to native store streams.
2. If `product.isInApp`, `CheckoutBottomSheet` renders native "Pay with Google Play" or "Pay with App Store" button, alongside optional web checkout fallback.
3. Upon store confirmation, the receipt/token is submitted to `POST /v1/payment/verify`.
4. Backend verifies credentials and invokes `AccessService.grant`.
5. Mobile completes native transaction via `InAppPurchase.instance.completePurchase(purchase)`.
