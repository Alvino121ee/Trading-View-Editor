# ZS MT5 Signal Bridge

A trading signal bridge that receives signals from TradingView webhooks, stores them in PostgreSQL, and serves them to a MetaTrader 5 Expert Advisor (EA) which executes the trades automatically on XAUUSD.

## Run & Operate

- `pnpm install` — install all workspace dependencies
- `pnpm --filter @workspace/api-server run dev` — run the API server (port from `$PORT`)
- `pnpm --filter @workspace/monitor run dev` — run the monitor dashboard (port from `$PORT`)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)

## Stack

- pnpm workspaces, Node.js 20, TypeScript 5.9
- API: Express 5 + pino logging
- DB: PostgreSQL (Replit built-in) + Drizzle ORM
- Validation: Zod (`zod/v4`), `drizzle-zod`
- API codegen: Orval (from OpenAPI spec)
- Build: esbuild (CJS bundle)
- Frontend: React + Vite + shadcn/ui + Wouter

## Where things live

- `artifacts/api-server/src/routes/` — Express route handlers
  - `webhook.ts` — receives TradingView signals (`POST /api/webhook`)
  - `mt5.ts` — MT5 EA polls here (`GET /api/mt5/pending`, `POST /api/mt5/ack/:id`)
  - `monitor.ts` — dashboard data (`GET /api/monitor/signals`, `/api/monitor/summary`)
  - `health.ts` — `GET /api/healthz`
- `artifacts/monitor/` — React dashboard (ZS Signal Monitor)
- `lib/db/src/schema/signals.ts` — source-of-truth DB schema (signalsTable)
- `lib/api-spec/openapi.yaml` — OpenAPI spec (source of truth for API contracts)
- `ZS_MT5_Bridge_EA.mq5` — MetaTrader 5 Expert Advisor file (copy to MT5 Experts folder)

## Architecture decisions

- Signals flow: TradingView → `POST /api/webhook` → DB (status: pending) → MT5 EA polls `GET /api/mt5/pending` (status: sent) → EA acks `POST /api/mt5/ack/:id` (status: executed)
- Signals auto-expire after 15 minutes if not picked up by MT5
- `WEBHOOK_SECRET` defaults to `"ZS909506"` if env var not set — set it as a secret for production
- MT5 EA uses market orders (buy/sell at current price) with trailing stop logic across TP1/TP2/TP3 levels
- The EA's server URL must be set to this app's published URL (e.g. `https://YOUR-APP.replit.app`)

## Product

- Receive buy/sell signals from TradingView alerts via webhook
- Automatically execute trades on MetaTrader 5 (XAUUSD)
- Trailing stop management: SL moves to breakeven at TP1, to TP1 at TP2, closes at TP3
- Real-time monitor dashboard showing signal status and audit log

## User preferences

- Gunakan Bahasa Indonesia dalam semua komunikasi dengan pengguna.

## Gotchas

- After schema changes run `pnpm --filter @workspace/db run push` before restarting the API server
- The MT5 EA must have the published Replit app URL configured in `InpServerURL`
- The `WEBHOOK_SECRET` in the EA (`InpSecret`) must match the server's `WEBHOOK_SECRET` env var (default: `ZS909506`)
- MT5 must have "Allow WebRequest" enabled for the server URL in Tools > Options > Expert Advisors

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
