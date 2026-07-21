//+------------------------------------------------------------------+
//|  ZS_V10_Standalone_EA.mq5                                       |
//|  ZS XAUUSD V10 SR Precision Pro — Standalone MT5 EA            |
//|                                                                  |
//|  Replicates Pine Script indicator ZS XAUUSD V10 logic 1:1      |
//|  — EMA M1/M5/M15 trend, RSI, ADX, ATR, BB, SR levels          |
//|  — Score system, all entry conditions, session WIB filter      |
//|  — Trailing stop: TP1→BE, TP2→TP1, TP3→Close                  |
//|  — No TradingView, no server, no webhook required              |
//|                                                                  |
//|  INSTALL:                                                        |
//|  1. Copy ke: MT5 > File > Open Data Folder > MQL5 > Experts    |
//|  2. Compile (F7)                                                 |
//|  3. Attach ke chart XAUUSDc timeframe M1                       |
//|  4. Aktifkan "Allow Automated Trading"                          |
//+------------------------------------------------------------------+
#property copyright "ZS Trading"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//==================== SIGNAL MODE ====================//
input group "=== SIGNAL MODE ==="
input string InpModeSignal        = "AUTO BUY SELL"; // AUTO BUY SELL / BUY ONLY / SELL ONLY
input string InpEntryMode         = "BALANCED";       // SAFE / BALANCED / AGGRESSIVE
input int    InpMinQualitySafe    = 88;
input int    InpMinQualityBal     = 82;
input int    InpMinQualityAgg     = 72;
input int    InpScoreGap          = 6;   // Minimal selisih BUY vs SELL score
input int    InpCooldownBars      = 2;   // Cooldown bars setelah TP/SL

//==================== SESSION FILTER ====================//
input group "=== SESSION FILTER WIB ==="
input bool   InpUseWIBFilter      = true;  // Aktifkan filter jam 04:00-15:00 WIB

//==================== TP / SL ====================//
input group "=== TP / SL ==="
input double InpPointSize         = 0.01;  // Point Size XAUUSD
input int    InpTP1Points         = 200;
input int    InpTP2Points         = 600;
input int    InpTP3Points         = 900;
input string InpSLMode            = "ADAPTIVE"; // ADAPTIVE / FIXED
input int    InpATRLen            = 14;
input double InpATRSLMult         = 1.45;
input int    InpMinSLPoints       = 650;
input int    InpMaxSLPoints       = 900;
input int    InpFixedSLPoints     = 800;
input int    InpMaxHoldMinutes    = 180;

//==================== EMA TREND ====================//
input group "=== EMA TREND ==="
input int    InpEmaFastLen        = 20;   // EMA Fast M1
input int    InpEmaMidLen         = 50;   // EMA Mid M1
input int    InpEmaSlowLen        = 200;  // EMA Slow M1 (EMA200)
input int    InpMtfEmaFastLen     = 50;   // EMA Fast M5/M15
input int    InpMtfEmaSlowLen     = 200;  // EMA Slow M5/M15
input int    InpEma200SlopeBars   = 5;    // Bar untuk hitung slope EMA200

//==================== MOMENTUM ====================//
input group "=== MOMENTUM ==="
input int    InpRsiLen            = 14;
input int    InpAdxLen            = 14;
input int    InpAdxSmooth         = 14;
input int    InpBBLen             = 50;
input double InpBBDev             = 2.4;
input double InpMinBodyRatio      = 0.30;
input double InpCloseEdge         = 0.58;
input double InpMaxCandleATR      = 2.6;   // Anti spike
input double InpSideMaxADX        = 22.0;
input double InpMinATRPrice       = 0.25;
input double InpMaxATRPrice       = 7.00;

//==================== SR LEVELS ====================//
input group "=== HIGH VOLUME SR ==="
input int    InpSRLookback        = 20;
input double InpSRBoxWidth        = 1.0;   // SR Box Width ATR
input double InpSRBufferATR       = 0.30;
input int    InpSRBoostPts        = 8;
input int    InpSRBreakBoostPts   = 12;
input int    InpSRDangerPenalty   = 18;
input bool   InpSRBoostBlock      = true;  // BOOST + BLOCK DANGER
input int    InpSRRetestBars      = 18;    // Maks bar retest setelah break
input int    InpRetestBoostPts    = 16;

//==================== PRECISION SR RULES ====================//
input group "=== PRECISION SR RULES ==="
input bool   InpBlockBuyAtRedBox        = true;
input bool   InpBlockSellAtGreenBox     = true;
input bool   InpRequireBreakForReversal = true;

//==================== SR STRENGTH SETUP ====================//
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
input string InpSRStrongSLMode       = "ADAPTIVE"; // ADAPTIVE / FIXED
input double InpSRStrongATRSLMult    = 1.30;
input int    InpSRStrongMinSL        = 550;
input int    InpSRStrongMaxSL        = 950;
input int    InpSRStrongFixedSL      = 700;
input int    InpSRMediumTP1Pts       = 150;
input int    InpSRMediumTP2Pts       = 400;
input int    InpSRMediumTP3Pts       = 650;
input string InpSRMediumSLMode       = "ADAPTIVE"; // ADAPTIVE / FIXED
input double InpSRMediumATRSLMult    = 1.05;
input int    InpSRMediumMinSL        = 420;
input int    InpSRMediumMaxSL        = 760;
input int    InpSRMediumFixedSL      = 560;

//==================== ORDER ====================//
input group "=== ORDER ==="
input string InpSymbol            = "XAUUSDc";
input int    InpMagicNumber       = 909506;
input double InpLot               = 0.01;
input double InpMaxLot            = 1.0;
input int    InpSlippage          = 20;
input bool   InpTrailingEnabled   = true;
input bool   InpDeleteOnNew       = true;
input bool   InpEnabled           = true;

//==================== INDICATOR HANDLES ====================//
int hEmaFast, hEmaMid, hEmaSlow;
int hEmaM5Fast, hEmaM5Slow;
int hEmaM15Fast, hEmaM15Slow;
int hRsi, hAdx, hAtr, hBB;

//==================== TRADE OBJECTS ====================//
CTrade        trade;
CPositionInfo posInfo;

//==================== ACTIVE TRADE STATE ====================//
double gEntry=0, gSL=0, gTP1=0, gTP2=0, gTP3=0;
int    gDir=0;
bool   gHitTP1=false, gHitTP2=false;
datetime gOpenTime=0;

//==================== BAR & COOLDOWN TRACKING ====================//
datetime gLastBarTime=0;
int    gLastExitBar=0;  // bars(M1) value when last trade closed

//==================== SR STATE ====================//
double gSupLevel=0,  gSupLevel1=0;   // support top, support bottom
double gResLevel=0,  gResLevel1=0;   // resistance bottom, resistance top
bool   gResIsSup=false, gSupIsRes=false;
// Break tracking for retest
double gBreakResHigh=0;  int gBreakResBar=0;
double gBreakSupLow=0;   int gBreakSupBar=0;
// Previous SR for same-bar change detection
double gPrevSupLevel=0, gPrevResLevel=0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(!InpEnabled) { Print("EA dinonaktifkan."); return INIT_SUCCEEDED; }

   // Create all indicator handles once
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
      Print("ERROR: Gagal membuat indicator handles. Pastikan symbol benar: ", InpSymbol);
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   Print("ZS V10 Standalone EA v1.0 aktif | Symbol: ", InpSymbol, " | Mode: ", InpModeSignal, " | Entry: ", InpEntryMode);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(hEmaFast);  IndicatorRelease(hEmaMid);   IndicatorRelease(hEmaSlow);
   IndicatorRelease(hEmaM5Fast);IndicatorRelease(hEmaM5Slow);
   IndicatorRelease(hEmaM15Fast);IndicatorRelease(hEmaM15Slow);
   IndicatorRelease(hRsi); IndicatorRelease(hAdx);
   IndicatorRelease(hAtr); IndicatorRelease(hBB);
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
// Session filter: WIB 04:00-15:00 = UTC 21:00 (prev) - 08:00
//+------------------------------------------------------------------+
bool InWIBSession()
{
   if(!InpUseWIBFilter) return true;
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;
   // UTC 21,22,23 = WIB 04,05,06 (dini hari WIB)
   // UTC 00-07    = WIB 07-14
   // UTC 08       = WIB 15 (batas akhir)
   return (h >= 21 || h < 8);
}

//+------------------------------------------------------------------+
// Hitung pivot high: apakah bar[shift] adalah highest di window lookback?
//+------------------------------------------------------------------+
double CalcPivotHigh(int lookback, int shift)
{
   int needed = shift + lookback + 1;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(InpSymbol, PERIOD_M1, 0, needed + lookback, rates) < needed + lookback) return 0;

   int idx = shift; // rates is series: rates[0]=current, rates[shift]=bar we check
   if(idx < lookback || idx + lookback >= ArraySize(rates)) return 0;

   double cHigh = rates[idx].high;
   for(int i = idx - lookback; i <= idx + lookback; i++)
   {
      if(i == idx) continue;
      if(rates[i].high >= cHigh) return 0;
   }
   return cHigh;
}

//+------------------------------------------------------------------+
// Hitung pivot low
//+------------------------------------------------------------------+
double CalcPivotLow(int lookback, int shift)
{
   int needed = shift + lookback + 1;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(InpSymbol, PERIOD_M1, 0, needed + lookback, rates) < needed + lookback) return 0;

   int idx = shift;
   if(idx < lookback || idx + lookback >= ArraySize(rates)) return 0;

   double cLow = rates[idx].low;
   for(int i = idx - lookback; i <= idx + lookback; i++)
   {
      if(i == idx) continue;
      if(rates[i].low <= cLow) return 0;
   }
   return cLow;
}

//+------------------------------------------------------------------+
// Update SR levels — scan pivot high/low terbaru dengan volume filter
// (Pine Script: pivot high = resistance, pivot low = support)
//+------------------------------------------------------------------+
void UpdateSRLevels(double atrVal)
{
   double widthSR = atrVal * InpSRBoxWidth;
   int lookback   = InpSRLookback;
   int scanRange  = lookback * 6; // scan 6x lookback ke belakang

   // Volume (tick_volume) untuk filter: pivot dengan volume di atas rata-rata
   // Pine Script: vol_hi = highest(Vol/2.5, srVolLen); pivot low = support jika Vol > vol_hi
   // Simplified: accept pivot dengan volume >= average atau just accept all pivots (seperti default setting)

   // Cari support terbaru (pivot low)
   bool foundSup = false;
   for(int shift = lookback + 1; shift <= scanRange; shift++)
   {
      double pl = CalcPivotLow(lookback, shift);
      if(pl > 0)
      {
         double newSup = pl, newSup1 = pl - widthSR;
         if(!foundSup || newSup != gSupLevel)
         {
            gPrevSupLevel = gSupLevel;
            gSupLevel  = newSup;
            gSupLevel1 = newSup1;
         }
         foundSup = true;
         break;
      }
   }

   // Cari resistance terbaru (pivot high)
   bool foundRes = false;
   for(int shift = lookback + 1; shift <= scanRange; shift++)
   {
      double ph = CalcPivotHigh(lookback, shift);
      if(ph > 0)
      {
         double newRes = ph, newRes1 = ph + widthSR;
         if(!foundRes || newRes != gResLevel)
         {
            gPrevResLevel = gResLevel;
            gResLevel  = newRes;
            gResLevel1 = newRes1;
         }
         foundRes = true;
         break;
      }
   }
}

//+------------------------------------------------------------------+
// Tutup semua posisi EA ini
//+------------------------------------------------------------------+
void CloseMyPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()==InpMagicNumber && posInfo.Symbol()==InpSymbol)
         trade.PositionClose(posInfo.Ticket());
   }
}

//+------------------------------------------------------------------+
// Modifikasi SL posisi
//+------------------------------------------------------------------+
void ModifySL(ulong ticket, double newSL)
{
   int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
   newSL = NormalizeDouble(newSL, digits);
   if(!posInfo.SelectByTicket(ticket)) return;
   double curTP = posInfo.TakeProfit();
   if(trade.PositionModify(ticket, newSL, curTP))
      Print("SL diubah ke ", newSL, " ticket=", ticket);
   else
      Print("Gagal modifikasi SL: ", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
// Cek apakah ada posisi aktif EA ini
//+------------------------------------------------------------------+
bool HasActivePosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()==InpMagicNumber && posInfo.Symbol()==InpSymbol) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
// Reset state setelah trade selesai
//+------------------------------------------------------------------+
void ResetTrade()
{
   gDir=0; gHitTP1=false; gHitTP2=false;
   gEntry=0; gSL=0; gTP1=0; gTP2=0; gTP3=0;
   gLastExitBar = iBars(InpSymbol, PERIOD_M1) - 1;
   Print("Trade selesai. Menunggu sinyal berikutnya.");
}

//+------------------------------------------------------------------+
// TRAILING STOP — dijalankan setiap tick
// Logic sama dengan bridge EA:
//   TP1 hit → SL pindah ke Breakeven (entry)
//   TP2 hit → SL pindah ke TP1
//   TP3 hit → Close posisi
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!InpTrailingEnabled || gDir==0) return;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()!=InpMagicNumber || posInfo.Symbol()!=InpSymbol) continue;

      double curPrice = posInfo.PriceCurrent();
      double curSL    = posInfo.StopLoss();
      ulong  ticket   = posInfo.Ticket();
      double pt       = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);

      if(gDir == 1) // BUY
      {
         // TP3 tercapai → close
         if(gTP3 > 0 && curPrice >= gTP3)
         {
            Print("TP3 TERCAPAI! Closing BUY @ ", curPrice);
            trade.PositionClose(ticket);
            ResetTrade();
            return;
         }
         // TP2 tercapai → SL ke TP1
         if(!gHitTP2 && gTP2 > 0 && curPrice >= gTP2)
         {
            gHitTP2 = true;
            if(gTP1 > 0 && curSL < gTP1 - pt)
            {
               Print("TP2 TERCAPAI → SL pindah ke TP1 (", gTP1, ")");
               ModifySL(ticket, gTP1);
            }
         }
         // TP1 tercapai → SL ke Breakeven
         if(!gHitTP1 && gTP1 > 0 && curPrice >= gTP1)
         {
            gHitTP1 = true;
            if(curSL < gEntry - pt)
            {
               Print("TP1 TERCAPAI → SL pindah ke Breakeven (", gEntry, ")");
               ModifySL(ticket, gEntry);
            }
         }
      }
      else if(gDir == -1) // SELL
      {
         // TP3 tercapai → close
         if(gTP3 > 0 && curPrice <= gTP3)
         {
            Print("TP3 TERCAPAI! Closing SELL @ ", curPrice);
            trade.PositionClose(ticket);
            ResetTrade();
            return;
         }
         // TP2 tercapai → SL ke TP1
         if(!gHitTP2 && gTP2 > 0 && curPrice <= gTP2)
         {
            gHitTP2 = true;
            if(gTP1 > 0 && curSL > gTP1 + pt)
            {
               Print("TP2 TERCAPAI → SL pindah ke TP1 (", gTP1, ")");
               ModifySL(ticket, gTP1);
            }
         }
         // TP1 tercapai → SL ke Breakeven
         if(!gHitTP1 && gTP1 > 0 && curPrice <= gTP1)
         {
            gHitTP1 = true;
            if(curSL > gEntry + pt)
            {
               Print("TP1 TERCAPAI → SL pindah ke Breakeven (", gEntry, ")");
               ModifySL(ticket, gEntry);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
// MAIN TICK
//+------------------------------------------------------------------+
void OnTick()
{
   if(!InpEnabled) return;

   // Trailing stop jalan setiap tick
   ManageTrailingStop();

   // Sinyal hanya dicek pada bar baru (seperti barstate.isconfirmed di Pine Script)
   datetime curBarTime = iTime(InpSymbol, PERIOD_M1, 0);
   if(curBarTime == gLastBarTime) return;
   gLastBarTime = curBarTime;

   // Cek posisi aktif
   if(HasActivePosition())
   {
      // Max hold time check
      if(gDir != 0 && gOpenTime > 0)
      {
         int holdMin = (int)((TimeCurrent() - gOpenTime) / 60);
         if(holdMin >= InpMaxHoldMinutes)
         {
            Print("Max hold time (", InpMaxHoldMinutes, " menit) tercapai. Menutup posisi.");
            CloseMyPositions();
            ResetTrade();
         }
      }
      return;
   }
   else if(gDir != 0)
   {
      // Posisi ditutup dari luar (SL hit, manual close)
      ResetTrade();
      return;
   }

   // --- Cooldown setelah exit ---
   int currentBars = iBars(InpSymbol, PERIOD_M1);
   if(gLastExitBar > 0 && (currentBars - 1) - gLastExitBar < InpCooldownBars) return;

   // --- Session filter WIB ---
   if(!InWIBSession()) return;

   // --- Baca bar terakhir yang sudah close (shift=1, sama dengan Pine Script) ---
   MqlRates bar[];
   ArraySetAsSeries(bar, true);
   if(CopyRates(InpSymbol, PERIOD_M1, 1, 3, bar) < 3) return;

   double open1  = bar[0].open;
   double high1  = bar[0].high;
   double low1   = bar[0].low;
   double close1 = bar[0].close;
   double close2 = bar[1].close; // bar sebelumnya (untuk break detection)
   double high2  = bar[1].high;  // untuk sellBreak: close < low[1]
   double low2   = bar[1].low;   // untuk buyBreak: close > high[1]

   // --- EMA M1 ---
   double emaFast = Buf(hEmaFast, 0, 1);
   double emaMid  = Buf(hEmaMid,  0, 1);
   double emaSlow = Buf(hEmaSlow, 0, 1);
   double emaSlowOld = Buf(hEmaSlow, 0, 1 + InpEma200SlopeBars); // untuk slope EMA200

   // --- MTF EMA ---
   // M5: close dan EMA50
   double m5Close  = iClose(InpSymbol, PERIOD_M5, 1);
   double m5Ema50  = Buf(hEmaM5Fast, 0, 1);

   // M15: close, EMA50 dan EMA50 3-bar lalu (untuk slope)
   double m15Close   = iClose(InpSymbol, PERIOD_M15, 1);
   double m15Ema50   = Buf(hEmaM15Fast, 0, 1);
   double m15Ema50_3 = Buf(hEmaM15Fast, 0, 4); // [3] bars lalu di M15
   double m15Slope   = m15Ema50 - m15Ema50_3;

   // --- RSI, ADX, ATR, BB ---
   double rsiVal  = Buf(hRsi, 0, 1);
   double rsiPrev = Buf(hRsi, 0, 2);
   double adxVal  = Buf(hAdx, 0, 1); // ADX main line
   double atrVal  = Buf(hAtr, 0, 1);
   double bbUpper = Buf(hBB,  1, 1); // upper band
   double bbLower = Buf(hBB,  2, 1); // lower band

   if(atrVal <= 0 || emaFast <= 0) return;

   // --- Candle properties ---
   double body       = MathAbs(close1 - open1);
   double candleRange= high1 - low1;
   double bodyRatio  = candleRange > 0 ? body / candleRange : 0.0;
   double closePos   = candleRange > 0 ? (close1 - low1) / candleRange : 0.5;

   bool bullCandle = close1 > open1 && closePos >= InpCloseEdge;
   bool bearCandle = close1 < open1 && closePos <= 1.0 - InpCloseEdge;
   bool bodyOK     = bodyRatio >= InpMinBodyRatio;
   bool antiSpike  = candleRange <= atrVal * InpMaxCandleATR;
   bool atrOK      = atrVal >= InpMinATRPrice && atrVal <= InpMaxATRPrice;

   // Wick ratio
   double wickBuy  = MathMin(open1, close1) - low1;
   double wickSell = high1 - MathMax(open1, close1);
   bool wickBuyOK  = candleRange > 0 ? wickBuy  / candleRange >= 0.32 : false;
   bool wickSellOK = candleRange > 0 ? wickSell / candleRange >= 0.32 : false;

   // --- MTF Trend (sama dengan Pine Script) ---
   bool m1Bull = emaFast > emaMid && close1 > emaMid;
   bool m1Bear = emaFast < emaMid && close1 < emaMid;
   bool m5Bull = m5Close > m5Ema50;
   bool m5Bear = m5Close < m5Ema50;
   bool m15Bull= m15Close > m15Ema50 && m15Slope >= 0;
   bool m15Bear= m15Close < m15Ema50 && m15Slope <= 0;

   int bullCount = (m1Bull?1:0) + (m5Bull?1:0) + (m15Bull?1:0);
   int bearCount = (m1Bear?1:0) + (m5Bear?1:0) + (m15Bear?1:0);

   bool trendBuyOK  = bullCount >= 2;
   bool trendSellOK = bearCount >= 2;

   // --- Sideways ---
   double emaGapATR = atrVal > 0 ? MathAbs(emaMid - emaSlow) / atrVal : 999.0;
   bool sideways = bullCount < 2 && bearCount < 2 && adxVal <= InpSideMaxADX && emaGapATR <= 1.60;

   // --- RSI ---
   bool rsiBuyTurn  = rsiVal > rsiPrev;
   bool rsiSellTurn = rsiVal < rsiPrev;
   bool rsiBuyOK, rsiSellOK;
   if(InpEntryMode == "SAFE")
      { rsiBuyOK = rsiVal>=38 && rsiVal<=62; rsiSellOK = rsiVal>=38 && rsiVal<=62; }
   else if(InpEntryMode == "BALANCED")
      { rsiBuyOK = rsiVal>=34 && rsiVal<=68; rsiSellOK = rsiVal>=32 && rsiVal<=66; }
   else // AGGRESSIVE
      { rsiBuyOK = rsiVal>=30 && rsiVal<=72; rsiSellOK = rsiVal>=28 && rsiVal<=70; }

   // ==================== SR LEVELS ====================
   UpdateSRLevels(atrVal);

   double srBuffer = atrVal * InpSRBufferATR;

   // Near support / resistance (sama dengan Pine Script)
   bool nearSupport    = gSupLevel>0 && low1 <= gSupLevel + srBuffer && close1 >= gSupLevel1 - srBuffer;
   bool nearResistance = gResLevel>0 && high1>= gResLevel - srBuffer && close1 <= gResLevel1 + srBuffer;
   bool aboveResistance= gResLevel1>0 && close1 > gResLevel1;
   bool belowSupport   = gSupLevel1>0 && close1 < gSupLevel1;

   // Breakout detection (crossover/crossunder equivalen)
   bool brekoutRes = gResLevel1>0 && close2 <= gResLevel1 && close1 > gResLevel1;
   bool brekoutSup = gSupLevel1>0 && close2 >= gSupLevel1 && close1 < gSupLevel1;
   bool resHolds   = gResLevel>0 && high1 >= gResLevel - srBuffer && close1 <= gResLevel;
   bool supHolds   = gSupLevel>0 && low1  <= gSupLevel + srBuffer && close1 >= gSupLevel;

   // Update persistent SR state
   if(brekoutRes) { gResIsSup = true;  gBreakResHigh = gResLevel1; gBreakResBar = currentBars-1; }
   else if(resHolds) gResIsSup = false;
   if(brekoutSup) { gSupIsRes = true;  gBreakSupLow  = gSupLevel1; gBreakSupBar = currentBars-1; }
   else if(supHolds) gSupIsRes = false;

   // Green/Red diamond (SR Strength visual)
   bool greenSupportHold  = supHolds;
   bool greenResAsSupport = brekoutRes && gResIsSup;
   bool redResistanceHold = resHolds;
   bool redSupAsResistance= brekoutSup && gSupIsRes;

   bool greenDiamond = greenSupportHold || greenResAsSupport;
   bool redDiamond   = redResistanceHold || redSupAsResistance;

   // Retest detection
   bool resRetestBuy =
      gBreakResBar > 0 &&
      (currentBars-1) > gBreakResBar &&
      (currentBars-1) - gBreakResBar <= InpSRRetestBars &&
      gBreakResHigh > 0 &&
      low1 <= gBreakResHigh + srBuffer &&
      close1 >= gBreakResHigh &&
      bullCandle && rsiBuyTurn;

   bool supRetestSell =
      gBreakSupBar > 0 &&
      (currentBars-1) > gBreakSupBar &&
      (currentBars-1) - gBreakSupBar <= InpSRRetestBars &&
      gBreakSupLow > 0 &&
      high1 >= gBreakSupLow - srBuffer &&
      close1 <= gBreakSupLow &&
      bearCandle && rsiSellTurn;

   // --- SR Boost / Block ---
   bool srBuyDanger  = nearResistance && !aboveResistance && !brekoutRes;
   bool srSellDanger = nearSupport    && !belowSupport    && !brekoutSup;
   bool srBlockBuy   = InpSRBoostBlock && srBuyDanger;
   bool srBlockSell  = InpSRBoostBlock && srSellDanger;

   int srBuyBoost = 0, srSellBoost = 0;
   if(InpSRBoostBlock)
   {
      srBuyBoost  += nearSupport    ? InpSRBoostPts : 0;
      srBuyBoost  += brekoutRes     ? InpSRBreakBoostPts : 0;
      srBuyBoost  += (gResIsSup && close1 > gResLevel) ? InpSRBoostPts : 0;
      srBuyBoost  -= srBuyDanger    ? InpSRDangerPenalty : 0;
      srBuyBoost  += resRetestBuy   ? InpRetestBoostPts : 0;

      srSellBoost += nearResistance ? InpSRBoostPts : 0;
      srSellBoost += brekoutSup     ? InpSRBreakBoostPts : 0;
      srSellBoost += (gSupIsRes && close1 < gSupLevel) ? InpSRBoostPts : 0;
      srSellBoost -= srSellDanger   ? InpSRDangerPenalty : 0;
      srSellBoost += supRetestSell  ? InpRetestBoostPts : 0;
   }

   // --- Precision SR Block ---
   double ema200Slope = emaSlow - emaSlowOld;
   bool majorBear = close1 < emaSlow && ema200Slope < 0 && bearCount >= 2;
   bool majorBull = close1 > emaSlow && ema200Slope > 0 && bullCount >= 2;

   bool buyReversalOK  = brekoutRes || resRetestBuy  || (nearSupport    && bullCandle && rsiBuyTurn  && close1 > emaFast);
   bool sellReversalOK = brekoutSup || supRetestSell || (nearResistance && bearCandle && rsiSellTurn && close1 < emaFast);

   bool redBoxBuyBlock    = InpBlockBuyAtRedBox     && nearResistance && !aboveResistance && !brekoutRes && !resRetestBuy;
   bool greenBoxSellBlock = InpBlockSellAtGreenBox  && nearSupport    && !belowSupport    && !brekoutSup && !supRetestSell;

   bool buyPrecisionOK  = !InpRequireBreakForReversal || !majorBear || buyReversalOK;
   bool sellPrecisionOK = !InpRequireBreakForReversal || !majorBull || sellReversalOK;

   bool precisionBlockBuy  = redBoxBuyBlock   || !buyPrecisionOK;
   bool precisionBlockSell = greenBoxSellBlock || !sellPrecisionOK;

   // ==================== ENTRY SETUPS (sama dengan Pine Script) ====================
   bool buyTrend  = trendBuyOK  && close1 > emaMid  && rsiBuyOK  && rsiBuyTurn  && bullCandle && bodyOK && antiSpike && atrOK;
   bool sellTrend = trendSellOK && close1 < emaMid  && rsiSellOK && rsiSellTurn && bearCandle && bodyOK && antiSpike && atrOK;

   bool buyBreak  = trendBuyOK  && close1 > high2 && close1 > emaFast && rsiVal > 50 && rsiVal < 72 && bullCandle && antiSpike && atrOK;
   bool sellBreak = trendSellOK && close1 < low2  && close1 < emaFast && rsiVal < 50 && rsiVal > 28 && bearCandle && antiSpike && atrOK;

   bool sideBuy  = sideways && low1  <= bbLower && close1 > bbLower && rsiVal <= 45 && rsiBuyTurn  && wickBuyOK  && antiSpike && atrOK;
   bool sideSell = sideways && high1 >= bbUpper && close1 < bbUpper && rsiVal >= 55 && rsiSellTurn && wickSellOK && antiSpike && atrOK;

   // ==================== SCORE SYSTEM (identik Pine Script) ====================
   int buyScoreRaw =
      (bullCount * 18) +
      (close1 > emaMid  ? 12 : 0) +
      (close1 > emaFast ?  8 : 0) +
      (rsiBuyTurn       ? 10 : 0) +
      (rsiBuyOK         ? 10 : 0) +
      (bullCandle       ? 10 : 0) +
      (bodyOK           ?  5 : 0) +
      (antiSpike        ?  5 : 0) +
      (atrOK            ?  5 : 0) +
      (sideBuy          ? 20 : 0);

   int sellScoreRaw =
      (bearCount * 18) +
      (close1 < emaMid  ? 12 : 0) +
      (close1 < emaFast ?  8 : 0) +
      (rsiSellTurn      ? 10 : 0) +
      (rsiSellOK        ? 10 : 0) +
      (bearCandle       ? 10 : 0) +
      (bodyOK           ?  5 : 0) +
      (antiSpike        ?  5 : 0) +
      (atrOK            ?  5 : 0) +
      (sideSell         ? 20 : 0);

   int buyScore  = MathMax(0, buyScoreRaw  + srBuyBoost  - (precisionBlockBuy  ? InpSRDangerPenalty : 0));
   int sellScore = MathMax(0, sellScoreRaw + srSellBoost - (precisionBlockSell ? InpSRDangerPenalty : 0));

   // Min quality berdasarkan entryMode
   int minQuality = (InpEntryMode=="SAFE") ? InpMinQualitySafe : (InpEntryMode=="BALANCED") ? InpMinQualityBal : InpMinQualityAgg;

   bool allowBuy  = InpModeSignal != "SELL ONLY";
   bool allowSell = InpModeSignal != "BUY ONLY";

   bool buySetup  = (buyTrend  || buyBreak  || sideBuy  || resRetestBuy)  && !srBlockBuy  && !precisionBlockBuy;
   bool sellSetup = (sellTrend || sellBreak || sideSell || supRetestSell) && !srBlockSell && !precisionBlockSell;

   bool buyValid  = allowBuy  && buySetup  && buyScore  >= minQuality && buyScore  >= sellScore + InpScoreGap;
   bool sellValid = allowSell && sellSetup && sellScore >= minQuality && sellScore >= buyScore  + InpScoreGap;

   // ==================== SR STRENGTH SETUP ====================
   bool buyStrongSR  = InpUseSRStrength && greenDiamond &&
      (trendBuyOK || bullCount>=2 || resRetestBuy) &&
      buyScore >= InpSRStrongMinScore && buyScore >= sellScore + InpSRStrongGap &&
      !srBlockBuy && !precisionBlockBuy;

   bool sellStrongSR = InpUseSRStrength && redDiamond &&
      (trendSellOK || bearCount>=2 || supRetestSell) &&
      sellScore >= InpSRStrongMinScore && sellScore >= buyScore + InpSRStrongGap &&
      !srBlockSell && !precisionBlockSell;

   bool buyMediumSR  = InpAllowSRMedium && greenDiamond && !buyStrongSR &&
      buyScore >= InpSRMediumMinScore && buyScore >= sellScore + InpSRMediumGap &&
      !srBlockBuy && !precisionBlockBuy;

   bool sellMediumSR = InpAllowSRMedium && redDiamond && !sellStrongSR &&
      sellScore >= InpSRMediumMinScore && sellScore >= buyScore + InpSRMediumGap &&
      !srBlockSell && !precisionBlockSell;

   bool doSRBuy  = allowBuy  && (buyStrongSR  || buyMediumSR)  && (!(sellStrongSR||sellMediumSR) || buyScore  >= sellScore + InpScoreGap);
   bool doSRSell = allowSell && (sellStrongSR || sellMediumSR) && (!(buyStrongSR||buyMediumSR)   || sellScore >= buyScore  + InpScoreGap);

   // ==================== FINAL SIGNAL DECISION ====================
   // Prioritas: SR Strength > Normal (sama dengan Pine Script)
   int    finalDir = 0;
   double finalTP1Pts=0, finalTP2Pts=0, finalTP3Pts=0, finalSLPts=0;
   string setupClass = "";

   // --- SL calculation ---
   double atrSLRaw  = atrVal / InpPointSize * InpATRSLMult;
   double adaptiveSL= MathMin(MathMax(atrSLRaw, InpMinSLPoints), InpMaxSLPoints);
   double normalSLPts = (InpSLMode=="ADAPTIVE") ? adaptiveSL : InpFixedSLPoints;

   double srStrongSLRaw = atrVal / InpPointSize * InpSRStrongATRSLMult;
   double srStrongSLPts = (InpSRStrongSLMode=="ADAPTIVE") ?
      MathMin(MathMax(srStrongSLRaw, InpSRStrongMinSL), InpSRStrongMaxSL) : InpSRStrongFixedSL;

   double srMediumSLRaw = atrVal / InpPointSize * InpSRMediumATRSLMult;
   double srMediumSLPts = (InpSRMediumSLMode=="ADAPTIVE") ?
      MathMin(MathMax(srMediumSLRaw, InpSRMediumMinSL), InpSRMediumMaxSL) : InpSRMediumFixedSL;

   if(doSRBuy)
   {
      finalDir = 1;
      if(buyStrongSR) { finalTP1Pts=InpSRStrongTP1Pts; finalTP2Pts=InpSRStrongTP2Pts; finalTP3Pts=InpSRStrongTP3Pts; finalSLPts=srStrongSLPts; setupClass="BUY_KUAT_SR"; }
      else            { finalTP1Pts=InpSRMediumTP1Pts; finalTP2Pts=InpSRMediumTP2Pts; finalTP3Pts=InpSRMediumTP3Pts; finalSLPts=srMediumSLPts; setupClass="BUY_SEDANG_SR"; }
   }
   else if(doSRSell)
   {
      finalDir = -1;
      if(sellStrongSR) { finalTP1Pts=InpSRStrongTP1Pts; finalTP2Pts=InpSRStrongTP2Pts; finalTP3Pts=InpSRStrongTP3Pts; finalSLPts=srStrongSLPts; setupClass="SELL_KUAT_SR"; }
      else             { finalTP1Pts=InpSRMediumTP1Pts; finalTP2Pts=InpSRMediumTP2Pts; finalTP3Pts=InpSRMediumTP3Pts; finalSLPts=srMediumSLPts; setupClass="SELL_SEDANG_SR"; }
   }
   else if(buyValid)
   {
      finalDir=1;  finalTP1Pts=InpTP1Points; finalTP2Pts=InpTP2Points; finalTP3Pts=InpTP3Points; finalSLPts=normalSLPts; setupClass="BUY_NORMAL";
   }
   else if(sellValid)
   {
      finalDir=-1; finalTP1Pts=InpTP1Points; finalTP2Pts=InpTP2Points; finalTP3Pts=InpTP3Points; finalSLPts=normalSLPts; setupClass="SELL_NORMAL";
   }

   if(finalDir == 0) return; // No signal

   // ==================== EKSEKUSI ORDER ====================
   // Pine Script: entry = open (bar berikutnya setelah sinyal)
   // MT5: bar baru sudah dibuka, kita masuk sekarang di harga market
   int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
   double slPrice  = finalSLPts  * InpPointSize;
   double tp1Price = finalTP1Pts * InpPointSize;
   double tp2Price = finalTP2Pts * InpPointSize;
   double tp3Price = finalTP3Pts * InpPointSize;

   double entryPrice, sl, tp1, tp2, tp3;
   bool ok = false;
   int score = (finalDir==1) ? buyScore : sellScore;

   if(finalDir == 1) // BUY
   {
      entryPrice = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
      sl  = NormalizeDouble(entryPrice - slPrice,  digits);
      tp1 = NormalizeDouble(entryPrice + tp1Price, digits);
      tp2 = NormalizeDouble(entryPrice + tp2Price, digits);
      tp3 = NormalizeDouble(entryPrice + tp3Price, digits);

      if(InpDeleteOnNew) CloseMyPositions();

      string cmt = StringFormat("ZS V10 %s s%d", setupClass, score);
      if(StringLen(cmt) > 63) cmt = StringSubstr(cmt, 0, 63);
      ok = trade.Buy(MathMin(InpLot, InpMaxLot), InpSymbol, entryPrice, sl, tp3, cmt);
   }
   else // SELL
   {
      entryPrice = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
      sl  = NormalizeDouble(entryPrice + slPrice,  digits);
      tp1 = NormalizeDouble(entryPrice - tp1Price, digits);
      tp2 = NormalizeDouble(entryPrice - tp2Price, digits);
      tp3 = NormalizeDouble(entryPrice - tp3Price, digits);

      if(InpDeleteOnNew) CloseMyPositions();

      string cmt = StringFormat("ZS V10 %s s%d", setupClass, score);
      if(StringLen(cmt) > 63) cmt = StringSubstr(cmt, 0, 63);
      ok = trade.Sell(MathMin(InpLot, InpMaxLot), InpSymbol, entryPrice, sl, tp3, cmt);
   }

   if(ok)
   {
      gEntry    = entryPrice;
      gSL       = sl;
      gTP1      = tp1;
      gTP2      = tp2;
      gTP3      = tp3;
      gDir      = finalDir;
      gHitTP1   = false;
      gHitTP2   = false;
      gOpenTime = TimeCurrent();

      Print(StringFormat(
         ">>> TRADE %s | Setup=%s | Score=%d | Entry=%.2f | SL=%.2f | TP1=%.2f | TP2=%.2f | TP3=%.2f | bullC=%d bearC=%d | RSI=%.1f ADX=%.1f",
         finalDir==1?"BUY":"SELL", setupClass, score,
         entryPrice, sl, tp1, tp2, tp3,
         bullCount, bearCount, rsiVal, adxVal));
   }
   else
   {
      Print("Order GAGAL: ", trade.ResultRetcodeDescription(), " (", trade.ResultRetcode(), ")");
   }
}
//+------------------------------------------------------------------+
