# Cybersecurity - Top 20 Tools

## Web Application Security

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 1 | **OWASP ZAP** | Vulnerability Scanner | Free | Web app scanning, OWASP Top 10 | zaproxy.org |
| 2 | **Burp Suite** | Security Testing | Free (Community) / $449/yr (Pro) | Penetration testing, proxy | portswigger.net |
| 3 | **Snyk** | Dependency Scanning | Free tier / Paid | NPM/pip vulnerability scanning | snyk.io |
| 4 | **Socket.dev** | Supply Chain | Free tier / Paid | Detect malicious packages | socket.dev |
| 5 | **Helmet.js** | HTTP Security | Free | Express.js security headers | helmetjs.github.io |

## Network Security

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 6 | **Nmap** | Network Scanner | Free | Port scanning, network discovery | nmap.org |
| 7 | **Wireshark** | Packet Analyzer | Free | Network traffic analysis | wireshark.org |
| 8 | **Cloudflare** | WAF + DDoS | Free tier / Paid | DDoS protection, bot management | cloudflare.com |

## Secret Management

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 9 | **1Password** | Password Manager | $3/mo | Team password management | 1password.com |
| 10 | **Bitwarden** | Password Manager | Free / $10/yr | Open-source password manager | bitwarden.com |
| 11 | **dotenv-vault** | Secret Management | Free | Encrypted .env files | dotenv.org |
| 12 | **GitHub Secret Scanning** | Leak Detection | Free | Detect leaked secrets in repos | github.com |
| 13 | **HashiCorp Vault** | Secret Store | Free (OSS) / Paid | Enterprise secret management | vaultproject.io |

## SSL & Encryption

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 14 | **Let's Encrypt** | SSL Certs | Free | Free HTTPS certificates | letsencrypt.org |
| 15 | **Cloudflare SSL** | SSL | Free | One-click SSL, auto-renewal | cloudflare.com |

## Security Auditing

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 16 | **SonarQube** | Code Analysis | Free (Community) / Paid | Security bugs, code smells | sonarqube.org |
| 17 | **npm audit** | Dependency Audit | Free | Node.js vulnerability check | npmjs.com |
| 18 | **Trivy** | Container Security | Free | Docker image scanning | trivy.dev |

## Auth & Access

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 19 | **CORS Tester** | Security Test | Free | Test CORS configuration | cors-test.codehappy.dev |
| 20 | **CSP Evaluator** | Content Security | Free | Content Security Policy testing | csp-evaluator.withgoogle.com |

## When to Use What

| Task | Recommended Tools |
|------|------------------|
| Web App Security Scan | OWASP ZAP + Snyk + Helmet.js |
| Dependency Audit | Snyk + npm audit + Socket.dev |
| SSL Setup | Let's Encrypt or Cloudflare SSL |
| Password Management | Bitwarden (personal) / 1Password (team) |
| Secret Management | dotenv-vault + GitHub Secret Scanning |
| Container Security | Trivy + Docker Bench |
| Pen Testing | Burp Suite + Nmap |
