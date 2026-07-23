import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from '@/components/ui/toaster';
import { TooltipProvider } from '@/components/ui/tooltip';
import NotFound from '@/pages/not-found';
import { Route, Switch, Router as WouterRouter, Link, useRoute } from 'wouter';
import Dashboard from '@/pages/Dashboard';
import Analytics from '@/pages/Analytics';
import { Activity, BarChart2 } from 'lucide-react';

const queryClient = new QueryClient();

function NavBar() {
  const [onDash] = useRoute('/');
  const [onAnalytics] = useRoute('/analytics');

  return (
    <nav className="border-b border-border/60 bg-background/95 backdrop-blur sticky top-0 z-50">
      <div className="max-w-[1600px] mx-auto px-4 md:px-6 lg:px-8 flex items-center gap-1 h-11">
        <Link href="/"
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded text-xs font-medium uppercase tracking-widest transition-colors ${
            onDash
              ? 'bg-primary/15 text-primary'
              : 'text-muted-foreground hover:text-foreground hover:bg-secondary'
          }`}
        >
          <Activity className="w-3.5 h-3.5" /> Monitor
        </Link>
        <Link href="/analytics"
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded text-xs font-medium uppercase tracking-widest transition-colors ${
            onAnalytics
              ? 'bg-primary/15 text-primary'
              : 'text-muted-foreground hover:text-foreground hover:bg-secondary'
          }`}
        >
          <BarChart2 className="w-3.5 h-3.5" /> Analytics
        </Link>
      </div>
    </nav>
  );
}

function Router() {
  return (
    <>
      <NavBar />
      <Switch>
        <Route path="/" component={Dashboard} />
        <Route path="/analytics" component={Analytics} />
        <Route component={NotFound} />
      </Switch>
    </>
  );
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <TooltipProvider>
        <WouterRouter base={import.meta.env.BASE_URL.replace(/\/$/, '')}>
          <Router />
        </WouterRouter>
        <Toaster />
      </TooltipProvider>
    </QueryClientProvider>
  );
}

export default App;
