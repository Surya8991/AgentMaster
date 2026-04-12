# Backend Development - Top 20 Tools & Tech Stack

## Runtime & Frameworks

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 1 | **Node.js** | Runtime | Free | JS backend, APIs, real-time apps | nodejs.org |
| 2 | **Express.js** | Framework | Free | REST APIs, lightweight servers | expressjs.com |
| 3 | **Fastify** | Framework | Free | High-performance APIs | fastify.dev |
| 4 | **Hono** | Framework | Free | Edge-first, ultra-fast APIs | hono.dev |
| 5 | **Django** | Python Framework | Free | Full-featured web apps, admin panels | djangoproject.com |
| 6 | **FastAPI** | Python Framework | Free | High-perf APIs, async, auto-docs | fastapi.tiangolo.com |
| 7 | **Flask** | Python Framework | Free | Lightweight APIs, microservices | flask.palletsprojects.com |
| 8 | **Spring Boot** | Java Framework | Free | Enterprise Java apps | spring.io |

## Databases

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 9 | **PostgreSQL** | Relational DB | Free | Complex queries, ACID, JSON support | postgresql.org |
| 10 | **MongoDB** | NoSQL | Free (Community) / Paid (Atlas) | Flexible schema, rapid prototyping | mongodb.com |
| 11 | **Supabase** | BaaS (Postgres) | Free tier / Paid | Firebase alternative, real-time, auth | supabase.com |
| 12 | **Firebase** | BaaS | Free tier / Paid | Real-time, auth, quick MVPs | firebase.google.com |
| 13 | **Redis** | In-memory Cache | Free | Caching, sessions, queues | redis.io |
| 14 | **SQLite** | Embedded DB | Free | Local apps, dev, Electron, mobile | sqlite.org |
| 15 | **Turso (libSQL)** | Edge DB | Free tier / Paid | Edge-first SQLite, low latency | turso.tech |

## ORM & Data Layer

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 16 | **Prisma** | ORM | Free | Type-safe DB queries, migrations | prisma.io |
| 17 | **Drizzle ORM** | ORM | Free | Lightweight, SQL-like, edge-ready | orm.drizzle.team |

## Auth & Security

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 18 | **NextAuth.js (Auth.js)** | Auth Library | Free | OAuth, session management | authjs.dev |
| 19 | **Clerk** | Auth Service | Free tier / Paid | Drop-in auth UI, user management | clerk.com |
| 20 | **Lucia** | Auth Library | Free | Lightweight, session-based auth | lucia-auth.com |

## When to Use What

| Project Type | Recommended Stack |
|-------------|-------------------|
| REST API | Node.js + Express/Fastify + PostgreSQL + Prisma |
| Real-time App | Node.js + Socket.io + Redis + MongoDB |
| Full-stack SaaS | Next.js API routes + Supabase + Prisma |
| AI/ML Backend | Python + FastAPI + PostgreSQL |
| Serverless API | Hono/Next.js + Turso/Supabase + Drizzle |
| Enterprise App | Spring Boot + PostgreSQL + Redis |
| MVP/Prototype | Supabase + Next.js (zero backend code) |
