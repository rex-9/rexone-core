flowchart TD

subgraph group_api["Rails API &amp; Admin"]
node_routes["Routes &amp; Rails boot<br/>Rails entrypoint<br/>[routes.rb]"]
node_api_controller["API controller boundary<br/>controller base"]
node_authorization["Authorization<br/>controller concern<br/>[authorization.rb]"]
node_admin["Admin surface<br/>admin controller"]
end

subgraph group_domain["Domain Workflows"]
node_identity_iam["Identity, IAM &amp; access<br/>domain models<br/>[user.rb]"]
node_commerce["Commerce &amp; webhook state<br/>payment models<br/>[webhook_event.rb]"]
node_access_service["Access grants<br/>entitlement service<br/>[access_service.rb]"]
node_media_pipeline["Media pipeline<br/>media workflow"]
node_chat_ai["Chat &amp; AI workflow<br/>chat service<br/>[message_service.rb]"]
node_notification_center["Notification center<br/>notification service<br/>[center.rb]"]
end

subgraph group_async["Async &amp; Real-time"]
node_postgres[("PostgreSQL<br/>system of record<br/>[schema.rb]")]
node_solid_queue["Solid Queue<br/>job runtime<br/>[queue.yml]"]
node_payment_job["Webhook processor<br/>background job"]
node_chat_job["Chat processor<br/>background job"]
node_delivery_job["Notification delivery<br/>background job<br/>[deliver_job.rb]"]
node_action_cable["Action Cable channels<br/>real-time transport"]
end

subgraph group_external["Providers &amp; Runtime"]
  node_payment_provider{ { "Stripe adapter<br/>payment provider<br/>[stripe.rb]" } }
  node_ai_providers{ { "AI providers<br/>provider boundary<br/>[client.rb]" } }
  node_delivery_providers{ { "Push, email &amp; socket adapters<br/>delivery provider boundary<br/>[one_signal.rb]" } }
  node_storage_providers{ { "Storage adapters<br/>media provider boundary<br/>[client.rb]" } }
node_container_runtime["Container topology<br/>deployment"]
end

node_routes-- >| "API requests" | node_api_controller
node_routes-- >| "admin requests" | node_admin
node_api_controller-- >| "enforces access" | node_authorization
node_authorization-- >| "checks roles and grants" | node_identity_iam
node_api_controller-- >| "commerce endpoints" | node_commerce
node_api_controller-- >| "asset requests" | node_media_pipeline
node_api_controller-- >| "chat requests" | node_chat_ai
node_identity_iam-- >| "persists" | node_postgres
node_commerce-- >| "persists events and subscriptions" | node_postgres
node_commerce-- >| "queues webhook work" | node_solid_queue
node_solid_queue-- >| "executes" | node_payment_job
node_payment_job-- >| "reconciles Stripe" | node_payment_provider
node_payment_job-- >| "updates entitlements" | node_access_service
node_access_service-- >| "creates grants" | node_identity_iam
node_media_pipeline-- >| "defers transforms" | node_solid_queue
node_media_pipeline-- >| "stores assets" | node_storage_providers
node_chat_ai-- >| "queues completions" | node_solid_queue
node_solid_queue-- >| "executes" | node_chat_job
node_chat_job-- >| "invokes" | node_ai_providers
node_notification_center-- >| "queues delivery" | node_solid_queue
node_solid_queue-- >| "executes" | node_delivery_job
node_delivery_job-- >| "delivers" | node_delivery_providers
node_notification_center-- >| "in-app updates" | node_action_cable
node_container_runtime-- >| "runs" | node_postgres
node_container_runtime-- >| "runs worker" | node_solid_queue

click node_routes "https://github.com/rex-9/rexone-core/blob/dev/config/routes.rb"
click node_api_controller "https://github.com/rex-9/rexone-core/blob/dev/app/controllers/v1/application_controller.rb"
click node_authorization "https://github.com/rex-9/rexone-core/blob/dev/app/controllers/concerns/authorization.rb"
click node_admin "https://github.com/rex-9/rexone-core/blob/dev/app/controllers/admin/application_controller.rb"
click node_identity_iam "https://github.com/rex-9/rexone-core/blob/dev/app/models/user.rb"
click node_commerce "https://github.com/rex-9/rexone-core/blob/dev/app/models/payment/webhook_event.rb"
click node_access_service "https://github.com/rex-9/rexone-core/blob/dev/app/services/access_service.rb"
click node_media_pipeline "https://github.com/rex-9/rexone-core/blob/dev/app/jobs/media/compress_media_job.rb"
click node_chat_ai "https://github.com/rex-9/rexone-core/blob/dev/app/services/chat/message_service.rb"
click node_notification_center "https://github.com/rex-9/rexone-core/blob/dev/app/services/notification_service/center.rb"
click node_postgres "https://github.com/rex-9/rexone-core/blob/dev/db/schema.rb"
click node_solid_queue "https://github.com/rex-9/rexone-core/blob/dev/config/queue.yml"
click node_payment_job "https://github.com/rex-9/rexone-core/blob/dev/app/jobs/payment/process_webhook_job.rb"
click node_chat_job "https://github.com/rex-9/rexone-core/blob/dev/app/jobs/chat/process_message_job.rb"
click node_delivery_job "https://github.com/rex-9/rexone-core/blob/dev/app/jobs/notification/deliver_job.rb"
click node_action_cable "https://github.com/rex-9/rexone-core/blob/dev/app/channels/notification_channel.rb"
click node_payment_provider "https://github.com/rex-9/rexone-core/blob/dev/app/services/payment_service/stripe.rb"
click node_ai_providers "https://github.com/rex-9/rexone-core/blob/dev/app/services/ai/providers/client.rb"
click node_delivery_providers "https://github.com/rex-9/rexone-core/blob/dev/app/services/push_noti_service/one_signal.rb"
click node_storage_providers "https://github.com/rex-9/rexone-core/blob/dev/app/services/storage_service/client.rb"
click node_container_runtime "https://github.com/rex-9/rexone-core/blob/dev/docker-compose.yaml"

classDef toneNeutral fill: #f8fafc, stroke:#334155, stroke - width: 1.5px, color:#0f172a
classDef toneBlue fill: #dbeafe, stroke:#2563eb, stroke - width: 1.5px, color:#172554
classDef toneAmber fill: #fef3c7, stroke: #d97706, stroke - width: 1.5px, color:#78350f
classDef toneMint fill: #dcfce7, stroke:#16a34a, stroke - width: 1.5px, color:#14532d
classDef toneRose fill: #ffe4e6, stroke: #e11d48, stroke - width: 1.5px, color:#881337
classDef toneIndigo fill: #e0e7ff, stroke:#4f46e5, stroke - width: 1.5px, color:#312e81
classDef toneTeal fill: #ccfbf1, stroke:#0f766e, stroke - width: 1.5px, color:#134e4a
class node_routes, node_api_controller, node_authorization, node_admin toneBlue
class node_identity_iam, node_commerce, node_access_service, node_media_pipeline, node_chat_ai, node_notification_center toneAmber
class node_postgres, node_solid_queue, node_payment_job, node_chat_job, node_delivery_job, node_action_cable toneMint
class node_payment_provider, node_ai_providers, node_delivery_providers, node_storage_providers, node_container_runtime toneRose