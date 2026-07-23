//+------------------------------------------------------------------+
//|  ZS_V10_Standalone_EA.mq5                                       |
//|  ZS XAUUSD V10 SR Precision Pro — Standalone MT5 EA            |
//|  Replicates Pine Script indicator ZS XAUUSD V10 logic 1:1      |
//|  No TradingView, no server, no webhook required                 |
//|  v3.0 — Stochastic Filter + Ultra Modern Panel                 |
//+------------------------------------------------------------------+
#property copyright "ZS Trading"
#property version   "3.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//==================== SIGNAL MODE ====================//
input group "=== SIGNAL MODE ==="
input string InpModeSignal        = "AUTO BUY SELL"; // AUTO BUY SELL / BUY ONLY / SELL ONLY
input string InpEntryMode         = "BALANCED";       // SAFE / BALANCED / AGGRESSIVE
input int    InpMinQualitySafe    = 88;
input int    InpMinQualityBal     = 82;
input int    InpMinQualityAgg     = 72;
input int    InpScoreGap          = 6;
input int    InpCooldownBars      = 2;

input group "=== SESSION FILTER WIB ==="
input bool   InpUseWIBFilter      = true;

input group "=== ENTRY MODE ==="
input bool   InpReverseMode        = false; // Reverse Mode: BUY→SELL, SELL→BUY

input group "=== TP / SL (Dollar Fixed) ==="
input double InpSLDollars         = 5.0;
input double InpTP1Dollars        = 5.0;
input double InpTP2Dollars        = 10.0;
input double InpTP3Dollars        = 15.0;
input int    InpATRLen            = 14;
input int    InpMaxHoldMinutes    = 180;

input group "=== EMA TREND ==="
input int    InpEmaFastLen        = 20;
input int    InpEmaMidLen         = 50;
input int    InpEmaSlowLen        = 200;
input int    InpMtfEmaFastLen     = 50;
input int    InpMtfEmaSlowLen     = 200;
input int    InpEma200SlopeBars   = 5;

input group "=== MOMENTUM ==="
input int    InpRsiLen            = 14;
input int    InpAdxLen            = 14;
input int    InpBBLen             = 50;
input double InpBBDev             = 2.4;
input double InpMinBodyRatio      = 0.30;
input double InpCloseEdge         = 0.58;
input double InpMaxCandleATR      = 2.6;
input double InpSideMaxADX        = 22.0;
input double InpMinATRPrice       = 0.25;
input double InpMaxATRPrice       = 7.00;

input group "=== HIGH VOLUME SR ==="
input int    InpSRLookback        = 20;
input double InpSRBoxWidth        = 1.0;
input double InpSRBufferATR       = 0.30;
input int    InpSRBoostPts        = 8;
input int    InpSRBreakBoostPts   = 12;
input int    InpSRDangerPenalty   = 18;
input bool   InpSRBoostBlock      = true;
input int    InpSRRetestBars      = 18;
input int    InpRetestBoostPts    = 16;

input group "=== PRECISION SR RULES ==="
input bool   InpBlockBuyAtRedBox        = true;
input bool   InpBlockSellAtGreenBox     = true;
input bool   InpRequireBreakForReversal = true;

input group "=== SR STRENGTH SETUP ==="
input bool   InpUseSRStrength        = true;
input bool   InpAllowSRMedium        = true;
input int    InpSRMediumMinScore     = 58;
input int    InpSRStrongMinScore     = 76;
input int    InpSRMediumGap          = 2;
input int    InpSRStrongGap          = 6;
input int    InpSRStrongTP1Pts       = 250;
input int    InpSRStrongTP2Pts       = 700;
input int    InpSRStrongTP3Pts       = 1100;
input string InpSRStrongSLMode       = "ADAPTIVE";
input double InpSRStrongATRSLMult    = 1.30;
input int    InpSRStrongMinSL        = 550;
input int    InpSRStrongMaxSL        = 950;
input int    InpSRStrongFixedSL      = 700;
input int    InpSRMediumTP1Pts       = 150;
input int    InpSRMediumTP2Pts       = 400;
input int    InpSRMediumTP3Pts       = 650;
input string InpSRMediumSLMode       = "ADAPTIVE";
input double InpSRMediumATRSLMult    = 1.05;
input int    InpSRMediumMinSL        = 420;
input int    InpSRMediumMaxSL        = 760;
input int    InpSRMediumFixedSL      = 560;

input group "=== PEAK / DEEP FILTER ==="
input bool   InpBlockBuyAtPeak    = true;
input bool   InpBlockSellAtDeep   = true;
input int    InpOverboughtRSI     = 70;
input int    InpOversoldRSI       = 30;

input group "=== ORDER ==="
input string InpSymbol            = "XAUUSDc";
input int    InpMagicNumber       = 909506;
input double InpLot               = 0.01;
input double InpMaxLot            = 1.0;
input int    InpSlippage          = 20;
input bool   InpTrailingEnabled   = true;
input bool   InpDeleteOnNew       = true;
input bool   InpEnabled           = true;

input group "=== LAYER ENTRY ==="
input bool   InpLayerEnabled      = true;
input double InpLayerDollars      = 1.0;

input group "=== AUTO REVERSAL ==="
input bool   InpAutoReversal      = true;   // Auto close & flip saat signal berubah arah
input int    InpReversalMinScore  = 75;     // Min score sebelum reversal dieksekusi

input group "=== REPORTING ==="
input bool   InpEnableReporting   = true;    // Kirim data ke website untuk analisis
input string InpServerURL         = "";       // URL server (https://yourapp.replit.app)
input string InpReportSecret      = "ZS909506"; // Harus sama dengan WEBHOOK_SECRET server
input int    InpSnapshotSecs      = 300;      // Kirim snapshot setiap N detik (default 5 menit)
input int    InpPollInterval      = 5;        // Interval timer EA dalam detik (default 5)

input group "=== STOCHASTIC FILTER ==="
input bool   InpUseStochFilter    = true;    // Aktifkan filter Stochastic sebelum entry
input int    InpStochKPeriod      = 5;       // Stochastic %K period
input int    InpStochDPeriod      = 3;       // Stochastic %D period
input int    InpStochSlowing      = 3;       // Stochastic slowing
input int    InpStochSellLevel    = 80;      // SELL: entry saat Stoch >= level ini
input int    InpStochBuyLevel     = 25;      // BUY: entry saat Stoch <= level ini
input int    InpStochMaxWaitBars  = 15;      // Batas tunggu maksimum (bar M1), 0=unlimited

input group "=== PANEL ==="
input bool   InpShowPanel         = true;
input int    InpPanelX            = 20;
input int    InpPanelY            = 30;
input int    InpPanelFontSize     = 9;

//==================== INDICATOR HANDLES ====================//
int hEmaFast, hEmaMid, hEmaSlow;
int hEmaM5Fast, hEmaM5Slow;
int hEmaM15Fast, hEmaM15Slow;
int hRsi, hAdx, hAtr, hBB;
int hStoch;

//==================== TRADE OBJECTS ====================//
CTrade        trade;
CPositionInfo posInfo;
COrderInfo    orderInfo;

//==================== ACTIVE TRADE STATE ====================//
double gEntry=0, gSL=0, gTP1=0, gTP2=0, gTP3=0;
int    gDir=0;
bool   gHitTP1=false, gHitTP2=false;
datetime gOpenTime=0;

//==================== BAR TRACKING ====================//
datetime gLastBarTime=0;
int    gLastExitBar=0;

//==================== SR STATE ====================//
double gSupLevel=0,  gSupLevel1=0;
double gResLevel=0,  gResLevel1=0;
bool   gResIsSup=false, gSupIsRes=false;
double gBreakResHigh=0;  int gBreakResBar=0;
double gBreakSupLow=0;   int gBreakSupBar=0;

//==================== PANEL STATE ====================//
string gPanelStatus    = "INIT";
string gPanelSetup     = "-";
int    gBuyScore       = 0;
int    gSellScore      = 0;
int    gBullCount      = 0;
int    gBearCount      = 0;
bool   gM1Bull=false, gM5Bull=false, gM15Bull=false;
bool   gM1Bear=false, gM5Bear=false, gM15Bear=false;
double gRsiVal         = 0;
double gAdxVal         = 0;
double gAtrVal         = 0;
double gStochK         = 0;    // Stochastic %K value for panel
double gStochD         = 0;    // Stochastic %D value for panel
bool   gSidewaysFlag   = false;
string gSRStatus       = "-";
bool   gSRBlockBuy     = false;
bool   gSRBlockSell    = false;
bool   gPrecBlockBuy   = false;
bool   gPrecBlockSell  = false;
bool   gPeakBlock      = false;
bool   gDeepBlock      = false;
bool   gSessionOK      = false;
int    gMinQuality     = 82;
int    gWinCount       = 0;
int    gLossCount      = 0;
int    gTotalSignals   = 0;   // total trade dibuka sejak EA aktif
double gTotalClosedPL  = 0.0; // akumulasi P&L semua trade yang sudah tutup
string gLastReversalInfo = "";   // "SELL→BUY @ 3185.20"
bool   gReversalAlert  = false;  // flash saat reversal baru terjadi
int    gReversalFlash  = 0;      // countdown flash

//==================== PENDING SIGNAL (STOCH FILTER) ====================//
int    gPendingDir      = 0;     // 1=BUY, -1=SELL, 0=none
double gPendingSLDist   = 0;     // jarak SL dalam harga
double gPendingTP1Dist  = 0;
double gPendingTP2Dist  = 0;
double gPendingTP3Dist  = 0;
string gPendingSetup    = "";
int    gPendingScore    = 0;
int    gPendingBar      = 0;     // bar index saat sinyal muncul

// Reporting
int    gSnapshotCounter = 0;     // counts OnTimer() calls for snapshot pacing

//==================== PANEL OBJECT PREFIX ====================//
#define PANEL_PREFIX "ZSEA_"

//+------------------------------------------------------------------+
// REPORTING: Hitung total P&L posisi aktif saat ini
//+------------------------------------------------------------------+
double CalcCurrentPL()
{
   double pl = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()==InpMagicNumber && posInfo.Symbol()==InpSymbol)
         pl += posInfo.Profit() + posInfo.Swap();
   }
   return pl;
}

//+------------------------------------------------------------------+
// REPORTING: Kirim event ke server untuk analisis & penyimpanan
// Pastikan URL server sudah ditambahkan ke Tools→Options→Expert Advisors→Allowed URLs
//+------------------------------------------------------------------+
void SendReport(string eventType, string closeReason, double closePrice, double plDollars)
{
   if(!InpEnableReporting || StringLen(InpServerURL) == 0) return;

   int    holdMin  = (gOpenTime > 0) ? (int)((TimeCurrent()-gOpenTime)/60) : 0;
   string dirStr   = (gDir==1) ? "BUY" : (gDir==-1) ? "SELL" : "";
   string tpLvl    = (closeReason=="TP1") ? "TP1" : (closeReason=="TP2") ? "TP2" : (closeReason=="TP3") ? "TP3" : "";
   string sesStr   = gSessionOK ? "true" : "false";

   string json = StringFormat(
      "{\"secret\":\"%s\",\"event_type\":\"%s\",\"symbol\":\"%s\","
      "\"direction\":\"%s\",\"setup\":\"%s\",\"score\":%d,"
      "\"entry\":%.5f,\"sl\":%.5f,\"tp1\":%.5f,\"tp2\":%.5f,\"tp3\":%.5f,"
      "\"close_price\":%.5f,\"pl_dollars\":%.2f,\"close_reason\":\"%s\","
      "\"tp_level\":\"%s\","
      "\"rsi\":%.2f,\"adx\":%.2f,\"atr\":%.5f,"
      "\"buy_score\":%d,\"sell_score\":%d,"
      "\"bull_count\":%d,\"bear_count\":%d,"
      "\"sr_status\":\"%s\","
      "\"session_ok\":%s,"
      "\"hold_minutes\":%d,"
      "\"total_signals\":%d,\"win_count\":%d,\"loss_count\":%d}",
      InpReportSecret, eventType, InpSymbol,
      dirStr, gPanelSetup, (gDir==1) ? gBuyScore : gSellScore,
      gEntry, gSL, gTP1, gTP2, gTP3,
      closePrice, plDollars, closeReason,
      tpLvl,
      gRsiVal, gAdxVal, gAtrVal,
      gBuyScore, gSellScore,
      gBullCount, gBearCount,
      gSRStatus,
      sesStr,
      holdMin,
      gTotalSignals, gWinCount, gLossCount
   );

   string url = InpServerURL + "/api/ea/report";
   char   postData[];
   char   result[];
   string reqHeaders = "Content-Type: application/json\r\n";
   string resHeaders;
   StringToCharArray(json, postData, 0, StringLen(json), CP_UTF8);

   int code = WebRequest("POST", url, reqHeaders, 5000, postData, result, resHeaders);
   if(code < 0)
      Print("SendReport GAGAL: event=", eventType, " err=", GetLastError(),
            " (tambahkan URL ke Tools→Options→Expert Advisors→Allowed URLs)");
   else if(code != 200 && code != 201)
      Print("SendReport HTTP ", code, ": event=", eventType);
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(!InpEnabled) { Print("EA dinonaktifkan."); return INIT_SUCCEEDED; }

   hEmaFast   = iMA(InpSymbol, PERIOD_M1,  InpEmaFastLen,    0, MODE_EMA, PRICE_CLOSE);
   hEmaMid    = iMA(InpSymbol, PERIOD_M1,  InpEmaMidLen,     0, MODE_EMA, PRICE_CLOSE);
   hEmaSlow   = iMA(InpSymbol, PERIOD_M1,  InpEmaSlowLen,    0, MODE_EMA, PRICE_CLOSE);
   hEmaM5Fast = iMA(InpSymbol, PERIOD_M5,  InpMtfEmaFastLen, 0, MODE_EMA, PRICE_CLOSE);
   hEmaM5Slow = iMA(InpSymbol, PERIOD_M5,  InpMtfEmaSlowLen, 0, MODE_EMA, PRICE_CLOSE);
   hEmaM15Fast= iMA(InpSymbol, PERIOD_M15, InpMtfEmaFastLen, 0, MODE_EMA, PRICE_CLOSE);
   hEmaM15Slow= iMA(InpSymbol, PERIOD_M15, InpMtfEmaSlowLen, 0, MODE_EMA, PRICE_CLOSE);
   hRsi       = iRSI(InpSymbol, PERIOD_M1, InpRsiLen, PRICE_CLOSE);
   hAdx       = iADX(InpSymbol, PERIOD_M1, InpAdxLen);
   hAtr       = iATR(InpSymbol, PERIOD_M1, InpATRLen);
   hBB        = iBands(InpSymbol, PERIOD_M1, InpBBLen, 0, InpBBDev, PRICE_CLOSE);
   hStoch     = iStochastic(InpSymbol, PERIOD_M1, InpStochKPeriod, InpStochDPeriod, InpStochSlowing, MODE_SMA, STO_LOWHIGH);

   if(hEmaFast==INVALID_HANDLE || hEmaMid==INVALID_HANDLE || hEmaSlow==INVALID_HANDLE ||
      hEmaM5Fast==INVALID_HANDLE || hEmaM15Fast==INVALID_HANDLE ||
      hRsi==INVALID_HANDLE || hAdx==INVALID_HANDLE || hAtr==INVALID_HANDLE ||
      hBB==INVALID_HANDLE || hStoch==INVALID_HANDLE)
   {
      Print("ERROR: Gagal membuat indicator handles. Symbol benar? ", InpSymbol);
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   PanelDelete();
   PanelCreate();

   // Aktifkan timer untuk snapshot periodik (hanya jika reporting aktif)
   if(InpEnableReporting && StringLen(InpServerURL) > 0)
      EventSetTimer(InpPollInterval > 0 ? InpPollInterval : 5);

   Print("ZS V10 Standalone EA v2.0 aktif | Symbol: ", InpSymbol, " | AutoReversal: ", InpAutoReversal?"ON":"OFF",
         " | Reporting: ", (InpEnableReporting && StringLen(InpServerURL)>0) ? InpServerURL : "OFF");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   PanelDelete();
   IndicatorRelease(hEmaFast);  IndicatorRelease(hEmaMid);   IndicatorRelease(hEmaSlow);
   IndicatorRelease(hEmaM5Fast);IndicatorRelease(hEmaM5Slow);
   IndicatorRelease(hEmaM15Fast);IndicatorRelease(hEmaM15Slow);
   IndicatorRelease(hRsi); IndicatorRelease(hAdx);
   IndicatorRelease(hAtr); IndicatorRelease(hBB);
   IndicatorRelease(hStoch);
}

//+------------------------------------------------------------------+
// TIMER: kirim snapshot periodik ke server
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!InpEnableReporting || StringLen(InpServerURL) == 0) return;
   gSnapshotCounter++;
   int snapEvery = MathMax(1, InpSnapshotSecs / (InpPollInterval > 0 ? InpPollInterval : 5));
   if(gSnapshotCounter >= snapEvery)
   {
      gSnapshotCounter = 0;
      SendReport("SNAPSHOT", "", 0, CalcCurrentPL());
   }
}

//+------------------------------------------------------------------+
// Helper: baca 1 nilai dari indicator buffer
//+------------------------------------------------------------------+
double Buf(int handle, int bufIdx, int shift)
{
   double arr[];
   if(CopyBuffer(handle, bufIdx, shift, 1, arr) <= 0) return 0;
   return arr[0];
}

//+------------------------------------------------------------------+
// Session filter: WIB 04:00-15:00 = UTC 21:00-08:00
//+------------------------------------------------------------------+
bool InWIBSession()
{
   if(!InpUseWIBFilter) return true;
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;
   return (h >= 21 || h < 8);
}

//+------------------------------------------------------------------+
// Pivot High / Low detection
//+------------------------------------------------------------------+
double CalcPivotHigh(int lookback, int shift)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int needed = shift + lookback + 1 + lookback;
   if(CopyRates(InpSymbol, PERIOD_M1, 0, needed, rates) < needed) return 0;
   int idx = shift;
   if(idx < lookback || idx + lookback >= ArraySize(rates)) return 0;
   double cHigh = rates[idx].high;
   for(int i = idx - lookback; i <= idx + lookback; i++)
   { if(i != idx && rates[i].high >= cHigh) return 0; }
   return cHigh;
}

double CalcPivotLow(int lookback, int shift)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int needed = shift + lookback + 1 + lookback;
   if(CopyRates(InpSymbol, PERIOD_M1, 0, needed, rates) < needed) return 0;
   int idx = shift;
   if(idx < lookback || idx + lookback >= ArraySize(rates)) return 0;
   double cLow = rates[idx].low;
   for(int i = idx - lookback; i <= idx + lookback; i++)
   { if(i != idx && rates[i].low <= cLow) return 0; }
   return cLow;
}

//+------------------------------------------------------------------+
// Update SR Levels
//+------------------------------------------------------------------+
void UpdateSRLevels(double atrVal)
{
   double widthSR = atrVal * InpSRBoxWidth;
   int lookback   = InpSRLookback;
   int scanRange  = lookback * 6;

   for(int shift = lookback+1; shift <= scanRange; shift++)
   {
      double pl = CalcPivotLow(lookback, shift);
      if(pl > 0) { gSupLevel = pl; gSupLevel1 = pl - widthSR; break; }
   }
   for(int shift = lookback+1; shift <= scanRange; shift++)
   {
      double ph = CalcPivotHigh(lookback, shift);
      if(ph > 0) { gResLevel = ph; gResLevel1 = ph + widthSR; break; }
   }
}

//+------------------------------------------------------------------+
// Trade helpers
//+------------------------------------------------------------------+
void CancelPendingOrders()
{
   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      if(!orderInfo.SelectByIndex(i)) continue;
      if(orderInfo.Magic()==InpMagicNumber && orderInfo.Symbol()==InpSymbol)
         trade.OrderDelete(orderInfo.Ticket());
   }
}

void CloseMyPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()==InpMagicNumber && posInfo.Symbol()==InpSymbol)
         trade.PositionClose(posInfo.Ticket());
   }
   CancelPendingOrders();
}

void PlaceLayers(int dir, double marketEntry, double sl, double tp3,
                 double lot, string baseCmt, double layerDist, int digits)
{
   if(!InpLayerEnabled || layerDist <= 0) return;

   string cmt;
   int i;

   if(dir == 1)
   {
      i = 1;
      while(true)
      {
         double bsPrice = NormalizeDouble(marketEntry + i * layerDist, digits);
         if(bsPrice >= tp3) break;
         cmt = StringFormat("%s BS%d", baseCmt, i);
         if(StringLen(cmt) > 63) cmt = StringSubstr(cmt, 0, 63);
         if(!trade.BuyStop(lot, bsPrice, InpSymbol, sl, tp3, ORDER_TIME_GTC, 0, cmt))
            Print("BuyStop  L",i," GAGAL: ", trade.ResultRetcodeDescription());
         else
            Print("BuyStop  L",i," @ ", DoubleToString(bsPrice, digits));
         i++;
      }
      i = 1;
      while(true)
      {
         double blPrice = NormalizeDouble(marketEntry - i * layerDist, digits);
         if(blPrice <= sl) break;
         cmt = StringFormat("%s BL%d", baseCmt, i);
         if(StringLen(cmt) > 63) cmt = StringSubstr(cmt, 0, 63);
         if(!trade.BuyLimit(lot, blPrice, InpSymbol, sl, tp3, ORDER_TIME_GTC, 0, cmt))
            Print("BuyLimit L",i," GAGAL: ", trade.ResultRetcodeDescription());
         else
            Print("BuyLimit L",i," @ ", DoubleToString(blPrice, digits));
         i++;
      }
   }
   else
   {
      i = 1;
      while(true)
      {
         double ssPrice = NormalizeDouble(marketEntry - i * layerDist, digits);
         if(ssPrice <= tp3) break;
         cmt = StringFormat("%s SS%d", baseCmt, i);
         if(StringLen(cmt) > 63) cmt = StringSubstr(cmt, 0, 63);
         if(!trade.SellStop(lot, ssPrice, InpSymbol, sl, tp3, ORDER_TIME_GTC, 0, cmt))
            Print("SellStop  L",i," GAGAL: ", trade.ResultRetcodeDescription());
         else
            Print("SellStop  L",i," @ ", DoubleToString(ssPrice, digits));
         i++;
      }
      i = 1;
      while(true)
      {
         double slLimitPrice = NormalizeDouble(marketEntry + i * layerDist, digits);
         if(slLimitPrice >= sl) break;
         cmt = StringFormat("%s SL%d", baseCmt, i);
         if(StringLen(cmt) > 63) cmt = StringSubstr(cmt, 0, 63);
         if(!trade.SellLimit(lot, slLimitPrice, InpSymbol, sl, tp3, ORDER_TIME_GTC, 0, cmt))
            Print("SellLimit L",i," GAGAL: ", trade.ResultRetcodeDescription());
         else
            Print("SellLimit L",i," @ ", DoubleToString(slLimitPrice, digits));
         i++;
      }
   }
}

void ModifySL(ulong ticket, double newSL)
{
   int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
   newSL = NormalizeDouble(newSL, digits);
   if(!posInfo.SelectByTicket(ticket)) return;
   if(trade.PositionModify(ticket, newSL, posInfo.TakeProfit()))
      Print("SL diubah ke ", newSL);
   else
      Print("Gagal modify SL: ", trade.ResultRetcodeDescription());
}

bool HasActivePosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()==InpMagicNumber && posInfo.Symbol()==InpSymbol) return true;
   }
   return false;
}

void ResetTrade()
{
   CancelPendingOrders();
   gDir=0; gHitTP1=false; gHitTP2=false;
   gEntry=0; gSL=0; gTP1=0; gTP2=0; gTP3=0;
   gLastExitBar = iBars(InpSymbol, PERIOD_M1) - 1;
   gPanelStatus = "WAIT";
   gPanelSetup  = "-";
   Print("Trade selesai. Menunggu sinyal berikutnya.");
}

void ResetPending()
{
   gPendingDir=0; gPendingSLDist=0;
   gPendingTP1Dist=0; gPendingTP2Dist=0; gPendingTP3Dist=0;
   gPendingSetup=""; gPendingScore=0; gPendingBar=0;
}

//+------------------------------------------------------------------+
// Ambil P&L trade terakhir yang sudah ditutup dari history akun
//+------------------------------------------------------------------+
double GetLastClosedPL()
{
   double pl = 0;
   datetime from = gOpenTime > 0 ? gOpenTime - 60 : TimeCurrent() - 86400;
   if(!HistorySelect(from, TimeCurrent())) return 0;
   for(int i = HistoryDealsTotal()-1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != InpSymbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT ||
         HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_INOUT)
      {
         pl += HistoryDealGetDouble(ticket, DEAL_PROFIT)
             + HistoryDealGetDouble(ticket, DEAL_SWAP)
             + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      }
   }
   return pl;
}

//+------------------------------------------------------------------+
// Update statistik saat trade ditutup
//+------------------------------------------------------------------+
void UpdateStatsOnClose(double pl)
{
   gTotalClosedPL += pl;
   if(pl >= 0) gWinCount++;
   else        gLossCount++;
   Print(StringFormat("Trade ditutup | P&L=%.2f | W:%d L:%d | Total PL=%.2f",
         pl, gWinCount, gLossCount, gTotalClosedPL));
}

//+------------------------------------------------------------------+
// Cek Stochastic lalu eksekusi pending signal (dipanggil setiap tick)
//+------------------------------------------------------------------+
void CheckStochEntry()
{
   if(gPendingDir == 0) return;
   if(HasActivePosition())  { ResetPending(); return; }

   // Batas tunggu
   if(InpStochMaxWaitBars > 0)
   {
      int curBars = iBars(InpSymbol, PERIOD_M1) - 1;
      if(curBars - gPendingBar >= InpStochMaxWaitBars)
      {
         Print(">>> STOCH TIMEOUT: sinyal expired setelah ", InpStochMaxWaitBars, " bar. Dir=", gPendingDir>0?"BUY":"SELL");
         ResetPending();
         gPanelStatus = "STOCH TIMEOUT";
         return;
      }
   }

   // Baca Stoch saat ini
   gStochK = Buf(hStoch, 0, 0);  // %K (main line, shift=0 = current bar)
   gStochD = Buf(hStoch, 1, 0);  // %D (signal line)
   if(gStochK <= 0) return;

   bool stochOK = false;
   if(gPendingDir ==  1) stochOK = (gStochK <= InpStochBuyLevel);   // BUY: Stoch <= 25
   if(gPendingDir == -1) stochOK = (gStochK >= InpStochSellLevel);  // SELL: Stoch >= 80

   if(!stochOK)
   {
      gPanelStatus = StringFormat("WAIT STOCH %s (%.1f)", gPendingDir>0?"BUY":"SELL", gStochK);
      return;
   }

   // Stoch terpenuhi → entry sekarang dengan harga saat ini
   int    digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
   double lot    = MathMin(InpLot, InpMaxLot);
   double layerPriceDist = gPendingSLDist > 0 ? gPendingSLDist * (InpLayerDollars / InpSLDollars) : 0;
   double entryPrice, sl, tp1, tp2, tp3;
   bool   ok = false;

   if(gPendingDir == 1)
   {
      entryPrice = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
      sl  = NormalizeDouble(entryPrice - gPendingSLDist,   digits);
      tp1 = NormalizeDouble(entryPrice + gPendingTP1Dist,  digits);
      tp2 = NormalizeDouble(entryPrice + gPendingTP2Dist,  digits);
      tp3 = NormalizeDouble(entryPrice + gPendingTP3Dist,  digits);
      if(InpDeleteOnNew) CloseMyPositions();
      string cmt = StringFormat("ZS V10 %s s%d STOCH", gPendingSetup, gPendingScore);
      if(StringLen(cmt)>63) cmt=StringSubstr(cmt,0,63);
      ok = trade.Buy(lot, InpSymbol, entryPrice, sl, tp3, cmt);
      if(ok) PlaceLayers(1, entryPrice, sl, tp3, lot, cmt, layerPriceDist, digits);
   }
   else
   {
      entryPrice = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
      sl  = NormalizeDouble(entryPrice + gPendingSLDist,   digits);
      tp1 = NormalizeDouble(entryPrice - gPendingTP1Dist,  digits);
      tp2 = NormalizeDouble(entryPrice - gPendingTP2Dist,  digits);
      tp3 = NormalizeDouble(entryPrice - gPendingTP3Dist,  digits);
      if(InpDeleteOnNew) CloseMyPositions();
      string cmt = StringFormat("ZS V10 %s s%d STOCH", gPendingSetup, gPendingScore);
      if(StringLen(cmt)>63) cmt=StringSubstr(cmt,0,63);
      ok = trade.Sell(lot, InpSymbol, entryPrice, sl, tp3, cmt);
      if(ok) PlaceLayers(-1, entryPrice, sl, tp3, lot, cmt, layerPriceDist, digits);
   }

   if(ok)
   {
      gEntry=entryPrice; gSL=sl; gTP1=tp1; gTP2=tp2; gTP3=tp3;
      gDir=gPendingDir; gHitTP1=false; gHitTP2=false;
      gOpenTime=TimeCurrent();
      gTotalSignals++;
      gPanelStatus = (gPendingDir==1) ? "BUY ACTIVE" : "SELL ACTIVE";
      gPanelSetup  = gPendingSetup;
      Print(StringFormat(">>> STOCH ENTRY %s | %s | Score=%d | StochK=%.1f | Entry=%.2f | SL=%.2f | TP1=%.2f | TP2=%.2f | TP3=%.2f",
            gPendingDir==1?"BUY":"SELL", gPendingSetup, gPendingScore, gStochK,
            entryPrice, sl, tp1, tp2, tp3));
      SendReport("OPEN", "", entryPrice, 0);
   }
   else
      Print("Order GAGAL (stoch entry): ", trade.ResultRetcodeDescription());

   ResetPending();
}

//+------------------------------------------------------------------+
// TRAILING STOP
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!InpTrailingEnabled || gDir==0) return;

   double pt  = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
   double now = (gDir==1) ? SymbolInfoDouble(InpSymbol, SYMBOL_BID)
                           : SymbolInfoDouble(InpSymbol, SYMBOL_ASK);

   if(gDir == 1)
   {
      if(gTP3>0 && now>=gTP3)
      {
         Print("TP3 TERCAPAI! Close ALL BUY + cancel pending");
         double plTP3Buy = CalcCurrentPL();
         CloseMyPositions();
         UpdateStatsOnClose(plTP3Buy);
         SendReport("CLOSE", "TP3", gTP3, plTP3Buy);
         ResetTrade();
         return;
      }
      if(!gHitTP2 && gTP2>0 && now>=gTP2) { gHitTP2=true; Print("TP2 hit → SL semua posisi ke TP1"); SendReport("TP_HIT","TP2",now,CalcCurrentPL()); }
      if(!gHitTP1 && gTP1>0 && now>=gTP1) { gHitTP1=true; Print("TP1 hit → SL semua posisi ke BE");  SendReport("TP_HIT","TP1",now,CalcCurrentPL()); }
   }
   else
   {
      if(gTP3>0 && now<=gTP3)
      {
         Print("TP3 TERCAPAI! Close ALL SELL + cancel pending");
         double plTP3Sell = CalcCurrentPL();
         CloseMyPositions();
         UpdateStatsOnClose(plTP3Sell);
         SendReport("CLOSE", "TP3", gTP3, plTP3Sell);
         ResetTrade();
         return;
      }
      if(!gHitTP2 && gTP2>0 && now<=gTP2) { gHitTP2=true; Print("TP2 hit → SL semua posisi ke TP1"); SendReport("TP_HIT","TP2",now,CalcCurrentPL()); }
      if(!gHitTP1 && gTP1>0 && now<=gTP1) { gHitTP1=true; Print("TP1 hit → SL semua posisi ke BE");  SendReport("TP_HIT","TP1",now,CalcCurrentPL()); }
   }

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()!=InpMagicNumber || posInfo.Symbol()!=InpSymbol) continue;

      double curSL = posInfo.StopLoss();
      ulong  ticket = posInfo.Ticket();

      if(gDir == 1)
      {
         if(gHitTP2 && gTP1>0 && curSL < gTP1-pt)        ModifySL(ticket, gTP1);
         else if(gHitTP1 && curSL < gEntry-pt)             ModifySL(ticket, gEntry);
      }
      else
      {
         if(gHitTP2 && gTP1>0 && curSL > gTP1+pt)        ModifySL(ticket, gTP1);
         else if(gHitTP1 && curSL > gEntry+pt)             ModifySL(ticket, gEntry);
      }
   }
}

//+------------------------------------------------------------------+
// MAIN TICK
//+------------------------------------------------------------------+
void OnTick()
{
   if(!InpEnabled) return;

   // Trailing stop berjalan di setiap tick (price-based)
   ManageTrailingStop();

   // Cek stochastic & eksekusi pending signal setiap tick
   if(InpUseStochFilter && gPendingDir != 0)
   {
      CheckStochEntry();
      if(InpShowPanel) DrawPanel();
      return;
   }

   // Update stoch display saat tidak ada pending
   gStochK = Buf(hStoch, 0, 0);
   gStochD = Buf(hStoch, 1, 0);

   // Countdown flash reversal alert
   if(gReversalFlash > 0) gReversalFlash--;
   if(gReversalFlash == 0) gReversalAlert = false;

   // Batasi processing sinyal ke 1x per bar (M1)
   datetime curBarTime = iTime(InpSymbol, PERIOD_M1, 0);
   if(curBarTime == gLastBarTime)
   {
      if(InpShowPanel) DrawPanel();
      return;
   }
   gLastBarTime = curBarTime;

   // Check max hold time
   if(HasActivePosition() && gDir!=0 && gOpenTime>0)
   {
      int holdMin = (int)((TimeCurrent()-gOpenTime)/60);
      if(holdMin >= InpMaxHoldMinutes)
      {
         Print("Max hold time tercapai (", InpMaxHoldMinutes, " min). Menutup posisi.");
         double plTimeout = CalcCurrentPL();
         double closeTimeout = (gDir==1)?SymbolInfoDouble(InpSymbol,SYMBOL_BID):SymbolInfoDouble(InpSymbol,SYMBOL_ASK);
         CloseMyPositions();
         UpdateStatsOnClose(plTimeout);
         SendReport("CLOSE", "TIMEOUT", closeTimeout, plTimeout);
         ResetTrade();
         if(InpShowPanel) DrawPanel();
         return;
      }
   }
   else if(!HasActivePosition() && gDir != 0)
   {
      // Posisi ditutup eksternal (SL kena broker) — ambil P&L dari history
      double plSL = GetLastClosedPL();
      UpdateStatsOnClose(plSL);
      SendReport("CLOSE", "SL", (gDir==1)?SymbolInfoDouble(InpSymbol,SYMBOL_BID):SymbolInfoDouble(InpSymbol,SYMBOL_ASK), plSL);
      ResetTrade();
   }

   // Session filter
   gSessionOK = InWIBSession();
   if(!gSessionOK)
   {
      gPanelStatus = "SESSION OFF";
      if(InpShowPanel) DrawPanel();
      return;
   }

   int currentBars = iBars(InpSymbol, PERIOD_M1);

   // Cooldown hanya berlaku saat tidak ada posisi aktif
   if(!HasActivePosition() && gLastExitBar>0 && (currentBars-1)-gLastExitBar < InpCooldownBars)
   {
      gPanelStatus = "COOLDOWN";
      if(InpShowPanel) DrawPanel();
      return;
   }

   // CheckSignal menangani: entry baru + deteksi reversal saat posisi aktif
   CheckSignal(currentBars);
   if(InpShowPanel) DrawPanel();
}

//+------------------------------------------------------------------+
// SIGNAL DETECTION + AUTO REVERSAL
//+------------------------------------------------------------------+
void CheckSignal(int currentBars)
{
   MqlRates bar[];
   ArraySetAsSeries(bar, true);
   if(CopyRates(InpSymbol, PERIOD_M1, 1, 3, bar) < 3) return;

   double open1  = bar[0].open,  high1  = bar[0].high;
   double low1   = bar[0].low,   close1 = bar[0].close;
   double close2 = bar[1].close, high2  = bar[1].high, low2 = bar[1].low;

   double emaFast   = Buf(hEmaFast, 0, 1);
   double emaMid    = Buf(hEmaMid,  0, 1);
   double emaSlow   = Buf(hEmaSlow, 0, 1);
   double emaSlowOld= Buf(hEmaSlow, 0, 1+InpEma200SlopeBars);

   double m5Close   = iClose(InpSymbol, PERIOD_M5,  1);
   double m5Ema50   = Buf(hEmaM5Fast, 0, 1);
   double m15Close  = iClose(InpSymbol, PERIOD_M15, 1);
   double m15Ema50  = Buf(hEmaM15Fast, 0, 1);
   double m15Ema50_3= Buf(hEmaM15Fast, 0, 4);
   double m15Slope  = m15Ema50 - m15Ema50_3;

   double rsiVal  = Buf(hRsi, 0, 1);
   double rsiPrev = Buf(hRsi, 0, 2);
   double adxVal  = Buf(hAdx, 0, 1);
   double atrVal  = Buf(hAtr, 0, 1);
   double bbUpper = Buf(hBB,  1, 1);
   double bbLower = Buf(hBB,  2, 1);

   if(atrVal<=0 || emaFast<=0) return;

   gRsiVal = rsiVal; gAdxVal = adxVal; gAtrVal = atrVal;

   double body       = MathAbs(close1-open1);
   double candleRange= high1-low1;
   double bodyRatio  = candleRange>0 ? body/candleRange : 0.0;
   double closePos   = candleRange>0 ? (close1-low1)/candleRange : 0.5;
   bool bullCandle = close1>open1 && closePos>=InpCloseEdge;
   bool bearCandle = close1<open1 && closePos<=1.0-InpCloseEdge;
   bool bodyOK     = bodyRatio>=InpMinBodyRatio;
   bool antiSpike  = candleRange<=atrVal*InpMaxCandleATR;
   bool atrOK      = atrVal>=InpMinATRPrice && atrVal<=InpMaxATRPrice;
   double wickBuy  = MathMin(open1,close1)-low1;
   double wickSell = high1-MathMax(open1,close1);
   bool wickBuyOK  = candleRange>0 ? wickBuy/candleRange>=0.32 : false;
   bool wickSellOK = candleRange>0 ? wickSell/candleRange>=0.32 : false;

   gM1Bull = emaFast>emaMid && close1>emaMid;
   gM1Bear = emaFast<emaMid && close1<emaMid;
   gM5Bull = m5Close>m5Ema50;
   gM5Bear = m5Close<m5Ema50;
   gM15Bull= m15Close>m15Ema50 && m15Slope>=0;
   gM15Bear= m15Close<m15Ema50 && m15Slope<=0;
   gBullCount = (gM1Bull?1:0)+(gM5Bull?1:0)+(gM15Bull?1:0);
   gBearCount = (gM1Bear?1:0)+(gM5Bear?1:0)+(gM15Bear?1:0);
   bool trendBuyOK  = gBullCount>=2;
   bool trendSellOK = gBearCount>=2;

   double emaGapATR = atrVal>0 ? MathAbs(emaMid-emaSlow)/atrVal : 999.0;
   gSidewaysFlag = gBullCount<2 && gBearCount<2 && adxVal<=InpSideMaxADX && emaGapATR<=1.60;

   bool rsiBuyTurn  = rsiVal>rsiPrev;
   bool rsiSellTurn = rsiVal<rsiPrev;
   bool rsiBuyOK, rsiSellOK;
   if(InpEntryMode=="SAFE")         { rsiBuyOK=rsiVal>=38&&rsiVal<=62; rsiSellOK=rsiVal>=38&&rsiVal<=62; }
   else if(InpEntryMode=="BALANCED"){ rsiBuyOK=rsiVal>=34&&rsiVal<=68; rsiSellOK=rsiVal>=32&&rsiVal<=66; }
   else                              { rsiBuyOK=rsiVal>=30&&rsiVal<=72; rsiSellOK=rsiVal>=28&&rsiVal<=70; }

   UpdateSRLevels(atrVal);
   double srBuffer    = atrVal*InpSRBufferATR;
   bool nearSupport   = gSupLevel>0 && low1<=gSupLevel+srBuffer && close1>=gSupLevel1-srBuffer;
   bool nearResistance= gResLevel>0 && high1>=gResLevel-srBuffer && close1<=gResLevel1+srBuffer;
   bool aboveResistance= gResLevel1>0 && close1>gResLevel1;
   bool belowSupport  = gSupLevel1>0 && close1<gSupLevel1;

   bool brekoutRes = gResLevel1>0 && close2<=gResLevel1 && close1>gResLevel1;
   bool brekoutSup = gSupLevel1>0 && close2>=gSupLevel1 && close1<gSupLevel1;
   bool resHolds   = gResLevel>0 && high1>=gResLevel-srBuffer && close1<=gResLevel;
   bool supHolds   = gSupLevel>0 && low1<=gSupLevel+srBuffer  && close1>=gSupLevel;

   if(brekoutRes) { gResIsSup=true;  gBreakResHigh=gResLevel1; gBreakResBar=currentBars-1; }
   else if(resHolds) gResIsSup=false;
   if(brekoutSup) { gSupIsRes=true;  gBreakSupLow=gSupLevel1;  gBreakSupBar=currentBars-1; }
   else if(supHolds) gSupIsRes=false;

   bool greenSupportHold = supHolds;
   bool greenResAsSupport= brekoutRes && gResIsSup;
   bool redResistanceHold= resHolds;
   bool redSupAsResistance= brekoutSup && gSupIsRes;
   bool greenDiamond = greenSupportHold || greenResAsSupport;
   bool redDiamond   = redResistanceHold || redSupAsResistance;

   bool resRetestBuy =
      gBreakResBar>0 && (currentBars-1)>gBreakResBar &&
      (currentBars-1)-gBreakResBar<=InpSRRetestBars && gBreakResHigh>0 &&
      low1<=gBreakResHigh+srBuffer && close1>=gBreakResHigh &&
      bullCandle && rsiBuyTurn;

   bool supRetestSell =
      gBreakSupBar>0 && (currentBars-1)>gBreakSupBar &&
      (currentBars-1)-gBreakSupBar<=InpSRRetestBars && gBreakSupLow>0 &&
      high1>=gBreakSupLow-srBuffer && close1<=gBreakSupLow &&
      bearCandle && rsiSellTurn;

   bool srBuyDanger  = nearResistance && !aboveResistance && !brekoutRes;
   bool srSellDanger = nearSupport    && !belowSupport    && !brekoutSup;
   gSRBlockBuy  = InpSRBoostBlock && srBuyDanger;
   gSRBlockSell = InpSRBoostBlock && srSellDanger;

   int srBuyBoost=0, srSellBoost=0;
   if(InpSRBoostBlock)
   {
      srBuyBoost  += nearSupport    ?InpSRBoostPts:0;
      srBuyBoost  += brekoutRes     ?InpSRBreakBoostPts:0;
      srBuyBoost  += (gResIsSup&&close1>gResLevel)?InpSRBoostPts:0;
      srBuyBoost  -= srBuyDanger    ?InpSRDangerPenalty:0;
      srBuyBoost  += resRetestBuy   ?InpRetestBoostPts:0;
      srSellBoost += nearResistance ?InpSRBoostPts:0;
      srSellBoost += brekoutSup     ?InpSRBreakBoostPts:0;
      srSellBoost += (gSupIsRes&&close1<gSupLevel)?InpSRBoostPts:0;
      srSellBoost -= srSellDanger   ?InpSRDangerPenalty:0;
      srSellBoost += supRetestSell  ?InpRetestBoostPts:0;
   }

   gSRStatus = brekoutRes ? "BREAK RESIST" : brekoutSup ? "BREAK SUPPORT" :
               nearSupport ? "NEAR SUPPORT" : nearResistance ? "NEAR RESIST" :
               resRetestBuy ? "RETEST BUY" : supRetestSell ? "RETEST SELL" : "NEUTRAL";

   double ema200Slope = emaSlow - emaSlowOld;
   bool majorBear = close1<emaSlow && ema200Slope<0 && gBearCount>=2;
   bool majorBull = close1>emaSlow && ema200Slope>0 && gBullCount>=2;

   bool buyReversalOK  = brekoutRes||resRetestBuy||(nearSupport&&bullCandle&&rsiBuyTurn&&close1>emaFast);
   bool sellReversalOK = brekoutSup||supRetestSell||(nearResistance&&bearCandle&&rsiSellTurn&&close1<emaFast);

   bool redBoxBuyBlock    = InpBlockBuyAtRedBox    &&nearResistance&&!aboveResistance&&!brekoutRes&&!resRetestBuy;
   bool greenBoxSellBlock = InpBlockSellAtGreenBox &&nearSupport   &&!belowSupport   &&!brekoutSup&&!supRetestSell;
   bool buyPrecisionOK    = !InpRequireBreakForReversal||!majorBear||buyReversalOK;
   bool sellPrecisionOK   = !InpRequireBreakForReversal||!majorBull||sellReversalOK;
   gPrecBlockBuy  = redBoxBuyBlock   ||!buyPrecisionOK;
   gPrecBlockSell = greenBoxSellBlock||!sellPrecisionOK;

   bool buyTrend  = trendBuyOK &&close1>emaMid &&rsiBuyOK &&rsiBuyTurn &&bullCandle&&bodyOK&&antiSpike&&atrOK;
   bool sellTrend = trendSellOK&&close1<emaMid &&rsiSellOK&&rsiSellTurn&&bearCandle&&bodyOK&&antiSpike&&atrOK;
   bool buyBreak  = trendBuyOK &&close1>high2  &&close1>emaFast&&rsiVal>50&&rsiVal<72&&bullCandle&&antiSpike&&atrOK;
   bool sellBreak = trendSellOK&&close1<low2   &&close1<emaFast&&rsiVal<50&&rsiVal>28&&bearCandle&&antiSpike&&atrOK;
   bool sideBuy   = gSidewaysFlag&&low1<=bbLower&&close1>bbLower&&rsiVal<=45&&rsiBuyTurn &&wickBuyOK &&antiSpike&&atrOK;
   bool sideSell  = gSidewaysFlag&&high1>=bbUpper&&close1<bbUpper&&rsiVal>=55&&rsiSellTurn&&wickSellOK&&antiSpike&&atrOK;

   int buyScoreRaw  = (gBullCount*18)+(close1>emaMid?12:0)+(close1>emaFast?8:0)+(rsiBuyTurn?10:0)+(rsiBuyOK?10:0)+(bullCandle?10:0)+(bodyOK?5:0)+(antiSpike?5:0)+(atrOK?5:0)+(sideBuy?20:0);
   int sellScoreRaw = (gBearCount*18)+(close1<emaMid?12:0)+(close1<emaFast?8:0)+(rsiSellTurn?10:0)+(rsiSellOK?10:0)+(bearCandle?10:0)+(bodyOK?5:0)+(antiSpike?5:0)+(atrOK?5:0)+(sideSell?20:0);
   gBuyScore  = MathMax(0, buyScoreRaw +srBuyBoost -(gPrecBlockBuy ?InpSRDangerPenalty:0));
   gSellScore = MathMax(0, sellScoreRaw+srSellBoost-(gPrecBlockSell?InpSRDangerPenalty:0));

   gMinQuality = (InpEntryMode=="SAFE")?InpMinQualitySafe:(InpEntryMode=="BALANCED")?InpMinQualityBal:InpMinQualityAgg;

   bool allowBuy  = InpModeSignal!="SELL ONLY";
   bool allowSell = InpModeSignal!="BUY ONLY";

   bool buySetup  = (buyTrend||buyBreak||sideBuy||resRetestBuy) &&!gSRBlockBuy &&!gPrecBlockBuy;
   bool sellSetup = (sellTrend||sellBreak||sideSell||supRetestSell)&&!gSRBlockSell&&!gPrecBlockSell;
   bool buyValid  = allowBuy &&buySetup &&gBuyScore>=gMinQuality&&gBuyScore>=gSellScore+InpScoreGap;
   bool sellValid = allowSell&&sellSetup&&gSellScore>=gMinQuality&&gSellScore>=gBuyScore+InpScoreGap;

   bool buyStrongSR  = InpUseSRStrength&&greenDiamond&&(trendBuyOK||gBullCount>=2||resRetestBuy)&&gBuyScore>=InpSRStrongMinScore&&gBuyScore>=gSellScore+InpSRStrongGap&&!gSRBlockBuy&&!gPrecBlockBuy;
   bool sellStrongSR = InpUseSRStrength&&redDiamond&&(trendSellOK||gBearCount>=2||supRetestSell)&&gSellScore>=InpSRStrongMinScore&&gSellScore>=gBuyScore+InpSRStrongGap&&!gSRBlockSell&&!gPrecBlockSell;
   bool buyMediumSR  = InpAllowSRMedium&&greenDiamond&&!buyStrongSR&&gBuyScore>=InpSRMediumMinScore&&gBuyScore>=gSellScore+InpSRMediumGap&&!gSRBlockBuy&&!gPrecBlockBuy;
   bool sellMediumSR = InpAllowSRMedium&&redDiamond&&!sellStrongSR&&gSellScore>=InpSRMediumMinScore&&gSellScore>=gBuyScore+InpSRMediumGap&&!gSRBlockSell&&!gPrecBlockSell;

   bool doSRBuy  = allowBuy &&(buyStrongSR||buyMediumSR) &&(!(sellStrongSR||sellMediumSR)||gBuyScore>=gSellScore+InpScoreGap);
   bool doSRSell = allowSell&&(sellStrongSR||sellMediumSR)&&(!(buyStrongSR||buyMediumSR) ||gSellScore>=gBuyScore+InpScoreGap);

   gPeakBlock = InpBlockBuyAtPeak  && rsiVal >= InpOverboughtRSI;
   gDeepBlock = InpBlockSellAtDeep && rsiVal <= InpOversoldRSI;

   double lot          = MathMin(InpLot, InpMaxLot);
   double tickVal      = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz       = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE);
   double dollarPerUnit= (tickSz > 0 && tickVal > 0) ? lot * (tickVal / tickSz) : lot;
   double slPriceDist  = (dollarPerUnit > 0) ? InpSLDollars  / dollarPerUnit : 5.0;
   double tp1PriceDist = (dollarPerUnit > 0) ? InpTP1Dollars / dollarPerUnit : 5.0;
   double tp2PriceDist = (dollarPerUnit > 0) ? InpTP2Dollars / dollarPerUnit : 10.0;
   double tp3PriceDist = (dollarPerUnit > 0) ? InpTP3Dollars / dollarPerUnit : 15.0;

   int    finalDir   = 0;
   string setupClass = "";

   if     (doSRBuy   && !gPeakBlock)  { finalDir =  1; setupClass = buyStrongSR  ? "BUY_KUAT_SR"  : "BUY_SEDANG_SR";  }
   else if(doSRSell  && !gDeepBlock)  { finalDir = -1; setupClass = sellStrongSR ? "SELL_KUAT_SR" : "SELL_SEDANG_SR"; }
   else if(buyValid  && !gPeakBlock)  { finalDir =  1; setupClass = "BUY_NORMAL";  }
   else if(sellValid && !gDeepBlock)  { finalDir = -1; setupClass = "SELL_NORMAL"; }

   if(InpReverseMode && finalDir != 0)
   {
      finalDir   = -finalDir;
      setupClass = setupClass + "_REV";
   }

   // ================================================================
   // AUTO REVERSAL: signal flip saat posisi aktif → close & buka baru
   // ================================================================
   if(InpAutoReversal && finalDir != 0 && gDir != 0 && finalDir != gDir && HasActivePosition())
   {
      int revScore = (finalDir == 1) ? gBuyScore : gSellScore;
      if(revScore >= InpReversalMinScore)
      {
         string revFrom = (gDir == 1) ? "BUY" : "SELL";
         string revTo   = (finalDir == 1) ? "BUY" : "SELL";
         double revPrice= (finalDir == 1) ? SymbolInfoDouble(InpSymbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(InpSymbol, SYMBOL_BID);
         Print(">>> ⚡ AUTO REVERSAL: ", revFrom, " → ", revTo,
               " | Score=", revScore, " | @ ", DoubleToString(revPrice, (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS)));
         double plRev = CalcCurrentPL();
         CloseMyPositions();
         UpdateStatsOnClose(plRev);
         gDir = 0;
         gLastReversalInfo = revFrom + "→" + revTo + " @" + DoubleToString(revPrice, 2);
         gReversalAlert    = true;
         gReversalFlash    = 10; // flash 10 bar
         SendReport("REVERSAL", revFrom+"→"+revTo, revPrice, plRev);
         // fall through → buka posisi baru arah finalDir
      }
      else
      {
         // Score tidak cukup, tetap hold posisi lama
         gPanelStatus = (gDir == 1) ? "BUY ACTIVE" : "SELL ACTIVE";
         return;
      }
   }
   else if(HasActivePosition())
   {
      // Ada posisi aktif, tidak ada reversal → update panel saja
      gPanelStatus = (gDir == 1) ? "BUY ACTIVE" : "SELL ACTIVE";
      // Update predict panel
      if(finalDir == 0)
      {
         if(InpReverseMode)
         {
            if(gBuyScore>=gSellScore+2)      gPanelStatus=(gDir==1)?"BUY ACTIVE ↓ PRED SELL":"SELL ACTIVE";
            else if(gSellScore>=gBuyScore+2) gPanelStatus=(gDir==-1)?"SELL ACTIVE ↓ PRED BUY":"BUY ACTIVE";
         }
      }
      return;
   }

   // ================================================================
   // Tidak ada posisi aktif → update predict panel atau execute
   // ================================================================
   if(finalDir == 0)
   {
      if(InpReverseMode)
      {
         if(gBuyScore>=gSellScore+2)      gPanelStatus="PREDICT SELL";
         else if(gSellScore>=gBuyScore+2) gPanelStatus="PREDICT BUY";
         else                             gPanelStatus="WAIT";
      }
      else
      {
         if(gBuyScore>=gSellScore+2)      gPanelStatus="PREDICT BUY";
         else if(gSellScore>=gBuyScore+2) gPanelStatus="PREDICT SELL";
         else                             gPanelStatus="WAIT";
      }
      gPanelSetup = "-";
      return;
   }

   // ================================================================
   // EXECUTE ORDER  (atau simpan pending jika stoch filter aktif)
   // ================================================================
   int score=(finalDir==1)?gBuyScore:gSellScore;

   if(InpUseStochFilter)
   {
      // Simpan sinyal sebagai pending — entry menunggu Stochastic
      gPendingDir     = finalDir;
      gPendingSLDist  = slPriceDist;
      gPendingTP1Dist = tp1PriceDist;
      gPendingTP2Dist = tp2PriceDist;
      gPendingTP3Dist = tp3PriceDist;
      gPendingSetup   = setupClass;
      gPendingScore   = score;
      gPendingBar     = iBars(InpSymbol, PERIOD_M1) - 1;
      gPanelSetup     = setupClass;

      string waitDir  = (finalDir == 1) ? "BUY" : "SELL";
      string waitCond = (finalDir == 1)
                        ? StringFormat("Stoch <= %d", InpStochBuyLevel)
                        : StringFormat("Stoch >= %d", InpStochSellLevel);
      Print(StringFormat(">>> SIGNAL %s | %s | Score=%d | Menunggu %s | SLdist=%.2f | TP1=%.2f TP2=%.2f TP3=%.2f",
            waitDir, setupClass, score, waitCond, slPriceDist, tp1PriceDist, tp2PriceDist, tp3PriceDist));
      return; // ExecPending akan handle entry di CheckStochEntry()
   }

   // Stoch filter OFF → langsung entry seperti biasa
   int    digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
   double entryPrice, sl, tp1, tp2, tp3;
   bool   ok=false;
   double layerPriceDist = (dollarPerUnit > 0) ? InpLayerDollars / dollarPerUnit : 0;

   if(finalDir==1)
   {
      entryPrice=SymbolInfoDouble(InpSymbol,SYMBOL_ASK);
      sl =NormalizeDouble(entryPrice - slPriceDist,  digits);
      tp1=NormalizeDouble(entryPrice + tp1PriceDist, digits);
      tp2=NormalizeDouble(entryPrice + tp2PriceDist, digits);
      tp3=NormalizeDouble(entryPrice + tp3PriceDist, digits);
      if(InpDeleteOnNew) CloseMyPositions();
      string cmt=StringFormat("ZS V10 %s s%d",setupClass,score);
      if(StringLen(cmt)>63) cmt=StringSubstr(cmt,0,63);
      ok=trade.Buy(lot,InpSymbol,entryPrice,sl,tp3,cmt);
      if(ok) PlaceLayers(1, entryPrice, sl, tp3, lot, cmt, layerPriceDist, digits);
   }
   else
   {
      entryPrice=SymbolInfoDouble(InpSymbol,SYMBOL_BID);
      sl =NormalizeDouble(entryPrice + slPriceDist,  digits);
      tp1=NormalizeDouble(entryPrice - tp1PriceDist, digits);
      tp2=NormalizeDouble(entryPrice - tp2PriceDist, digits);
      tp3=NormalizeDouble(entryPrice - tp3PriceDist, digits);
      if(InpDeleteOnNew) CloseMyPositions();
      string cmt=StringFormat("ZS V10 %s s%d",setupClass,score);
      if(StringLen(cmt)>63) cmt=StringSubstr(cmt,0,63);
      ok=trade.Sell(lot,InpSymbol,entryPrice,sl,tp3,cmt);
      if(ok) PlaceLayers(-1, entryPrice, sl, tp3, lot, cmt, layerPriceDist, digits);
   }

   if(ok)
   {
      gEntry=entryPrice; gSL=sl; gTP1=tp1; gTP2=tp2; gTP3=tp3;
      gDir=finalDir; gHitTP1=false; gHitTP2=false;
      gOpenTime=TimeCurrent();
      gTotalSignals++;
      gPanelStatus=(finalDir==1)?"BUY ACTIVE":"SELL ACTIVE";
      gPanelSetup=setupClass;
      Print(StringFormat(">>> %s | %s | Score=%d | Entry=%.2f | SL=%.2f | TP1=%.2f | TP2=%.2f | TP3=%.2f | Layer=$%.2f",
            finalDir==1?"BUY":"SELL",setupClass,score,entryPrice,sl,tp1,tp2,tp3,InpLayerDollars));
      SendReport("OPEN", "", entryPrice, 0);
   }
   else
      Print("Order GAGAL: ",trade.ResultRetcodeDescription()," (",trade.ResultRetcode(),")");
}

//==========================================================================
//  PANEL HELPERS
//==========================================================================

string ProgBar(double val, double maxVal, int width)
{
   if(maxVal <= 0) return "";
   int filled = (int)MathRound(MathMin(MathMax(val,0)/maxVal,1.0)*width);
   string bar = "";
   for(int i=0;i<width;i++) bar += (i<filled)?"█":"░";
   return bar;
}

string ScoreBar(int score, int minQ, int width)
{
   int maxScore=140;
   int filled=(int)MathRound(MathMin((double)score/maxScore,1.0)*width);
   string bar="";
   for(int i=0;i<width;i++) bar+=(i<filled)?"▓":"░";
   return bar;
}

string TPBar(double curPrice, double entry, double tp, int width, bool isBuy)
{
   if(entry==0||tp==0||entry==tp){ string e=""; for(int i=0;i<width;i++) e+="░"; return e; }
   double range=MathAbs(tp-entry);
   double progress=isBuy?(curPrice-entry):(entry-curPrice);
   int filled=(int)MathRound(MathMin(MathMax(progress/range,0.0),1.0)*width);
   string bar="";
   for(int i=0;i<width;i++) bar+=(i<filled)?"█":"░";
   return bar;
}

void PanelLabel(string name, string text, int x, int y, color clr, int fontSize=0)
{
   string fullName=PANEL_PREFIX+name;
   int fs=fontSize>0?fontSize:InpPanelFontSize;
   if(ObjectFind(0,fullName)<0)
   {
      ObjectCreate(0,fullName,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,fullName,OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,fullName,OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
      ObjectSetString (0,fullName,OBJPROP_FONT,      "Courier New");
      ObjectSetInteger(0,fullName,OBJPROP_BACK,      false);
      ObjectSetInteger(0,fullName,OBJPROP_SELECTABLE,false);
   }
   ObjectSetString (0,fullName,OBJPROP_TEXT,     text);
   ObjectSetInteger(0,fullName,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,fullName,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,fullName,OBJPROP_COLOR,    clr);
   ObjectSetInteger(0,fullName,OBJPROP_FONTSIZE, fs);
}

void PanelRect(string name, int x, int y, int w, int h, color bgColor, color borderColor=C'40,40,60')
{
   string fullName=PANEL_PREFIX+name;
   if(ObjectFind(0,fullName)<0)
   {
      ObjectCreate(0,fullName,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,fullName,OBJPROP_CORNER,     CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,fullName,OBJPROP_ANCHOR,     ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0,fullName,OBJPROP_BACK,       true);
      ObjectSetInteger(0,fullName,OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0,fullName,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   }
   ObjectSetInteger(0,fullName,OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0,fullName,OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0,fullName,OBJPROP_XSIZE,      w);
   ObjectSetInteger(0,fullName,OBJPROP_YSIZE,      h);
   ObjectSetInteger(0,fullName,OBJPROP_BGCOLOR,    bgColor);
   ObjectSetInteger(0,fullName,OBJPROP_BORDER_COLOR,borderColor);
}

void PanelDelete()
{
   int total=ObjectsTotal(0,0,-1);
   for(int i=total-1;i>=0;i--)
   {
      string name=ObjectName(0,i,0,-1);
      if(StringFind(name,PANEL_PREFIX)==0) ObjectDelete(0,name);
   }
}

void PanelCreate()
{
   PanelRect("BG", InpPanelX, InpPanelY, 340, 700, C'8,10,20');
}

//==========================================================================
//  DRAW PANEL v3 — Ultra Modern
//==========================================================================
void DrawPanel()
{
   if(!InpShowPanel) return;

   int x   = InpPanelX;
   int y0  = InpPanelY;
   int fs  = InpPanelFontSize;
   int fsS = MathMax(fs-1,7);
   int lh  = fs + 7;
   int W   = 340;
   // lx = label anchor (right edge of label col), px = value anchor
   int lx  = x + 6 + 170;
   int px  = x + 6;

   // ── Live data ──
   double spread   = SymbolInfoInteger(InpSymbol,SYMBOL_SPREAD)*SymbolInfoDouble(InpSymbol,SYMBOL_POINT);
   double curPrice = (gDir==1)?SymbolInfoDouble(InpSymbol,SYMBOL_BID):SymbolInfoDouble(InpSymbol,SYMBOL_ASK);
   double floatPL  = 0;
   int    posCount = 0;
   for(int i=0;i<PositionsTotal();i++)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()==InpMagicNumber && posInfo.Symbol()==InpSymbol)
      { floatPL+=posInfo.Profit()+posInfo.Swap(); posCount++; }
   }
   bool hasTrade = (gDir!=0 && HasActivePosition());
   int  holdMin  = hasTrade?(int)((TimeCurrent()-gOpenTime)/60):0;

   MqlDateTime mt;
   TimeToStruct(TimeCurrent(),mt);
   string timeStr=StringFormat("%02d:%02d:%02d",mt.hour,mt.min,mt.sec);

   // ── Status colors ──
   color sBG,sFG;
   bool isPending = (gPendingDir!=0);
   if     (gReversalAlert)                             { sBG=C'55,22,0';    sFG=C'255,165,0';  }
   else if(gPanelStatus=="BUY ACTIVE")                 { sBG=C'0,55,18';    sFG=C'0,255,100';  }
   else if(gPanelStatus=="SELL ACTIVE")                { sBG=C'55,0,8';     sFG=C'255,55,55';  }
   else if(isPending && gPendingDir== 1)               { sBG=C'0,35,55';    sFG=C'0,180,255';  }
   else if(isPending && gPendingDir==-1)               { sBG=C'40,15,55';   sFG=C'200,100,255';}
   else if(gPanelStatus=="PREDICT BUY")                { sBG=C'0,38,12';    sFG=C'0,200,80';   }
   else if(gPanelStatus=="PREDICT SELL")               { sBG=C'38,5,5';     sFG=C'220,50,50';  }
   else if(gPanelStatus=="COOLDOWN")                   { sBG=C'38,22,0';    sFG=clrOrange;     }
   else if(gPanelStatus=="SESSION OFF")                { sBG=C'22,22,22';   sFG=C'80,80,80';   }
   else                                                { sBG=C'15,17,32';   sFG=C'110,115,155';}

   int row = y0+2;

   // ══════════════════════════════════════════
   // [1] HEADER BAR
   // ══════════════════════════════════════════
   PanelRect("HDR",  x, row, W, lh+6, C'14,16,38', C'50,70,160');
   PanelLabel("T_TITLE"," ⚡ ZS V10  SR PRECISION PRO  v3", lx+20, row+4, clrGold, fs+1);
   row+=lh+8;

   // Sub-header: symbol / spread / time
   PanelRect("SUBBG", x, row, W, lh+2, C'10,12,28', C'30,35,70');
   PanelLabel("T_SYM", StringFormat(" %s", InpSymbol),             lx+20, row+2, C'200,210,255', fsS);
   PanelLabel("T_SPD", StringFormat("Spd:%.1f", spread),           px+180,row+2, C'120,130,170', fsS);
   PanelLabel("T_TIME",StringFormat("%s UTC", timeStr),             px+60, row+2, C'100,120,180', fsS);
   row+=lh+4;

   // ══════════════════════════════════════════
   // [2] STATUS BOX
   // ══════════════════════════════════════════
   PanelRect("STBG", x, row, W, lh+8, sBG, sFG);
   string statusTxt;
   if(gReversalAlert)
      statusTxt = StringFormat(" ⚡ FLIP! %s", gLastReversalInfo);
   else if(isPending)
      statusTxt = StringFormat(" ◉ WAIT STOCH %s  K=%.1f (need%s%d)",
                  gPendingDir>0?"BUY":"SELL", gStochK,
                  gPendingDir>0?"<=":">= ", gPendingDir>0?InpStochBuyLevel:InpStochSellLevel);
   else
      statusTxt = " " + gPanelStatus + (StringLen(gPanelSetup)>1?" ["+gPanelSetup+"]":"");
   PanelLabel("V_STATUS", statusTxt, lx+20, row+4, sFG, fs+1);
   row+=lh+10;

   if(InpReverseMode)
   {
      PanelRect("REVBG",x,row,W,lh+2,C'42,18,0',clrOrange);
      PanelLabel("V_REV"," ⟲  REVERSE MODE AKTIF",lx+20,row+2,clrOrange,fsS);
      row+=lh+4;
   }

   // ══════════════════════════════════════════
   // [3] STOCHASTIC GAUGE
   // ══════════════════════════════════════════
   PanelRect("SEP_ST",x,row,W,1,C'28,32,60'); row+=3;
   PanelLabel("SEC_ST"," ◆ STOCHASTIC",lx+20,row,C'80,160,255',fsS); row+=lh-1;

   color stKcol = (gStochK>=InpStochSellLevel)?C'255,55,55':(gStochK<=InpStochBuyLevel)?C'0,230,90':C'160,180,220';
   string stKtag= (gStochK>=InpStochSellLevel)?" OVERBOUGHT":(gStochK<=InpStochBuyLevel)?" OVERSOLD":" NEUTRAL";
   string stBar = ProgBar(gStochK,100.0,16);
   PanelLabel("L_STK"," %K  ",lx+20,row,C'150,160,190',fsS);
   PanelLabel("B_STK",stBar,  px+70, row,stKcol,fsS);
   PanelLabel("V_STK",StringFormat(" %.1f%s",gStochK,stKtag),px,row,stKcol,fsS);
   row+=lh-1;

   color stDcol=(gStochD>=InpStochSellLevel)?C'200,80,80':(gStochD<=InpStochBuyLevel)?C'0,180,80':C'120,130,160';
   PanelLabel("L_STD"," %D  ",lx+20,row,C'150,160,190',fsS);
   PanelLabel("V_STD",StringFormat(" %.1f",gStochD),px+70,row,stDcol,fsS);
   PanelLabel("V_STC",StringFormat("   Sell≥%d  Buy≤%d",InpStochSellLevel,InpStochBuyLevel),px,row,C'80,90,120',fsS);
   row+=lh+2;

   // Pending signal countdown
   if(isPending)
   {
      int waited = (iBars(InpSymbol,PERIOD_M1)-1) - gPendingBar;
      int maxW   = InpStochMaxWaitBars>0?InpStochMaxWaitBars:99;
      string waitBar = ProgBar((double)waited,maxW,14);
      color  waitCol = waited>maxW*0.7?clrOrange:C'0,160,240';
      PanelRect("PEND_BG",x,row,W,lh+4,C'10,25,45',C'0,120,200');
      PanelLabel("V_PEND",StringFormat(" Menunggu Stoch: bar %d/%d  [%s]",waited,maxW,waitBar),lx+20,row+2,waitCol,fsS);
      row+=lh+6;
   }

   // ══════════════════════════════════════════
   // [4] SIGNAL STRENGTH
   // ══════════════════════════════════════════
   PanelRect("SEP_SS",x,row,W,1,C'28,32,60'); row+=3;
   PanelLabel("SEC_SS"," ◆ SIGNAL STRENGTH",lx+20,row,C'80,160,255',fsS); row+=lh-1;

   color buySCL  = gBuyScore>=gMinQuality?C'0,235,85':C'70,75,100';
   color sellSCL = gSellScore>=gMinQuality?C'240,55,55':C'70,75,100';
   PanelLabel("L_BS"," BUY ", lx+20,row,buySCL,fsS);
   PanelLabel("B_BS",ScoreBar(gBuyScore,gMinQuality,12),px+65,row,buySCL,fsS);
   PanelLabel("V_BS",StringFormat(" %3d/%d",gBuyScore,gMinQuality),px,row,buySCL,fsS);
   row+=lh-1;
   PanelLabel("L_SS"," SELL",lx+20,row,sellSCL,fsS);
   PanelLabel("B_SS",ScoreBar(gSellScore,gMinQuality,12),px+65,row,sellSCL,fsS);
   PanelLabel("V_SS",StringFormat(" %3d/%d",gSellScore,gMinQuality),px,row,sellSCL,fsS);
   row+=lh+1;

   // Auto-reversal line
   color revClr=InpAutoReversal?C'200,155,0':C'60,65,90';
   string revStr=InpAutoReversal?StringFormat(" ⟲ AUTO-REV ON (min=%d)",InpReversalMinScore):" ⟲ AUTO-REV OFF";
   PanelLabel("V_AREV",revStr,lx+20,row,revClr,fsS); row+=lh-1;
   if(StringLen(gLastReversalInfo)>0)
   { PanelLabel("V_LREV",StringFormat(" Last flip: %s",gLastReversalInfo),lx+20,row,C'170,115,0',fsS); row+=lh-1; }

   // ══════════════════════════════════════════
   // [5] MULTI-TF TREND
   // ══════════════════════════════════════════
   PanelRect("SEP_TF",x,row,W,1,C'28,32,60'); row+=3;
   PanelLabel("SEC_TF"," ◆ MULTI-TF TREND",lx+20,row,C'80,160,255',fsS); row+=lh-1;

   color m1c =gM1Bull?C'0,215,85':gM1Bear?C'235,55,55':C'110,115,140';
   color m5c =gM5Bull?C'0,215,85':gM5Bear?C'235,55,55':C'110,115,140';
   color m15c=gM15Bull?C'0,215,85':gM15Bear?C'235,55,55':C'110,115,140';
   PanelLabel("V_M1", " M1 "+(gM1Bull?"▲BULL":gM1Bear?"▼BEAR":"─MIX"),lx+20,  row,m1c, fsS);
   PanelLabel("V_M5", " M5 "+(gM5Bull?"▲BULL":gM5Bear?"▼BEAR":"─MIX"),lx-30,  row,m5c, fsS);
   PanelLabel("V_M15"," M15"+(gM15Bull?"▲BULL":gM15Bear?"▼BEAR":"─MIX"),lx-95, row,m15c,fsS);
   row+=lh;

   string regime=(gBullCount>=2)?"BUY BIAS":(gBearCount>=2)?"SELL BIAS":gSidewaysFlag?"SIDEWAYS":"MIXED";
   color  regCol=(gBullCount>=2)?C'0,215,85':(gBearCount>=2)?C'235,55,55':C'175,120,0';
   PanelLabel("V_REGC",StringFormat(" Bulls:%d Bears:%d Regime:",gBullCount,gBearCount),lx+20,row,C'130,135,160',fsS);
   PanelLabel("V_REGV"," "+regime,px,row,regCol,fsS);
   row+=lh+2;

   // ══════════════════════════════════════════
   // [6] INDICATORS
   // ══════════════════════════════════════════
   PanelRect("SEP_IN",x,row,W,1,C'28,32,60'); row+=3;
   PanelLabel("SEC_IN"," ◆ INDICATORS",lx+20,row,C'80,160,255',fsS); row+=lh-1;

   color rsiCol=(gRsiVal>=InpOverboughtRSI)?C'235,55,55':(gRsiVal<=InpOversoldRSI)?C'0,205,85':(gRsiVal>=50)?C'200,155,0':C'0,175,120';
   string rsiTag=(gRsiVal>=InpOverboughtRSI)?" PEAK":(gRsiVal<=InpOversoldRSI)?" DEEP":" OK";
   PanelLabel("L_RSI"," RSI  ",lx+20,row,C'150,155,185',fsS);
   PanelLabel("B_RSI",ProgBar(gRsiVal,100.0,12),px+65,row,rsiCol,fsS);
   PanelLabel("V_RSI",StringFormat(" %.1f%s",gRsiVal,rsiTag),px,row,rsiCol,fsS);
   row+=lh-1;

   color adxCol=(gAdxVal>=25)?clrGold:C'90,95,125';
   string adxTag=(gAdxVal>=25)?" TREND":(gAdxVal<=InpSideMaxADX)?" SIDE":" WEAK";
   PanelLabel("L_ADX"," ADX  ",lx+20,row,C'150,155,185',fsS);
   PanelLabel("B_ADX",ProgBar(gAdxVal,50.0,12),px+65,row,adxCol,fsS);
   PanelLabel("V_ADX",StringFormat(" %.1f%s",gAdxVal,adxTag),px,row,adxCol,fsS);
   row+=lh-1;

   bool atrOK2=(gAtrVal>=InpMinATRPrice&&gAtrVal<=InpMaxATRPrice);
   PanelLabel("L_ATR",StringFormat(" ATR  %.3f (%s)",gAtrVal,atrOK2?"OK":"!"),
              lx+20,row,atrOK2?C'0,175,100':C'200,70,70',fsS);
   row+=lh+2;

   // ══════════════════════════════════════════
   // [7] SR LEVELS
   // ══════════════════════════════════════════
   PanelRect("SEP_SR",x,row,W,1,C'28,32,60'); row+=3;
   PanelLabel("SEC_SR"," ◆ SUPPORT / RESISTANCE",lx+20,row,C'80,160,255',fsS); row+=lh-1;

   string supTxt=gSupLevel>0?StringFormat("%.2f",gSupLevel):"-";
   string resTxt=gResLevel>0?StringFormat("%.2f",gResLevel):"-";
   PanelLabel("V_SRLVL",StringFormat(" Sup:%-8s Res:%s",supTxt,resTxt),lx+20,row,C'150,155,185',fsS); row+=lh-1;

   color srCol2=(gSRStatus=="NEUTRAL")?C'90,95,120':(StringFind(gSRStatus,"BUY")>=0||StringFind(gSRStatus,"SUPPORT")>=0)?C'0,200,80':C'230,55,55';
   PanelLabel("V_SRS",StringFormat(" %s",gSRStatus),lx+20,row,srCol2,fsS);
   bool anyBlockBuy2 =gSRBlockBuy||gPrecBlockBuy||gPeakBlock;
   bool anyBlockSell2=gSRBlockSell||gPrecBlockSell||gDeepBlock;
   string bTxt=(!anyBlockBuy2&&!anyBlockSell2)?"✓ CLEAR":(anyBlockBuy2&&anyBlockSell2)?"✗ BOTH":anyBlockBuy2?(gPeakBlock?"✗ PEAK":"✗ BLK-B"):(gDeepBlock?"✗ DEEP":"✗ BLK-S");
   color  bCol=(bTxt=="✓ CLEAR")?C'0,175,80':C'230,55,55';
   PanelLabel("V_BLK",StringFormat("  Filter:%s",bTxt),px+80,row,bCol,fsS);
   row+=lh+2;

   // ══════════════════════════════════════════
   // [8] ACTIVE TRADE
   // ══════════════════════════════════════════
   PanelRect("SEP_TR",x,row,W,1,C'28,32,60'); row+=3;

   if(hasTrade)
   {
      bool  isBuy   =(gDir==1);
      color trHdr   =isBuy?C'0,70,25':C'70,10,10';
      color trFG    =isBuy?C'0,245,105':C'255,60,60';
      string trLabel=isBuy?"▲ BUY  ACTIVE":"▼ SELL ACTIVE";

      PanelRect("THDR",x,row,W,lh+4,trHdr,trFG);
      PanelLabel("SEC_TR",StringFormat(" ◆ %s   [%d pos]",trLabel,posCount),lx+20,row+3,trFG,fsS);
      row+=lh+6;

      // Entry / SL
      PanelLabel("L_EN2",StringFormat(" Entry : %.2f",gEntry),lx+20,row,C'210,185,80',fsS); row+=lh-1;
      PanelLabel("L_SL2",StringFormat(" SL    : %.2f   [-$%.2f]",gSL,InpSLDollars),lx+20,row,C'235,55,55',fsS); row+=lh+1;

      // TP Progress
      double tp1Pct=0,tp2Pct=0,tp3Pct=0;
      if(gEntry!=0&&gTP1!=gEntry) tp1Pct=MathMin(MathMax(isBuy?(curPrice-gEntry)/(gTP1-gEntry):(gEntry-curPrice)/(gEntry-gTP1),0),1.0)*100;
      if(gEntry!=0&&gTP2!=gEntry) tp2Pct=MathMin(MathMax(isBuy?(curPrice-gEntry)/(gTP2-gEntry):(gEntry-curPrice)/(gEntry-gTP2),0),1.0)*100;
      if(gEntry!=0&&gTP3!=gEntry) tp3Pct=MathMin(MathMax(isBuy?(curPrice-gEntry)/(gTP3-gEntry):(gEntry-curPrice)/(gEntry-gTP3),0),1.0)*100;

      color tp1Col=gHitTP1?clrGold:C'0,205,85';
      color tp2Col=gHitTP2?clrGold:C'0,185,85';
      PanelLabel("B_T1"," TP1["+TPBar(curPrice,gEntry,gTP1,10,isBuy)+"]",lx+20,row,tp1Col,fsS);
      PanelLabel("V_T1",StringFormat(" %.2f %s",gTP1,gHitTP1?"✓BE":StringFormat("%3.0f%%",tp1Pct)),px,row,tp1Col,fsS); row+=lh-1;
      PanelLabel("B_T2"," TP2["+TPBar(curPrice,gEntry,gTP2,10,isBuy)+"]",lx+20,row,tp2Col,fsS);
      PanelLabel("V_T2",StringFormat(" %.2f %s",gTP2,gHitTP2?"✓TP1":StringFormat("%3.0f%%",tp2Pct)),px,row,tp2Col,fsS); row+=lh-1;
      PanelLabel("B_T3"," TP3["+TPBar(curPrice,gEntry,gTP3,10,isBuy)+"]",lx+20,row,C'0,165,85',fsS);
      PanelLabel("V_T3",StringFormat(" %.2f %3.0f%%",gTP3,tp3Pct),px,row,C'0,165,85',fsS); row+=lh+1;

      // Price / Float P&L / Hold
      PanelLabel("L_NOW",StringFormat(" Price : %.2f",curPrice),lx+20,row,clrWhite,fsS); row+=lh-1;
      color plCol=floatPL>=0?C'0,235,95':C'235,55,55';
      string plSign=floatPL>=0?"+":"";
      PanelLabel("L_PL", StringFormat(" Float : %s%.2f $",plSign,floatPL),lx+20,row,plCol,fs);
      PanelLabel("B_PL", "["+ProgBar(MathAbs(floatPL),InpTP3Dollars*MathMax(posCount,1),10)+"]",px+55,row,plCol,fsS); row+=lh-1;
      string holdBar=ProgBar(holdMin,InpMaxHoldMinutes,10);
      color  holdCol=holdMin>InpMaxHoldMinutes*0.8?clrOrange:C'90,135,200';
      PanelLabel("B_HOLD",StringFormat(" Hold  : %d/%dmin [%s]",holdMin,InpMaxHoldMinutes,holdBar),lx+20,row,holdCol,fsS);
      row+=lh+3;
   }
   else
   {
      PanelLabel("SEC_TR"," ◆ NO ACTIVE TRADE",lx+20,row,C'55,58,88',fsS); row+=lh+1;
      // hide stale trade labels
      string clrList[]={"L_EN2","L_SL2","B_T1","V_T1","B_T2","V_T2","B_T3","V_T3","L_NOW","L_PL","B_PL","B_HOLD","THDR"};
      for(int i=0;i<ArraySize(clrList);i++) PanelLabel(clrList[i],"",px,row,clrNONE,1);
   }

   // ══════════════════════════════════════════
   // [9] SESSION + PERFORMANCE STATS
   // ══════════════════════════════════════════
   PanelRect("SEP_ST2",x,row,W,1,C'28,32,60'); row+=3;
   PanelLabel("SEC_SES"," ◆ SESSION & PERFORMANCE",lx+20,row,C'80,160,255',fsS); row+=lh-1;

   // Session
   color sesCol=gSessionOK?C'0,215,85':C'70,75,100';
   string sesTxt=gSessionOK?" ● SESSION ON  (WIB 04-15)":" ○ SESSION OFF (WIB 04-15)";
   PanelLabel("V_SES",sesTxt,lx+20,row,sesCol,fsS); row+=lh-1;
   string modeStr=StringFormat(" Mode:%-10s Entry:%-10s Rev:%s",InpModeSignal,InpEntryMode,InpAutoReversal?"ON":"OFF");
   PanelLabel("V_MODE",modeStr,lx+20,row,C'90,95,130',fsS); row+=lh+2;

   // ── PERFORMANCE STATS BOX ──
   int    totalClosed = gWinCount + gLossCount;
   double wr          = totalClosed>0?(gWinCount*100.0/totalClosed):0;
   double totalPLall  = gTotalClosedPL + floatPL;  // closed + floating
   color  wrCol       = wr>=60?C'0,205,85':wr>=50?C'200,155,0':C'225,50,50';
   color  netCol      = totalPLall>=0?C'0,235,95':C'235,55,55';
   color  closedCol   = gTotalClosedPL>=0?C'0,205,80':C'220,50,50';

   PanelRect("STAT_BG",x,row,W,lh*5+10,C'12,14,28',C'40,50,100');
   row+=3;
   PanelLabel("L_STAT1",StringFormat(" Trades  : %d  (W:%d  L:%d)",totalClosed,gWinCount,gLossCount),
              lx+20,row,C'160,165,200',fsS); row+=lh-1;
   PanelLabel("L_STAT2",StringFormat(" WinRate : %.1f%%",wr),lx+20,row,wrCol,fsS);
   PanelLabel("B_WR","["+ProgBar(wr,100.0,12)+"]",px+60,row,wrCol,fsS); row+=lh-1;
   PanelLabel("L_STAT3",StringFormat(" Closed PL: %s%.2f $",gTotalClosedPL>=0?"+":"",gTotalClosedPL),
              lx+20,row,closedCol,fsS); row+=lh-1;
   PanelLabel("L_STAT4",StringFormat(" Float PL : %s%.2f $",floatPL>=0?"+":"",floatPL),
              lx+20,row,floatPL>=0?C'0,200,80':C'220,50,50',fsS); row+=lh-1;
   PanelLabel("L_STAT5",StringFormat(" NET P&L  : %s%.2f $",totalPLall>=0?"+":"",totalPLall),
              lx+20,row,netCol,fs); row+=lh+4;

   // Total signals opened
   PanelLabel("V_SIG",StringFormat(" Signals opened: %d",gTotalSignals),lx+20,row,C'80,90,130',fsS);
   row+=lh+4;

   // ── Resize BG ──
   PanelRect("BG", x,y0,W,row-y0+4,C'8,10,20',C'35,45,90');
   PanelRect("HDR",x,y0,W,lh+6,    C'14,16,38',C'50,70,160');

   ChartRedraw(0);
}
//+------------------------------------------------------------------+
