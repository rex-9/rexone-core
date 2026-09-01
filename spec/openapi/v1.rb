# frozen_string_literal: true

module Openapi
  module V1
    module_function

    JSON_CONTENT = "application/json"
    UUID = { type: :string, format: :uuid }.freeze
    DATE_TIME = { type: :string, format: "date-time", nullable: true }.freeze
    SECURITY = [ { bearerAuth: [] } ].freeze
    STATUSES = Chat::Message::STATUSES.values.freeze
    AI_ROLES = [ AiConstants::ChatRole::USER, AiConstants::ChatRole::ASSISTANT ].freeze
    LOG_SEVERITIES = Log::Client.severities.keys.freeze
    LOG_PLATFORMS = Log::Client.platforms.keys.freeze
    LOG_ENVIRONMENTS = Log::Client.environments.keys.freeze

    def ref(name)
      { "$ref": "#/components/schemas/#{name}" }
    end

    def json(schema)
      { content: { JSON_CONTENT => { schema: schema } } }
    end

    def response(description, schema = ref(:response))
      { description: description }.merge(json(schema))
    end

    def request(schema, required: true)
      {
        required: required,
        content: { JSON_CONTENT => { schema: schema } }
      }
    end

    def operation(tags:, summary:, description: nil, success: 200, body: nil, parameters: [],
                  security: SECURITY, errors: [ 401, 422 ], success_schema: nil)
      operation = {
        tags: Array(tags),
        summary: summary,
        parameters: parameters,
        responses: {
          success.to_s => response(
            success == 201 ? "Created" : "Successful response",
            success_schema || ref(:response)
          )
        }
      }
      operation[:description] = description if description
      operation[:security] = security unless security.nil?
      operation[:requestBody] = request(body) if body
      errors.each do |status|
        operation[:responses][status.to_s] = response(
          Rack::Utils::HTTP_STATUS_CODES.fetch(status),
          ref(:error_response)
        )
      end
      operation
    end

    def object(required: [], **properties)
      { type: :object, properties: properties, required: required }
    end

    def path_parameter(name, description = nil)
      {
        name: name,
        in: :path,
        required: true,
        description: description,
        schema: UUID
      }.compact
    end

    def query_parameter(name, type: :string, required: false, description: nil, **schema)
      {
        name: name,
        in: :query,
        required: required,
        description: description,
        schema: { type: type }.merge(schema)
      }.compact
    end

    def standard_crud(path:, tag:, schema:, writable: nil)
      writable ||= schema
      {
        path => {
          get: operation(tags: tag, summary: "List #{tag.downcase}"),
          post: operation(
            tags: tag,
            summary: "Create #{tag.downcase.singularize}",
            success: 201,
            body: ref(writable),
            errors: [ 401, 403, 422 ]
          )
        },
        "#{path}/{id}" => {
          get: operation(
            tags: tag,
            summary: "Get #{tag.downcase.singularize}",
            parameters: [ path_parameter(:id) ],
            errors: [ 401, 403, 404 ]
          ),
          patch: operation(
            tags: tag,
            summary: "Update #{tag.downcase.singularize}",
            body: ref(writable),
            parameters: [ path_parameter(:id) ],
            errors: [ 401, 403, 404, 422 ]
          ),
          delete: operation(
            tags: tag,
            summary: "Delete #{tag.downcase.singularize}",
            parameters: [ path_parameter(:id) ],
            errors: [ 401, 403, 404 ]
          )
        }
      }
    end

    SCHEMAS = {
      signup_request: object(
        required: [ :user ],
        user: object(
          required: %i[username name email password password_confirmation],
          username: { type: :string, pattern: "^[a-z0-9_]+$", example: "elden_lord" },
          name: { type: :string, maxLength: 50, example: "Elden Lord" },
          email: { type: :string, format: :email, example: "lord@example.com" },
          password: { type: :string, format: :password, minLength: 6, writeOnly: true },
          password_confirmation: { type: :string, format: :password, minLength: 6, writeOnly: true }
        )
      ),
      signin_request: object(
        required: [ :user ],
        user: object(
          required: %i[signin_key password],
          signin_key: { type: :string, description: "Email address or username", example: "elden_lord" },
          password: { type: :string, format: :password, writeOnly: true }
        )
      ),
      token_signin_request: object(
        required: [ :token ],
        token: { type: :string, writeOnly: true, description: "One-time account sign-in token." }
      ),
      google_signin_request: object(
        required: [ :token ],
        token: { type: :string, writeOnly: true, description: "Google identity token." }
      ),
      google_registration_request: object(
        required: %i[challenge_token password],
        challenge_token: { type: :string, writeOnly: true },
        password: { type: :string, format: :password, minLength: 6, writeOnly: true }
      ),
      confirmation_code_request: object(
        required: [ :signin_key ],
        signin_key: { type: :string, description: "Email address or username." }
      ),
      confirmation_verify_request: object(
        required: %i[signin_key confirmation_code],
        signin_key: { type: :string, description: "Email address or username." },
        confirmation_code: { type: :string, pattern: "^[0-9]{6}$", example: "123456" }
      ),
      forgot_password_request: object(
        required: [ :email ],
        email: { type: :string, format: :email }
      ),
      reset_password_request: object(
        required: [ :user ],
        user: object(
          required: %i[reset_password_token password password_confirmation],
          reset_password_token: { type: :string, writeOnly: true },
          password: { type: :string, format: :password, minLength: 6, writeOnly: true },
          password_confirmation: { type: :string, format: :password, minLength: 6, writeOnly: true }
        )
      ),
      role_request: object(
        required: [ :name ],
        name: { type: :string, example: "teacher" },
        description: { type: :string, nullable: true },
        permission_ids: {
          type: :array,
          uniqueItems: true,
          items: UUID,
          description: "Permission UUIDs assigned to the role."
        }
      ),
      permission_request: object(
        action: { type: :string, enum: Iam::Permission::ACTIONS, example: "read" },
        resource: { type: :string, enum: Iam::Permission::RESOURCES, example: "users" }
      ),
      admin_user_request: object(
        required: [ :user ],
        user: object(
          username: { type: :string, pattern: "^[a-z0-9_]+$", example: "admin_created" },
          name: { type: :string, maxLength: 50, example: "Admin Created" },
          email: { type: :string, format: :email, example: "admin-created@example.com" },
          password: { type: :string, format: :password, minLength: 6, writeOnly: true },
          password_confirmation: { type: :string, format: :password, minLength: 6, writeOnly: true },
          role_ids: { type: :array, uniqueItems: true, items: UUID }
        )
      ),
      admin_chat_room_request: object(
        required: [ :room ],
        room: object(
          required: [ :title ],
          title: { type: :string, minLength: 1, example: "Support chat" }
        )
      ),
      admin_chat_message_request: object(
        required: [ :message ],
        message: object(
          role: { type: :string, enum: AI_ROLES },
          content: { type: :string, minLength: 1, example: "Updated message content" }
        )
      ),
      admin_product_request: object(
        required: [ :product ],
        product: object(
          required: %i[name price_unit_amount currency],
          name: { type: :string, minLength: 1, example: "Premium Access" },
          description: { type: :string, nullable: true, example: "Unlocks premium features." },
          price_unit_amount: {
            type: :integer,
            minimum: 0,
            description: "Amount in the smallest currency unit, for example cents. Use 0 for a free product."
          },
          currency: { type: :string, enum: Payment::Product.currencies.values, example: "usd" },
          cycle: {
            type: :string,
            nullable: true,
            enum: Payment::Product.cycles.values + [ nil ],
            description: "Use null for one-time products."
          },
          active: { type: :boolean, default: true }
        )
      ),
      user_role_request: object(
        required: [ :role_id ],
        role_id: UUID.merge(description: "Role UUID to assign to the path user.")
      ),
      feedback_request: object(
        required: [ :feedback ],
        feedback: object(
          required: [ :content ],
          content: { type: :string, minLength: 1, example: "Great platform!" },
          rating: { type: :integer, minimum: 1, maximum: 5, example: 5 },
          category: { type: :string, example: "general" },
          priority: { type: :string, example: "normal" },
          app_version: { type: :string, example: "1.0.0" },
          os: { type: :string, example: "mac" },
          device: { type: :string, example: "MacBookPro" },
          browser: { type: :string, example: "Chrome" },
          page: { type: :string, example: "/home" },
          metadata: { type: :object, additionalProperties: true }
        )
      ),
      admin_feedback_request: object(
        required: [ :feedback ],
        feedback: object(
          status: { type: :string, example: "reviewed" },
          category: { type: :string, example: "feature_request" },
          priority: { type: :string, example: "high" },
          admin_notes: { type: :string, example: "Followed up with user" }
        )
      ),
      client_log_context: {
        type: :object,
        description: "Free-form, JSON-safe diagnostic context supplied by the client. Do not include secrets or tokens.",
        additionalProperties: true,
        example: { component: "CheckoutPage", action: "loadSession", attempt: 2 }
      },
      client_log_request: object(
        required: [ :log ],
        log: object(
          required: [ :message ],
          message: { type: :string, example: "Checkout request failed" },
          severity: { type: :string, enum: LOG_SEVERITIES, default: "error" },
          platform: { type: :string, enum: LOG_PLATFORMS, nullable: true },
          environment: { type: :string, enum: LOG_ENVIRONMENTS, nullable: true },
          app_version: { type: :string, nullable: true },
          browser: { type: :string, nullable: true },
          user_agent: { type: :string, nullable: true },
          os: { type: :string, nullable: true },
          os_version: { type: :string, nullable: true },
          device: { type: :string, nullable: true },
          url: { type: :string, format: :uri, nullable: true },
          method: { type: :string, example: "POST", nullable: true },
          context: ref(:client_log_context),
          stack_trace: { type: :array, items: { type: :string } },
          local_storage_keys: { type: :array, items: { type: :string } },
          session_storage_keys: { type: :array, items: { type: :string } },
          cookies: {
            type: :object,
            description: "Cookie names and diagnostic values. Do not submit authentication cookies or secrets.",
            additionalProperties: { type: :string }
          }
        )
      ),
      notification_request: object(
        required: %i[event audience channels],
        event: {
          type: :string,
          enum: NotificationService::Templates.events,
          description: "Admin-enabled event whose server-side template supplies the title and message."
        },
        audience: {
          description: "Use exactly one audience shape. Role matches use OR semantics and each user is notified once.",
          oneOf: [
            object(
              required: %i[type user_ids],
              type: { type: :string, enum: [ "users" ] },
              user_ids: { type: :array, minItems: 1, uniqueItems: true, items: UUID }
            ),
            object(
              required: %i[type role_ids],
              type: { type: :string, enum: [ "roles" ] },
              role_ids: { type: :array, minItems: 1, uniqueItems: true, items: UUID }
            ),
            object(required: [ :type ], type: { type: :string, enum: [ "all" ] })
          ]
        },
        channels: {
          type: :array,
          minItems: 1,
          uniqueItems: true,
          items: { type: :string, enum: NotificationService::Center::CHANNELS },
          description: "One or more delivery channels: socket, push, or email."
        }
      ),
      asset_upload_request: object(
        required: [ :file ],
        file: { type: :string, format: :binary },
        type: {
          type: :string,
          default: "general",
          description: "Asset type: avatar, cover, card, audio, video, attachment, general."
        },
        resource_model: {
          type: :string,
          description: "Resource model name: user, course, lesson, monastery, teacher, message."
        },
        resource_id: UUID.merge(description: "UUID of the linked resource."),
        duration_secs: { type: :integer, description: "Duration in seconds for audio / video files." },
        size_bytes: { type: :integer, description: "Exact file size in bytes." }
      ),
      checkout_session_request: object(
        required: %i[product_id success_url cancel_url],
        product_id: UUID,
        success_url: { type: :string, format: :uri, description: "Client URL used by Stripe after success." },
        cancel_url: { type: :string, format: :uri, description: "Client URL used by Stripe after cancellation." }
      ),
      ai_chat_request: object(
        required: [ :message ],
        message: { type: :string, minLength: 1 },
        room_id: UUID.merge(description: "Existing owned room UUID. Omit to use or create the current room."),
        system_prompt: { type: :string, nullable: true, description: "Optional instruction prepended to this request." },
        temperature: { type: :number, format: :float, default: 0.7, minimum: 0 },
        max_tokens: { type: :integer, default: 2000, minimum: 1 }
      ),
      ai_rename_request: object(
        required: [ :title ],
        title: { type: :string, minLength: 1 },
        room_id: UUID.merge(description: "Owned room UUID. Omit to use the current room.")
      ),
      ai_room_request: object(
        title: { type: :string, minLength: 1, description: "Omit to use the translated default room title." }
      ),
      ai_text_request: object(
        required: [ :text ],
        text: { type: :string, minLength: 1 }
      ),
      ai_translate_request: object(
        required: %i[text language],
        text: { type: :string, minLength: 1 },
        language: {
          type: :string,
          minLength: 1,
          description: "Natural-language target such as English, Myanmar, Japanese, or Spanish; not a fixed enum."
        }
      ),
      ai_analyze_request: object(
        required: [ :text ],
        text: { type: :string, minLength: 1 },
        type: { type: :string, enum: %w[sentiment entities keywords], default: "sentiment" }
      ),
      speech_tts_request: object(
        text: {
          type: :string,
          minLength: 1,
          description: "Required for sync MP3 responses. Ignored when message_id is present."
        },
        message_id: {
          type: :string,
          format: :uuid,
          description: "Queue async TTS for a chat message owned by the current user. Text comes from the message content."
        },
        voice_name: {
          type: :string,
          description: "Provider voice name for sync TTS only. Omit to use the provider default. camelCase voiceName is not accepted."
        }
      ),
      speech_tts_queued_data: object(
        required: %i[message_id room_id status job_id],
        message_id: UUID,
        room_id: UUID,
        status: { type: :string, enum: Chat::Message::STATUSES.values },
        job_id: { type: :string }
      ),
      speech_tts_queued_response: object(
        required: [ :status ],
        status: object(
          required: %i[code success message],
          code: { type: :integer, example: 200 },
          success: { type: :boolean, example: true },
          message: { type: :string }
        ),
        data: ref(:speech_tts_queued_data)
      ),
      speech_tts_ready_notification_data: object(
        required: %i[type room_id message_id assets],
        type: { type: :string, enum: [ NotificationConstants::NotificationType::TTS_READY ] },
        room_id: UUID,
        message_id: UUID,
        assets: {
          type: :array,
          description: "Full Asset objects for this message. Play TTS via the audio item's url.",
          items: ref(:asset)
        }
      ),
      speech_tts_failed_notification_data: object(
        required: %i[type room_id message_id],
        type: { type: :string, enum: [ NotificationConstants::NotificationType::TTS_FAILED ] },
        room_id: UUID,
        message_id: UUID,
        assets: {
          type: :array,
          description: "Empty when TTS fails before an asset is saved.",
          items: ref(:asset)
        }
      ),
      speech_stt_file_request: object(
        required: [ :audio ],
        audio: { type: :string, format: :binary, description: "Audio file. Takes precedence over audio_url when both are sent." }
      ),
      speech_stt_url_request: object(
        required: [ :audio_url ],
        audio_url: {
          type: :string,
          format: :uri,
          minLength: 1,
          description: "Used when no audio file is uploaded. camelCase audioUrl is not accepted."
        }
      ),
      speech_stt_data: object(
        required: [ :text ],
        text: { type: :string }
      ),
      speech_stt_response: object(
        required: [ :status ],
        status: object(
          required: %i[code success message],
          code: { type: :integer, example: 200 },
          success: { type: :boolean, example: true },
          message: { type: :string }
        ),
        data: ref(:speech_stt_data)
      ),
      ai_message_metadata: object(
        status: { type: :string, enum: STATUSES, description: "Processing state; set on queued user messages." },
        system_prompt: { type: :string, nullable: true },
        temperature: { type: :number, format: :float, nullable: true },
        max_tokens: { type: :integer, nullable: true },
        assistant_message_id: UUID.merge(nullable: true),
        error: { type: :string, nullable: true },
        usage: {
          type: :object,
          nullable: true,
          description: "Provider token-usage object returned for an assistant response.",
          additionalProperties: true,
          example: { prompt_tokens: 42, completion_tokens: 18, total_tokens: 60 }
        },
        model: { type: :string, nullable: true, description: "Provider model identifier used for the response." },
        tts_status: { type: :string, enum: STATUSES, nullable: true, description: "Async TTS state for assistant messages." },
        tts_error: { type: :string, nullable: true, description: "Last TTS failure message when tts_status is failed or retrying." }
      ),
      response: object(
        required: [ :status ],
        status: object(
          required: %i[code success message],
          code: { type: :integer, example: 200 },
          success: { type: :boolean, example: true },
          message: { type: :string }
        ),
        data: { nullable: true },
        meta: object(pagination: ref(:pagination))
      ),
      error_response: object(
        required: [ :status ],
        status: object(
          required: %i[code success message],
          code: { type: :integer, example: 422 },
          success: { type: :boolean, example: false },
          message: { type: :string },
          error: { type: :string }
        ),
        data: { nullable: true }
      ),
      pagination: object(
        current_page: { type: :integer },
        total_pages: { type: :integer },
        total_count: { type: :integer },
        limit: { type: :integer },
        next_page: { type: :integer, nullable: true },
        prev_page: { type: :integer, nullable: true }
      ),
      user: object(
        required: %i[id email username provider created_at updated_at],
        id: UUID,
        email: { type: :string, format: :email },
        username: { type: :string },
        name: { type: :string, nullable: true },
        provider: { type: :string, enum: %w[email google] },
        profile_pic_url: { type: :string, format: :uri, nullable: true },
        role_ids: { type: :array, items: UUID },
        role_names: { type: :array, items: { type: :string } },
        permissions: { type: :object, additionalProperties: { type: :array, items: { type: :string } } },
        created_at: DATE_TIME,
        updated_at: DATE_TIME
      ),
      role: object(
        id: UUID,
        name: { type: :string },
        description: { type: :string, nullable: true },
        system: { type: :boolean },
        permissions: { type: :object, additionalProperties: { type: :array, items: { type: :string } } },
        permission_ids: { type: :array, items: UUID },
        user_count: { type: :integer },
        created_at: DATE_TIME,
        updated_at: DATE_TIME
      ),
      permission: object(
        id: UUID,
        name: { type: :string },
        action: { type: :string },
        resource: { type: :string },
        created_at: DATE_TIME,
        updated_at: DATE_TIME
      ),
      product: object(
        id: UUID,
        name: { type: :string },
        description: { type: :string, nullable: true },
        price_unit_amount: { type: :integer, description: "Minor currency units" },
        price: { type: :string },
        currency: { type: :string, example: "usd" },
        cycle: { type: :string },
        period_label: { type: :string },
        recurring: { type: :boolean },
        free: { type: :boolean },
        active: { type: :boolean },
        stripe_product_id: { type: :string },
        stripe_price_id: { type: :string },
        created_at: DATE_TIME,
        updated_at: DATE_TIME
      ),
      subscription: object(
        id: UUID,
        user_id: UUID,
        product_id: UUID,
        stripe_subscription_id: { type: :string },
        stripe_customer_id: { type: :string },
        status: { type: :string },
        cycle: { type: :string },
        current_period_start: DATE_TIME,
        current_period_end: DATE_TIME,
        cancel_at_period_end: { type: :boolean },
        canceled_at: DATE_TIME,
        cancel_at: DATE_TIME,
        ended_at: DATE_TIME,
        active: { type: :boolean },
        canceled: { type: :boolean },
        ended: { type: :boolean },
        scheduled_for_cancellation: { type: :boolean },
        cancelable: { type: :boolean },
        product_name: { type: :string },
        price: { type: :string },
        created_at: DATE_TIME,
        updated_at: DATE_TIME
      ),
      transaction: object(
        id: UUID,
        user_id: UUID,
        product_id: UUID.merge(nullable: true),
        stripe_payment_intent_id: { type: :string },
        status: { type: :string },
        price_unit_amount: { type: :string },
        currency: { type: :string },
        paid_at: DATE_TIME,
        refunded_at: DATE_TIME,
        paid: { type: :boolean },
        pending: { type: :boolean },
        failed: { type: :boolean },
        product_name: { type: :string, nullable: true },
        created_at: DATE_TIME,
        updated_at: DATE_TIME
      ),
      access: object(
        id: UUID,
        product_id: UUID,
        product_name: { type: :string, nullable: true },
        status: { type: :string },
        granted_at: DATE_TIME,
        expires_at: DATE_TIME,
        days_remaining: { type: :integer, nullable: true },
        active: { type: :boolean },
        created_at: DATE_TIME,
        updated_at: DATE_TIME
      ),
      asset: object(
        required: %i[id name url type source],
        id: UUID,
        name: { type: :string },
        url: { type: :string, format: :uri },
        type: { type: :string, enum: AssetConstants::AssetType::ALL },
        format: { type: :string, enum: AssetConstants::AssetFormat::ALL, nullable: true },
        extension: { type: :string, nullable: true },
        size_bytes: { type: :integer, nullable: true },
        duration_secs: { type: :integer, nullable: true },
        source: { type: :string, enum: [ AssetConstants::AssetSource::UPLOAD, AssetConstants::AssetSource::GOOGLE ] },
        resource_model: { type: :string, nullable: true, description: "Polymorphic owner model, e.g. chat_message or user." },
        resource_id: UUID.merge(nullable: true),
        created_by_id: UUID.merge(nullable: true),
        created_at: DATE_TIME,
        updated_at: DATE_TIME
      ),
      room: object(
        id: UUID,
        user_id: UUID,
        title: { type: :string },
        metadata: {
          type: :object,
          description: "Server-owned room metadata. No public request currently accepts room metadata.",
          additionalProperties: true
        },
        message_count: { type: :integer },
        last_message: { type: :string, nullable: true },
        created_at: DATE_TIME,
        updated_at: DATE_TIME
      ),
      message: object(
        id: UUID,
        room_id: UUID,
        role: { type: :string, enum: AI_ROLES },
        content: { type: :string },
        metadata: ref(:ai_message_metadata),
        assets: {
          type: :array,
          description: "Assets linked to this message. Empty until async TTS completes.",
          items: ref(:asset)
        },
        created_at: DATE_TIME,
        updated_at: DATE_TIME
      )
    }.freeze

    COMMON_HEADERS = [
      {
        name: "X-Locale", in: :header, required: false,
        description: "Response language. Accepts en or my; Accept-Language is also supported.",
        schema: { type: :string, enum: %w[en my] }
      },
      {
        name: "X-Platform", in: :header, required: false,
        description: "Active-session namespace.",
        schema: { type: :string, enum: %w[web mobile], default: "web" }
      }
    ].freeze

    PATHS = begin
      paths = {
        "/peek" => {
          get: operation(
            tags: "Authentication", summary: "Check whether an email account exists",
            security: nil, parameters: [ query_parameter(:email, required: true, format: :email) ],
            errors: [ 400 ]
          )
        },
        "/signup" => {
          post: operation(tags: "Authentication", summary: "Create an email account", success: 201,
                          security: nil, body: ref(:signup_request), errors: [ 400, 422 ]),
          delete: operation(tags: "Authentication", summary: "Delete the current account", errors: [ 401 ])
        },
        "/signin" => {
          post: operation(tags: "Authentication", summary: "Sign in with email or username",
                          security: nil, body: ref(:signin_request), errors: [ 401, 403, 429 ])
        },
        "/signout" => {
          delete: operation(tags: "Authentication", summary: "Sign out the active platform session", errors: [ 401 ])
        },
        "/signin/token" => {
          post: operation(tags: "Authentication", summary: "Exchange a one-time account token for a JWT",
                          security: nil, body: ref(:token_signin_request), errors: [ 401, 403 ])
        },
        "/signin/google" => {
          post: operation(tags: "Authentication", summary: "Start Google sign-in",
                          security: nil, body: ref(:google_signin_request), errors: [ 401, 403 ])
        },
        "/signin/google/complete" => {
          post: operation(
            tags: "Authentication", summary: "Complete Google registration with a passcode", security: nil,
            body: ref(:google_registration_request),
            errors: [ 401, 403, 422 ]
          )
        },
        "/confirmation" => {
          get: operation(
            tags: "Authentication", summary: "Confirm an email link and redirect to the web client", security: nil,
            parameters: [ query_parameter(:confirmation_token, required: true) ], errors: [], success: 302
          )
        },
        "/confirmation/send_code" => {
          post: operation(tags: "Authentication", summary: "Send a new email confirmation code", security: nil,
                          body: ref(:confirmation_code_request), errors: [ 404, 422 ])
        },
        "/confirmation/confirm_code" => {
          post: operation(
            tags: "Authentication", summary: "Confirm an account using its email code", security: nil,
            body: ref(:confirmation_verify_request), errors: [ 422 ]
          )
        },
        "/password/forgot" => {
          post: operation(tags: "Authentication", summary: "Request a password reset email", security: nil,
                          body: ref(:forgot_password_request), errors: [ 404 ])
        },
        "/password/reset" => {
          put: operation(
            tags: "Authentication", summary: "Reset a password using a reset token", security: nil,
            body: ref(:reset_password_request), errors: [ 422 ]
          )
        },
        "/webhooks/stripe" => {
          post: operation(
            tags: "Webhooks", summary: "Receive, persist, and queue a Stripe webhook", security: nil,
            body: { type: :object, additionalProperties: true },
            parameters: [ { name: "Stripe-Signature", in: :header, required: true, schema: { type: :string } } ],
            errors: [ 400, 500, 503 ]
          )
        },
        "/v1/users/current" => {
          get: operation(tags: "Users", summary: "Get the current user", errors: [ 401 ])
        },
        "/v1/users/current/iam" => {
          get: operation(tags: "Users", summary: "Get the current user's roles and permissions", errors: [ 401 ])
        }
      }

      paths["/v1/admin/users"] = {
        get: operation(tags: "Admin / Users", summary: "List users for the admin client",
                       parameters: [
                         query_parameter(:limit, type: :integer, minimum: 1),
                         query_parameter(:search, type: :string)
                       ], errors: [ 401, 403 ]),
        post: operation(tags: "Admin / Users", summary: "Create an admin-managed user", success: 201,
                        body: ref(:admin_user_request), errors: [ 401, 403, 422 ])
      }
      paths["/v1/admin/users/discarded"] = {
        get: operation(tags: "Admin / Users", summary: "List discarded users in the recycle bin",
                       parameters: [ query_parameter(:limit, type: :integer, minimum: 1) ], errors: [ 401, 403 ])
      }
      paths["/v1/admin/users/{id}"] = {
        get: operation(tags: "Admin / Users", summary: "Get an admin-managed user",
                       parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ]),
        patch: operation(tags: "Admin / Users", summary: "Update an admin-managed user",
                         parameters: [ path_parameter(:id) ], body: ref(:admin_user_request),
                         errors: [ 401, 403, 404, 422 ])
      }
      %w[discard undiscard].each do |action|
        paths["/v1/admin/users/{id}/#{action}"] = {
          post: operation(tags: "Admin / Users", summary: "#{action.capitalize} an admin-managed user",
                          parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404, 422 ])
        }
      end
      paths["/v1/admin/iam/roles"] = {
        get: operation(tags: "Admin / IAM Roles", summary: "List roles for the admin client", errors: [ 401, 403 ]),
        post: operation(tags: "Admin / IAM Roles", summary: "Create an admin-managed role", success: 201,
                        body: ref(:role_request), errors: [ 401, 403, 422 ])
      }
      paths["/v1/admin/iam/permissions"] = {
        get: operation(tags: "Admin / IAM Permissions", summary: "List permissions for the admin client",
                       parameters: [ query_parameter(:limit, type: :integer, minimum: 1) ], errors: [ 401, 403 ]),
        post: operation(tags: "Admin / IAM Permissions", summary: "Create an admin-managed permission", success: 201,
                        body: ref(:permission_request), errors: [ 401, 403, 422 ])
      }
      paths["/v1/admin/iam/roles/{id}"] = {
        get: operation(tags: "Admin / IAM Roles", summary: "Get an admin-managed role",
                       parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ]),
        patch: operation(tags: "Admin / IAM Roles", summary: "Update an admin-managed role",
                         parameters: [ path_parameter(:id) ], body: ref(:role_request),
                         errors: [ 401, 403, 404, 422 ]),
        delete: operation(tags: "Admin / IAM Roles", summary: "Delete an admin-managed role",
                          parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404, 422 ])
      }
      paths["/v1/admin/iam/permissions/{id}"] = {
        get: operation(tags: "Admin / IAM Permissions", summary: "Get an admin-managed permission",
                       parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ]),
        patch: operation(tags: "Admin / IAM Permissions", summary: "Update an admin-managed permission",
                         parameters: [ path_parameter(:id) ], body: ref(:permission_request),
                         errors: [ 401, 403, 404, 422 ]),
        delete: operation(tags: "Admin / IAM Permissions", summary: "Delete an admin-managed permission",
                          parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ])
      }
      paths["/v1/admin/chat/rooms"] = {
        get: operation(tags: "Admin / Chat Rooms", summary: "List chat rooms for the admin client",
                       parameters: [ query_parameter(:limit, type: :integer, minimum: 1) ], errors: [ 401, 403 ])
      }
      paths["/v1/admin/chat/rooms/{id}"] = {
        get: operation(tags: "Admin / Chat Rooms", summary: "Get an admin chat room",
                       parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ]),
        patch: operation(tags: "Admin / Chat Rooms", summary: "Update an admin chat room",
                         parameters: [ path_parameter(:id) ], body: ref(:admin_chat_room_request),
                         errors: [ 401, 403, 404, 422 ]),
        delete: operation(tags: "Admin / Chat Rooms", summary: "Delete an admin chat room",
                          parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ])
      }
      paths["/v1/admin/chat/messages"] = {
        get: operation(tags: "Admin / Chat Messages", summary: "List chat messages for the admin client",
                       parameters: [ query_parameter(:limit, type: :integer, minimum: 1) ], errors: [ 401, 403 ])
      }
      paths["/v1/admin/chat/messages/{id}"] = {
        get: operation(tags: "Admin / Chat Messages", summary: "Get an admin chat message",
                       parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ]),
        patch: operation(tags: "Admin / Chat Messages", summary: "Update an admin chat message",
                         parameters: [ path_parameter(:id) ], body: ref(:admin_chat_message_request),
                         errors: [ 401, 403, 404, 422 ]),
        delete: operation(tags: "Admin / Chat Messages", summary: "Delete an admin chat message",
                          parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ])
      }
      paths["/v1/admin/payment/products"] = {
        get: operation(tags: "Admin / Payment Products", summary: "List Stripe-backed products for the admin client",
                       parameters: [ query_parameter(:limit, type: :integer, minimum: 1) ], errors: [ 401, 403 ]),
        post: operation(tags: "Admin / Payment Products", summary: "Create a Stripe-backed product", success: 201,
                        body: ref(:admin_product_request), errors: [ 401, 403, 422 ])
      }
      paths["/v1/admin/payment/products/discarded"] = {
        get: operation(tags: "Admin / Payment Products", summary: "List discarded Stripe-backed products for the recycle bin",
                       parameters: [ query_parameter(:limit, type: :integer, minimum: 1) ], errors: [ 401, 403 ])
      }
      paths["/v1/admin/payment/products/{id}"] = {
        get: operation(tags: "Admin / Payment Products", summary: "Get a Stripe-backed product",
                       parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ]),
        patch: operation(tags: "Admin / Payment Products", summary: "Update a Stripe-backed product",
                         parameters: [ path_parameter(:id) ], body: ref(:admin_product_request),
                         errors: [ 401, 403, 404, 422 ]),
        delete: operation(tags: "Admin / Payment Products", summary: "Discard a Stripe-backed product",
                          parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404, 422 ])
      }
      paths["/v1/admin/payment/products/{id}/undiscard"] = {
        post: operation(tags: "Admin / Payment Products", summary: "Restore a discarded Stripe-backed product",
                        parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404, 422 ])
      }
      paths["/v1/iam/permissions/current"] = {
        get: operation(tags: "IAM Permissions", summary: "List current user's permissions",
                       parameters: [ query_parameter(:limit, type: :integer, minimum: 1) ], errors: [ 401, 403 ])
      }
      paths["/v1/iam/roles/current"] = {
        get: operation(tags: "IAM Roles", summary: "List current user's roles",
                       parameters: [ query_parameter(:limit, type: :integer, minimum: 1) ], errors: [ 401, 403 ])
      }

      paths["/v1/iam/users/{user_id}/roles"] = {
        get: operation(tags: "IAM User Roles", summary: "List a user's roles",
                       parameters: [ path_parameter(:user_id) ], errors: [ 401, 403, 404 ]),
        post: operation(
          tags: "IAM User Roles", summary: "Assign a role to a user",
          parameters: [ path_parameter(:user_id) ],
          body: ref(:user_role_request), errors: [ 401, 403, 404, 422 ]
        )
      }
      paths["/v1/iam/users/{user_id}/roles/{id}"] = {
        delete: operation(tags: "IAM User Roles", summary: "Remove a role from a user",
                          parameters: [ path_parameter(:user_id), path_parameter(:id, "Role ID") ],
                          errors: [ 401, 403, 404 ])
      }

      log_filters = %i[severity platform environment unresolved resolved storage_issues].map do |name|
        query_parameter(name, type: name.in?(%i[unresolved resolved storage_issues]) ? :boolean : :string)
      end
      paths["/v1/log/clients"] = {
        get: operation(tags: "Client Logs", summary: "List and filter client error reports",
                       parameters: log_filters + [ query_parameter(:limit, type: :integer, minimum: 1) ],
                       errors: [ 401, 403 ]),
        post: operation(tags: "Client Logs", summary: "Report or increment a client error", success: 201,
                        security: nil, body: ref(:client_log_request), errors: [ 422 ])
      }
      paths["/v1/log/clients/{id}"] = {
        get: operation(tags: "Client Logs", summary: "Get a client error report",
                       parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ]),
        delete: operation(tags: "Client Logs", summary: "Delete a client error report",
                          parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ])
      }
      %w[resolve unresolve].each do |action|
        paths["/v1/log/clients/{id}/#{action}"] = {
          patch: operation(tags: "Client Logs", summary: "Mark a client error as #{action}d",
                           parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ])
        }
      end

      paths["/v1/media/upload"] = {
        post: operation(tags: "Media", summary: "Upload and persist an asset", success: 201,
                        body: ref(:asset_upload_request), errors: [ 401, 422, 500 ])
      }
      paths["/v1/media/upload"][:post][:requestBody] = {
        required: true,
        content: {
          "multipart/form-data" => {
            schema: ref(:asset_upload_request)
          }
        }
      }
      paths["/v1/admin/notifications"] = {
        post: operation(
          tags: "Admin / Notifications",
          summary: "Queue an admin notification for selected users, selected roles, or all users",
          description: <<~DESCRIPTION.squish,
            Requires an authenticated user with the admin role and create_notifications permission. Only confirmed,
            active users are eligible. A users audience targets explicit users. A roles audience matches users holding
            any supplied role and de-duplicates users who hold multiple matching roles. The request queues fan-out and
            returns before channel delivery completes.
          DESCRIPTION
          success: 202,
          body: ref(:notification_request),
          errors: [ 401, 403, 422, 503 ]
        )
      }
      paths["/v1/admin/notifications/templates"] = {
        get: operation(
          tags: "Admin / Notifications",
          summary: "List notification events and their admin availability",
          description: "Returns both selectable broadcast events and unavailable transactional events for display.",
          errors: [ 401, 403 ]
        )
      }
      paths["/v1/admin/analytics/overview"] = {
        get: operation(tags: "Admin / Analytics", summary: "Get admin analytics overview KPIs, time-series data, and breakdowns",
                       parameters: [
                         query_parameter(:period, type: :string),
                         query_parameter(:start_date, type: :string),
                         query_parameter(:end_date, type: :string)
                       ], errors: [ 401, 403 ])
      }
      paths["/v1/feedbacks"] = {
        post: operation(tags: "Feedback", summary: "Submit feedback", success: 201,
                        security: nil, body: ref(:feedback_request), errors: [ 422 ]),
        get: operation(tags: "Feedback", summary: "List current user's submitted feedbacks",
                       parameters: [ query_parameter(:limit, type: :integer, minimum: 1) ], errors: [ 401 ])
      }
      paths["/v1/feedbacks/{id}"] = {
        get: operation(tags: "Feedback", summary: "Get a submitted feedback",
                       parameters: [ path_parameter(:id) ], errors: [ 401, 404 ])
      }
      paths["/v1/admin/feedbacks"] = {
        get: operation(tags: "Admin / Feedback", summary: "List feedbacks for the admin client",
                       parameters: [
                         query_parameter(:status, type: :string),
                         query_parameter(:category, type: :string),
                         query_parameter(:priority, type: :string),
                         query_parameter(:platform, type: :string),
                         query_parameter(:user_id, type: :string, format: :uuid),
                         query_parameter(:limit, type: :integer, minimum: 1)
                       ], errors: [ 401, 403 ])
      }
      paths["/v1/admin/feedbacks/{id}"] = {
        get: operation(tags: "Admin / Feedback", summary: "Get an admin-managed feedback",
                       parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ]),
        patch: operation(tags: "Admin / Feedback", summary: "Update an admin-managed feedback",
                         parameters: [ path_parameter(:id) ], body: ref(:admin_feedback_request),
                         errors: [ 401, 403, 404, 422 ]),
        delete: operation(tags: "Admin / Feedback", summary: "Discard a feedback",
                          parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ])
      }

      paths["/v1/payment/products"] = {
        get: operation(tags: "Payments", summary: "List active payment products", errors: [ 401 ])
      }
      paths["/v1/payment/products/{id}"] = {
        get: operation(tags: "Payments", summary: "Get a payment product",
                       parameters: [ path_parameter(:id) ], errors: [ 401, 404 ])
      }
      paths["/v1/payment/subscriptions"] = {
        get: operation(tags: "Payments", summary: "List the current user's subscriptions", errors: [ 401 ])
      }
      paths["/v1/payment/subscriptions/{id}"] = {
        get: operation(tags: "Payments", summary: "Get a subscription",
                       parameters: [ path_parameter(:id) ], errors: [ 401, 404 ]),
        delete: operation(tags: "Payments", summary: "Hide an ended subscription",
                          parameters: [ path_parameter(:id) ], errors: [ 401, 404, 422 ])
      }
      %w[cancel resume].each do |action|
        paths["/v1/payment/subscriptions/{id}/#{action}"] = {
          post: operation(tags: "Payments", summary: "#{action.capitalize} a subscription",
                          parameters: [ path_parameter(:id) ], errors: [ 401, 404, 422 ])
        }
      end
      paths["/v1/payment/transactions"] = {
        get: operation(tags: "Payments", summary: "List the current user's transactions", errors: [ 401 ])
      }
      paths["/v1/payment/transactions/recent"] = {
        get: operation(tags: "Payments", summary: "List recent successful transactions", errors: [ 401 ])
      }
      paths["/v1/payment/transactions/{id}"] = {
        get: operation(tags: "Payments", summary: "Get a transaction",
                       parameters: [ path_parameter(:id) ], errors: [ 401, 404 ])
      }
      paths["/v1/payment/session"] = {
        post: operation(
          tags: "Payments", summary: "Create a Stripe Checkout session",
          body: ref(:checkout_session_request),
          errors: [ 401, 404, 422 ]
        )
      }
      paths["/v1/payment/session/{session_id}"] = {
        get: operation(tags: "Payments", summary: "Get a Checkout session status",
                       parameters: [ { name: :session_id, in: :path, required: true,
                                       schema: { type: :string, example: "cs_test_123" } } ],
                       errors: [ 401, 404 ])
      }

      paths["/v1/access"] = {
        get: operation(tags: "Access", summary: "List the current user's product access", errors: [ 401 ])
      }
      paths["/v1/access/active"] = {
        get: operation(tags: "Access", summary: "List active product access", errors: [ 401 ])
      }
      paths["/v1/access/check"] = {
        get: operation(tags: "Access", summary: "Check access to a product",
                       parameters: [ query_parameter(:product_id, required: true, format: :uuid) ], errors: [ 401 ])
      }
      paths["/v1/access/{id}"] = {
        delete: operation(tags: "Access", summary: "Revoke owned product access",
                          parameters: [ path_parameter(:id) ], errors: [ 401, 403, 404 ])
      }

      room_parameter = query_parameter(:room_id, required: false, format: :uuid,
                                       description: "Uses or creates the current room when omitted")
      paths["/v1/ai/chat"] = {
        post: operation(tags: "AI", summary: "Persist and queue a message for an AI room",
                        body: ref(:ai_chat_request), errors: [ 401, 422, 500, 503 ])
      }
      paths["/v1/ai/history"] = {
        get: operation(tags: "AI", summary: "Get room message history", parameters: [ room_parameter ], errors: [ 401, 404 ])
      }
      paths["/v1/ai/clear"] = {
        delete: operation(tags: "AI", summary: "Clear a room's messages", parameters: [ room_parameter ], errors: [ 401, 404 ])
      }
      paths["/v1/ai/rename"] = {
        put: operation(tags: "AI", summary: "Rename a room",
                       body: ref(:ai_rename_request),
                       errors: [ 401, 404, 422 ])
      }
      paths["/v1/ai/rooms"] = {
        get: operation(tags: "AI", summary: "List AI rooms", errors: [ 401 ]),
        post: operation(tags: "AI", summary: "Create an AI room", success: 201,
                        body: ref(:ai_room_request), errors: [ 401, 422 ])
      }
      paths["/v1/ai/rooms/{id}"] = {
        delete: operation(tags: "AI", summary: "Delete an AI room",
                          parameters: [ path_parameter(:id) ], errors: [ 401, 404 ])
      }
      {
        summarize: ref(:ai_text_request),
        translate: ref(:ai_translate_request),
        analyze: ref(:ai_analyze_request)
      }.each do |action, body|
        paths["/v1/ai/#{action}"] = {
          post: operation(tags: "AI", summary: "#{action.to_s.capitalize} text", body: body,
                          errors: [ 401, 422, 500 ])
        }
      end

      paths["/v1/speech/tts"] = {
        post: operation(
          tags: "Speech",
          summary: "Synthesize speech from text (MP3) or queue TTS for a chat message",
          description: "Send text for a sync MP3 response, or message_id to queue Azure TTS for that chat message. When queued TTS completes, NotificationChannel delivers tts_ready with data.assets (full Asset list); tts_failed sends assets: []. Chat history exposes the same assets on each message.",
          body: ref(:speech_tts_request),
          errors: [ 401, 404, 422, 500, 503 ]
        )
      }
      paths["/v1/speech/tts"][:post][:responses]["200"] = {
        description: "MP3 audio (sync) or queued JSON (async message_id)",
        content: {
          "audio/mpeg" => {
            schema: { type: :string, format: :binary }
          },
          JSON_CONTENT => {
            schema: ref(:speech_tts_queued_response)
          }
        }
      }

      paths["/v1/speech/stt"] = {
        post: operation(
          tags: "Speech",
          summary: "Transcribe speech from an audio file or audio URL",
          success_schema: ref(:speech_stt_response),
          errors: [ 401, 422, 500 ]
        )
      }
      paths["/v1/speech/stt"][:post][:requestBody] = {
        required: true,
        content: {
          "multipart/form-data" => { schema: ref(:speech_stt_file_request) },
          JSON_CONTENT => { schema: ref(:speech_stt_url_request) }
        }
      }

      paths.each_value do |methods|
        methods.each_value do |definition|
          definition[:parameters] = COMMON_HEADERS + definition.fetch(:parameters, [])
        end
      end

      paths.freeze
    end
  end
end
