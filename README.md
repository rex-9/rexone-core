# auth-service-api

<a name="readme-top"></a>

<div align="center">
  <h3><b>Auth Service Api</b></h3>
</div>

<!-- TABLE OF CONTENTS -->

# 📗 Table of Contents

- [auth-service-api](#auth-service-api)
- [📗 Table of Contents](#-table-of-contents)
- [📖 Auth Service Api ](#-auth-service-api-)
  - [🛠 Built With ](#-built-with-)
    - [Tech Stack ](#tech-stack-)
  - [💻 Getting Started ](#-getting-started-)
    - [Prerequisites](#prerequisites)
    - [Setup](#setup)
    - [Run](#run)
    - [Test](#test)
    - [Doc](#doc)
- [☕ Support ](#-support-)

<!-- PROJECT DESCRIPTION -->

# 📖 Auth Service Api <a name="about-project"></a>

**Auth Service Api** is the server application for [Auth Service](https://google.com/) to contribute the society.

## 🛠 Built With <a name="built-with"></a>

### Tech Stack <a name="tech-stack"></a>

<details>
  <summary>Client</summary>
  <ul>
    <li><a href="https://react.dev/">React</a></li>
    <li><a href="https://tailwindcss.com/">TailwindCSS</a></li>
    <li><a href="https://www.typescriptlang.org/">TypeScript</a></li>
    <li><a href="https://vitejs.dev/">Vite</a></li>
  </ul>
</details>

<details>
  <summary>Server</summary>
  <ul>
    <li><a href="https://rubyonrails.org/">Ruby on Rails</a></li>
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

In order to run this project you need [ruby-on-rails](https://www.ruby-lang.org/en/downloads/) and [postgresql](https://www.postgresql.org/) set up on your computer:

Check your ruby and postgresql installations are complete.

```sh
  ruby --version && postgres --version
```

### Setup

Clone this repository or download as a zip file to your desired folder:

```sh
  cd my-folder
  git clone git@github.com:auth-service/auth-service-api.git
```

Enter the Root level of the project

```sh
  cd auth-service-api
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

### Run

run the app.

```sh
> sh run_dev.sh
```

### Test

set up rspec for once

```sh
> rails generate rspec:install
```

execute tests

```sh
> sh tests_exec.sh
```

### Doc

generate swagger documentation

```sh
> sh rswag_gen.sh
```

view the API documentation at

http://localhost:3000/api-docs/index.html

# ☕ Support <a name="support"></a>

If you like this project, please consider giving it a star on GitHub and buying me a coffee to support its development:

[![GitHub Stars](https://img.shields.io/github/stars/rex-9/auth-service-api.svg?style=social&label=Star)](https://github.com/your-repo-name)

<div align="center">
  <a href="https://buymeacoffee.com/rex9" target="_blank">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" >
  </a>
</div>

<p align="right">(<a href="#readme-top">back to top</a>)</p>
