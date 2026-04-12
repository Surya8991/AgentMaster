# Testing & Quality - Top 20 Tools

## Unit & Integration Testing

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 1 | **Vitest** | Test Runner | Free | Vite-native, fast unit tests | vitest.dev |
| 2 | **Jest** | Test Runner | Free | React testing, mocking | jestjs.io |
| 3 | **Pytest** | Python Testing | Free | Python unit/integration tests | pytest.org |
| 4 | **Testing Library** | DOM Testing | Free | Component testing (React, Vue) | testing-library.com |

## E2E & Browser Testing

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 5 | **Playwright** | E2E Testing | Free | Cross-browser E2E, fast, reliable | playwright.dev |
| 6 | **Cypress** | E2E Testing | Free tier / Paid | E2E with great DX, time-travel debug | cypress.io |
| 7 | **Puppeteer** | Browser Automation | Free | Chrome automation, scraping | pptr.dev |

## API Testing

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 8 | **Bruno** | API Client | Free | Offline-first, Git-friendly API testing | usebruno.com |
| 9 | **Postman** | API Client | Free tier / Paid | API testing, collections, team collab | postman.com |
| 10 | **Insomnia** | API Client | Free | REST + GraphQL testing | insomnia.rest |
| 11 | **Hoppscotch** | API Client | Free | Open-source, lightweight Postman alt | hoppscotch.io |

## Performance & Load Testing

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 12 | **Lighthouse** | Perf Audit | Free | Core Web Vitals, SEO, accessibility | developer.chrome.com/docs/lighthouse |
| 13 | **WebPageTest** | Perf Testing | Free | Detailed waterfall, real device testing | webpagetest.org |
| 14 | **k6** | Load Testing | Free | Load/stress testing APIs | k6.io |

## Code Quality

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 15 | **ESLint** | Linter | Free | JavaScript/TypeScript linting | eslint.org |
| 16 | **Prettier** | Formatter | Free | Code formatting | prettier.io |
| 17 | **SonarQube** | Code Analysis | Free (Community) / Paid | Security, bugs, code smells | sonarqube.org |
| 18 | **Biome** | Linter + Formatter | Free | Fast all-in-one (replaces ESLint+Prettier) | biomejs.dev |

## Accessibility & Security

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 19 | **axe DevTools** | Accessibility | Free extension / Paid | WCAG compliance testing | deque.com/axe |
| 20 | **Snyk** | Security Scanning | Free tier / Paid | Dependency vulnerability scanning | snyk.io |

## When to Use What

| Task | Recommended Tools |
|------|------------------|
| React App Testing | Vitest + Testing Library + Playwright |
| API Testing | Bruno or Hoppscotch + Vitest |
| Performance Audit | Lighthouse + WebPageTest |
| Load Testing | k6 |
| Code Quality | Biome or ESLint + Prettier |
| Security Scan | Snyk + SonarQube |
| Accessibility | axe DevTools + Lighthouse |
