module MessageService
  class Payment < Base
    # API responses
    PRODUCTS_FETCHED = "payment.products.fetched"
    PRODUCT_FETCHED = "payment.products.fetched_one"
    TRANSACTIONS_FETCHED = "payment.transactions.fetched"
    TRANSACTION_FETCHED = "payment.transactions.fetched_one"
    RECENT_TRANSACTIONS_FETCHED = "payment.transactions.recent_fetched"
    SUBSCRIPTIONS_FETCHED = "payment.subscriptions.fetched"
    SUBSCRIPTION_FETCHED = "payment.subscriptions.fetched_one"
    ALREADY_SUBSCRIBED = "payment.checkout.already_subscribed"
    ACTIVE_SUBSCRIPTION_EXISTS = "payment.checkout.active_subscription_exists"
    CHECKOUT_CREATE_FAILED = "payment.checkout.create_failed"
    CHECKOUT_CREATED = "payment.checkout.created"
    SESSION_NOT_FOUND = "payment.checkout.session_not_found"
    SESSION_STATUS = "payment.checkout.session_status"
    CANNOT_CANCEL = "payment.subscriptions.cannot_cancel"
    ALREADY_SCHEDULED_FOR_CANCELLATION =
      "payment.subscriptions.already_scheduled_for_cancellation"
    NOT_CANCELABLE = "payment.subscriptions.not_cancelable"
    CANCEL_FAILED = "payment.subscriptions.cancel_failed"
    CANCELLATION_SCHEDULED = "payment.subscriptions.cancellation_scheduled"
    CANNOT_RESUME = "payment.subscriptions.cannot_resume"
    NOT_SCHEDULED_FOR_CANCELLATION =
      "payment.subscriptions.not_scheduled_for_cancellation"
    RESUME_FAILED = "payment.subscriptions.resume_failed"
    RESUMED = "payment.subscriptions.resumed"
    CANNOT_REMOVE = "payment.subscriptions.cannot_remove"
    ONLY_ENDED_CAN_BE_REMOVED = "payment.subscriptions.only_ended_can_be_removed"
    REMOVED = "payment.subscriptions.removed"

    # Webhook responses
    INVALID_STRIPE_SIGNATURE = "payment.webhooks.invalid_stripe_signature"
    INVALID_JSON_PAYLOAD = "payment.webhooks.invalid_json_payload"
    WEBHOOK_QUEUE_FAILED = "payment.webhooks.queue_failed"
    WEBHOOK_PERSIST_FAILED = "payment.webhooks.persist_failed"
    WEBHOOK_PROCESSING_FAILED = "payment.webhooks.processing_failed"

    # Notifications
    PAYMENT_SUCCESS_TITLE = "payment.notifications.payment_success.title"
    PAYMENT_SUCCESS_BODY = "payment.notifications.payment_success.body"
    SUBSCRIPTION_CREATED_TITLE = "payment.notifications.subscription_created.title"
    SUBSCRIPTION_CREATED_BODY = "payment.notifications.subscription_created.body"
    SUBSCRIPTION_CANCELED_TITLE = "payment.notifications.subscription_canceled.title"
    SUBSCRIPTION_CANCELED_BODY = "payment.notifications.subscription_canceled.body"
    SUBSCRIPTION_CANCELED_BODY_WITH_DATE =
      "payment.notifications.subscription_canceled.body_with_date"
    SUBSCRIPTION_RESUMED_TITLE = "payment.notifications.subscription_resumed.title"
    SUBSCRIPTION_RESUMED_BODY = "payment.notifications.subscription_resumed.body"
    PAYMENT_FAILED_TITLE = "payment.notifications.payment_failed.title"
    PAYMENT_FAILED_BODY = "payment.notifications.payment_failed.body"
    TODAY = "payment.notifications.today"
    END_OF_PERIOD = "payment.notifications.end_of_period"
  end
end
