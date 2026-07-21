import { Router, type IRouter } from "express";
import { db, signalsTable } from "@workspace/db";
import { eq, and } from "drizzle-orm";

const router: IRouter = Router();

const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET ?? "ZS909506";

router.post("/webhook", async (req, res): Promise<void> => {
  const body = req.body;

  if (!body || body.secret !== WEBHOOK_SECRET) {
    req.log.warn({ provided: body?.secret }, "Invalid webhook secret");
    res.status(401).json({ error: "Invalid secret" });
    return;
  }

  const action: string = body.action ?? "";

  // ── PING ──────────────────────────────────────────────────────────
  if (action === "PING") {
    req.log.info("Webhook PING");
    res.json({ ok: true, action: "PING" });
    return;
  }

  // ── DELETE_PENDING ────────────────────────────────────────────────
  if (action === "DELETE_PENDING") {
    await db
      .update(signalsTable)
      .set({ status: "cancelled", updatedAt: new Date() })
      .where(
        and(
          eq(signalsTable.symbol, String(body.symbol ?? "")),
          eq(signalsTable.status, "pending"),
        ),
      );

    req.log.info({ symbol: body.symbol }, "Cancelled pending signals");
    res.json({ ok: true, action: "DELETE_PENDING" });
    return;
  }

  // ── BUY_LIMIT / SELL_LIMIT ────────────────────────────────────────
  if (action === "BUY_LIMIT" || action === "SELL_LIMIT") {
    const [signal] = await db
      .insert(signalsTable)
      .values({
        secret: String(body.secret),
        action,
        symbol: String(body.symbol ?? ""),
        lot: String(body.lot ?? "0.01"),
        entry: body.entry != null ? String(body.entry) : null,
        sl: body.sl != null ? String(body.sl) : null,
        tp1: body.tp1 != null ? String(body.tp1) : null,
        tp2: body.tp2 != null ? String(body.tp2) : null,
        tp3: body.tp3 != null ? String(body.tp3) : null,
        setup: body.setup ?? null,
        comment: body.comment ?? null,
        status: "pending",
      })
      .returning();

    req.log.info({ id: signal.id, action, symbol: body.symbol }, "Signal stored");
    res.status(201).json({ ok: true, id: signal.id });
    return;
  }

  req.log.warn({ action }, "Unknown webhook action");
  res.status(400).json({ error: `Unknown action: ${action}` });
});

export default router;
