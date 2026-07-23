import {
  pgTable,
  serial,
  text,
  numeric,
  bigint,
  timestamp,
} from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";

export const signalsTable = pgTable("signals", {
  id: serial("id").primaryKey(),
  secret: text("secret").notNull(),
  action: text("action").notNull(), // BUY_LIMIT | SELL_LIMIT | DELETE_PENDING | PING
  symbol: text("symbol").notNull(),
  lot: numeric("lot", { precision: 10, scale: 2 }).notNull().default("0.01"),
  entry: numeric("entry", { precision: 18, scale: 5 }),
  sl: numeric("sl", { precision: 18, scale: 5 }),
  tp1: numeric("tp1", { precision: 18, scale: 5 }),
  tp2: numeric("tp2", { precision: 18, scale: 5 }),
  tp3: numeric("tp3", { precision: 18, scale: 5 }),
  setup: text("setup"),
  comment: text("comment"),
  // pending → sent → executed | cancelled | expired
  status: text("status").notNull().default("pending"),
  mt5Ticket: bigint("mt5_ticket", { mode: "number" }),

  // Win/Loss tracking — diisi oleh EA setelah posisi ditutup
  // null = belum ada hasil (posisi masih open atau belum dilapor)
  result: text("result"), // win | loss | breakeven
  closePrice: numeric("close_price", { precision: 18, scale: 5 }),
  pnl: numeric("pnl", { precision: 10, scale: 2 }), // P&L dalam USD
  closeReason: text("close_reason"), // TP1 | TP2 | TP3 | SL | MANUAL | REVERSAL

  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
  executedAt: timestamp("executed_at", { withTimezone: true }),
});

export const insertSignalSchema = createInsertSchema(signalsTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});
export type InsertSignal = z.infer<typeof insertSignalSchema>;
export type Signal = typeof signalsTable.$inferSelect;
