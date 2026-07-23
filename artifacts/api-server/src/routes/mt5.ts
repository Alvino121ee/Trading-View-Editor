import { Router, type IRouter } from "express";
import { db, signalsTable } from "@workspace/db";
import { eq, and, asc, desc, lt } from "drizzle-orm";

const router: IRouter = Router();

const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET ?? "ZS909506";

// ── GET /api/mt5/pending ────────────────────────────────────────────
// MT5 EA polls this every N seconds. Returns oldest pending signal and
// marks it as "sent" so it won't be returned twice.
router.get("/mt5/pending", async (req, res): Promise<void> => {
  const { secret, symbol } = req.query;

  if (secret !== WEBHOOK_SECRET) {
    res.status(401).json({ error: "Invalid secret" });
    return;
  }

  // Auto-expire signals older than 15 minutes
  const expiryCutoff = new Date(Date.now() - 15 * 60 * 1000);
  await db
    .update(signalsTable)
    .set({ status: "expired", updatedAt: new Date() })
    .where(
      and(
        eq(signalsTable.status, "pending"),
        lt(signalsTable.createdAt, expiryCutoff),
      ),
    );

  const whereClause =
    symbol && String(symbol).length > 0
      ? and(
          eq(signalsTable.status, "pending"),
          eq(signalsTable.symbol, String(symbol)),
        )
      : eq(signalsTable.status, "pending");

  const [signal] = await db
    .select()
    .from(signalsTable)
    .where(whereClause)
    .orderBy(asc(signalsTable.createdAt))
    .limit(1);

  if (!signal) {
    res.json({ ok: true, signal: null });
    return;
  }

  // Mark as sent so it won't be returned on the next poll
  await db
    .update(signalsTable)
    .set({ status: "sent", updatedAt: new Date() })
    .where(eq(signalsTable.id, signal.id));

  req.log.info({ id: signal.id, action: signal.action }, "Signal sent to MT5");
  res.json({ ok: true, signal });
});

// ── POST /api/mt5/ack/:id ───────────────────────────────────────────
// MT5 EA calls this after placing the order to confirm execution.
router.post("/mt5/ack/:id", async (req, res): Promise<void> => {
  const rawId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
  const id = parseInt(rawId, 10);

  if (isNaN(id)) {
    res.status(400).json({ error: "Invalid signal id" });
    return;
  }

  const { ticket, secret } = req.body;

  if (secret && secret !== WEBHOOK_SECRET) {
    res.status(401).json({ error: "Invalid secret" });
    return;
  }

  const [signal] = await db
    .update(signalsTable)
    .set({
      status: "executed",
      mt5Ticket: ticket ? Number(ticket) : null,
      executedAt: new Date(),
      updatedAt: new Date(),
    })
    .where(eq(signalsTable.id, id))
    .returning();

  if (!signal) {
    res.status(404).json({ error: "Signal not found" });
    return;
  }

  req.log.info({ id, ticket }, "Signal acknowledged by MT5");
  res.json({ ok: true, signal });
});

// ── POST /api/mt5/result/:id ────────────────────────────────────────
// EA melaporkan hasil trade setelah posisi ditutup (win/loss/breakeven).
// Dipanggil EA pada event CLOSE setelah posisi selesai.
router.post("/mt5/result/:id", async (req, res): Promise<void> => {
  const rawId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
  const id = parseInt(rawId, 10);

  if (isNaN(id)) {
    res.status(400).json({ error: "Invalid signal id" });
    return;
  }

  const { secret, result, close_price, pnl, close_reason } = req.body;

  if (secret && secret !== WEBHOOK_SECRET) {
    res.status(401).json({ error: "Invalid secret" });
    return;
  }

  const allowed = ["win", "loss", "breakeven"];
  if (!result || !allowed.includes(String(result).toLowerCase())) {
    res.status(400).json({ error: `result harus salah satu dari: ${allowed.join(", ")}` });
    return;
  }

  const [signal] = await db
    .update(signalsTable)
    .set({
      result: String(result).toLowerCase(),
      closePrice: close_price != null ? String(close_price) : null,
      pnl: pnl != null ? String(pnl) : null,
      closeReason: close_reason != null ? String(close_reason) : null,
      updatedAt: new Date(),
    })
    .where(eq(signalsTable.id, id))
    .returning();

  if (!signal) {
    res.status(404).json({ error: "Signal not found" });
    return;
  }

  req.log.info({ id, result, pnl }, "Signal result recorded");
  res.json({ ok: true, signal });
});

// ── GET /api/mt5/signals ────────────────────────────────────────────
// View recent signal history (for debugging).
router.get("/mt5/signals", async (req, res): Promise<void> => {
  const { secret, limit } = req.query;

  if (secret !== WEBHOOK_SECRET) {
    res.status(401).json({ error: "Invalid secret" });
    return;
  }

  const n = Math.min(parseInt(String(limit ?? "50"), 10) || 50, 200);

  const signals = await db
    .select()
    .from(signalsTable)
    .orderBy(desc(signalsTable.createdAt))
    .limit(n);

  res.json({ ok: true, signals });
});

export default router;
