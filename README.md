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
  - [🛠 Built With ](#-built-with-)
    - [Tech Stack ](#tech-stack-)
  - [💻 Getting Started ](#-getting-started-)
    - [Prerequisites](#prerequisites)
    - [Setup](#setup)
    - [Scripts](#scripts)
    - [Run](#run)
    - [Test](#test)
    - [Doc](#doc)
    - [Performance](#performance)
    - [Explore More Open Source Projects](#explore-more-open-source-projects)
- [☕ Support ](#-support-)

<!-- PROJECT DESCRIPTION -->

# 📖 Meritbox Api <a name="about-project"></a>

**Meritbox Api** is a robust backend framework for authenticated web applications, offering a solid foundation for diverse product development needs. This repository also serves as an excellent learning resource for anyone looking to master backend development. It emphasizes best practices on the server side, enabling developers to write simple yet clean code. You can find the corresponding frontend application here: [Meritbox Web](https://github.com/rex-9/meritbox-me-web).

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

### 🔐 Authentication & Security

- **Email-Password Authentication**: Securely authenticate users with email and password.
- **Google Authentication**: Provide a seamless sign in experience with Google OAuth.
- **Forgot Password & Reset Password**: Allow users to recover their accounts with ease.
- **Email Confirmation**: Verify user email addresses to enhance security.

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
> sh scripts/tests.sh
```

### Doc

generate swagger documentation

```sh
> sh scripts/rswag.sh
```

view the API documentation at

`/api-docs/index.html`

### Performance

view the performance dashboard at

`/performance`

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
