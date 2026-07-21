//+------------------------------------------------------------------+
//|  ZS_V10_Standalone_EA.mq5                                       |
//|  ZS XAUUSD V10 SR Precision Pro — Standalone MT5 EA            |
//|  Replicates Pine Script indicator ZS XAUUSD V10 logic 1:1      |
//|  No TradingView, no server, no webhook required                 |
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
input int    InpScoreGap          = 6;
input int    InpCooldownBars      = 2;

input group "=== SESSION FILTER WIB ==="
input bool   InpUseWIBFilter      = true;

input group "=== TP / SL (Dollar Fixed) ==="
input double InpSLDollars         = 5.0;   // Stop Loss dalam Dolar dari entry
input double InpTP1Dollars        = 5.0;   // Take Profit 1 dalam Dolar dari entry
input double InpTP2Dollars        = 10.0;  // Take Profit 2 dalam Dolar dari entry
input double InpTP3Dollars        = 15.0;  // Take Profit 3 dalam Dolar dari entry
input int    InpATRLen            = 14;    // ATR period (untuk scoring, bukan SL)
input int    InpMaxHoldMinutes    = 180;   // Max hold time (menit)

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
input bool   InpBlockBuyAtPeak    = true;  // Block BUY jika RSI >= threshold (harga di pucuk)
input bool   InpBlockSellAtDeep   = true;  // Block SELL jika RSI <= threshold (sudah turun terlalu dalam)
input int    InpOverboughtRSI     = 70;    // RSI threshold pucuk (block buy)
input int    InpOversoldRSI       = 30;    // RSI threshold oversold (block sell)

input group "=== ORDER ==="
input string InpSymbol            = "XAUUSDc";
input int    InpMagicNumber       = 909506;
input double InpLot               = 0.01;
input double InpMaxLot            = 1.0;
input int    InpSlippage          = 20;
input bool   InpTrailingEnabled   = true;
input bool   InpDeleteOnNew       = true;
input bool   InpEnabled           = true;

input group "=== PANEL ==="
input bool   InpShowPanel         = true;       // Tampilkan panel status
input int    InpPanelX            = 20;         // Posisi X panel (dari kanan)
input int    InpPanelY            = 30;         // Posisi Y panel (dari atas)
input int    InpPanelFontSize     = 9;          // Ukuran font panel

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

//==================== BAR TRACKING ====================//
datetime gLastBarTime=0;
int    gLastExitBar=0;

//==================== SR STATE ====================//
double gSupLevel=0,  gSupLevel1=0;
double gResLevel=0,  gResLevel1=0;
bool   gResIsSup=false, gSupIsRes=false;
double gBreakResHigh=0;  int gBreakResBar=0;
double gBreakSupLow=0;   int gBreakSupBar=0;

//==================== PANEL STATE (updated tiap bar) ====================//
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
bool   gPeakBlock      = false;  // RSI overbought → block buy
bool   gDeepBlock      = false;  // RSI oversold   → block sell
bool   gSessionOK      = false;
int    gMinQuality     = 82;
int    gWinCount       = 0;
int    gLossCount      = 0;
int    gTotalSignals   = 0;

//==================== PANEL OBJECT PREFIX ====================//
#define PANEL_PREFIX "ZSEA_"

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

   Print("ZS V10 Standalone EA v1.0 aktif | Symbol: ", InpSymbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   PanelDelete();
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
void CloseMyPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()==InpMagicNumber && posInfo.Symbol()==InpSymbol)
         trade.PositionClose(posInfo.Ticket());
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
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()!=InpMagicNumber || posInfo.Symbol()!=InpSymbol) continue;
      double curPrice = posInfo.PriceCurrent();
      double curSL    = posInfo.StopLoss();
      ulong  ticket   = posInfo.Ticket();
      double pt       = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);

      if(gDir == 1)
      {
         if(gTP3>0 && curPrice>=gTP3) { Print("TP3 TERCAPAI! Closing BUY"); gLossCount--; gWinCount++; trade.PositionClose(ticket); ResetTrade(); return; }
         if(!gHitTP2 && gTP2>0 && curPrice>=gTP2) { gHitTP2=true; if(gTP1>0 && curSL<gTP1-pt){ Print("TP2 hit → SL ke TP1"); ModifySL(ticket,gTP1); } }
         if(!gHitTP1 && gTP1>0 && curPrice>=gTP1) { gHitTP1=true; if(curSL<gEntry-pt){ Print("TP1 hit → SL ke BE"); ModifySL(ticket,gEntry); } }
      }
      else if(gDir == -1)
      {
         if(gTP3>0 && curPrice<=gTP3) { Print("TP3 TERCAPAI! Closing SELL"); gLossCount--; gWinCount++; trade.PositionClose(ticket); ResetTrade(); return; }
         if(!gHitTP2 && gTP2>0 && curPrice<=gTP2) { gHitTP2=true; if(gTP1>0 && curSL>gTP1+pt){ Print("TP2 hit → SL ke TP1"); ModifySL(ticket,gTP1); } }
         if(!gHitTP1 && gTP1>0 && curPrice<=gTP1) { gHitTP1=true; if(curSL>gEntry+pt){ Print("TP1 hit → SL ke BE"); ModifySL(ticket,gEntry); } }
      }
   }
}

//+------------------------------------------------------------------+
// MAIN TICK
//+------------------------------------------------------------------+
void OnTick()
{
   if(!InpEnabled) return;

   ManageTrailingStop();

   datetime curBarTime = iTime(InpSymbol, PERIOD_M1, 0);
   if(curBarTime == gLastBarTime)
   {
      if(InpShowPanel) DrawPanel(); // update P/L setiap tick
      return;
   }
   gLastBarTime = curBarTime;

   if(HasActivePosition())
   {
      if(gDir!=0 && gOpenTime>0)
      {
         int holdMin = (int)((TimeCurrent()-gOpenTime)/60);
         if(holdMin >= InpMaxHoldMinutes)
         {
            Print("Max hold time tercapai. Menutup posisi.");
            CloseMyPositions(); ResetTrade();
         }
      }
      if(InpShowPanel) DrawPanel();
      return;
   }
   else if(gDir != 0) { ResetTrade(); }

   int currentBars = iBars(InpSymbol, PERIOD_M1);
   if(gLastExitBar>0 && (currentBars-1)-gLastExitBar < InpCooldownBars)
   {
      gPanelStatus = "COOLDOWN";
      if(InpShowPanel) DrawPanel();
      return;
   }

   gSessionOK = InWIBSession();
   if(!gSessionOK)
   {
      gPanelStatus = "SESSION OFF";
      if(InpShowPanel) DrawPanel();
      return;
   }

   CheckSignal(currentBars);
   if(InpShowPanel) DrawPanel();
}

//+------------------------------------------------------------------+
// SIGNAL DETECTION (logika identik Pine Script)
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

   // Store for panel
   gRsiVal = rsiVal; gAdxVal = adxVal; gAtrVal = atrVal;

   // Candle
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

   // MTF Trend
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

   // RSI
   bool rsiBuyTurn  = rsiVal>rsiPrev;
   bool rsiSellTurn = rsiVal<rsiPrev;
   bool rsiBuyOK, rsiSellOK;
   if(InpEntryMode=="SAFE")         { rsiBuyOK=rsiVal>=38&&rsiVal<=62; rsiSellOK=rsiVal>=38&&rsiVal<=62; }
   else if(InpEntryMode=="BALANCED"){ rsiBuyOK=rsiVal>=34&&rsiVal<=68; rsiSellOK=rsiVal>=32&&rsiVal<=66; }
   else                              { rsiBuyOK=rsiVal>=30&&rsiVal<=72; rsiSellOK=rsiVal>=28&&rsiVal<=70; }

   // SR
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

   // SR text for panel
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

   // Entry setups
   bool buyTrend  = trendBuyOK &&close1>emaMid &&rsiBuyOK &&rsiBuyTurn &&bullCandle&&bodyOK&&antiSpike&&atrOK;
   bool sellTrend = trendSellOK&&close1<emaMid &&rsiSellOK&&rsiSellTurn&&bearCandle&&bodyOK&&antiSpike&&atrOK;
   bool buyBreak  = trendBuyOK &&close1>high2  &&close1>emaFast&&rsiVal>50&&rsiVal<72&&bullCandle&&antiSpike&&atrOK;
   bool sellBreak = trendSellOK&&close1<low2   &&close1<emaFast&&rsiVal<50&&rsiVal>28&&bearCandle&&antiSpike&&atrOK;
   bool sideBuy   = gSidewaysFlag&&low1<=bbLower&&close1>bbLower&&rsiVal<=45&&rsiBuyTurn &&wickBuyOK &&antiSpike&&atrOK;
   bool sideSell  = gSidewaysFlag&&high1>=bbUpper&&close1<bbUpper&&rsiVal>=55&&rsiSellTurn&&wickSellOK&&antiSpike&&atrOK;

   // Score
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

   // SR Strength
   bool buyStrongSR  = InpUseSRStrength&&greenDiamond&&(trendBuyOK||gBullCount>=2||resRetestBuy)&&gBuyScore>=InpSRStrongMinScore&&gBuyScore>=gSellScore+InpSRStrongGap&&!gSRBlockBuy&&!gPrecBlockBuy;
   bool sellStrongSR = InpUseSRStrength&&redDiamond&&(trendSellOK||gBearCount>=2||supRetestSell)&&gSellScore>=InpSRStrongMinScore&&gSellScore>=gBuyScore+InpSRStrongGap&&!gSRBlockSell&&!gPrecBlockSell;
   bool buyMediumSR  = InpAllowSRMedium&&greenDiamond&&!buyStrongSR&&gBuyScore>=InpSRMediumMinScore&&gBuyScore>=gSellScore+InpSRMediumGap&&!gSRBlockBuy&&!gPrecBlockBuy;
   bool sellMediumSR = InpAllowSRMedium&&redDiamond&&!sellStrongSR&&gSellScore>=InpSRMediumMinScore&&gSellScore>=gBuyScore+InpSRMediumGap&&!gSRBlockSell&&!gPrecBlockSell;

   bool doSRBuy  = allowBuy &&(buyStrongSR||buyMediumSR) &&(!(sellStrongSR||sellMediumSR)||gBuyScore>=gSellScore+InpScoreGap);
   bool doSRSell = allowSell&&(sellStrongSR||sellMediumSR)&&(!(buyStrongSR||buyMediumSR) ||gSellScore>=gBuyScore+InpScoreGap);

   // ---- Peak / Deep filter (update global untuk panel) ----
   gPeakBlock = InpBlockBuyAtPeak  && rsiVal >= InpOverboughtRSI;   // RSI terlalu tinggi = pucuk
   gDeepBlock = InpBlockSellAtDeep && rsiVal <= InpOversoldRSI;     // RSI terlalu rendah = sudah terlalu turun

   // ---- Dollar-based SL/TP → konversi ke jarak harga ----
   // Rumus: dollarPerUnit = lot × (tickValue / tickSize)
   // Untuk XAUUSD 0.01 lot: tickVal≈0.01, tickSz=0.01 → dollarPerUnit = 0.01×(0.01/0.01)×100 = 1 $/unit
   double lot          = MathMin(InpLot, InpMaxLot);
   double tickVal      = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz       = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE);
   double dollarPerUnit= (tickSz > 0 && tickVal > 0) ? lot * (tickVal / tickSz) : lot;
   double slPriceDist  = (dollarPerUnit > 0) ? InpSLDollars  / dollarPerUnit : 5.0;
   double tp1PriceDist = (dollarPerUnit > 0) ? InpTP1Dollars / dollarPerUnit : 5.0;
   double tp2PriceDist = (dollarPerUnit > 0) ? InpTP2Dollars / dollarPerUnit : 10.0;
   double tp3PriceDist = (dollarPerUnit > 0) ? InpTP3Dollars / dollarPerUnit : 15.0;

   // ---- Final signal (semua setup pakai dollar SL/TP) ----
   int    finalDir   = 0;
   string setupClass = "";

   if     (doSRBuy   && !gPeakBlock)  { finalDir =  1; setupClass = buyStrongSR  ? "BUY_KUAT_SR"  : "BUY_SEDANG_SR";  }
   else if(doSRSell  && !gDeepBlock)  { finalDir = -1; setupClass = sellStrongSR ? "SELL_KUAT_SR" : "SELL_SEDANG_SR"; }
   else if(buyValid  && !gPeakBlock)  { finalDir =  1; setupClass = "BUY_NORMAL";  }
   else if(sellValid && !gDeepBlock)  { finalDir = -1; setupClass = "SELL_NORMAL"; }

   // Update panel predict text even if no signal fires
   if(finalDir==0)
   {
      if(gBuyScore>=gSellScore+2) gPanelStatus="PREDICT BUY";
      else if(gSellScore>=gBuyScore+2) gPanelStatus="PREDICT SELL";
      else gPanelStatus="WAIT";
      gPanelSetup = "-";
      return;
   }

   // ---- Execute ----
   int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
   double entryPrice, sl, tp1, tp2, tp3;
   bool ok=false;
   int score=(finalDir==1)?gBuyScore:gSellScore;

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
   }

   if(ok)
   {
      gEntry=entryPrice; gSL=sl; gTP1=tp1; gTP2=tp2; gTP3=tp3;
      gDir=finalDir; gHitTP1=false; gHitTP2=false;
      gOpenTime=TimeCurrent();
      gTotalSignals++;
      gLossCount++; // akan di-decrement jika win (TP3 hit)
      gPanelStatus=(finalDir==1)?"BUY ACTIVE":"SELL ACTIVE";
      gPanelSetup=setupClass;
      Print(StringFormat(">>> %s | %s | Score=%d | Entry=%.2f | SL=%.2f | TP1=%.2f | TP2=%.2f | TP3=%.2f",
            finalDir==1?"BUY":"SELL",setupClass,score,entryPrice,sl,tp1,tp2,tp3));
   }
   else
      Print("Order GAGAL: ",trade.ResultRetcodeDescription()," (",trade.ResultRetcode(),")");
}

//==========================================================================
//  PANEL FUNCTIONS
//==========================================================================

// Helper: buat/update 1 label teks di chart
void PanelLabel(string name, string text, int x, int y, color clr, int fontSize=0)
{
   string fullName = PANEL_PREFIX + name;
   int fs = fontSize>0 ? fontSize : InpPanelFontSize;
   if(ObjectFind(0, fullName) < 0)
   {
      ObjectCreate(0, fullName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, fullName, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, fullName, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
      ObjectSetString (0, fullName, OBJPROP_FONT,      "Courier New");
      ObjectSetInteger(0, fullName, OBJPROP_BACK,      false);
      ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE,false);
   }
   ObjectSetString (0, fullName, OBJPROP_TEXT,     text);
   ObjectSetInteger(0, fullName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, fullName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, fullName, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, fullName, OBJPROP_FONTSIZE,  fs);
}

// Helper: buat rectangle background
void PanelRect(string name, int x, int y, int w, int h, color bgColor)
{
   string fullName = PANEL_PREFIX + name;
   if(ObjectFind(0, fullName) < 0)
   {
      ObjectCreate(0, fullName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, fullName, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, fullName, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, fullName, OBJPROP_BACK,      true);
      ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, fullName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   }
   ObjectSetInteger(0, fullName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, fullName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, fullName, OBJPROP_XSIZE,     w);
   ObjectSetInteger(0, fullName, OBJPROP_YSIZE,     h);
   ObjectSetInteger(0, fullName, OBJPROP_BGCOLOR,   bgColor);
   ObjectSetInteger(0, fullName, OBJPROP_BORDER_COLOR, C'50,50,50');
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
   // Background utama
   PanelRect("BG", InpPanelX, InpPanelY, 260, 460, C'15,15,25');
   PanelRect("BG_TITLE", InpPanelX, InpPanelY, 260, 22, C'20,20,40');
}

//+------------------------------------------------------------------+
// DRAW PANEL — dipanggil setiap tick
//+------------------------------------------------------------------+
void DrawPanel()
{
   if(!InpShowPanel) return;

   int x  = InpPanelX;
   int y0 = InpPanelY;
   int lh = InpPanelFontSize + 5; // line height
   int px = x + 4;                // margin kanan panel
   int lx = px + 130;             // kolom label (kiri)  — lebih jauh dari kanan = lebih ke kiri di layar
   int vx = px;                   // kolom value (kanan) — dekat dari kanan = lebih ke kanan di layar
   int fs = InpPanelFontSize;

   // -- Status & warna --
   color statusColor;
   if(gPanelStatus=="BUY ACTIVE" || gPanelStatus=="PREDICT BUY")       statusColor=clrLime;
   else if(gPanelStatus=="SELL ACTIVE" || gPanelStatus=="PREDICT SELL") statusColor=clrRed;
   else if(gPanelStatus=="COOLDOWN")                                    statusColor=clrOrange;
   else if(gPanelStatus=="SESSION OFF")                                 statusColor=clrGray;
   else                                                                  statusColor=clrSilver;

   // -- Resize background sesuai isi --
   int totalRows = 32;
   int bgH = totalRows * lh + 30;
   PanelRect("BG",       x, y0,     260, bgH,  C'15,15,25');
   PanelRect("BG_TITLE", x, y0,     260, lh+4, C'20,20,40');

   int row = y0 + 4;

   // JUDUL
   PanelLabel("T1", "  ZS V10 SR PRECISION EA", lx, row, clrGold, fs);
   row += lh + 4;

   // Separator
   PanelLabel("SEP1","────────────────────────", lx, row, C'50,50,80', fs-1); row+=lh-2;

   // STATUS
   PanelLabel("L_STATUS", "STATUS    :", lx, row, clrSilver, fs);
   PanelLabel("V_STATUS",  " "+gPanelStatus, vx, row, statusColor, fs);
   row += lh;

   // SETUP
   color setupCol = (StringFind(gPanelSetup,"BUY")>=0) ? clrLimeGreen : (StringFind(gPanelSetup,"SELL")>=0) ? clrTomato : clrSilver;
   PanelLabel("L_SETUP",  "SETUP     :", lx, row, clrSilver, fs);
   PanelLabel("V_SETUP",   " "+gPanelSetup, vx, row, setupCol, fs);
   row += lh;

   // Separator
   PanelLabel("SEP2","────────────────────────", lx, row, C'50,50,80', fs-1); row+=lh-2;

   // SCORE
   color buyScoreCol  = gBuyScore>=gMinQuality  ? clrLimeGreen : clrSilver;
   color sellScoreCol = gSellScore>=gMinQuality ? clrTomato    : clrSilver;
   PanelLabel("L_BS","BUY  SCORE:", lx, row, clrSilver, fs);
   PanelLabel("V_BS", StringFormat(" %d / %d", gBuyScore, gMinQuality), vx, row, buyScoreCol, fs);
   row+=lh;
   PanelLabel("L_SS","SELL SCORE:", lx, row, clrSilver, fs);
   PanelLabel("V_SS", StringFormat(" %d / %d", gSellScore, gMinQuality), vx, row, sellScoreCol, fs);
   row+=lh;

   // Separator
   PanelLabel("SEP3","────────────────────────", lx, row, C'50,50,80', fs-1); row+=lh-2;

   // TREND MTF
   PanelLabel("L_T","BULL/BEAR :", lx, row, clrSilver, fs);
   string bcText = StringFormat(" %dB / %dS", gBullCount, gBearCount);
   color bcCol = (gBullCount>=2)?clrLimeGreen:(gBearCount>=2)?clrTomato:clrOrange;
   PanelLabel("V_T", bcText, vx, row, bcCol, fs);
   row+=lh;

   PanelLabel("L_M1","M1 EMA    :", lx, row, clrSilver, fs);
   string m1txt = gM1Bull?" BULL ▲":gM1Bear?" BEAR ▼":" MIXED";
   color m1col  = gM1Bull?clrLimeGreen:gM1Bear?clrTomato:clrGray;
   PanelLabel("V_M1", m1txt, vx, row, m1col, fs); row+=lh;

   PanelLabel("L_M5","M5 EMA    :", lx, row, clrSilver, fs);
   string m5txt = gM5Bull?" BULL ▲":gM5Bear?" BEAR ▼":" MIXED";
   color m5col  = gM5Bull?clrLimeGreen:gM5Bear?clrTomato:clrGray;
   PanelLabel("V_M5", m5txt, vx, row, m5col, fs); row+=lh;

   PanelLabel("L_M15","M15 EMA  :", lx, row, clrSilver, fs);
   string m15txt = gM15Bull?" BULL ▲":gM15Bear?" BEAR ▼":" MIXED";
   color m15col  = gM15Bull?clrLimeGreen:gM15Bear?clrTomato:clrGray;
   PanelLabel("V_M15", m15txt, vx, row, m15col, fs); row+=lh;

   string regimeText = (gBullCount>=2)?"BUY BIAS":(gBearCount>=2)?"SELL BIAS":gSidewaysFlag?"SIDEWAYS":"MIXED";
   color regCol = (gBullCount>=2)?clrLimeGreen:(gBearCount>=2)?clrTomato:clrOrange;
   PanelLabel("L_RG","REGIME    :", lx, row, clrSilver, fs);
   PanelLabel("V_RG"," "+regimeText, vx, row, regCol, fs); row+=lh;

   // Separator
   PanelLabel("SEP4","────────────────────────", lx, row, C'50,50,80', fs-1); row+=lh-2;

   // RSI / ADX / ATR
   color rsiCol = (gRsiVal>=40&&gRsiVal<=60)?clrSilver:(gRsiVal<40)?clrLimeGreen:clrTomato;
   PanelLabel("L_RSI","RSI(14)   :", lx, row, clrSilver, fs);
   PanelLabel("V_RSI", StringFormat(" %.1f", gRsiVal), vx, row, rsiCol, fs); row+=lh;

   color adxCol = (gAdxVal>=25)?clrGold:clrSilver;
   PanelLabel("L_ADX","ADX(14)   :", lx, row, clrSilver, fs);
   PanelLabel("V_ADX", StringFormat(" %.1f %s", gAdxVal, gAdxVal<=InpSideMaxADX?"[SIDE]":"[TREND]"), vx, row, adxCol, fs); row+=lh;

   PanelLabel("L_ATR","ATR(14)   :", lx, row, clrSilver, fs);
   PanelLabel("V_ATR", StringFormat(" %.2f", gAtrVal), vx, row, clrSilver, fs); row+=lh;

   // SR Status
   PanelLabel("SEP5","────────────────────────", lx, row, C'50,50,80', fs-1); row+=lh-2;
   color srCol = (gSRStatus=="NEUTRAL")?clrSilver:(StringFind(gSRStatus,"BUY")>=0||StringFind(gSRStatus,"SUPPORT")>=0)?clrLimeGreen:clrTomato;
   PanelLabel("L_SR","SR STATUS :", lx, row, clrSilver, fs);
   PanelLabel("V_SR"," "+gSRStatus, vx, row, srCol, fs); row+=lh;

   bool anyBlockBuy  = gSRBlockBuy  || gPrecBlockBuy  || gPeakBlock;
   bool anyBlockSell = gSRBlockSell || gPrecBlockSell || gDeepBlock;
   string blockTxt = (!anyBlockBuy && !anyBlockSell) ? "OK" :
                     (anyBlockBuy && anyBlockSell)   ? "BLOCK BOTH" :
                     anyBlockBuy                     ? (gPeakBlock?"PEAK(RSI)":"BLOCK BUY") :
                                                       (gDeepBlock?"DEEP(RSI)":"BLOCK SELL");
   color blockCol  = (blockTxt=="OK")?clrLimeGreen:clrTomato;
   PanelLabel("L_BL","SR BLOCK  :", lx, row, clrSilver, fs);
   PanelLabel("V_BL"," "+blockTxt, vx, row, blockCol, fs); row+=lh;

   string supTxt = gSupLevel>0?StringFormat(" %.2f",gSupLevel):" -";
   string resTxt = gResLevel>0?StringFormat(" %.2f",gResLevel):" -";
   PanelLabel("L_SUP","SUPPORT   :", lx, row, clrSilver, fs);
   PanelLabel("V_SUP", supTxt, vx, row, clrLimeGreen, fs); row+=lh;
   PanelLabel("L_RES","RESIST    :", lx, row, clrSilver, fs);
   PanelLabel("V_RES", resTxt, vx, row, clrTomato, fs); row+=lh;

   // Session
   PanelLabel("SEP6","────────────────────────", lx, row, C'50,50,80', fs-1); row+=lh-2;
   PanelLabel("L_SES","SESSION   :", lx, row, clrSilver, fs);
   PanelLabel("V_SES", gSessionOK?" WIB ON ✓":" WIB OFF ✗", vx, row, gSessionOK?clrLimeGreen:clrGray, fs); row+=lh;

   // Trade info
   PanelLabel("SEP7","────────────────────────", lx, row, C'50,50,80', fs-1); row+=lh-2;

   if(gDir!=0 && HasActivePosition())
   {
      // Hitung P/L saat ini
      double pl=0;
      for(int i=0;i<PositionsTotal();i++)
      {
         if(!posInfo.SelectByIndex(i)) continue;
         if(posInfo.Magic()==InpMagicNumber&&posInfo.Symbol()==InpSymbol)
            pl += posInfo.Profit()+posInfo.Swap();
      }
      double curPrice=(gDir==1)?SymbolInfoDouble(InpSymbol,SYMBOL_BID):SymbolInfoDouble(InpSymbol,SYMBOL_ASK);
      color plCol = pl>=0?clrLimeGreen:clrTomato;
      string plSign = pl>=0?"+":"";

      PanelLabel("L_EN","ENTRY     :", lx, row, clrSilver, fs);
      PanelLabel("V_EN", StringFormat(" %.2f", gEntry), vx, row, clrGold, fs); row+=lh;

      PanelLabel("L_SL2","SL        :", lx, row, clrSilver, fs);
      PanelLabel("V_SL2", StringFormat(" %.2f", gSL), vx, row, clrTomato, fs); row+=lh;

      string tp1Mark = gHitTP1?" ✓":"";
      string tp2Mark = gHitTP2?" ✓":"";
      PanelLabel("L_T1","TP1       :", lx, row, clrSilver, fs);
      PanelLabel("V_T1", StringFormat(" %.2f%s", gTP1, tp1Mark), vx, row, gHitTP1?clrGold:clrLimeGreen, fs); row+=lh;
      PanelLabel("L_T2","TP2       :", lx, row, clrSilver, fs);
      PanelLabel("V_T2", StringFormat(" %.2f%s", gTP2, tp2Mark), vx, row, gHitTP2?clrGold:clrLimeGreen, fs); row+=lh;
      PanelLabel("L_T3","TP3       :", lx, row, clrSilver, fs);
      PanelLabel("V_T3", StringFormat(" %.2f", gTP3), vx, row, clrLimeGreen, fs); row+=lh;

      PanelLabel("L_NOW","PRICE NOW :", lx, row, clrSilver, fs);
      PanelLabel("V_NOW", StringFormat(" %.2f", curPrice), vx, row, clrWhite, fs); row+=lh;

      PanelLabel("L_PL","P / L     :", lx, row, clrSilver, fs);
      PanelLabel("V_PL", StringFormat(" %s%.2f $", plSign, pl), vx, row, plCol, fs); row+=lh;

      int holdMin=(int)((TimeCurrent()-gOpenTime)/60);
      PanelLabel("L_HOLD","HOLD TIME :", lx, row, clrSilver, fs);
      PanelLabel("V_HOLD", StringFormat(" %d / %d min", holdMin, InpMaxHoldMinutes), vx, row, holdMin>InpMaxHoldMinutes*0.8?clrOrange:clrSilver, fs); row+=lh;
   }
   else
   {
      PanelLabel("L_EN", "NO ACTIVE TRADE", lx, row, C'70,70,90', fs); row+=lh;
      PanelLabel("V_EN","", vx, row, clrNONE, fs);
      PanelLabel("L_SL2","", lx, row, clrNONE, fs); PanelLabel("V_SL2","", vx, row, clrNONE, fs); row+=lh;
      PanelLabel("L_T1","", lx, row, clrNONE, fs); PanelLabel("V_T1","", vx, row, clrNONE, fs); row+=lh;
      PanelLabel("L_T2","", lx, row, clrNONE, fs); PanelLabel("V_T2","", vx, row, clrNONE, fs); row+=lh;
      PanelLabel("L_T3","", lx, row, clrNONE, fs); PanelLabel("V_T3","", vx, row, clrNONE, fs); row+=lh;
      PanelLabel("L_NOW","", lx, row, clrNONE, fs); PanelLabel("V_NOW","", vx, row, clrNONE, fs); row+=lh;
      PanelLabel("L_PL","", lx, row, clrNONE, fs); PanelLabel("V_PL","", vx, row, clrNONE, fs); row+=lh;
      PanelLabel("L_HOLD","", lx, row, clrNONE, fs); PanelLabel("V_HOLD","", vx, row, clrNONE, fs); row+=lh;
   }

   // Stats
   PanelLabel("SEP8","────────────────────────", lx, row, C'50,50,80', fs-1); row+=lh-2;
   int totalTrades = gWinCount + gLossCount;
   double wr = totalTrades>0 ? (gWinCount*100.0/totalTrades) : 0;
   PanelLabel("L_STAT","WIN/LOSS  :", lx, row, clrSilver, fs);
   PanelLabel("V_STAT", StringFormat(" %d W / %d L  (%.0f%%)", gWinCount, gLossCount, wr), vx, row, wr>=50?clrLimeGreen:clrTomato, fs); row+=lh;

   // Resize background
   PanelRect("BG", x, y0, 260, row-y0+8, C'15,15,25');

   ChartRedraw(0);
}
//+------------------------------------------------------------------+
