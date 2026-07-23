import { Router, type IRouter } from "express";
import { db, eaReportsTable } from "@workspace/db";
import { desc, eq, and, isNotNull } from "drizzle-orm";

const router: IRouter = Router();

const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET ?? "ZS909506";

// ── POST /api/ea/report ─────────────────────────────────────────────
// EA sends an event report (OPEN, CLOSE, TP_HIT, REVERSAL, SNAPSHOT).
router.post("/ea/report", async (req, res): Promise<void> => {
  const body = req.body;

  if (!body || body.secret !== WEBHOOK_SECRET) {
    res.status(401).json({ error: "Invalid secret" });
    return;
  }

  const eventType: string = String(body.event_type ?? "").toUpperCase();
  const allowed = ["OPEN", "CLOSE", "TP_HIT", "REVERSAL", "SNAPSHOT"];
  if (!allowed.includes(eventType)) {
    res.status(400).json({ error: `Unknown event_type: ${eventType}` });
    return;
  }

  const toStr = (v: unknown) => (v != null ? String(v) : null);
  const toInt = (v: unknown) => {
    const n = parseInt(String(v ?? ""), 10);
    return isNaN(n) ? null : n;
  };
  const toBool = (v: unknown) => {
    if (v === true || v === "true" || v === 1) return true;
    if (v === false || v === "false" || v === 0) return false;
    return null;
  };

  const [row] = await db
    .insert(eaReportsTable)
    .values({
      eventType,
      symbol: String(body.symbol ?? "XAUUSD"),
      direction: toStr(body.direction),
      setup: toStr(body.setup),
      score: toInt(body.score),
      entry: toStr(body.entry),
      sl: toStr(body.sl),
      tp1: toStr(body.tp1),
      tp2: toStr(body.tp2),
      tp3: toStr(body.tp3),
      closePrice: toStr(body.close_price),
      plDollars: toStr(body.pl_dollars),
      closeReason: toStr(body.close_reason),
      holdMinutes: toInt(body.hold_minutes),
      tpLevel: toStr(body.tp_level),
      rsi: toStr(body.rsi),
      adx: toStr(body.adx),
      atr: toStr(body.atr),
      buyScore: toInt(body.buy_score),
      sellScore: toInt(body.sell_score),
      bullCount: toInt(body.bull_count),
      bearCount: toInt(body.bear_count),
      srStatus: toStr(body.sr_status),
      mt5Ticket: toInt(body.mt5_ticket),
      sessionOk: toBool(body.session_ok),
      totalSignals: toInt(body.total_signals),
      winCount: toInt(body.win_count),
      lossCount: toInt(body.loss_count),
    })
    .returning({ id: eaReportsTable.id });

  req.log.info({ id: row.id, eventType, symbol: body.symbol }, "EA report stored");
  res.status(201).json({ ok: true, id: row.id });
});

// ── GET /api/ea/reports ─────────────────────────────────────────────
// Recent EA event reports for the dashboard feed.
router.get("/ea/reports", async (req, res): Promise<void> => {
  const n = Math.min(parseInt(String(req.query.limit ?? "100"), 10) || 100, 500);

  const rows = await db
    .select()
    .from(eaReportsTable)
    .orderBy(desc(eaReportsTable.createdAt))
    .limit(n);

  res.json({ ok: true, reports: rows });
});

// ── GET /api/ea/analytics ───────────────────────────────────────────
// Aggregated performance analytics derived from EA reports.
router.get("/ea/analytics", async (req, res): Promise<void> => {
  // --- Closed trades (CLOSE events with P&L) ---
  const closedTrades = await db
    .select()
    .from(eaReportsTable)
    .where(eq(eaReportsTable.eventType, "CLOSE"))
    .orderBy(desc(eaReportsTable.createdAt))
    .limit(500);

  const totalTrades = closedTrades.length;
  let winCount = 0;
  let lossCount = 0;
  let totalPl = 0;
  let totalHold = 0;
  let holdCount = 0;
  const byDirection: Record<string, { total: number; win: number }> = {};
  const bySetup: Record<string, { total: number; win: number; totalPl: number }> = {};

  for (const t of closedTrades) {
    const pl = parseFloat(t.plDollars ?? "0");
    const isWin = pl > 0;
    if (isWin) winCount++; else lossCount++;
    totalPl += pl;

    if (t.holdMinutes) {
      totalHold += t.holdMinutes;
      holdCount++;
    }

    if (t.direction) {
      byDirection[t.direction] ??= { total: 0, win: 0 };
      byDirection[t.direction].total++;
      if (isWin) byDirection[t.direction].win++;
    }

    if (t.setup) {
      bySetup[t.setup] ??= { total: 0, win: 0, totalPl: 0 };
      bySetup[t.setup].total++;
      bySetup[t.setup].totalPl += pl;
      if (isWin) bySetup[t.setup].win++;
    }
  }

  // --- Score distribution at OPEN events ---
  const openEvents = await db
    .select({
      score: eaReportsTable.score,
      direction: eaReportsTable.direction,
    })
    .from(eaReportsTable)
    .where(and(eq(eaReportsTable.eventType, "OPEN"), isNotNull(eaReportsTable.score)))
    .orderBy(desc(eaReportsTable.createdAt))
    .limit(200);

  const scoreRanges: Record<string, number> = {
    "70-79": 0, "80-89": 0, "90-99": 0, "100-109": 0, "110+": 0,
  };
  for (const o of openEvents) {
    const s = o.score ?? 0;
    if (s >= 110) scoreRanges["110+"]++;
    else if (s >= 100) scoreRanges["100-109"]++;
    else if (s >= 90)  scoreRanges["90-99"]++;
    else if (s >= 80)  scoreRanges["80-89"]++;
    else if (s >= 70)  scoreRanges["70-79"]++;
  }

  // --- Latest snapshot (EA live state) ---
  const [latestSnapshot] = await db
    .select()
    .from(eaReportsTable)
    .where(eq(eaReportsTable.eventType, "SNAPSHOT"))
    .orderBy(desc(eaReportsTable.createdAt))
    .limit(1);

  // --- Latest OPEN event ---
  const [latestOpen] = await db
    .select()
    .from(eaReportsTable)
    .where(eq(eaReportsTable.eventType, "OPEN"))
    .orderBy(desc(eaReportsTable.createdAt))
    .limit(1);

  // --- Cumulative P&L over time (last 50 closed trades) ---
  const plHistory = closedTrades
    .slice(0, 50)
    .reverse()
    .reduce<{ time: string; pl: number; cumPl: number }[]>((acc, t) => {
      const prev = acc[acc.length - 1]?.cumPl ?? 0;
      const pl = parseFloat(t.plDollars ?? "0");
      acc.push({
        time: t.createdAt.toISOString(),
        pl: Math.round(pl * 100) / 100,
        cumPl: Math.round((prev + pl) * 100) / 100,
      });
      return acc;
    }, []);

  res.json({
    ok: true,
    analytics: {
      totalTrades,
      winCount,
      lossCount,
      winRate: totalTrades > 0 ? Math.round((winCount / totalTrades) * 1000) / 10 : 0,
      totalPl: Math.round(totalPl * 100) / 100,
      avgHoldMinutes: holdCount > 0 ? Math.round(totalHold / holdCount) : 0,
      byDirection: Object.entries(byDirection).map(([dir, v]) => ({
        direction: dir,
        total: v.total,
        winCount: v.win,
        winRate: v.total > 0 ? Math.round((v.win / v.total) * 1000) / 10 : 0,
      })),
      bySetup: Object.entries(bySetup)
        .map(([setup, v]) => ({
          setup,
          total: v.total,
          winCount: v.win,
          winRate: v.total > 0 ? Math.round((v.win / v.total) * 1000) / 10 : 0,
          totalPl: Math.round(v.totalPl * 100) / 100,
        }))
        .sort((a, b) => b.total - a.total),
      scoreRanges: Object.entries(scoreRanges).map(([range, count]) => ({
        range,
        count,
      })),
      plHistory,
      recentClosed: closedTrades.slice(0, 20),
      latestSnapshot: latestSnapshot ?? null,
      latestOpen: latestOpen ?? null,
    },
  });
});

export default router;
