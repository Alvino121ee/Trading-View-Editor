import React, { useEffect, useState } from 'react';
import { useGetMonitorSummary, useListMonitorSignals, Signal } from '@workspace/api-client-react';
import { format, parseISO } from 'date-fns';
import { 
  Activity, Clock, Hash, TrendingDown, TrendingUp, 
  CheckCircle2, XCircle, AlertCircle, Send, PlayCircle, Clock4,
  RefreshCw
} from 'lucide-react';

// --- UTILS ---

const formatTime = (isoString?: string | null) => {
  if (!isoString) return '--:--:--';
  try {
    return format(parseISO(isoString), 'HH:mm:ss');
  } catch (e) {
    return '--:--:--';
  }
};

const formatDate = (isoString?: string | null) => {
  if (!isoString) return '--/--';
  try {
    return format(parseISO(isoString), 'MM/dd HH:mm:ss');
  } catch (e) {
    return '--/--';
  }
};

const formatPrice = (price?: string | null) => {
  if (!price) return '---.--';
  return parseFloat(price).toFixed(2);
};

// --- COMPONENTS ---

const StatusBadge = ({ status }: { status: string }) => {
  const styles: Record<string, string> = {
    pending: 'text-amber-400 bg-amber-400/10 border-amber-400/20',
    sent: 'text-blue-400 bg-blue-400/10 border-blue-400/20',
    executed: 'text-emerald-400 bg-emerald-400/10 border-emerald-400/20',
    cancelled: 'text-gray-400 bg-gray-400/10 border-gray-400/20',
    expired: 'text-orange-500 bg-orange-500/10 border-orange-500/20',
  };

  const icons: Record<string, React.ReactNode> = {
    pending: <Clock4 className="w-3 h-3 mr-1.5" />,
    sent: <Send className="w-3 h-3 mr-1.5" />,
    executed: <CheckCircle2 className="w-3 h-3 mr-1.5" />,
    cancelled: <XCircle className="w-3 h-3 mr-1.5" />,
    expired: <AlertCircle className="w-3 h-3 mr-1.5" />,
  };

  const s = status.toLowerCase();
  const style = styles[s] || 'text-gray-400 bg-gray-400/10 border-gray-400/20';
  const icon = icons[s] || null;

  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium border uppercase tracking-wider ${style}`}>
      {icon}
      {status}
    </span>
  );
};

const ActionBadge = ({ action }: { action: string }) => {
  const isBuy = action.includes('BUY');
  const isSell = action.includes('SELL');
  const isDelete = action.includes('DELETE');

  let style = 'text-gray-400 bg-gray-400/10 border-gray-400/20';
  let icon = null;

  if (isBuy) {
    style = 'text-emerald-400 bg-emerald-400/10 border-emerald-400/30 font-bold';
    icon = <TrendingUp className="w-3.5 h-3.5 mr-1" />;
  } else if (isSell) {
    style = 'text-rose-500 bg-rose-500/10 border-rose-500/30 font-bold';
    icon = <TrendingDown className="w-3.5 h-3.5 mr-1" />;
  } else if (isDelete) {
    style = 'text-orange-400 bg-orange-400/10 border-orange-400/30';
    icon = <XCircle className="w-3.5 h-3.5 mr-1" />;
  }

  const label = action.replace('_LIMIT', '').replace('PENDING', '');

  return (
    <span className={`inline-flex items-center px-2 py-1 rounded text-xs border uppercase tracking-wider ${style}`}>
      {icon}
      {label}
    </span>
  );
};

const StatCard = ({ title, value, labelClass = "text-muted-foreground" }: { title: string, value: number, labelClass?: string }) => (
  <div className="bg-card border rounded p-4 flex flex-col justify-between h-24">
    <span className={`text-xs uppercase tracking-widest font-medium ${labelClass}`}>{title}</span>
    <span className="text-3xl font-mono font-semibold text-foreground tracking-tight">{value}</span>
  </div>
);

// --- MAIN PAGE ---

export default function Dashboard() {
  const [now, setNow] = useState(new Date());

  // Live clock
  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  const { data: summary, isFetching: summaryFetching, isError: summaryError } = useGetMonitorSummary({
    query: { refetchInterval: 5000 }
  });

  const { data: listRes, isFetching: listFetching } = useListMonitorSignals(
    { limit: 50 },
    { query: { refetchInterval: 5000 } }
  );

  const stats = summary?.stats || { total: 0, executed: 0, pending: 0, sent: 0, cancelled: 0, expired: 0 };
  const active = summary?.active;
  const lastTrade = summary?.lastTrade;
  const signals = listRes?.signals || [];
  
  const isFetching = summaryFetching || listFetching;
  const isConnected = !summaryError;

  return (
    <div className="min-h-screen p-4 md:p-6 lg:p-8 max-w-[1600px] mx-auto space-y-6 flex flex-col">
      
      {/* HEADER */}
      <header className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-border/50 pb-4">
        <div className="flex items-center gap-4">
          <div className="w-10 h-10 bg-primary/20 text-primary rounded border border-primary/30 flex items-center justify-center">
            <Activity className="w-5 h-5" />
          </div>
          <div>
            <h1 className="text-xl font-bold tracking-tight text-foreground flex items-center gap-2">
              ZS SIGNAL MONITOR
              <span className="px-2 py-0.5 rounded text-xs bg-secondary text-secondary-foreground font-mono tracking-widest border border-border">XAUUSD</span>
            </h1>
            <p className="text-sm text-muted-foreground flex items-center gap-2 mt-1">
              <span className="relative flex h-2.5 w-2.5">
                {isConnected && (
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                )}
                <span className={`relative inline-flex rounded-full h-2.5 w-2.5 ${isConnected ? 'bg-emerald-500' : 'bg-destructive'}`}></span>
              </span>
              {isConnected ? 'Bridge Connected' : 'Connection Lost'}
              {isFetching && <RefreshCw className="w-3 h-3 ml-2 animate-spin text-muted-foreground" />}
            </p>
          </div>
        </div>
        
        <div className="flex items-center gap-6 bg-card px-6 py-3 rounded border font-mono text-lg tracking-wider text-primary shadow-inner">
          <Clock className="w-5 h-5 text-primary/70" />
          {format(now, 'HH:mm:ss')} <span className="text-muted-foreground text-sm ml-1">UTC</span>
        </div>
      </header>

      {/* STATS ROW */}
      <div className="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-5 gap-4">
        <StatCard title="Total Signals" value={stats.total} />
        <StatCard title="Executed" value={stats.executed} labelClass="text-emerald-400" />
        <StatCard title="Pending / Sent" value={stats.pending + stats.sent} labelClass="text-amber-400" />
        <StatCard title="Cancelled" value={stats.cancelled} />
        <StatCard title="Expired" value={stats.expired} labelClass="text-orange-500" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* ACTIVE SIGNAL PANEL */}
        <div className="lg:col-span-2 flex flex-col gap-4">
          <h2 className="text-sm uppercase tracking-widest text-muted-foreground font-semibold flex items-center gap-2">
            <PlayCircle className="w-4 h-4" /> Active Signal
          </h2>
          
          {active ? (
            <div className="bg-card border rounded p-6 shadow-sm relative overflow-hidden flex flex-col gap-6">
              {/* Top row */}
              <div className="flex justify-between items-start">
                <div className="flex flex-col gap-2">
                  <div className="flex items-center gap-3">
                    <ActionBadge action={active.action} />
                    <StatusBadge status={active.status} />
                    {active.mt5Ticket && (
                      <span className="text-xs font-mono text-muted-foreground flex items-center gap-1 bg-secondary px-2 py-1 rounded">
                        <Hash className="w-3 h-3" /> {active.mt5Ticket}
                      </span>
                    )}
                  </div>
                  <div className="text-sm font-mono text-muted-foreground mt-2">
                    {formatDate(active.createdAt)}
                  </div>
                </div>
                
                <div className="text-right flex flex-col items-end">
                  <div className="text-xs text-muted-foreground uppercase tracking-widest mb-1">Lot Size</div>
                  <div className="text-2xl font-mono text-primary font-bold bg-primary/10 px-3 py-1 rounded border border-primary/20">
                    {active.lot || '0.01'}
                  </div>
                </div>
              </div>
              
              {/* Setup Info */}
              {active.setup && (
                <div className="bg-secondary/50 border border-border/50 rounded p-3 text-sm">
                  <span className="text-muted-foreground mr-2 uppercase text-xs tracking-wider">Setup:</span> 
                  <span className="font-mono text-foreground font-medium">{active.setup}</span>
                  {active.comment && <span className="text-muted-foreground ml-2">({active.comment})</span>}
                </div>
              )}

              {/* Price Grid */}
              <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 mt-2">
                <div className="bg-secondary/30 border border-border/30 rounded p-3 flex flex-col items-center justify-center">
                  <span className="text-[10px] uppercase tracking-widest text-muted-foreground mb-1">Entry</span>
                  <span className="font-mono font-medium text-lg text-foreground">{formatPrice(active.entry)}</span>
                </div>
                <div className="bg-rose-500/5 border border-rose-500/20 rounded p-3 flex flex-col items-center justify-center">
                  <span className="text-[10px] uppercase tracking-widest text-rose-500/70 mb-1">Stop Loss</span>
                  <span className="font-mono font-medium text-lg text-rose-400">{formatPrice(active.sl)}</span>
                </div>
                <div className="bg-emerald-500/5 border border-emerald-500/20 rounded p-3 flex flex-col items-center justify-center">
                  <span className="text-[10px] uppercase tracking-widest text-emerald-500/70 mb-1">TP 1</span>
                  <span className="font-mono font-medium text-lg text-emerald-400">{formatPrice(active.tp1)}</span>
                </div>
                <div className="bg-emerald-500/5 border border-emerald-500/20 rounded p-3 flex flex-col items-center justify-center">
                  <span className="text-[10px] uppercase tracking-widest text-emerald-500/70 mb-1">TP 2</span>
                  <span className="font-mono font-medium text-lg text-emerald-400">{formatPrice(active.tp2)}</span>
                </div>
                <div className="bg-emerald-500/5 border border-emerald-500/20 rounded p-3 flex flex-col items-center justify-center">
                  <span className="text-[10px] uppercase tracking-widest text-emerald-500/70 mb-1">TP 3</span>
                  <span className="font-mono font-medium text-lg text-emerald-400">{formatPrice(active.tp3)}</span>
                </div>
              </div>

              {/* Trailing Rules */}
              <div className="mt-2 pt-5 border-t border-border/50">
                <div className="text-[10px] uppercase tracking-widest text-muted-foreground mb-3 font-semibold">Trailing Stop Protocol</div>
                <div className="grid grid-cols-3 gap-2">
                  <div className="text-center text-xs font-mono py-2 bg-secondary rounded border border-border text-foreground/80">TP1 → BE</div>
                  <div className="text-center text-xs font-mono py-2 bg-secondary rounded border border-border text-foreground/80">TP2 → TP1</div>
                  <div className="text-center text-xs font-mono py-2 bg-secondary rounded border border-border text-foreground/80">TP3 → CLOSE</div>
                </div>
              </div>
            </div>
          ) : (
            <div className="bg-card/50 border border-dashed rounded p-12 flex flex-col items-center justify-center text-center text-muted-foreground h-[360px]">
              <div className="w-16 h-16 rounded-full bg-secondary flex items-center justify-center mb-4">
                <Clock className="w-8 h-8 opacity-20" />
              </div>
              <h3 className="text-lg font-medium text-foreground mb-1">System Idle</h3>
              <p className="text-sm max-w-sm">No active signals currently pending or executing. Monitoring incoming webhooks from TradingView.</p>
            </div>
          )}
        </div>

        {/* LAST TRADE & QUICK STATS */}
        <div className="flex flex-col gap-4">
          <h2 className="text-sm uppercase tracking-widest text-muted-foreground font-semibold flex items-center gap-2">
            <Clock4 className="w-4 h-4" /> Last Executed Trade
          </h2>
          
          {lastTrade ? (
            <div className="bg-card border rounded p-5 flex flex-col gap-4">
              <div className="flex justify-between items-center pb-3 border-b border-border/50">
                <ActionBadge action={lastTrade.action} />
                <span className="text-sm font-mono text-muted-foreground">{formatDate(lastTrade.executedAt || lastTrade.updatedAt)}</span>
              </div>
              
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-xs text-muted-foreground uppercase tracking-wider">Ticket</span>
                  <span className="font-mono text-sm bg-secondary px-2 py-0.5 rounded text-foreground">#{lastTrade.mt5Ticket || 'N/A'}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs text-muted-foreground uppercase tracking-wider">Entry</span>
                  <span className="font-mono text-sm">{formatPrice(lastTrade.entry)}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs text-muted-foreground uppercase tracking-wider">Stop Loss</span>
                  <span className="font-mono text-sm text-rose-400">{formatPrice(lastTrade.sl)}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs text-muted-foreground uppercase tracking-wider">Take Profits</span>
                  <div className="font-mono text-xs text-emerald-400 flex gap-2">
                    <span>{formatPrice(lastTrade.tp1)}</span>
                    <span className="opacity-50">/</span>
                    <span>{formatPrice(lastTrade.tp2)}</span>
                    <span className="opacity-50">/</span>
                    <span>{formatPrice(lastTrade.tp3)}</span>
                  </div>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs text-muted-foreground uppercase tracking-wider">Setup</span>
                  <span className="font-mono text-xs">{lastTrade.setup || '--'}</span>
                </div>
              </div>
            </div>
          ) : (
            <div className="bg-card border rounded p-6 flex items-center justify-center text-muted-foreground h-full min-h-[200px]">
              <span className="text-sm">No recent trades found</span>
            </div>
          )}
          
          <div className="mt-auto pt-4 border-t border-border/50">
            <div className="bg-secondary/50 p-4 rounded text-xs flex flex-col gap-2">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Polling Interval</span>
                <span className="font-mono text-primary">5000ms</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Bridge Target</span>
                <span className="font-mono">MetaTrader 5</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Instrument</span>
                <span className="font-mono text-primary font-bold tracking-widest">XAUUSD</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* HISTORY TABLE */}
      <div className="flex flex-col gap-4 mt-4 flex-1">
        <h2 className="text-sm uppercase tracking-widest text-muted-foreground font-semibold flex items-center gap-2">
          <Activity className="w-4 h-4" /> Signal Audit Log
        </h2>
        
        <div className="bg-card border rounded overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm text-left whitespace-nowrap">
              <thead className="text-xs text-muted-foreground uppercase tracking-widest bg-secondary/50 border-b border-border">
                <tr>
                  <th className="px-4 py-3 font-medium">Time</th>
                  <th className="px-4 py-3 font-medium">Action</th>
                  <th className="px-4 py-3 font-medium">Entry</th>
                  <th className="px-4 py-3 font-medium">SL</th>
                  <th className="px-4 py-3 font-medium">TP1</th>
                  <th className="px-4 py-3 font-medium">TP2</th>
                  <th className="px-4 py-3 font-medium">TP3</th>
                  <th className="px-4 py-3 font-medium">Lot</th>
                  <th className="px-4 py-3 font-medium">Setup</th>
                  <th className="px-4 py-3 font-medium">Status</th>
                  <th className="px-4 py-3 font-medium text-right">Ticket</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/50">
                {signals.length === 0 ? (
                  <tr>
                    <td colSpan={11} className="px-4 py-8 text-center text-muted-foreground">
                      No signals recorded yet.
                    </td>
                  </tr>
                ) : (
                  signals.map((sig) => (
                    <tr key={sig.id} className="hover:bg-secondary/30 transition-colors">
                      <td className="px-4 py-3 font-mono text-muted-foreground text-xs">{formatDate(sig.createdAt)}</td>
                      <td className="px-4 py-3"><ActionBadge action={sig.action} /></td>
                      <td className="px-4 py-3 font-mono">{formatPrice(sig.entry)}</td>
                      <td className="px-4 py-3 font-mono text-rose-400/80">{formatPrice(sig.sl)}</td>
                      <td className="px-4 py-3 font-mono text-emerald-400/80">{formatPrice(sig.tp1)}</td>
                      <td className="px-4 py-3 font-mono text-emerald-400/80">{formatPrice(sig.tp2)}</td>
                      <td className="px-4 py-3 font-mono text-emerald-400/80">{formatPrice(sig.tp3)}</td>
                      <td className="px-4 py-3 font-mono text-primary/80">{sig.lot || '0.01'}</td>
                      <td className="px-4 py-3 font-mono text-xs text-muted-foreground max-w-[120px] truncate" title={sig.setup || ''}>{sig.setup || '--'}</td>
                      <td className="px-4 py-3"><StatusBadge status={sig.status} /></td>
                      <td className="px-4 py-3 font-mono text-right text-xs text-muted-foreground">{sig.mt5Ticket ? `#${sig.mt5Ticket}` : '--'}</td>
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
