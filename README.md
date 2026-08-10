<a name="readme-top"></a>

<div align="center">
  <h3><b>Rexone CORE</b></h3>

  <p>
    A production-ready Ruby on Rails Core foundation for building modern applications.
  </p>

  <p>
    Authentication · Authorization · Payments · Media · AI · Real-time · Background Jobs · Admin · Monitoring
  </p>
</div>

<!-- TABLE OF CONTENTS -->

# 📗 Table of Contents

- [📗 Table of Contents](#-table-of-contents)
- [📖 Rexone Core ](#-rexone-core-)
  - [🚀 Featuring!](#-featuring)
    - [🌟 Modern Tech Stack](#-modern-tech-stack)
    - [🏗️ Design Patterns \& Architecture](#️-design-patterns--architecture)
    - [🔐 Authentication \& Security](#-authentication--security)
    - [🛡️ IAM \& RBAC](#️-iam--rbac)
    - [🔌 Integrated Services](#-integrated-services)
      - [📧 Email Service](#-email-service)
      - [🔔 Push Notification Service](#-push-notification-service)
      - [📁 Storage Service](#-storage-service)
      - [💳 Payment Service](#-payment-service)
      - [🤖 AI Service](#-ai-service)
      - [🔌 Socket Service](#-socket-service)
    - [🗃️ Testing \& Quality Assurance](#️-testing--quality-assurance)
  - [🛠 Built With ](#-built-with-)
    - [Tech Stack ](#tech-stack-)
  - [💻 Getting Started ](#-getting-started-)
    - [Prerequisites](#prerequisites)
    - [Setup](#setup)
    - [Run](#run)
    - [Scripts](#scripts)
    - [Doc](#doc)
    - [Test](#test)
    - [Performance Dashboard](#performance-dashboard)
      - [Access](#access)
    - [Solid Web UI](#solid-web-ui)
    - [Queue Dashboard](#queue-dashboard)
    - [Cache Dashboard](#cache-dashboard)
    - [Cable Dashboard](#cable-dashboard)
    - [Admin Dashboard](#admin-dashboard)
      - [Authentication \& RBAC](#authentication--rbac)
      - [Super Admin Setup](#super-admin-setup)
      - [Routes](#routes)
      - [Permissions](#permissions)
    - [Pagination](#pagination)
    - [Explore More Open Source Projects](#explore-more-open-source-projects)
- [☕ Support ](#-support-)
  - [👤 Author](#-author)

<!-- PROJECT DESCRIPTION -->

# 📖 Rexone Core <a name="about-project"></a>

**Rexone Core** is a production-ready Ruby on Rails API foundation designed to provide a complete backend starting point for modern authenticated applications.

The project brings together:

**Authentication**, **Authorization**, **IAM/RBAC**,
**API documentation**, **Pagination**, **Payments**,
**Media Storage**, **AI services**, **Real-time communications**,
**Background processing**, **Caching**, **Performance Monitoring**, **Administration**, **Testing**, and **Security**

tooling into a single well-rounded backend foundation.

The goal is to provide a clean and scalable foundation so product development can focus on business logic instead of repeatedly rebuilding the same backend infrastructure.

**Related Repositories:**

- **Web Frontend**: [Rexone Web](https://github.com/rex-9/rexone-web)
- **Mobile App**: [Rexone Mobile](https://github.com/rex-9/rexone_mobile)

## 🚀 Featuring!

### 🌟 Modern Tech Stack

- **Ruby on Rails 8.1**: API-only backend framework built for modern server-side applications.
- **PostgreSQL**: Robust relational database for application data.
- **Puma**: Production-ready Ruby application server.
- **Solid Cache**: Database-backed Rails cache storage.
- **Solid Queue**: Database-backed background job processing.
- **Solid Cable**: Database-backed Action Cable adapter.
- **Pagy**: Lightweight and efficient API pagination.
- **JSON:API Serializer**: Consistent JSON:API resource serialization.
- **Rswag**: OpenAPI/Swagger API documentation and request specifications.
- **Rails Pulse**: Application performance monitoring and diagnostics.
- **Administrate**: Administrative dashboard for managing application resources.
- **Solid Web UI**: Web dashboards for Solid Queue, Solid Cache, and Solid Cable.

### 🏗️ Design Patterns & Architecture

- **MVC Architecture**: Clear separation between models, controllers, and application logic.
- **API-Only Rails**: Lightweight backend optimized for web and mobile clients.
- **Service-Oriented Architecture**: Business operations can be isolated into dedicated services.
- **Concerns**: Shared controller and application behavior is organized into reusable concerns.
- **Serializer Layer**: API responses are consistently transformed through dedicated serializers.
- **Centralized API Response Format**: Successful and failed API responses follow a consistent envelope.
- **Centralized Pagination**: Pagination is handled through a shared Pagy-based backend implementation.
- **Dockerized Development**: Application services can be developed and run through Docker.
- **Modular Integrations**: External services are isolated behind application-level service abstractions.

### 🔐 Authentication & Security

- **Devise**: Secure authentication and account management.
- **Devise JWT**: Token-based authentication for API clients.
- **Email-Password Authentication**: Standard secure account authentication.
- **Google Authentication**: Google sign-in integration.
- **Forgot Password & Reset Password**: Account recovery workflows.
- **Email Confirmation**: Email verification for user accounts.
- **JWT Authentication**: Stateless API authentication using JSON Web Tokens.
- **Session Management**: Platform-aware authentication and session handling.
- **Rack Attack**: Request throttling and protection against abusive traffic.
- **Rack CORS**: Cross-Origin Resource Sharing support.
- **CSP & Rails Security**: Rails security mechanisms and browser security policies.

### 🛡️ IAM & RBAC

The backend includes a dedicated Identity and Access Management system for granular authorization.

- **Users**: Application user accounts.
- **Roles**: Groups of permissions assigned to users.
- **Permissions**: Resource/action-based authorization rules.
- **User Roles**: User-to-role assignments.
- **Role Permissions**: Role-to-permission assignments.
- **Resource-based Authorization**: Permissions can be organized around application resources.
- **Action-based Authorization**: Permissions can define actions such as `create`, `read`, `update`, and `delete`.
- **Super Admin**: Full administrative access across the system.

### 🔌 Integrated Services

The system integrates with multiple external and Rails-native services to provide a complete backend foundation.

#### 📧 Email Service

- **Function**: Transactional and account-related email workflows.
- **Implementation**: Application-level service abstraction for email operations.

#### 🔔 Push Notification Service

- **Function**: Push notification delivery for supported clients.
- **Implementation**: Application-level notification service abstraction.

#### 📁 Storage Service

- **Providers**: Cloudinary and local Active Storage processing.
- **Function**: File uploads, image processing, and media management.
- **Implementation**: Active Storage with image processing support.

#### 💳 Payment Service

- **Provider**: Stripe
- **Function**: Payment processing, products, subscriptions, and transactions.
- **Implementation**: Dedicated payment service and API endpoints.

#### 🤖 AI Service

- **Function**: AI-powered application features including chat, history, rooms, summarization, translation, and analysis.
- **Implementation**: Dedicated AI service layer with API endpoints for client applications.

#### 🔌 Socket Service

- **Provider**: Action Cable
- **Function**: Real-time WebSocket communication and live application updates.
- **Implementation**: Rails Action Cable backed by Solid Cable.

### 🗃️ Testing & Quality Assurance

- **RSpec Rails**: Comprehensive automated testing framework.
- **FactoryBot Rails**: Test data generation and factory management.
- **Shoulda Matchers**: Concise testing matchers for Rails models and controllers.
- **Faker**: Realistic test data generation.
- **Database Cleaner**: Reliable database isolation between tests.
- **Brakeman**: Static security analysis for Rails applications.
- **Bundler Audit**: Dependency vulnerability auditing.
- **RuboCop Rails Omakase**: Ruby and Rails code style enforcement.
- **Guard RSpec**: Automated test execution during development.

## 🛠 Built With <a name="built-with"></a>

### Tech Stack <a name="tech-stack"></a>

<details>
  <summary>Server</summary>
  <ul>
    <li><a href="https://rubyonrails.org/">Ruby on Rails 8.1</a></li>
    <li><a href="https://www.ruby-lang.org/">Ruby</a></li>
    <li><a href="https://puma.io/">Puma</a></li>
    <li><a href="https://github.com/rails/solid_cache">Solid Cache</a></li>
    <li><a href="https://github.com/rails/solid_queue">Solid Queue</a></li>
    <li><a href="https://github.com/rails/solid_cable">Solid Cable</a></li>
    <li><a href="https://github.com/heartcombo/devise">Devise</a></li>
    <li><a href="https://github.com/waiting-for-dev/devise-jwt">Devise JWT</a></li>
    <li><a href="https://github.com/jnunemaker/httparty">REST Client</a></li>
    <li><a href="https://stripe.com/">Stripe</a> (Payments)</li>
    <li><a href="https://cloudinary.com/">Cloudinary</a> (Media)</li>
    <li><a href="https://github.com/rack/rack-attack">Rack Attack</a> (Security)</li>
    <li><a href="https://deepseek.com/">DeepSeek</a> (AI Services)</li>
    <li><a href="https://github.com/cyu/rack-cors">Rack CORS</a></li>
    <li><a href="https://github.com/jnunemaker/httparty">REST Client</a></li>
    <li><a href="https://www.docker.com/">Docker</a></li>

  </ul>
</details>

<details>
  <summary>API & Serialization</summary>
  <ul>
    <li><a href="https://github.com/jsonapi-serializer/jsonapi-serializer">JSON:API Serializer</a></li>
    <li><a href="https://github.com/paper-trail-gem/paper_trail">Pagy</a> (Pagination)</li>
    <li><a href="https://github.com/rswag/rswag">Rswag</a></li>
    <li><a href="https://www.openapis.org/">OpenAPI</a></li>
    <li><a href="https://github.com/rswag/rswag-ui">Swagger UI</a></li>
  </ul>
</details>

<details>
  <summary>Administration & Monitoring</summary>
  <ul>
    <li><a href="https://github.com/thoughtbot/administrate">Administrate</a> (Admin Dashboard)</li>
    <li><a href="https://github.com/doromones/solid-web">Solid Web UI</a> (Queue, Cache, Cable)</li>
    <li><a href="https://railspulse.com/">Rails Pulse</a> (Performance Monitoring)</li>
  </ul>
</details>

<details>
  <summary>Testing & Development</summary>
  <ul>
    <li><a href="https://rspec.info/">RSpec</a></li>
    <li><a href="https://github.com/thoughtbot/factory_bot_rails">FactoryBot Rails</a></li>
    <li><a href="https://github.com/thoughtbot/shoulda-matchers">Shoulda Matchers</a></li>
    <li><a href="https://github.com/faker-ruby/faker">Faker</a></li>
    <li><a href="https://github.com/DatabaseCleaner/database_cleaner">Database Cleaner</a></li>
    <li><a href="https://github.com/guard/guard-rspec">Guard RSpec</a></li>
    <li><a href="https://brakemanscanner.org/">Brakeman</a></li>
    <li><a href="https://github.com/rubysec/bundler-audit">Bundler Audit</a></li>
    <li><a href="https://github.com/rails/rubocop-rails-omakase">RuboCop Rails Omakase</a></li>
    <li><a href="https://solargraph.org/">Solargraph</a></li>
  </ul>
</details>

<details>
  <summary>Database</summary>
  <ul>
    <li><a href="https://www.postgresql.org/">PostgreSQL</a></li>
  </ul>
</details>

<!-- GETTING STARTED -->

## 💻 Getting Started <a name="getting-started"></a>

To get a local copy up and running, follow these steps.

### Prerequisites

In order to run this project you need <a href="https://www.ruby-lang.org/en/downloads/">Ruby</a> and <a href="https://www.postgresql.org/">PostgreSQL</a> set up on your computer, or you can use <a href="https://www.docker.com/">Docker</a>.

Check your Ruby and PostgreSQL installations if you are not using Docker.

```sh
  ruby --version && postgres --version
```

### Setup

Clone this repository or download it as a zip file to your desired folder:

```sh
  cd my-folder
  git clone https://github.com/rex-9/rexone-core.git
```

Enter the root level of the project:

```sh
  cd rexone-core
```

### Run

Run the application.

```sh
  shell-1> sh scripts/dev_api.sh
  shell-2> sh scripts/dev_waka.sh
  shell-3> sh scripts/dev_db.sh
```

### Scripts

Explore them under the `/scripts` folder.

### Doc

Generate Swagger/OpenAPI documentation:

```sh
> sh scripts/rswag.sh
```

### Test

Set up RSpec once:

```sh
> rails generate rspec:install
```

Execute tests:

```sh
> sh scripts/test.sh
```

Watch tests:

```sh
> sh scripts/test_watch.sh
```

View the API documentation at:

`/api-docs/`

### Performance Dashboard

The application includes a built-in performance monitoring dashboard powered by Rails Pulse.

#### Access

View the performance dashboard at:

`/admin/pulse`

### Solid Web UI

The application includes dedicated dashboards for the Rails Solid Stack.

### Queue Dashboard

Monitor and manage background jobs through Solid Queue:

`/admin/queue`

### Cache Dashboard

Inspect and manage application cache through Solid Cache:

`/admin/cache`

### Cable Dashboard

Inspect Action Cable messages and manage retained messages through Solid Cable:

`/admin/cable`

### Admin Dashboard

**Administrate** is available at `/admin` for managing application resources with IAM and RBAC authorization.

The current administration area includes:

- Users
- Assets
- Accesses
- IAM Permissions
- IAM Roles
- IAM User Roles
- IAM Role Permissions
- Payment Products
- Payment Subscriptions
- Payment Transactions
- Chat Rooms
- Chat Messages

#### Authentication & RBAC

Administrative resources are protected through the application's authentication and authorization system.

Access is controlled through IAM roles and permissions rather than relying solely on the existence of an admin route.

Typical roles include:

- `admin`
- `super_admin`

The `super_admin` role is intended for unrestricted administrative access.

#### Super Admin Setup

The super admin account is created through the application's seed process.

Run:

**```sh**

> rails db:seed
> **```**

For production environments, use secure credentials and never commit passwords or secrets to the repository.

#### Routes

| Path                           | Description                 |
| ------------------------------ | --------------------------- |
| `/admin`                       | Administrate dashboard      |
| `/admin/users`                 | User management             |
| `/admin/assets`                | Asset management            |
| `/admin/accesses`              | Access management           |
| `/admin/iam/permissions`       | IAM permission management   |
| `/admin/iam/roles`             | IAM role management         |
| `/admin/iam/user_roles`        | User-role assignments       |
| `/admin/iam/role_permissions`  | Role-permission assignments |
| `/admin/payment/products`      | Payment product management  |
| `/admin/payment/subscriptions` | Subscription management     |
| `/admin/payment/transactions`  | Transaction management      |
| `/admin/chat/rooms`            | Chat room management        |
| `/admin/chat/messages`         | Chat message management     |

#### Permissions

The IAM system supports granular resource/action authorization.

| Resource         | Actions                      | Description                 |
| ---------------- | ---------------------------- | --------------------------- |
| Users            | create, read, update, delete | Manage user accounts        |
| Assets           | create, read, update, delete | Manage uploaded assets      |
| Roles            | create, read, update, delete | Manage application roles    |
| Permissions      | create, read, update, delete | Manage IAM permissions      |
| User Roles       | create, read, delete         | Assign roles to users       |
| Role Permissions | create, read, delete         | Assign permissions to roles |
| Payment Products | create, read, update, delete | Manage payment products     |
| Subscriptions    | create, read, update, delete | Manage subscriptions        |
| Transactions     | create, read                 | Manage payment transactions |
| Chat Rooms       | create, read, update, delete | Manage chat rooms           |
| Chat Messages    | create, read, update, delete | Manage chat messages        |

### Pagination

The API uses **Pagy** for centralized pagination.

Pagination parameters are provided through the API request:

**```http
GET /users?page=1&limit=20
**```\*\*

Paginated responses follow a consistent structure:

**```json
{
"status": {
"code": 200,
"success": true,
"message": "Users retrieved successfully"
},
"data": [
{
"id": "uuid-1",
"type": "user",
"attributes": {
"email": "user@example.com",
"username": "testuser",
"name": "Test User",
"created_at": "2026-08-09T12:00:00.000Z"
}
}
],
"meta": {
"pagination": {
"current_page": 1,
"total_pages": 10,
"total_count": 95,
"per_page": 20,
"next_page": 2,
"prev_page": null
}
}
}
**```\*\*

Pagination is centralized in the backend so API clients can consume the same response structure across paginated resources.

### Explore More Open Source Projects

If you are interested in exploring more open source projects, check out Instacart's GitHub page:

[Instacart Open Source Projects](https://github.com/instacart)

# ☕ Support <a name="support"></a>

If you like this project, please consider giving it a star on GitHub and supporting its development: 🌟

[![GitHub Stars](https://img.shields.io/github/stars/rex-9/rexone-core.svg?style=social&label=Star)](https://github.com/rex-9/rexone-core)

<!-- <div align="center">
  <a href="https://buymeacoffee.com/rex9" target="_blank">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" >
  </a>
</div> -->

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## 👤 Author

**Rex (Rex9)**

- GitHub: [@rex-9](https://github.com/rex-9)
- Portfolio: [rex9.vercel.app](https://rex9.vercel.app)
- Linkedin: [rex9](https://www.linkedin.com/in/rex9/)

_Built with ❤️ by Rex9_
