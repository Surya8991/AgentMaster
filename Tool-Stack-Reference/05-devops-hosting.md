# DevOps & Hosting - Top 20 Tools

## Hosting & Deployment

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 1 | **Vercel** | Frontend Hosting | Free tier / Paid | Next.js, React, static sites | vercel.com |
| 2 | **Netlify** | Frontend Hosting | Free tier / Paid | Static sites, serverless functions | netlify.com |
| 3 | **Railway** | App Hosting | Free trial / $5/mo | Full-stack apps, databases | railway.app |
| 4 | **Render** | Cloud Hosting | Free tier / Paid | Backend APIs, databases, cron | render.com |
| 5 | **Fly.io** | Edge Hosting | Free tier / Paid | Global edge deployment, Docker | fly.io |
| 6 | **AWS** | Cloud Provider | Pay-as-you-go (free tier 12mo) | Enterprise, scalable infra | aws.amazon.com |
| 7 | **DigitalOcean** | VPS/Cloud | $4/mo+ | Simple cloud servers, managed DBs | digitalocean.com |
| 8 | **Cloudflare Pages** | Static Hosting | Free | Static sites, edge functions | pages.cloudflare.com |

## CI/CD & Automation

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 9 | **GitHub Actions** | CI/CD | Free (2K min/mo) / Paid | Automated testing, deployment | github.com/features/actions |
| 10 | **Docker** | Containerization | Free | Consistent environments, deployment | docker.com |
| 11 | **Coolify** | Self-hosted PaaS | Free (self-host) | Self-hosted Vercel/Netlify alternative | coolify.io |

## Domain & DNS

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 12 | **Cloudflare** | CDN + DNS | Free tier / Paid | DNS, SSL, DDoS protection, CDN | cloudflare.com |
| 13 | **Namecheap** | Domain Registrar | ~$9/yr | Affordable domains | namecheap.com |
| 14 | **Google Domains (Squarespace)** | Domain Registrar | ~$12/yr | Clean UI, Google integration | domains.squarespace.com |

## Monitoring & Logging

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 15 | **Sentry** | Error Tracking | Free tier / Paid | Error monitoring, stack traces | sentry.io |
| 16 | **Uptime Robot** | Uptime Monitor | Free (50 monitors) / Paid | Uptime alerts, status pages | uptimerobot.com |
| 17 | **Better Stack (Logtail)** | Logging | Free tier / Paid | Log management, uptime | betterstack.com |

## Version Control & Collaboration

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 18 | **Git** | Version Control | Free | Source code management | git-scm.com |
| 19 | **GitHub** | Code Platform | Free / $4/mo (Pro) | Repos, CI/CD, collaboration | github.com |
| 20 | **VS Code** | Code Editor | Free | Primary development editor | code.visualstudio.com |

## When to Use What

| Project Type | Recommended Stack |
|-------------|-------------------|
| Static Site / Blog | Cloudflare Pages or Vercel + GitHub Actions |
| Next.js App | Vercel + Cloudflare DNS + Sentry |
| Full-stack with DB | Railway or Render + PostgreSQL + GitHub Actions |
| Side Project (free) | Vercel/Netlify + Supabase + Cloudflare |
| Production SaaS | AWS/DigitalOcean + Docker + GitHub Actions + Sentry |
| Self-hosted | Coolify + DigitalOcean + Docker |
