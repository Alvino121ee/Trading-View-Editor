//+------------------------------------------------------------------+
//|  ZS_MT5_Bridge_EA.mq5  — Market Order + Trailing Stop Edition   |
//|                                                                  |
//|  CARA INSTALL:                                                   |
//|  1. Copy ke: MT5 > File > Open Data Folder > MQL5 > Experts     |
//|  2. Tools > Options > Expert Advisors:                           |
//|     - Centang "Allow Automated Trading"                          |
//|     - Centang "Allow WebRequest for listed URL"                  |
//|     - Tambahkan URL server Anda                                  |
//|  3. Compile (F7) lalu attach ke chart XAUUSD                    |
//+------------------------------------------------------------------+
#property copyright "ZS Trading"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input Parameters
input group "=== SERVER ==="
input string InpServerURL    = "https://YOUR-APP.replit.app"; // URL Server Bridge
input string InpSecret       = "ZS909506";                    // Webhook Secret
input string InpSymbol       = "XAUUSDc";                     // Symbol MT5
input int    InpPollInterval = 5;                              // Poll interval (detik)

input group "=== ORDER ==="
input int    InpMagicNumber  = 909506;                        // Magic Number EA
input int    InpSlippage     = 20;                            // Max Slippage (points)
input bool   InpDeleteOnNew  = true;                          // Tutup posisi lama saat sinyal baru
input double InpMaxLot       = 1.0;                           // Batas maksimal lot

input group "=== TRAILING STOP SYSTEM ==="
// Saat nyentuh TP1 → SL pindah ke Breakeven (entry)
// Saat nyentuh TP2 → SL pindah ke TP1
// Saat nyentuh TP3 → Close posisi (DONE)
input bool   InpTrailingEnabled = true;                       // Aktifkan trailing stop

input group "=== SAFETY ==="
input bool   InpEnabled      = true;                          // EA Aktif

//--- Globals
CTrade         trade;
CPositionInfo  posInfo;

// Data sinyal aktif yang sedang running
double gEntry = 0;
double gSL    = 0;
double gTP1   = 0;
double gTP2   = 0;
double gTP3   = 0;
int    gDir   = 0; // 1=BUY, -1=SELL
bool   gHitTP1 = false;
bool   gHitTP2 = false;
int    gLastSignalId = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(!InpEnabled) { Print("EA dinonaktifkan."); return INIT_SUCCEEDED; }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   EventSetTimer(InpPollInterval);
   Print("ZS Bridge EA v2.0 aktif | Server: ", InpServerURL);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { EventKillTimer(); }

//+------------------------------------------------------------------+
//  MAIN TICK — Trailing Stop Logic
//+------------------------------------------------------------------+
void OnTick()
{
   if(!InpEnabled || !InpTrailingEnabled) return;
   if(gDir == 0) return; // tidak ada posisi aktif yang dimonitor

   // Cari posisi yang sesuai magic number
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      if(posInfo.Symbol() != InpSymbol) continue;

      double curPrice = posInfo.PriceCurrent();
      double curSL    = posInfo.StopLoss();
      ulong  ticket   = posInfo.Ticket();

      if(gDir == 1) // BUY position
      {
         // TP3 tercapai → close
         if(gTP3 > 0 && curPrice >= gTP3)
         {
            Print("TP3 TERCAPAI! Closing BUY @ ", curPrice);
            trade.PositionClose(ticket);
            ResetSignalData();
            return;
         }

         // TP2 tercapai → pindah SL ke TP1
         if(!gHitTP2 && gTP2 > 0 && curPrice >= gTP2)
         {
            gHitTP2 = true;
            if(gTP1 > 0 && curSL < gTP1 - symPoint())
            {
               Print("TP2 TERCAPAI → SL pindah ke TP1 (", gTP1, ")");
               ModifySL(ticket, gTP1);
            }
         }

         // TP1 tercapai → pindah SL ke Breakeven
         if(!gHitTP1 && gTP1 > 0 && curPrice >= gTP1)
         {
            gHitTP1 = true;
            double be = gEntry; // breakeven = entry
            if(curSL < be - symPoint())
            {
               Print("TP1 TERCAPAI → SL pindah ke Breakeven (", be, ")");
               ModifySL(ticket, be);
            }
         }
      }
      else if(gDir == -1) // SELL position
      {
         // TP3 tercapai → close
         if(gTP3 > 0 && curPrice <= gTP3)
         {
            Print("TP3 TERCAPAI! Closing SELL @ ", curPrice);
            trade.PositionClose(ticket);
            ResetSignalData();
            return;
         }

         // TP2 tercapai → pindah SL ke TP1
         if(!gHitTP2 && gTP2 > 0 && curPrice <= gTP2)
         {
            gHitTP2 = true;
            if(gTP1 > 0 && curSL > gTP1 + symPoint())
            {
               Print("TP2 TERCAPAI → SL pindah ke TP1 (", gTP1, ")");
               ModifySL(ticket, gTP1);
            }
         }

         // TP1 tercapai → pindah SL ke Breakeven
         if(!gHitTP1 && gTP1 > 0 && curPrice <= gTP1)
         {
            gHitTP1 = true;
            double be = gEntry;
            if(curSL > be + symPoint())
            {
               Print("TP1 TERCAPAI → SL pindah ke Breakeven (", be, ")");
               ModifySL(ticket, be);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//  TIMER — Poll server untuk sinyal baru
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!InpEnabled) return;
   PollServer();
}

//+------------------------------------------------------------------+
void PollServer()
{
   string url = InpServerURL + "/api/mt5/pending?secret=" + InpSecret + "&symbol=" + InpSymbol;
   char   postData[], result[];
   string headers = "Content-Type: application/json\r\n";
   string resultHeaders;

   int httpCode = WebRequest("GET", url, headers, 5000, postData, result, resultHeaders);
   if(httpCode == -1)
   {
      static bool warned = false;
      if(!warned) { Print("WebRequest gagal. Tambahkan URL di MT5 Options > Expert Advisors > Allow WebRequest. Err=", GetLastError()); warned = true; }
      return;
   }

   string json = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);

   if(StringFind(json, "\"signal\":null") >= 0 || StringFind(json, "\"signal\": null") >= 0)
      return;

   string signalJson = ExtractBlock(json, "signal");
   if(StringLen(signalJson) == 0) return;

   int    sigId  = (int)JsonNum(signalJson, "id");
   string action = JsonStr(signalJson, "action");
   double lot    = JsonNum(signalJson, "lot");
   double entry  = JsonNum(signalJson, "entry");
   double sl     = JsonNum(signalJson, "sl");
   double tp1    = JsonNum(signalJson, "tp1");
   double tp2    = JsonNum(signalJson, "tp2");
   double tp3    = JsonNum(signalJson, "tp3");
   string setup  = JsonStr(signalJson, "setup");
   string cmt    = JsonStr(signalJson, "comment");
   if(StringLen(cmt) == 0) cmt = "ZS " + action + " " + setup;
   if(StringLen(cmt) > 63) cmt = StringSubstr(cmt, 0, 63); // MT5 batas komentar

   if(sigId <= 0 || sigId == gLastSignalId) return;
   if(lot <= 0 || lot > InpMaxLot || sl <= 0)
   {
      Print("Signal tidak valid: lot=", lot, " sl=", sl);
      AckSignal(sigId, 0);
      return;
   }

   Print(">>> SINYAL: ID=", sigId, " | ", action, " | Lot=", lot, " | SL=", sl, " | TP1=", tp1, " | TP2=", tp2, " | TP3=", tp3);

   // Tutup/hapus posisi lama jika ada
   if(InpDeleteOnNew) CloseMyPositions();

   // Market order — entry harga pasar, SL dari sinyal, TP = TP3
   long ticket = ExecuteMarketOrder(action, lot, sl, tp3, cmt);
   gLastSignalId = sigId;

   // Simpan data sinyal untuk trailing stop
   if(ticket > 0)
   {
      gEntry  = (action == "BUY_LIMIT") ? SymbolInfoDouble(InpSymbol, SYMBOL_ASK) : SymbolInfoDouble(InpSymbol, SYMBOL_BID);
      gSL     = sl;
      gTP1    = tp1;
      gTP2    = tp2;
      gTP3    = tp3;
      gDir    = (action == "BUY_LIMIT") ? 1 : -1;
      gHitTP1 = false;
      gHitTP2 = false;
   }

   AckSignal(sigId, ticket);
}

//+------------------------------------------------------------------+
//  Eksekusi market order (BUY/SELL at market)
//+------------------------------------------------------------------+
long ExecuteMarketOrder(string action, double lot, double sl, double tp, string cmt)
{
   bool ok = false;

   if(action == "BUY_LIMIT")
   {
      double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
      // Normalkan SL/TP ke digit simbol
      sl = NormalizeDouble(sl, (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS));
      tp = NormalizeDouble(tp, (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS));
      ok = trade.Buy(lot, InpSymbol, ask, sl, tp, cmt);
   }
   else if(action == "SELL_LIMIT")
   {
      double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
      sl = NormalizeDouble(sl, (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS));
      tp = NormalizeDouble(tp, (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS));
      ok = trade.Sell(lot, InpSymbol, bid, sl, tp, cmt);
   }
   else
   {
      Print("Action tidak dikenal: ", action);
      return 0;
   }

   if(ok)
   {
      long ticket = (long)trade.ResultOrder();
      Print("Market order berhasil: ticket=", ticket, " | ", action, " | SL=", sl, " | TP3=", tp);
      return ticket;
   }
   else
   {
      Print("Order GAGAL: ", trade.ResultRetcodeDescription(), " (", trade.ResultRetcode(), ")");
      return 0;
   }
}

//+------------------------------------------------------------------+
//  Modifikasi SL posisi
//+------------------------------------------------------------------+
void ModifySL(ulong ticket, double newSL)
{
   newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS));
   if(!posInfo.SelectByTicket(ticket)) return;
   double curTP = posInfo.TakeProfit();
   if(trade.PositionModify(ticket, newSL, curTP))
      Print("SL berhasil diubah ke ", newSL, " untuk ticket ", ticket);
   else
      Print("Gagal modifikasi SL: ", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//  Reset data sinyal setelah posisi tertutup
//+------------------------------------------------------------------+
void ResetSignalData()
{
   gEntry = 0; gSL = 0; gTP1 = 0; gTP2 = 0; gTP3 = 0;
   gDir = 0; gHitTP1 = false; gHitTP2 = false;
   Print("Posisi selesai. EA menunggu sinyal berikutnya.");
}

//+------------------------------------------------------------------+
//  Tutup semua posisi milik EA ini
//+------------------------------------------------------------------+
void CloseMyPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == InpSymbol)
      {
         Print("Menutup posisi lama: ticket=", posInfo.Ticket());
         trade.PositionClose(posInfo.Ticket());
      }
   }
   ResetSignalData();
}

//+------------------------------------------------------------------+
//  Kirim ACK ke server
//+------------------------------------------------------------------+
void AckSignal(int sigId, long ticket)
{
   string url  = InpServerURL + "/api/mt5/ack/" + IntegerToString(sigId);
   string body = "{\"secret\":\"" + InpSecret + "\",\"ticket\":" + IntegerToString(ticket) + "}";
   string headers = "Content-Type: application/json\r\n";
   char postData[], result[];
   string resHeaders;
   StringToCharArray(body, postData, 0, StringLen(body), CP_UTF8);
   int code = WebRequest("POST", url, headers, 5000, postData, result, resHeaders);
   if(code == -1) Print("ACK gagal untuk signal ", sigId);
   else Print("ACK sukses: signal=", sigId, " ticket=", ticket);
}

//+------------------------------------------------------------------+
//  Helpers
//+------------------------------------------------------------------+
double symPoint() { return SymbolInfoDouble(InpSymbol, SYMBOL_POINT); }

string ExtractBlock(string json, string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(json, search);
   if(pos < 0) return "";
   pos += StringLen(search);
   while(pos < StringLen(json) && StringSubstr(json, pos, 1) == " ") pos++;
   if(StringSubstr(json, pos, 1) != "{") return "";
   int depth = 0, end = pos;
   while(end < StringLen(json))
   {
      string ch = StringSubstr(json, end, 1);
      if(ch == "{") depth++;
      else if(ch == "}") { depth--; if(depth == 0) { end++; break; } }
      end++;
   }
   return StringSubstr(json, pos, end - pos);
}

string JsonStr(string json, string key)
{
   string search = "\"" + key + "\":\"";
   int pos = StringFind(json, search);
   if(pos < 0) return "";
   pos += StringLen(search);
   int end = pos;
   while(end < StringLen(json) && StringSubstr(json, end, 1) != "\"") end++;
   return StringSubstr(json, pos, end - pos);
}

double JsonNum(string json, string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(json, search);
   if(pos < 0) return 0;
   pos += StringLen(search);
   while(pos < StringLen(json) && StringSubstr(json, pos, 1) == " ") pos++;
   if(StringSubstr(json, pos, 4) == "null") return 0;
   int end = pos;
   while(end < StringLen(json))
   {
      string ch = StringSubstr(json, end, 1);
      if(ch == "," || ch == "}" || ch == "]" || ch == " ") break;
      end++;
   }
   string val = StringSubstr(json, pos, end - pos);
   StringReplace(val, "\"", "");
   return StringToDouble(val);
}
//+------------------------------------------------------------------+
