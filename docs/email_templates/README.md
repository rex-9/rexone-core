# Email Templates & Alert Center Master Shell

Transactional and broadcast emails in RexOne are rendered through `EmailService::TemplateRenderer` using a unified, responsive **Master Shell** styled in RexOne's cyber-glass aesthetic.

## Architecture

1. **Master Shell**: A single, responsive HTML layout containing the RexOne Alert Center header, typography, primary accent colors (`#ff3048`), highlight callouts, CTA buttons, and standard footer.
2. **Template Catalog**: Programmatically registers core transactional templates with declarative headlines, bodies, and slots.
3. **Ad-Hoc Campaigns & Admin Broadcasts**: `TemplateRenderer.render_content` dynamically wraps any title, body, highlight box (e.g. promo/OTP code), details table, or CTA action link into the branded Master Shell without requiring raw HTML or code modifications.

## Core Templates

- `email_confirmation`: OTP confirmation code box
- `password_reset`: Passcode reset button + fallback link
- `payment_purchase_confirmation`: Receipt details grid (Amount, Date)
- `payment_failed`: Grace period alert with update payment CTA
- `payment_subscription_confirmation`: Subscription activation details
- `payment_subscription_canceled`: Cancellation notice with access expiration
- `payment_subscription_resumed`: Resumed billing schedule notice
- `welcome`: Onboarding welcome notice
- `sign_in_alert`: Security login alert with device timestamp

## Supported Dynamic Variables

Placeholders use `{{snake_case}}` and are automatically sanitized against HTML injection:

- `user_name` / `name`
- `email` / `user_email`
- `code` / `promo_code` / `highlight`
- `reset_url` / `cta_url` / `link`
- `cta_text`
- `product_name`
- `amount`
- `date`
- `period`
- `current_period_start`
- `current_period_end`
- `due_date`
- `canceled_on`
- `valid_until`
- `time`
- *Any custom variable* passed in template metadata / `data` hash

## Client Base URL Resolution

In email delivery, relative action links (e.g. `/home`, `/payment`, `/pricing`) are automatically converted to absolute URLs via `AppConfig.client_url(path)` using the canonical `RAILS_CLIENT_BASE_URL` defined in `.env.example` (default: `http://localhost:4000`).

This ensures email CTA buttons and plaintext fallback URLs always generate fully qualified links (e.g., `https://rexone.rex9.me/home`), preventing broken domain lookups in email clients.

## Zero Static HTML Files

All 9 transactional templates and dynamic campaigns compile in-memory directly from `EmailService::TemplateRenderer`. Static HTML template files on disk have been completely removed, eliminating stale code duplication and enabling instant styling updates across the entire email catalog from a single Master Shell layout.
