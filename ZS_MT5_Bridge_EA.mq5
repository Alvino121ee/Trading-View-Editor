//+------------------------------------------------------------------+
//|  ZS_MT5_Bridge_EA.mq5                                           |
//|  Auto trading EA - mengambil sinyal dari TradingView via server  |
//|                                                                  |
//|  CARA INSTALL:                                                   |
//|  1. Copy file ini ke: MT5 > File > Open Data Folder >           |
//|     MQL5 > Experts                                               |
//|  2. Buka MT5 > Tools > Options > Expert Advisors                 |
//|  3. Centang "Allow WebRequest for listed URL"                    |
//|  4. Tambahkan URL server Anda (contoh: https://xxx.replit.app)  |
//|  5. Attach EA ke chart XAUUSD                                    |
//+------------------------------------------------------------------+
#property copyright "ZS Trading"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "=== SERVER SETTINGS ==="
input string InpServerURL    = "https://YOUR-APP.replit.app"; // URL Server (ganti dengan URL Replit Anda)
input string InpSecret       = "ZS909506";                    // Webhook Secret (sama dengan di PineScript)
input string InpSymbol       = "XAUUSD";                      // Symbol MT5
input int    InpPollInterval = 5;                              // Poll setiap N detik

input group "=== ORDER SETTINGS ==="
input int    InpMagicNumber  = 909506;                        // Magic Number
input int    InpSlippage     = 10;                            // Slippage (pips)
input bool   InpDeleteOnNew  = true;                          // Hapus pending lama saat ada sinyal baru
input bool   InpUseTP2       = false;                         // Gunakan TP2 sebagai target (default: TP1)
input bool   InpUseTP3       = false;                         // Gunakan TP3 sebagai target

input group "=== SAFETY ==="
input bool   InpEnabled      = true;                          // EA Aktif
input double InpMaxLot       = 1.0;                           // Maksimal lot per order

//--- Global
CTrade trade;
int    lastSignalId  = 0;
bool   serverReachable = false;

//+------------------------------------------------------------------+
int OnInit()
{
   if(!InpEnabled)
   {
      Print("EA dinonaktifkan via input.");
      return INIT_SUCCEEDED;
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   EventSetTimer(InpPollInterval);
   Print("ZS Bridge EA aktif. Server: ", InpServerURL, " | Poll setiap ", InpPollInterval, "s");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
}

//+------------------------------------------------------------------+
void OnTimer()
{
   if(!InpEnabled) return;
   PollServer();
}

void OnTick() {}

//+------------------------------------------------------------------+
//  Ambil sinyal pending dari server
//+------------------------------------------------------------------+
void PollServer()
{
   string url = InpServerURL + "/api/mt5/pending"
              + "?secret=" + InpSecret
              + "&symbol=" + InpSymbol;

   char   postData[], result[];
   string headers = "Content-Type: application/json\r\n";
   string resultHeaders;

   int httpCode = WebRequest("GET", url, headers, 5000, postData, result, resultHeaders);

   if(httpCode == -1)
   {
      int err = GetLastError();
      if(!serverReachable)
         Print("WebRequest gagal (err=", err, "). Pastikan URL ditambahkan di MT5 Options > Expert Advisors > Allow WebRequest");
      serverReachable = false;
      return;
   }

   if(!serverReachable)
   {
      Print("Server terhubung: ", InpServerURL);
      serverReachable = true;
   }

   string json = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);

   // Tidak ada sinyal
   if(StringFind(json, "\"signal\":null") >= 0 || StringFind(json, "\"signal\": null") >= 0)
      return;

   // Ekstrak blok "signal":{...}
   string signalJson = ExtractSignalBlock(json);
   if(StringLen(signalJson) == 0) return;

   // Parse field
   int    signalId = (int)JsonGetDouble(signalJson, "id");
   string action   = JsonGetString(signalJson, "action");
   double lot      = JsonGetDouble(signalJson, "lot");
   double entry    = JsonGetDouble(signalJson, "entry");
   double sl       = JsonGetDouble(signalJson, "sl");
   double tp1      = JsonGetDouble(signalJson, "tp1");
   double tp2      = JsonGetDouble(signalJson, "tp2");
   double tp3      = JsonGetDouble(signalJson, "tp3");
   string comment  = JsonGetString(signalJson, "comment");
   if(StringLen(comment) == 0) comment = JsonGetString(signalJson, "setup");

   // Validasi dasar
   if(signalId <= 0 || signalId == lastSignalId) return;
   if(lot <= 0 || lot > InpMaxLot || entry <= 0)
   {
      Print("Signal tidak valid: lot=", lot, " entry=", entry);
      AcknowledgeSignal(signalId, 0);
      return;
   }

   // Pilih TP sesuai setting
   double targetTP = tp1;
   if(InpUseTP3 && tp3 > 0) targetTP = tp3;
   else if(InpUseTP2 && tp2 > 0) targetTP = tp2;

   Print(">>> Sinyal diterima: ID=", signalId,
         " | ", action,
         " | Lot=", lot,
         " | Entry=", entry,
         " | SL=", sl,
         " | TP=", targetTP,
         " | ", comment);

   // Hapus pending lama jika diaktifkan
   if(InpDeleteOnNew)
      DeleteMyPendingOrders();

   // Eksekusi order
   long ticket = ExecuteOrder(action, lot, entry, sl, targetTP, comment);
   lastSignalId = signalId;

   // Konfirmasi ke server
   AcknowledgeSignal(signalId, ticket);
}

//+------------------------------------------------------------------+
//  Tempatkan order BUY LIMIT / SELL LIMIT
//+------------------------------------------------------------------+
long ExecuteOrder(string action, double lot, double entry, double sl, double tp, string comment)
{
   bool ok = false;

   if(action == "BUY_LIMIT")
      ok = trade.BuyLimit(lot, entry, InpSymbol, sl, tp, ORDER_TIME_GTC, 0, comment);
   else if(action == "SELL_LIMIT")
      ok = trade.SellLimit(lot, entry, InpSymbol, sl, tp, ORDER_TIME_GTC, 0, comment);
   else
   {
      Print("Action tidak dikenal: ", action);
      return 0;
   }

   if(ok)
   {
      long ticket = (long)trade.ResultOrder();
      Print("Order berhasil: ticket=", ticket, " | ", action, " @ ", entry);
      return ticket;
   }
   else
   {
      Print("Order GAGAL: ", trade.ResultRetcodeDescription(), " (", trade.ResultRetcode(), ")");
      return 0;
   }
}

//+------------------------------------------------------------------+
//  Kirim konfirmasi ke server setelah order ditempatkan
//+------------------------------------------------------------------+
void AcknowledgeSignal(int signalId, long ticket)
{
   string url = InpServerURL + "/api/mt5/ack/" + IntegerToString(signalId);
   string body = "{\"secret\":\"" + InpSecret + "\",\"ticket\":" + IntegerToString(ticket) + "}";
   string headers = "Content-Type: application/json\r\n";
   char   postData[], result[];
   string resultHeaders;

   StringToCharArray(body, postData, 0, StringLen(body), CP_UTF8);

   int httpCode = WebRequest("POST", url, headers, 5000, postData, result, resultHeaders);
   if(httpCode == -1)
      Print("ACK gagal untuk signal ", signalId, " | err=", GetLastError());
   else
      Print("ACK sukses: signal=", signalId, " ticket=", ticket);
}

//+------------------------------------------------------------------+
//  Hapus semua pending order milik EA ini
//+------------------------------------------------------------------+
void DeleteMyPendingOrders()
{
   int deleted = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
         OrderGetString(ORDER_SYMBOL) == InpSymbol)
      {
         if(trade.OrderDelete(ticket))
            deleted++;
      }
   }
   if(deleted > 0)
      Print("Deleted ", deleted, " pending order lama.");
}

//+------------------------------------------------------------------+
//  JSON Helpers - Ekstrak blok "signal":{...}
//+------------------------------------------------------------------+
string ExtractSignalBlock(string json)
{
   string search = "\"signal\":";
   int pos = StringFind(json, search);
   if(pos < 0) return "";
   pos += StringLen(search);

   // Skip spasi
   while(pos < StringLen(json) && StringSubstr(json, pos, 1) == " ") pos++;

   if(StringSubstr(json, pos, 1) != "{") return "";

   int depth = 0, end = pos;
   while(end < StringLen(json))
   {
      string ch = StringSubstr(json, end, 1);
      if(ch == "{")      depth++;
      else if(ch == "}") { depth--; if(depth == 0) { end++; break; } }
      end++;
   }
   return StringSubstr(json, pos, end - pos);
}

//+------------------------------------------------------------------+
//  Ekstrak string value dari JSON
//+------------------------------------------------------------------+
string JsonGetString(string json, string key)
{
   string search = "\"" + key + "\":\"";
   int pos = StringFind(json, search);
   if(pos < 0) return "";
   pos += StringLen(search);
   int end = pos;
   while(end < StringLen(json))
   {
      if(StringSubstr(json, end, 1) == "\"" && (end == 0 || StringSubstr(json, end - 1, 1) != "\\"))
         break;
      end++;
   }
   return StringSubstr(json, pos, end - pos);
}

//+------------------------------------------------------------------+
//  Ekstrak numeric value dari JSON
//+------------------------------------------------------------------+
double JsonGetDouble(string json, string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(json, search);
   if(pos < 0) return 0;
   pos += StringLen(search);

   // Skip spasi
   while(pos < StringLen(json) && StringSubstr(json, pos, 1) == " ") pos++;

   // null
   if(StringSubstr(json, pos, 4) == "null") return 0;

   int end = pos;
   while(end < StringLen(json))
   {
      string ch = StringSubstr(json, end, 1);
      if(ch == "," || ch == "}" || ch == "]" || ch == " ") break;
      end++;
   }
   string val = StringSubstr(json, pos, end - pos);
   // Hapus tanda kutip jika ada (angka kadang dikutip karena numeric dari DB)
   StringReplace(val, "\"", "");
   return StringToDouble(val);
}
//+------------------------------------------------------------------+
