# Real-time & WebSocket - Top 20 Tools

## WebSocket Libraries

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 1 | **Socket.io** | WebSocket Library | Free | Real-time events, rooms, fallback | socket.io |
| 2 | **ws** | WebSocket (Node) | Free | Lightweight raw WebSocket server | github.com/websockets/ws |
| 3 | **WebSocket API** | Browser Native | Free | Native browser WebSocket | developer.mozilla.org |

## Real-time Services

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 4 | **Supabase Realtime** | BaaS Realtime | Free tier / Paid | Postgres changes, presence | supabase.com |
| 5 | **Pusher** | Real-time Service | Free tier / Paid | Channels, pub/sub, presence | pusher.com |
| 6 | **Ably** | Real-time Service | Free tier / Paid | Enterprise real-time messaging | ably.com |
| 7 | **Firebase Realtime DB** | Real-time BaaS | Free tier / Paid | Auto-sync, offline support | firebase.google.com |
| 8 | **Convex** | Reactive Backend | Free tier / Paid | Auto real-time data sync | convex.dev |
| 9 | **PartyKit** | Edge Real-time | Free tier / Paid | Multiplayer, collaborative apps | partykit.io |

## Video & Audio (Real-time)

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 10 | **LiveKit** | WebRTC Platform | Free (self-host) / Paid | Video calls, live streaming | livekit.io |
| 11 | **Daily.co** | Video API | Free tier / Paid | Embed video calls | daily.co |
| 12 | **Agora** | Video/Voice SDK | Free tier / Paid | Voice/video chat, streaming | agora.io |
| 13 | **100ms** | Video SDK | Free tier / Paid | India-based, video rooms | 100ms.live |

## Server-Sent Events (SSE)

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 14 | **EventSource API** | Browser SSE | Free | Server-to-client streaming | developer.mozilla.org |
| 15 | **Vercel AI SDK** | SSE Streaming | Free | AI response streaming | sdk.vercel.ai |

## Message Queues & Pub/Sub

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 16 | **Redis Pub/Sub** | Message Broker | Free | Simple pub/sub messaging | redis.io |
| 17 | **Upstash Kafka** | Serverless Kafka | Free tier / Paid | Serverless event streaming | upstash.com |
| 18 | **BullMQ** | Job Queue | Free | Node.js background jobs | bullmq.io |

## Collaboration & Sync

| # | Tool | Type | Free/Paid | Best For | Website |
|---|------|------|-----------|----------|---------|
| 19 | **Yjs** | CRDT Library | Free | Real-time collaborative editing | yjs.dev |
| 20 | **Liveblocks** | Collaboration SDK | Free tier / Paid | Comments, presence, cursors | liveblocks.io |

## When to Use What

| Task | Recommended Tools |
|------|------------------|
| Chat App | Socket.io + Redis Pub/Sub |
| Real-time Dashboard | Supabase Realtime or Pusher |
| Collaborative Editor | Yjs + Liveblocks |
| Video Call App | LiveKit or 100ms |
| AI Streaming | Vercel AI SDK (SSE) |
| Notifications | Pusher or Ably |
| Background Jobs | BullMQ + Redis |
| Multiplayer Game | PartyKit + WebSocket |
