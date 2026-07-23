//+------------------------------------------------------------------+
//|  ZS_V10_Standalone_EA.mq5                                       |
//|  ZS XAUUSD V10 SR Precision Pro — Standalone MT5 EA            |
//|  Replicates Pine Script indicator ZS XAUUSD V10 logic 1:1      |
//|  No TradingView, no server, no webhook required                 |
//|  v2.0 — Auto Reversal + Pro Dashboard Panel                    |
//+------------------------------------------------------------------+
#property copyright "ZS Trading"
#property version   "2.00"
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
int    gTotalSignals   = 0;
string gLastReversalInfo = "";   // "SELL→BUY @ 3185.20"
bool   gReversalAlert  = false;  // flash saat reversal baru terjadi
int    gReversalFlash  = 0;      // countdown flash

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

   if(hEmaFast==INVALID_HANDLE || hEmaMid==INVALID_HANDLE || hEmaSlow==INVALID_HANDLE ||
      hEmaM5Fast==INVALID_HANDLE || hEmaM15Fast==INVALID_HANDLE ||
      hRsi==INVALID_HANDLE || hAdx==INVALID_HANDLE || hAtr==INVALID_HANDLE || hBB==INVALID_HANDLE)
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
      SendReport("SNAPSHOT", "", 0, 0);
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
         gLossCount--; gWinCount++;
         double plTP3Buy = CalcCurrentPL();
         CloseMyPositions();
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
         gLossCount--; gWinCount++;
         double plTP3Sell = CalcCurrentPL();
         CloseMyPositions();
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
         CloseMyPositions(); ResetTrade();
         SendReport("CLOSE", "TIMEOUT", closeTimeout, plTimeout);
         if(InpShowPanel) DrawPanel();
         return;
      }
   }
   else if(!HasActivePosition() && gDir != 0)
   {
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
   // EXECUTE ORDER
   // ================================================================
   int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
   double entryPrice, sl, tp1, tp2, tp3;
   bool ok=false;
   int score=(finalDir==1)?gBuyScore:gSellScore;

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
      gLossCount++;
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

// Progress bar: filled = █  empty = ░
string ProgBar(double val, double maxVal, int width)
{
   if(maxVal <= 0) return "";
   int filled = (int)MathRound(MathMin(MathMax(val, 0) / maxVal, 1.0) * width);
   string bar = "";
   for(int i = 0; i < width; i++)
      bar += (i < filled) ? "█" : "░";
   return bar;
}

// Score bar with percentage text
string ScoreBar(int score, int minQ, int width)
{
   int maxScore = 140; // approximate max possible score
   int filled   = (int)MathRound(MathMin((double)score / maxScore, 1.0) * width);
   string bar   = "";
   for(int i = 0; i < width; i++)
      bar += (i < filled) ? "▓" : "░";
   return bar;
}

// TP progress bar: progress from entry toward TP level, clipped 0-width
string TPBar(double curPrice, double entry, double tp, int width, bool isBuy)
{
   if(entry == 0 || tp == 0 || entry == tp) return StringFormat("%.*s", width, "░░░░░░░░░░░░░░░░");
   double range    = MathAbs(tp - entry);
   double progress = isBuy ? (curPrice - entry) : (entry - curPrice);
   int    filled   = (int)MathRound(MathMin(MathMax(progress / range, 0.0), 1.0) * width);
   string bar = "";
   for(int i = 0; i < width; i++)
      bar += (i < filled) ? "█" : "░";
   return bar;
}

// Object helpers
void PanelLabel(string name, string text, int x, int y, color clr, int fontSize=0)
{
   string fullName = PANEL_PREFIX + name;
   int fs = fontSize > 0 ? fontSize : InpPanelFontSize;
   if(ObjectFind(0, fullName) < 0)
   {
      ObjectCreate(0, fullName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, fullName, OBJPROP_CORNER,     CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, fullName, OBJPROP_ANCHOR,     ANCHOR_RIGHT_UPPER);
      ObjectSetString (0, fullName, OBJPROP_FONT,       "Courier New");
      ObjectSetInteger(0, fullName, OBJPROP_BACK,       false);
      ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE, false);
   }
   ObjectSetString (0, fullName, OBJPROP_TEXT,      text);
   ObjectSetInteger(0, fullName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, fullName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, fullName, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, fullName, OBJPROP_FONTSIZE,  fs);
}

void PanelRect(string name, int x, int y, int w, int h, color bgColor, color borderColor = C'40,40,60')
{
   string fullName = PANEL_PREFIX + name;
   if(ObjectFind(0, fullName) < 0)
   {
      ObjectCreate(0, fullName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, fullName, OBJPROP_CORNER,      CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, fullName, OBJPROP_ANCHOR,      ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, fullName, OBJPROP_BACK,        true);
      ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE,  false);
      ObjectSetInteger(0, fullName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   }
   ObjectSetInteger(0, fullName, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, fullName, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, fullName, OBJPROP_XSIZE,       w);
   ObjectSetInteger(0, fullName, OBJPROP_YSIZE,       h);
   ObjectSetInteger(0, fullName, OBJPROP_BGCOLOR,     bgColor);
   ObjectSetInteger(0, fullName, OBJPROP_BORDER_COLOR,borderColor);
}

void PanelDelete()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total-1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, PANEL_PREFIX) == 0)
         ObjectDelete(0, name);
   }
}

void PanelCreate()
{
   PanelRect("BG",       InpPanelX, InpPanelY, 310, 600, C'10,12,22');
   PanelRect("BG_TITLE", InpPanelX, InpPanelY, 310, 24,  C'18,20,42');
}

//==========================================================================
//  DRAW PANEL — called every tick
//==========================================================================
void DrawPanel()
{
   if(!InpShowPanel) return;

   int x   = InpPanelX;
   int y0  = InpPanelY;
   int lh  = InpPanelFontSize + 6;
   int fs  = InpPanelFontSize;
   int fsS = MathMax(fs - 1, 7);  // small font
   int px  = x + 6;               // right margin for value column (closer to right edge)
   int lx  = px + 150;            // label column (further from right = further left on screen)
   int W   = 310;

   // ── Spread ──
   double spread = SymbolInfoInteger(InpSymbol, SYMBOL_SPREAD) * SymbolInfoDouble(InpSymbol, SYMBOL_POINT);

   // ── Current price & P/L ──
   double curPrice = (gDir==1) ? SymbolInfoDouble(InpSymbol, SYMBOL_BID)
                                : SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   double totalPL  = 0;
   int    posCount = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()==InpMagicNumber && posInfo.Symbol()==InpSymbol)
      {
         totalPL += posInfo.Profit() + posInfo.Swap();
         posCount++;
      }
   }

   bool   hasTrade = (gDir != 0 && HasActivePosition());
   int    holdMin  = hasTrade ? (int)((TimeCurrent()-gOpenTime)/60) : 0;

   // ── Status color ──
   color statusBG, statusFG;
   if     (gPanelStatus=="BUY ACTIVE")    { statusBG=C'0,60,20';   statusFG=C'0,255,100'; }
   else if(gPanelStatus=="SELL ACTIVE")   { statusBG=C'60,0,10';   statusFG=C'255,60,60'; }
   else if(gPanelStatus=="PREDICT BUY")   { statusBG=C'0,40,15';   statusFG=C'0,200,80';  }
   else if(gPanelStatus=="PREDICT SELL")  { statusBG=C'40,5,5';    statusFG=C'220,50,50'; }
   else if(gPanelStatus=="COOLDOWN")      { statusBG=C'40,25,0';   statusFG=clrOrange;    }
   else if(gPanelStatus=="SESSION OFF")   { statusBG=C'25,25,25';  statusFG=clrGray;      }
   else                                   { statusBG=C'18,18,35';  statusFG=C'120,120,160'; }

   // ── Reversal flash color ──
   if(gReversalAlert)
   {
      statusBG = C'50,20,0';
      statusFG = clrOrange;
   }

   int row = y0 + 2;

   // ════════════════════════════════════
   // HEADER
   // ════════════════════════════════════
   PanelRect("HDR", x, row, W, lh+4, C'18,20,45', C'60,80,160');
   PanelLabel("T_EA",   " ⚡ ZS V10 SR PRECISION PRO", lx+10, row+3, clrGold, fs+1);
   row += lh + 6;

   // Symbol | Spread | Time
   MqlDateTime mt;
   TimeToStruct(TimeCurrent(), mt);
   string timeStr = StringFormat("%02d:%02d:%02d", mt.hour, mt.min, mt.sec);
   PanelLabel("T_SYM", StringFormat(" %s  Spd:%.1f  %s UTC", InpSymbol, spread, timeStr), lx+10, row, C'140,160,200', fsS);
   row += lh;

   // ════════════════════════════════════
   // STATUS BOX (full width, color block)
   // ════════════════════════════════════
   PanelRect("STBG", x, row, W, lh+6, statusBG, statusFG);
   string statusText = gReversalAlert
      ? StringFormat(" ⚡ REVERSAL! %s", gLastReversalInfo)
      : StringFormat(" %s", gPanelStatus);
   if(StringLen(gPanelSetup) > 1 && !gReversalAlert)
      statusText += "  [" + gPanelSetup + "]";
   PanelLabel("V_STATUS", statusText, lx+10, row+3, statusFG, fs+1);
   row += lh + 8;

   // Reverse mode tag
   if(InpReverseMode)
   {
      PanelRect("REVBG", x, row, W, lh+2, C'45,20,0', clrOrange);
      PanelLabel("V_REV", " ⟲  REVERSE MODE ACTIVE", lx+10, row+2, clrOrange, fsS);
      row += lh + 4;
   }

   // ════════════════════════════════════
   // SECTION: SIGNAL STRENGTH
   // ════════════════════════════════════
   PanelLabel("SEC1", " ▸ SIGNAL STRENGTH", lx+10, row, C'100,120,200', fsS);
   row += lh - 2;

   // BUY score bar
   int    buyPct   = (int)MathRound(gBuyScore * 100.0 / 140);
   string buyBar   = ScoreBar(gBuyScore, gMinQuality, 12);
   color  buySCL   = gBuyScore >= gMinQuality ? C'0,230,80' : C'80,80,100';
   color  buyLbl   = gBuyScore >= gMinQuality ? C'0,230,80' : C'160,160,180';
   PanelLabel("L_BS", " BUY ", lx+10, row, buyLbl, fsS);
   PanelLabel("B_BS", buyBar,   px+50, row, buySCL, fsS);
   PanelLabel("V_BS", StringFormat(" %3d / %d", gBuyScore, gMinQuality), px, row, buySCL, fsS);
   row += lh - 1;

   // SELL score bar
   int    sellPct  = (int)MathRound(gSellScore * 100.0 / 140);
   string sellBar  = ScoreBar(gSellScore, gMinQuality, 12);
   color  sellSCL  = gSellScore >= gMinQuality ? C'240,60,60' : C'80,80,100';
   color  sellLbl  = gSellScore >= gMinQuality ? C'240,60,60' : C'160,160,180';
   PanelLabel("L_SS", " SELL", lx+10, row, sellLbl, fsS);
   PanelLabel("B_SS", sellBar,  px+50, row, sellSCL, fsS);
   PanelLabel("V_SS", StringFormat(" %3d / %d", gSellScore, gMinQuality), px, row, sellSCL, fsS);
   row += lh + 2;

   // Auto reversal status
   string revStr = InpAutoReversal
      ? StringFormat(" AUTO-REV ON  (min=%d)", InpReversalMinScore)
      : " AUTO-REV OFF";
   color revClr = InpAutoReversal ? C'200,160,0' : C'70,70,90';
   PanelLabel("V_AREV", revStr, lx+10, row, revClr, fsS);
   row += lh;

   // Last reversal info
   if(StringLen(gLastReversalInfo) > 0)
   {
      PanelLabel("V_LREV", StringFormat(" Last flip: %s", gLastReversalInfo), lx+10, row, C'180,120,0', fsS);
      row += lh - 1;
   }

   // ════════════════════════════════════
   // SECTION: MULTI-TIMEFRAME TREND
   // ════════════════════════════════════
   PanelLabel("SEP2", " ─────────────────────────────", lx+10, row, C'40,45,75', fsS); row += lh - 3;
   PanelLabel("SEC2", " ▸ MULTI-TIMEFRAME TREND", lx+10, row, C'100,120,200', fsS); row += lh - 2;

   // M1 / M5 / M15 in a single row
   string m1t = gM1Bull ? "M1 ▲BULL" : gM1Bear ? "M1 ▼BEAR" : "M1 ─MIX";
   string m5t = gM5Bull ? "M5 ▲BULL" : gM5Bear ? "M5 ▼BEAR" : "M5 ─MIX";
   string m15t= gM15Bull? "M15▲BULL" : gM15Bear? "M15▼BEAR" : "M15─MIX";
   color m1c  = gM1Bull  ? C'0,210,80'  : gM1Bear  ? C'230,55,55'  : C'120,120,140';
   color m5c  = gM5Bull  ? C'0,210,80'  : gM5Bear  ? C'230,55,55'  : C'120,120,140';
   color m15c = gM15Bull ? C'0,210,80'  : gM15Bear ? C'230,55,55'  : C'120,120,140';

   PanelLabel("V_M1",  " "+m1t,  lx+10,    row, m1c,  fsS);
   PanelLabel("V_M5",  " "+m5t,  lx-40,    row, m5c,  fsS);
   PanelLabel("V_M15", " "+m15t, lx-100,   row, m15c, fsS);
   row += lh;

   // Regime + Bull/Bear count
   string regime = (gBullCount>=2) ? "BUY BIAS" : (gBearCount>=2) ? "SELL BIAS" : gSidewaysFlag ? "SIDEWAYS" : "MIXED";
   color  regCol = (gBullCount>=2) ? C'0,210,80' : (gBearCount>=2) ? C'230,55,55' : C'180,120,0';
   string countTxt = StringFormat(" Bulls:%d  Bears:%d  Regime:", gBullCount, gBearCount);
   PanelLabel("V_REGC", countTxt, lx+10, row, C'140,140,160', fsS);
   PanelLabel("V_REGV", " "+regime, px,   row, regCol, fsS);
   row += lh + 2;

   // ════════════════════════════════════
   // SECTION: INDICATORS
   // ════════════════════════════════════
   PanelLabel("SEP3", " ─────────────────────────────", lx+10, row, C'40,45,75', fsS); row += lh - 3;
   PanelLabel("SEC3", " ▸ INDICATORS", lx+10, row, C'100,120,200', fsS); row += lh - 2;

   // RSI gauge
   string rsiBar = ProgBar(gRsiVal, 100.0, 14);
   color  rsiCol = (gRsiVal >= InpOverboughtRSI) ? C'230,55,55' :
                   (gRsiVal <= InpOversoldRSI)   ? C'0,200,80'  :
                   (gRsiVal >= 50)               ? C'200,160,0' : C'0,180,120';
   string rsiTag = (gRsiVal>=InpOverboughtRSI)?" PEAK":(gRsiVal<=InpOversoldRSI)?" DEEP":" OK";
   PanelLabel("L_RSI", " RSI  ", lx+10, row, C'160,160,180', fsS);
   PanelLabel("B_RSI", rsiBar,    px+55, row, rsiCol, fsS);
   PanelLabel("V_RSI", StringFormat(" %.1f%s", gRsiVal, rsiTag), px, row, rsiCol, fsS);
   row += lh - 1;

   // ADX gauge
   string adxBar = ProgBar(gAdxVal, 50.0, 14);
   color  adxCol = (gAdxVal >= 25) ? clrGold : C'100,100,130';
   string adxTag = (gAdxVal >= 25) ? " TREND" : (gAdxVal <= InpSideMaxADX) ? " SIDE" : " WEAK";
   PanelLabel("L_ADX", " ADX  ", lx+10, row, C'160,160,180', fsS);
   PanelLabel("B_ADX", adxBar,    px+55, row, adxCol, fsS);
   PanelLabel("V_ADX", StringFormat(" %.1f%s", gAdxVal, adxTag), px, row, adxCol, fsS);
   row += lh - 1;

   // ATR
   PanelLabel("L_ATR", StringFormat(" ATR  %.3f  (OK:%s)", gAtrVal,
              (gAtrVal>=InpMinATRPrice&&gAtrVal<=InpMaxATRPrice)?"YES":"NO"),
              lx+10, row, (gAtrVal>=InpMinATRPrice&&gAtrVal<=InpMaxATRPrice)?C'0,180,100':C'160,80,80', fsS);
   row += lh + 2;

   // ════════════════════════════════════
   // SECTION: SR LEVELS
   // ════════════════════════════════════
   PanelLabel("SEP4", " ─────────────────────────────", lx+10, row, C'40,45,75', fsS); row += lh - 3;
   PanelLabel("SEC4", " ▸ SUPPORT / RESISTANCE", lx+10, row, C'100,120,200', fsS); row += lh - 2;

   string supTxt = gSupLevel > 0 ? StringFormat("%.2f", gSupLevel) : "-";
   string resTxt = gResLevel > 0 ? StringFormat("%.2f", gResLevel) : "-";
   PanelLabel("V_SRLVL", StringFormat(" Sup: %s    Res: %s", supTxt, resTxt), lx+10, row, C'160,160,180', fsS);
   row += lh - 1;

   color srCol = (gSRStatus=="NEUTRAL") ? C'100,100,130' :
                 (StringFind(gSRStatus,"BUY")>=0 || StringFind(gSRStatus,"SUPPORT")>=0) ? C'0,200,80' : C'230,55,55';
   PanelLabel("V_SRS", StringFormat(" Status: %s", gSRStatus), lx+10, row, srCol, fsS);
   row += lh - 1;

   bool anyBlockBuy  = gSRBlockBuy  || gPrecBlockBuy  || gPeakBlock;
   bool anyBlockSell = gSRBlockSell || gPrecBlockSell || gDeepBlock;
   string blockTxt = (!anyBlockBuy && !anyBlockSell)     ? "✓ CLEAR" :
                     (anyBlockBuy  && anyBlockSell)       ? "✗ BOTH BLOCKED" :
                     anyBlockBuy                          ? (gPeakBlock?"✗ PEAK(RSI)":"✗ BLOCK BUY") :
                                                            (gDeepBlock?"✗ DEEP(RSI)":"✗ BLOCK SELL");
   color blockCol = (blockTxt=="✓ CLEAR") ? C'0,180,80' : C'230,55,55';
   PanelLabel("V_BLK", StringFormat(" Filter: %s", blockTxt), lx+10, row, blockCol, fsS);
   row += lh + 2;

   // ════════════════════════════════════
   // SECTION: ACTIVE TRADE
   // ════════════════════════════════════
   PanelLabel("SEP5", " ─────────────────────────────", lx+10, row, C'40,45,75', fsS); row += lh - 3;

   if(hasTrade)
   {
      bool isBuy = (gDir == 1);
      color tradeHdr = isBuy ? C'0,80,30' : C'80,10,10';
      color tradeFG  = isBuy ? C'0,240,100' : C'255,70,70';
      string dirLabel= isBuy ? "▲ BUY TRADE ACTIVE" : "▼ SELL TRADE ACTIVE";

      PanelRect("THDR", x, row, W, lh+2, tradeHdr, tradeFG);
      PanelLabel("SEC5", StringFormat(" ▸ %s  [%d pos]", dirLabel, posCount), lx+10, row+2, tradeFG, fsS);
      row += lh + 4;

      // Entry / SL
      double distToSL  = MathAbs(curPrice - gSL);
      double distToTP3 = MathAbs(curPrice - gTP3);
      PanelLabel("L_EN2", StringFormat(" Entry  : %.2f", gEntry), lx+10, row, C'200,180,80', fsS);
      row += lh - 1;
      PanelLabel("L_SL2", StringFormat(" SL     : %.2f   [-$%.2f]", gSL, InpSLDollars), lx+10, row, C'230,55,55', fsS);
      row += lh + 2;

      // TP Progress bars
      double tp1Pct = 0, tp2Pct = 0, tp3Pct = 0;
      if(gEntry != 0 && gTP1 != gEntry)
         tp1Pct = MathMin(MathMax(isBuy?(curPrice-gEntry)/(gTP1-gEntry):(gEntry-curPrice)/(gEntry-gTP1),0),1.0)*100;
      if(gEntry != 0 && gTP2 != gEntry)
         tp2Pct = MathMin(MathMax(isBuy?(curPrice-gEntry)/(gTP2-gEntry):(gEntry-curPrice)/(gEntry-gTP2),0),1.0)*100;
      if(gEntry != 0 && gTP3 != gEntry)
         tp3Pct = MathMin(MathMax(isBuy?(curPrice-gEntry)/(gTP3-gEntry):(gEntry-curPrice)/(gEntry-gTP3),0),1.0)*100;

      // TP1
      string tp1Bar  = TPBar(curPrice, gEntry, gTP1, 12, isBuy);
      color  tp1Col  = gHitTP1 ? clrGold : C'0,200,80';
      string tp1Mark = gHitTP1 ? " ✓ BE" : StringFormat(" %3.0f%%", tp1Pct);
      PanelLabel("B_T1", " TP1 [" + tp1Bar + "]", lx+10, row, tp1Col, fsS);
      PanelLabel("V_T1", StringFormat(" %.2f%s", gTP1, tp1Mark), px, row, tp1Col, fsS);
      row += lh - 1;

      // TP2
      string tp2Bar  = TPBar(curPrice, gEntry, gTP2, 12, isBuy);
      color  tp2Col  = gHitTP2 ? clrGold : C'0,180,80';
      string tp2Mark = gHitTP2 ? " ✓ TP1" : StringFormat(" %3.0f%%", tp2Pct);
      PanelLabel("B_T2", " TP2 [" + tp2Bar + "]", lx+10, row, tp2Col, fsS);
      PanelLabel("V_T2", StringFormat(" %.2f%s", gTP2, tp2Mark), px, row, tp2Col, fsS);
      row += lh - 1;

      // TP3
      string tp3Bar  = TPBar(curPrice, gEntry, gTP3, 12, isBuy);
      color  tp3Col  = C'0,160,80';
      PanelLabel("B_T3", " TP3 [" + tp3Bar + "]", lx+10, row, tp3Col, fsS);
      PanelLabel("V_T3", StringFormat(" %.2f  %3.0f%%", gTP3, tp3Pct), px, row, tp3Col, fsS);
      row += lh + 1;

      // Price now
      PanelLabel("L_NOW", StringFormat(" Price : %.2f", curPrice), lx+10, row, clrWhite, fsS);
      row += lh - 1;

      // P/L with progress bar toward TP3
      color plCol  = totalPL >= 0 ? C'0,230,90' : C'230,55,55';
      string plSign= totalPL >= 0 ? "+" : "";
      string plBar = ProgBar(MathAbs(totalPL), InpTP3Dollars * posCount, 12);
      PanelLabel("L_PL",  StringFormat(" P/L   : %s%.2f $", plSign, totalPL), lx+10, row, plCol, fs);
      row += lh - 1;
      PanelLabel("B_PL",  " [" + plBar + "]", lx+10, row, plCol, fsS);
      row += lh - 1;

      // Hold time bar
      string holdBar = ProgBar(holdMin, InpMaxHoldMinutes, 12);
      color  holdCol = holdMin > InpMaxHoldMinutes*0.8 ? clrOrange : C'100,140,200';
      PanelLabel("B_HOLD"," [" + holdBar + "] " + StringFormat("%d/%dmin", holdMin, InpMaxHoldMinutes), lx+10, row, holdCol, fsS);
      row += lh + 2;
   }
   else
   {
      PanelLabel("SEC5", " ▸ NO ACTIVE TRADE", lx+10, row, C'60,60,90', fsS);
      row += lh;
      // Clear old trade labels
      PanelLabel("L_EN2","", lx, row, clrNONE, 1); PanelLabel("L_SL2","", lx, row, clrNONE, 1);
      PanelLabel("B_T1", "", lx, row, clrNONE, 1); PanelLabel("V_T1", "", px, row, clrNONE, 1);
      PanelLabel("B_T2", "", lx, row, clrNONE, 1); PanelLabel("V_T2", "", px, row, clrNONE, 1);
      PanelLabel("B_T3", "", lx, row, clrNONE, 1); PanelLabel("V_T3", "", px, row, clrNONE, 1);
      PanelLabel("L_NOW","", lx, row, clrNONE, 1); PanelLabel("L_PL","",  lx, row, clrNONE, 1);
      PanelLabel("B_PL", "", lx, row, clrNONE, 1); PanelLabel("B_HOLD","",lx, row, clrNONE, 1);
      PanelLabel("THDR", "", lx, row, clrNONE, 1);
      row += 2;
   }

   // ════════════════════════════════════
   // SECTION: SESSION + STATS
   // ════════════════════════════════════
   PanelLabel("SEP6", " ─────────────────────────────", lx+10, row, C'40,45,75', fsS); row += lh - 3;

   // Session
   color sesCol = gSessionOK ? C'0,210,80' : C'80,80,100';
   string sesTxt= gSessionOK ? " ● SESSION ON  (WIB 04-15)" : " ○ SESSION OFF (WIB 04-15)";
   PanelLabel("V_SES", sesTxt, lx+10, row, sesCol, fsS); row += lh - 1;

   // Mode info
   string modeInfo = StringFormat(" Mode:%s  Entry:%s  Rev:%s",
                                   InpModeSignal, InpEntryMode, InpAutoReversal?"ON":"OFF");
   PanelLabel("V_MODE", modeInfo, lx+10, row, C'100,100,140', fsS); row += lh + 1;

   // Win/Loss stats
   int    totalTrades = gWinCount + gLossCount;
   double wr          = totalTrades > 0 ? (gWinCount * 100.0 / totalTrades) : 0;
   string wrBar       = ProgBar(wr, 100.0, 14);
   color  wrCol       = wr >= 60 ? C'0,200,80' : wr >= 50 ? C'200,160,0' : C'220,50,50';

   PanelLabel("L_STAT", StringFormat(" W:%d  L:%d  Total:%d  WR:%.0f%%", gWinCount, gLossCount, totalTrades, wr),
              lx+10, row, C'160,160,180', fsS); row += lh - 1;
   PanelLabel("B_WR", " [" + wrBar + "] " + StringFormat("%.0f%%", wr), lx+10, row, wrCol, fsS);
   row += lh + 4;

   // ── Resize background to content ──
   PanelRect("BG",       x, y0, W, row - y0 + 4, C'10,12,22', C'40,50,90');
   PanelRect("HDR",      x, y0, W, lh+4,          C'18,20,45', C'60,80,160');

   ChartRedraw(0);
}
//+------------------------------------------------------------------+
