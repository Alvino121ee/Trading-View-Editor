import { Router, type IRouter } from "express";
import { db, signalsTable } from "@workspace/db";
import { desc, eq, sql, and, isNotNull } from "drizzle-orm";

const router: IRouter = Router();

// ── GET /api/monitor/signals ────────────────────────────────────────
// Last 100 signals for the monitoring dashboard (public read-only).
router.get("/monitor/signals", async (req, res): Promise<void> => {
  const { limit } = req.query;
  const n = Math.min(parseInt(String(limit ?? "100"), 10) || 100, 200);

  const signals = await db
    .select()
    .from(signalsTable)
    .orderBy(desc(signalsTable.createdAt))
    .limit(n);

  res.json({ ok: true, signals });
});

// ── GET /api/monitor/summary ────────────────────────────────────────
// Aggregate stats + latest active signal.
router.get("/monitor/summary", async (req, res): Promise<void> => {
  // Count by status
  const counts = await db
    .select({
      status: signalsTable.status,
      count: sql<number>`cast(count(*) as int)`,
    })
    .from(signalsTable)
    .groupBy(signalsTable.status);

  const byStatus: Record<string, number> = {};
  for (const row of counts) {
    byStatus[row.status] = row.count;
  }

  // Latest active (pending or sent)
  const [active] = await db
    .select()
    .from(signalsTable)
    .where(
      sql`${signalsTable.status} IN ('pending', 'sent')`,
    )
    .orderBy(desc(signalsTable.createdAt))
    .limit(1);

  // Latest executed (most recent trade)
  const [lastTrade] = await db
    .select()
    .from(signalsTable)
    .where(eq(signalsTable.status, "executed"))
    .orderBy(desc(signalsTable.executedAt))
    .limit(1);

  // Hitung win/loss dari sinyal yang sudah ada hasilnya
  const resultCounts = await db
    .select({
      result: signalsTable.result,
      count: sql<number>`cast(count(*) as int)`,
      totalPnl: sql<number>`cast(coalesce(sum(${signalsTable.pnl}), 0) as float)`,
    })
    .from(signalsTable)
    .where(isNotNull(signalsTable.result))
    .groupBy(signalsTable.result);

  const byResult: Record<string, { count: number; totalPnl: number }> = {};
  for (const row of resultCounts) {
    byResult[row.result!] = { count: row.count, totalPnl: Number(row.totalPnl) };
  }

  const winCount = byResult["win"]?.count ?? 0;
  const lossCount = byResult["loss"]?.count ?? 0;
  const breakevenCount = byResult["breakeven"]?.count ?? 0;
  const totalWithResult = winCount + lossCount + breakevenCount;
  const totalPnl = Math.round(
    ((byResult["win"]?.totalPnl ?? 0) + (byResult["loss"]?.totalPnl ?? 0) + (byResult["breakeven"]?.totalPnl ?? 0)) * 100
  ) / 100;

  res.json({
    ok: true,
    stats: {
      total: Object.values(byStatus).reduce((a, b) => a + b, 0),
      pending: byStatus["pending"] ?? 0,
      sent: byStatus["sent"] ?? 0,
      executed: byStatus["executed"] ?? 0,
      cancelled: byStatus["cancelled"] ?? 0,
      expired: byStatus["expired"] ?? 0,
    },
    results: {
      win: winCount,
      loss: lossCount,
      breakeven: breakevenCount,
      total: totalWithResult,
      winRate: totalWithResult > 0 ? Math.round((winCount / totalWithResult) * 1000) / 10 : null,
      totalPnl,
    },
    active: active ?? null,
    lastTrade: lastTrade ?? null,
  });
});

export default router;
