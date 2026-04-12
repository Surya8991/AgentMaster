# Chrome Extension Development - Top 20 Tools

## Frameworks & Starters

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 1 | **WXT** | Extension Framework | Free | Vite-based, HMR, multi-browser | wxt.dev |
| 2 | **Plasmo** | Extension Framework | Free | React/Vue/Svelte extensions | plasmo.com |
| 3 | **CRXJS** | Vite Plugin | Free | Vite + Chrome Extension | crxjs.dev |
| 4 | **Vanilla JS** | No Framework | Free | Lightweight, zero deps (like GrabVault) | - |
| 5 | **Chrome Extension CLI** | Scaffolding | Free | Quick boilerplate generator | github.com |

## Chrome APIs

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 6 | **Manifest V3** | API Standard | Free | Required for new extensions | developer.chrome.com |
| 7 | **chrome.storage** | Storage API | Free | Persist user settings/data | developer.chrome.com |
| 8 | **chrome.tabs** | Tabs API | Free | Tab manipulation, injection | developer.chrome.com |
| 9 | **chrome.scripting** | Content Scripts | Free | DOM manipulation on pages | developer.chrome.com |
| 10 | **chrome.runtime** | Messaging | Free | Popup-background communication | developer.chrome.com |

## UI & Styling

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 11 | **Tailwind CSS** | Styling | Free | Rapid popup/options UI | tailwindcss.com |
| 12 | **shadcn/ui** | Components | Free | React extension popups | ui.shadcn.com |
| 13 | **Lucide Icons** | Icons | Free | Lightweight SVG icons | lucide.dev |

## Testing & Debugging

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 14 | **Chrome DevTools** | Debugging | Free | Extension debugging, console | developer.chrome.com |
| 15 | **Extension Reloader** | Dev Tool | Free | Auto-reload on file changes | chrome web store |
| 16 | **Puppeteer** | E2E Testing | Free | Automated extension testing | pptr.dev |

## Publishing & Monetization

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 17 | **Chrome Web Store** | Distribution | $5 one-time | Publish extensions | chrome.google.com/webstore |
| 18 | **ExtensionPay** | Payments | 5% fee | Stripe-based extension payments | extensionpay.com |
| 19 | **Gumroad** | License Keys | 10% fee | Sell extension license keys | gumroad.com |
| 20 | **Ko-fi** | Tips/Donations | 0% on tips | Free extension monetization | ko-fi.com |

## When to Use What

| Project Type | Recommended Stack |
|-------------|-------------------|
| Simple Extension | Vanilla JS + Manifest V3 + Tailwind |
| React Extension | Plasmo or WXT + React + Tailwind |
| Complex Extension | WXT + React + shadcn/ui + chrome.storage |
| Freemium Model | ExtensionPay + chrome.storage (license check) |
| Quick Prototype | CRXJS + Vite + Vanilla JS |
