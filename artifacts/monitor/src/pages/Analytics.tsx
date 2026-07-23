import React from 'react';
import { useGetEaAnalytics, useListEaReports, EaReport } from '@workspace/api-client-react';
import { format, parseISO, formatDistanceToNow } from 'date-fns';
import {
  AreaChart, Area, BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, Cell, PieChart, Pie, Legend
} from 'recharts';
import {
  TrendingUp, TrendingDown, Activity, Trophy, Clock, DollarSign,
  Zap, Target, BarChart2, RefreshCw, Wifi, WifiOff, AlertCircle
} from 'lucide-react';

// ── helpers ──────────────────────────────────────────────────────────

const fmt2 = (v?: string | number | null) => {
  if (v == null) return '--';
  return parseFloat(String(v)).toFixed(2);
};

const fmtTime = (iso?: string | null) => {
  if (!iso) return '--';
  try { return format(parseISO(iso), 'MM/dd HH:mm'); } catch { return '--'; }
};

const fmtAgo = (iso?: string | null) => {
  if (!iso) return '--';
  try { return formatDistanceToNow(parseISO(iso), { addSuffix: true }); } catch { return '--'; }
};

const eventColor: Record<string, string> = {
  OPEN:     'text-emerald-400',
  CLOSE:    'text-blue-400',
  TP_HIT:   'text-amber-400',
  REVERSAL: 'text-orange-400',
  SNAPSHOT: 'text-slate-400',
};

const eventBg: Record<string, string> = {
  OPEN:     'bg-emerald-400/10 border-emerald-400/20',
  CLOSE:    'bg-blue-400/10 border-blue-400/20',
  TP_HIT:   'bg-amber-400/10 border-amber-400/20',
  REVERSAL: 'bg-orange-400/10 border-orange-400/20',
  SNAPSHOT: 'bg-slate-400/10 border-slate-400/20',
};

// ── sub-components ────────────────────────────────────────────────────

const KpiCard = ({
  label, value, sub, icon: Icon, color = 'text-primary', trend
}: {
  label: string; value: string | number; sub?: string;
  icon: React.ElementType; color?: string; trend?: 'up' | 'down' | 'neutral';
}) => (
  <div className="bg-card border rounded-lg p-5 flex flex-col gap-3">
    <div className="flex items-center justify-between">
      <span className="text-xs uppercase tracking-widest text-muted-foreground font-medium">{label}</span>
      <Icon className={`w-4 h-4 ${color} opacity-70`} />
    </div>
    <div className={`text-3xl font-mono font-bold ${color} tracking-tight`}>{value}</div>
    {sub && <div className="text-xs text-muted-foreground">{sub}</div>}
  </div>
);

const SectionHeader = ({ icon: Icon, title }: { icon: React.ElementType; title: string }) => (
  <h2 className="text-xs uppercase tracking-widest text-muted-foreground font-semibold flex items-center gap-2 mb-3">
    <Icon className="w-4 h-4" /> {title}
  </h2>
);

const EventBadge = ({ type }: { type: string }) => (
  <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-mono font-semibold border uppercase ${eventColor[type] ?? 'text-slate-400'} ${eventBg[type] ?? 'bg-slate-400/10 border-slate-400/20'}`}>
    {type}
  </span>
);

const DirectionBadge = ({ dir }: { dir?: string | null }) => {
  if (!dir) return <span className="text-muted-foreground text-xs">—</span>;
  const isBuy = dir === 'BUY';
  return (
    <span className={`inline-flex items-center gap-1 text-xs font-bold font-mono ${isBuy ? 'text-emerald-400' : 'text-rose-400'}`}>
      {isBuy ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
      {dir}
    </span>
  );
};

// custom tooltip for charts
const ChartTooltip = ({ active, payload, label }: any) => {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-popover border border-border rounded-md p-3 text-xs shadow-lg">
      <div className="font-mono text-muted-foreground mb-1">{label}</div>
      {payload.map((p: any, i: number) => (
        <div key={i} className="flex gap-2 items-center">
          <span style={{ color: p.color }}>{p.name}:</span>
          <span className="font-mono font-semibold">{typeof p.value === 'number' ? p.value.toFixed(2) : p.value}</span>
        </div>
      ))}
    </div>
  );
};

// ── main page ─────────────────────────────────────────────────────────

export default function Analytics() {
  const { data: analyticsRes, isFetching, isError } = useGetEaAnalytics({
    query: { refetchInterval: 10000 }
  });
  const { data: reportsRes } = useListEaReports(
    { limit: 80 },
    { query: { refetchInterval: 10000 } }
  );

  const a = analyticsRes?.analytics;
  const reports = reportsRes?.reports ?? [];

  const winRate = a?.winRate ?? 0;
  const winRateColor = winRate >= 60 ? 'text-emerald-400' : winRate >= 50 ? 'text-amber-400' : 'text-rose-400';

  const plColor = (a?.totalPl ?? 0) >= 0 ? 'text-emerald-400' : 'text-rose-400';
  const plSign = (a?.totalPl ?? 0) >= 0 ? '+' : '';

  // Latest snapshot data
  const snap = a?.latestSnapshot;
  const snapTime = snap?.createdAt;
  const isEaOnline = snapTime
    ? (Date.now() - new Date(snapTime).getTime()) < 10 * 60 * 1000 // within 10 min
    : false;

  if (isError) {
    return (
      <div className="min-h-screen flex items-center justify-center text-muted-foreground">
        <div className="flex flex-col items-center gap-3">
          <AlertCircle className="w-10 h-10 opacity-40" />
          <p>Could not load analytics. API server may be offline.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-4 md:p-6 lg:p-8 max-w-[1600px] mx-auto space-y-8">

      {/* ── HEADER ── */}
      <header className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-border/50 pb-4">
        <div className="flex items-center gap-4">
          <div className="w-10 h-10 bg-primary/20 text-primary rounded border border-primary/30 flex items-center justify-center">
            <BarChart2 className="w-5 h-5" />
          </div>
          <div>
            <h1 className="text-xl font-bold tracking-tight">EA ANALYTICS</h1>
            <p className="text-sm text-muted-foreground flex items-center gap-2 mt-1">
              {isEaOnline
                ? <><span className="relative flex h-2 w-2"><span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span><span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span></span> EA Online — last seen {fmtAgo(snapTime)}</>
                : <><WifiOff className="w-3 h-3" /> EA Offline {snapTime ? `— last seen ${fmtAgo(snapTime)}` : '— no data yet'}</>
              }
              {isFetching && <RefreshCw className="w-3 h-3 animate-spin ml-1" />}
            </p>
          </div>
        </div>
        <div className="text-xs text-muted-foreground bg-card border rounded px-3 py-2 font-mono">
          Auto-refresh every 10s
        </div>
      </header>

      {/* ── KPI CARDS ── */}
      <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4">
        <KpiCard label="Total Trades" value={a?.totalTrades ?? 0} icon={Activity} />
        <KpiCard
          label="Win Rate"
          value={`${a?.winRate ?? 0}%`}
          sub={`${a?.winCount ?? 0}W / ${a?.lossCount ?? 0}L`}
          icon={Trophy}
          color={winRateColor}
        />
        <KpiCard
          label="Total P&L"
          value={`${plSign}$${fmt2(a?.totalPl)}`}
          icon={DollarSign}
          color={plColor}
        />
        <KpiCard
          label="Avg Hold"
          value={`${a?.avgHoldMinutes ?? 0} min`}
          icon={Clock}
        />
        <KpiCard
          label="Buy Trades"
          value={a?.byDirection?.find(d => d.direction === 'BUY')?.total ?? 0}
          sub={`WR: ${a?.byDirection?.find(d => d.direction === 'BUY')?.winRate ?? 0}%`}
          icon={TrendingUp}
          color="text-emerald-400"
        />
        <KpiCard
          label="Sell Trades"
          value={a?.byDirection?.find(d => d.direction === 'SELL')?.total ?? 0}
          sub={`WR: ${a?.byDirection?.find(d => d.direction === 'SELL')?.winRate ?? 0}%`}
          icon={TrendingDown}
          color="text-rose-400"
        />
      </div>

      {/* ── LIVE EA STATE ── */}
      {snap && (
        <div>
          <SectionHeader icon={Zap} title="Live EA State (last snapshot)" />
          <div className="bg-card border rounded-lg p-5 grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7 gap-4 text-xs">
            {[
              { label: 'Direction', value: <DirectionBadge dir={snap.direction} /> },
              { label: 'Setup', value: <span className="font-mono">{snap.setup || '—'}</span> },
              { label: 'RSI', value: <span className={`font-mono font-bold ${parseFloat(snap.rsi??'50') > 70 ? 'text-rose-400' : parseFloat(snap.rsi??'50') < 30 ? 'text-emerald-400' : 'text-foreground'}`}>{fmt2(snap.rsi)}</span> },
              { label: 'ADX', value: <span className={`font-mono font-bold ${parseFloat(snap.adx??'0') > 25 ? 'text-amber-400' : 'text-muted-foreground'}`}>{fmt2(snap.adx)}</span> },
              { label: 'ATR', value: <span className="font-mono">{fmt2(snap.atr)}</span> },
              { label: 'Bull/Bear', value: <span className="font-mono">{snap.bullCount ?? '?'} / {snap.bearCount ?? '?'}</span> },
              { label: 'SR Status', value: <span className="font-mono text-amber-400/90">{snap.srStatus || '—'}</span> },
              { label: 'Buy Score', value: <span className={`font-mono font-bold ${(snap.buyScore ?? 0) >= 82 ? 'text-emerald-400' : 'text-muted-foreground'}`}>{snap.buyScore ?? '—'}</span> },
              { label: 'Sell Score', value: <span className={`font-mono font-bold ${(snap.sellScore ?? 0) >= 82 ? 'text-rose-400' : 'text-muted-foreground'}`}>{snap.sellScore ?? '—'}</span> },
              { label: 'Session', value: <span className={snap.sessionOk ? 'text-emerald-400 font-semibold' : 'text-muted-foreground'}>{snap.sessionOk ? 'WIB ON' : 'WIB OFF'}</span> },
              { label: 'Win / Loss', value: <span className="font-mono">{snap.winCount ?? '?'} / {snap.lossCount ?? '?'}</span> },
              { label: 'Last Seen', value: <span className="text-muted-foreground">{fmtAgo(snap.createdAt)}</span> },
            ].map(({ label, value }) => (
              <div key={label} className="flex flex-col gap-1">
                <span className="text-muted-foreground uppercase tracking-wider" style={{ fontSize: '10px' }}>{label}</span>
                <div>{value}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ── CHARTS ROW ── */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

        {/* Cumulative P&L */}
        <div className="lg:col-span-2">
          <SectionHeader icon={DollarSign} title="Cumulative P&L (last 50 trades)" />
          <div className="bg-card border rounded-lg p-4 h-56">
            {(a?.plHistory?.length ?? 0) > 1 ? (
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={a!.plHistory} margin={{ top: 5, right: 5, bottom: 0, left: 0 }}>
                  <defs>
                    <linearGradient id="plGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                  <XAxis dataKey="time" tickFormatter={v => { try { return format(parseISO(v), 'MM/dd'); } catch { return ''; }}} tick={{ fontSize: 10, fill: '#64748b' }} />
                  <YAxis tick={{ fontSize: 10, fill: '#64748b' }} tickFormatter={v => `$${v}`} />
                  <Tooltip content={<ChartTooltip />} />
                  <Area type="monotone" dataKey="cumPl" name="Cum. P&L $" stroke="#10b981" fill="url(#plGrad)" strokeWidth={2} dot={false} />
                </AreaChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-full flex items-center justify-center text-muted-foreground text-sm">No closed trades yet</div>
            )}
          </div>
        </div>

        {/* Score Range distribution */}
        <div>
          <SectionHeader icon={Target} title="Score at Entry" />
          <div className="bg-card border rounded-lg p-4 h-56">
            {(a?.scoreRanges?.some(r => r.count > 0)) ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={a!.scoreRanges} margin={{ top: 5, right: 5, bottom: 0, left: -20 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                  <XAxis dataKey="range" tick={{ fontSize: 10, fill: '#64748b' }} />
                  <YAxis tick={{ fontSize: 10, fill: '#64748b' }} allowDecimals={false} />
                  <Tooltip content={<ChartTooltip />} />
                  <Bar dataKey="count" name="Trades" radius={[3, 3, 0, 0]}>
                    {a!.scoreRanges.map((_, i) => (
                      <Cell key={i} fill={['#64748b', '#94a3b8', '#f59e0b', '#10b981', '#22d3ee'][i % 5]} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-full flex items-center justify-center text-muted-foreground text-sm">No data yet</div>
            )}
          </div>
        </div>
      </div>

      {/* ── SETUP PERFORMANCE ── */}
      {(a?.bySetup?.length ?? 0) > 0 && (
        <div>
          <SectionHeader icon={BarChart2} title="Performance by Setup Class" />
          <div className="bg-card border rounded-lg overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm whitespace-nowrap">
                <thead className="text-xs text-muted-foreground uppercase tracking-widest bg-secondary/50 border-b border-border">
                  <tr>
                    <th className="px-4 py-3 text-left font-medium">Setup</th>
                    <th className="px-4 py-3 text-right font-medium">Trades</th>
                    <th className="px-4 py-3 text-right font-medium">Wins</th>
                    <th className="px-4 py-3 text-right font-medium">Win Rate</th>
                    <th className="px-4 py-3 text-right font-medium">Total P&L</th>
                    <th className="px-4 py-3 font-medium">Bar</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/50">
                  {a!.bySetup.map(s => {
                    const wrColor = s.winRate >= 60 ? 'text-emerald-400' : s.winRate >= 50 ? 'text-amber-400' : 'text-rose-400';
                    const plColor = s.totalPl >= 0 ? 'text-emerald-400' : 'text-rose-400';
                    const barW = Math.round(Math.min(s.winRate, 100));
                    return (
                      <tr key={s.setup} className="hover:bg-secondary/30 transition-colors">
                        <td className="px-4 py-3 font-mono text-xs font-semibold">{s.setup}</td>
                        <td className="px-4 py-3 text-right font-mono">{s.total}</td>
                        <td className="px-4 py-3 text-right font-mono text-emerald-400">{s.winCount}</td>
                        <td className={`px-4 py-3 text-right font-mono font-bold ${wrColor}`}>{s.winRate}%</td>
                        <td className={`px-4 py-3 text-right font-mono font-bold ${plColor}`}>{s.totalPl >= 0 ? '+' : ''}${s.totalPl.toFixed(2)}</td>
                        <td className="px-4 py-3 w-32">
                          <div className="h-2 bg-secondary rounded-full overflow-hidden">
                            <div
                              className={`h-full rounded-full transition-all ${s.winRate >= 60 ? 'bg-emerald-500' : s.winRate >= 50 ? 'bg-amber-500' : 'bg-rose-500'}`}
                              style={{ width: `${barW}%` }}
                            />
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ── RECENT CLOSED TRADES ── */}
      <div>
        <SectionHeader icon={Clock} title="Recent Closed Trades" />
        <div className="bg-card border rounded-lg overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm whitespace-nowrap">
              <thead className="text-xs text-muted-foreground uppercase tracking-widest bg-secondary/50 border-b border-border">
                <tr>
                  <th className="px-4 py-3 text-left font-medium">Time</th>
                  <th className="px-4 py-3 font-medium">Dir</th>
                  <th className="px-4 py-3 text-right font-medium">Entry</th>
                  <th className="px-4 py-3 text-right font-medium">Close</th>
                  <th className="px-4 py-3 text-right font-medium">P&L</th>
                  <th className="px-4 py-3 font-medium">Reason</th>
                  <th className="px-4 py-3 text-right font-medium">Hold</th>
                  <th className="px-4 py-3 font-medium">Setup</th>
                  <th className="px-4 py-3 text-right font-medium">Score</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/50">
                {(a?.recentClosed?.length ?? 0) === 0 ? (
                  <tr><td colSpan={9} className="px-4 py-8 text-center text-muted-foreground">No closed trades yet</td></tr>
                ) : (
                  a!.recentClosed.map(t => {
                    const pl = parseFloat(t.plDollars ?? '0');
                    const isWin = pl > 0;
                    return (
                      <tr key={t.id} className="hover:bg-secondary/30 transition-colors">
                        <td className="px-4 py-3 font-mono text-xs text-muted-foreground">{fmtTime(t.createdAt)}</td>
                        <td className="px-4 py-3"><DirectionBadge dir={t.direction} /></td>
                        <td className="px-4 py-3 text-right font-mono">{fmt2(t.entry)}</td>
                        <td className="px-4 py-3 text-right font-mono">{fmt2(t.closePrice)}</td>
                        <td className={`px-4 py-3 text-right font-mono font-bold ${isWin ? 'text-emerald-400' : 'text-rose-400'}`}>
                          {isWin ? '+' : ''}${pl.toFixed(2)}
                        </td>
                        <td className="px-4 py-3">
                          <span className={`text-xs font-mono px-2 py-0.5 rounded border ${
                            t.closeReason === 'TP3' ? 'text-emerald-400 bg-emerald-400/10 border-emerald-400/20' :
                            t.closeReason === 'REVERSAL' ? 'text-orange-400 bg-orange-400/10 border-orange-400/20' :
                            t.closeReason === 'TIMEOUT' ? 'text-amber-400 bg-amber-400/10 border-amber-400/20' :
                            'text-muted-foreground bg-secondary border-border'
                          }`}>{t.closeReason || '—'}</span>
                        </td>
                        <td className="px-4 py-3 text-right font-mono text-xs text-muted-foreground">{t.holdMinutes != null ? `${t.holdMinutes}m` : '—'}</td>
                        <td className="px-4 py-3 font-mono text-xs text-muted-foreground max-w-[120px] truncate">{t.setup || '—'}</td>
                        <td className="px-4 py-3 text-right font-mono text-xs">{t.score ?? '—'}</td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* ── EA EVENT FEED ── */}
      <div>
        <SectionHeader icon={Activity} title="EA Event Feed (live)" />
        <div className="bg-card border rounded-lg overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm whitespace-nowrap">
              <thead className="text-xs text-muted-foreground uppercase tracking-widest bg-secondary/50 border-b border-border">
                <tr>
                  <th className="px-4 py-3 text-left font-medium">Time</th>
                  <th className="px-4 py-3 font-medium">Event</th>
                  <th className="px-4 py-3 font-medium">Dir</th>
                  <th className="px-4 py-3 font-medium">Setup</th>
                  <th className="px-4 py-3 text-right font-medium">Score</th>
                  <th className="px-4 py-3 text-right font-medium">RSI</th>
                  <th className="px-4 py-3 text-right font-medium">ADX</th>
                  <th className="px-4 py-3 font-medium">SR Status</th>
                  <th className="px-4 py-3 text-right font-medium">W/L</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/50">
                {reports.length === 0 ? (
                  <tr><td colSpan={9} className="px-4 py-8 text-center text-muted-foreground text-sm">No EA events yet. Configure the EA with server URL to start sending data.</td></tr>
                ) : (
                  reports.map(r => (
                    <tr key={r.id} className="hover:bg-secondary/30 transition-colors">
                      <td className="px-4 py-3 font-mono text-xs text-muted-foreground">{fmtTime(r.createdAt)}</td>
                      <td className="px-4 py-3"><EventBadge type={r.eventType} /></td>
                      <td className="px-4 py-3"><DirectionBadge dir={r.direction} /></td>
                      <td className="px-4 py-3 font-mono text-xs max-w-[100px] truncate text-muted-foreground">{r.setup || '—'}</td>
                      <td className="px-4 py-3 text-right font-mono text-xs">{r.score ?? '—'}</td>
                      <td className="px-4 py-3 text-right font-mono text-xs">{r.rsi ? parseFloat(r.rsi).toFixed(1) : '—'}</td>
                      <td className="px-4 py-3 text-right font-mono text-xs">{r.adx ? parseFloat(r.adx).toFixed(1) : '—'}</td>
                      <td className="px-4 py-3 font-mono text-xs text-muted-foreground">{r.srStatus || '—'}</td>
                      <td className="px-4 py-3 text-right font-mono text-xs">{r.winCount != null ? `${r.winCount}/${(r.winCount ?? 0) + (r.lossCount ?? 0)}` : '—'}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>

    </div>
  );
}
