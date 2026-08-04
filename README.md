# meritbox-api

<a name="readme-top"></a>

<div align="center">
  <h3><b>Meritbox Api</b></h3>
</div>

<!-- TABLE OF CONTENTS -->

# 📗 Table of Contents

- [meritbox-api](#meritbox-api)
- [📗 Table of Contents](#-table-of-contents)
- [📖 Meritbox Api ](#-meritbox-api-)
  - [🚀 Featuring!](#-featuring)
    - [🌟 Modern Tech Stack](#-modern-tech-stack)
    - [🗃️ Testing \& Quality Assurance](#️-testing--quality-assurance)
    - [🏗️ Design Patterns \& Architecture](#️-design-patterns--architecture)
    - [🔐 Authentication \& Security](#-authentication--security)
    - [🔌 Integrated Services](#-integrated-services)
      - [📧 Email Service](#-email-service)
      - [🔔 Push Notification Service](#-push-notification-service)
      - [📁 Storage Service](#-storage-service)
      - [💳 Payment Service](#-payment-service)
      - [🤖 AI Service](#-ai-service)
      - [🔌 Socket Service](#-socket-service)
  - [🛠 Built With ](#-built-with-)
    - [Tech Stack ](#tech-stack-)
  - [💻 Getting Started ](#-getting-started-)
    - [Prerequisites](#prerequisites)
    - [Setup](#setup)
    - [Scripts](#scripts)
    - [Run](#run)
    - [Test](#test)
    - [Doc](#doc)
    - [Performance Dashboard](#performance-dashboard)
      - [Access](#access)
    - [Admin Dashboard](#admin-dashboard)
      - [Authentication \& RBAC](#authentication--rbac)
      - [Super Admin Setup](#super-admin-setup)
      - [Routes](#routes)
      - [Permissions](#permissions)
    - [Explore More Open Source Projects](#explore-more-open-source-projects)
- [☕ Support ](#-support-)
  - [👤 Author](#-author)

<!-- PROJECT DESCRIPTION -->

# 📖 Meritbox Api <a name="about-project"></a>

**Meritbox Api** is a robust backend framework for authenticated web applications, offering a solid foundation for diverse product development needs. This repository also serves as an excellent learning resource for anyone looking to master backend development. It emphasizes best practices on the server side, enabling developers to write simple yet clean code.

**Related Repositories:**

- **Web Frontend**: [Meritbox Web](https://github.com/rex-9/meritbox-me-web)
- **Mobile App**: [Auth Service Mobile](https://github.com/rex-9/auth_service_mobile)

## 🚀 Featuring!

### 🌟 Modern Tech Stack

- **Ruby on Rails API**: Built as an API-only application for efficient server-side processing.
- **PostgreSQL**: Utilized for robust and scalable database management.
- **Devise for Authentication**: Provides a secure and flexible user authentication system.
- **Swagger for API Documentation**: Clear and interactive API documentation for easy integration.

### 🗃️ Testing & Quality Assurance

- **RSpec**: Comprehensive automated testing framework to ensure application reliability and performance.

### 🏗️ Design Patterns & Architecture

- **MVC Design Pattern**: Maintains a clean separation of concerns with the Model-View-Controller design pattern.
- **Dockerized**: Facilitates easy deployment and management of the application using Docker.
- **Clean Architecture**: Promotes maintainability and scalability with a modular architecture.
- **Service-Oriented Architecture**: Modular service classes for better separation of concerns.

### 🔐 Authentication & Security

- **Email-Password Authentication**: Securely authenticate users with email and password.
- **Google Authentication**: Provide a seamless sign in experience with Google OAuth.
- **Forgot Password & Reset Password**: Allow users to recover their accounts with ease.
- **Email Confirmation**: Verify user email addresses to enhance security.
- **Password Attempt Tracking**: Monitor and limit failed login attempts.
- **Role-Based Access Control (RBAC)**: Granular permission management with IAM permissions.
- **Super Admin**: Pre-seeded super admin with full system access.

### 🔌 Integrated Services

The system integrates with multiple third-party services to provide a complete solution:

#### 📧 Email Service

- **Provider**: OneSignal
- **Function**: Send transactional and promotional emails
- **Implementation**: Modular design with support for multiple providers

#### 🔔 Push Notification Service

- **Provider**: OneSignal
- **Function**: Real-time push notifications for mobile and web
- **Implementation**: Extensible service layer with provider abstraction

#### 📁 Storage Service

- **Providers**: Cloudinary, AWS S3, Local
- **Function**: File uploads, image processing, and media storage
- **Implementation**: Adapter pattern for easy provider switching

#### 💳 Payment Service

- **Provider**: Stripe
- **Function**: Payment processing, subscription management
- **Implementation**: Clean service abstraction for payment operations

#### 🤖 AI Service

- **Provider**: DeepSeek
- **Function**: AI-powered features and content generation
- **Implementation**: Service-based architecture with fallback support

#### 🔌 Socket Service

- **Provider**: Action Cable
- **Function**: Real-time WebSocket connections and live updates
- **Implementation**: Built-in Rails Action Cable integration

## 🛠 Built With <a name="built-with"></a>

### Tech Stack <a name="tech-stack"></a>

<details>
  <summary>Client</summary>
  <ul>
    <li><a href="https://react.dev/">React</a></li>
    <li><a href="https://tailwindcss.com/">TailwindCSS</a></li>
    <li><a href="https://www.typescriptlang.org/">TypeScript</a></li>
    <li><a href="https://vitejs.dev/">Vite</a></li>
    <li><a href="https://www.docker.com/">Docker</a> (for development)</li>
  </ul>
</details>

<details>
  <summary>Server</summary>
  <ul>
    <li><a href="https://rubyonrails.org/">Ruby on Rails</a></li>
    <li><a href="https://rubygems.org/gems/devise/">Devise</a></li>
    <li><a href="https://redis.io/">Redis</a></li>
    <li><a href="https://www.docker.com/">Docker</a> (for development)</li>
    <li><a href="https://stripe.com/">Stripe</a> (Payment)</li>
    <li><a href="https://onesignal.com/">OneSignal</a> (Notifications)</li>
    <li><a href="https://cloudinary.com/">Cloudinary</a> (Media Storage)</li>
    <li><a href="https://aws.amazon.com/s3/">AWS S3</a> (File Storage)</li>
    <li><a href="https://deepseek.com/">DeepSeek</a> (AI Services)</li>
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

In order to run this project you need [ruby-on-rails](https://www.ruby-lang.org/en/downloads/) and [postgresql](https://www.postgresql.org/) set up on your computer or just a [docker](https://www.docker.com/):

Check your ruby and postgresql installations are complete if you are not using docker.

```sh
  ruby --version && postgres --version
```

### Setup

Clone this repository or download as a zip file to your desired folder:

```sh
  cd my-folder
  git clone git@github.com:meritbox-me/meritbox-api.git
```

Enter the Root level of the project

```sh
  cd meritbox-api
```

Install the dependencies using yarn or npm:

```sh
> bundle install
```

Set up the database:

```sh
> rails db:setup
```

Run database migrations:

```sh
> rails db:migrate
```

### Scripts

Explore them under `/scripts ` folder.

### Run

run the app.

```sh
> sh scripts/dev.sh
```

### Test

set up rspec for once

```sh
> rails generate rspec:install
```

execute tests

```sh
> sh scripts/test.sh
```

watch tests

```sh
> sh scripts/test_watch.sh
```

### Doc

generate swagger documentation

```sh
> sh scripts/rswag.sh
```

view the API documentation at

`/api-docs/index.html`

### Performance Dashboard

The application includes a built-in performance monitoring dashboard powered by Rails' built-in instrumentation.

#### Access

View the performance dashboard at:

`/performance`

with ENV variables credentials

```bash
RAILS_PERFORMANCE_USERNAME=admin
RAILS_PERFORMANCE_PASSWORD=password
```

### Admin Dashboard

**Administrate** is available at `/admin` for managing users, roles, permissions, and other resources with full RBAC support.

#### Authentication & RBAC

#### Super Admin Setup

The super admin user is automatically created through seeders:

```bash
# Run seeders to create super admin
> rails db:seed
```

**Default Super Admin Credentials:**

```
Email: super@admin.com
Password: 111111
```

> ⚠️ **Important**: Change the default super admin credentials immediately in production!

You can customize the super admin creation by modifying the seed file or setting environment variables:

```bash
# Override default super admin credentials
SUPER_ADMIN_EMAIL=admin@yourdomain.com
SUPER_ADMIN_PASSWORD=<secure-password>
```

#### Routes

| Path                 | Description           | Required Role      |
| -------------------- | --------------------- | ------------------ |
| `/admin`             | Admin dashboard       | admin, super_admin |
| `/admin/users`       | User management       | admin, super_admin |
| `/admin/roles`       | Role management       | super_admin only   |
| `/admin/permissions` | Permission management | super_admin only   |
| `/admin/assets`      | Asset management      | admin, super_admin |

#### Permissions

The RBAC system supports granular permissions:

| Resource    | Actions                      | Description                           |
| ----------- | ---------------------------- | ------------------------------------- |
| Users       | create, read, update, delete | Manage user accounts                  |
| Roles       | create, read, update, delete | Manage roles (super admin only)       |
| Permissions | create, read, update, delete | Manage permissions (super admin only) |
| Assets      | create, read, update, delete | Manage system assets                  |

### Explore More Open Source Projects

If you are interested in exploring more open source projects, check out Instacart's GitHub page:

[Instacart Open Source Projects](https://github.com/instacart)

# ☕ Support <a name="support"></a>

If you like this project, please consider giving it a star on GitHub and buying me a coffee to support its development: 🌟

[![GitHub Stars](https://img.shields.io/github/stars/meritbox-me/meritbox-api.svg?style=social&label=Star)](https://github.com/rex-9/meritbox-api)

<div align="center">
  <a href="https://buymeacoffee.com/rex9" target="_blank">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" >
  </a>
</div>

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## 👤 Author

**Rex (Rex9)**

- GitHub: [@rex-9](https://github.com/rex-9)
- Portfolio: [rex9.vercel.app](https://rex9.vercel.app)
- Linkedin: [rex9](https://www.linkedin.com/in/rex9/)

_Built with ❤️ by Rex9_
