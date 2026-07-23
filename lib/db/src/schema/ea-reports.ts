import {
  pgTable,
  serial,
  text,
  numeric,
  integer,
  bigint,
  boolean,
  timestamp,
} from "drizzle-orm/pg-core";

// Records every meaningful event sent from the ZS V10 Standalone EA:
// OPEN, CLOSE, TP_HIT, REVERSAL, SNAPSHOT (periodic heartbeat)
export const eaReportsTable = pgTable("ea_reports", {
  id: serial("id").primaryKey(),

  // What happened
  eventType: text("event_type").notNull(), // OPEN | CLOSE | TP_HIT | REVERSAL | SNAPSHOT
  symbol: text("symbol").notNull(),
  direction: text("direction"), // BUY | SELL | null when idle

  // Trade params at time of event
  setup: text("setup"),
  score: integer("score"),
  entry: numeric("entry", { precision: 18, scale: 5 }),
  sl: numeric("sl", { precision: 18, scale: 5 }),
  tp1: numeric("tp1", { precision: 18, scale: 5 }),
  tp2: numeric("tp2", { precision: 18, scale: 5 }),
  tp3: numeric("tp3", { precision: 18, scale: 5 }),

  // Close / result fields (populated on CLOSE events)
  closePrice: numeric("close_price", { precision: 18, scale: 5 }),
  plDollars: numeric("pl_dollars", { precision: 10, scale: 2 }),
  closeReason: text("close_reason"), // TP3 | REVERSAL | TIMEOUT | SL | MANUAL
  holdMinutes: integer("hold_minutes"),

  // TP tracking (for TP_HIT events)
  tpLevel: text("tp_level"), // TP1 | TP2 | TP3

  // Indicator snapshot at time of event
  rsi: numeric("rsi", { precision: 6, scale: 2 }),
  adx: numeric("adx", { precision: 6, scale: 2 }),
  atr: numeric("atr", { precision: 10, scale: 5 }),
  buyScore: integer("buy_score"),
  sellScore: integer("sell_score"),
  bullCount: integer("bull_count"),
  bearCount: integer("bear_count"),
  srStatus: text("sr_status"),

  // EA state counters
  mt5Ticket: bigint("mt5_ticket", { mode: "number" }),
  sessionOk: boolean("session_ok"),
  totalSignals: integer("total_signals"),
  winCount: integer("win_count"),
  lossCount: integer("loss_count"),

  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export type EaReport = typeof eaReportsTable.$inferSelect;
