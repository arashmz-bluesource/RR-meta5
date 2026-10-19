//+------------------------------------------------------------------+
//|                                       RR_Backtest_Tool.mq5       |
//| Interactive multi-trade Risk/Reward drawing tool for MT5         |
//+------------------------------------------------------------------+
#property copyright "arashmirzaie.1997@gmail.com"
#property version   "3.00"
#property description "Multi-trade RR backtest tool with alerts and average-candle defaults"
#property indicator_chart_window
#property indicator_plots 0

input int    InpAveragePeriod          = 20;  // Closed candles used for average High-Low range
input double InpCandleRangeMultiplier  = 2.0; // Default SL and TP distance = average range x multiplier
input int    InpBoxBars                = 10;  // Initial box width (bars)
input int    InpBoxTransparency        = 60;  // Approximate box transparency, percent (0=solid, 100=background)
input string InpInstanceTag            = "A"; // Different tag for another copy on the same chart

string g_prefix;
string g_buyButton;
string g_sellButton;
string g_previousButton;
string g_nextButton;
string g_pageLabel;
string g_panelName;
string g_panelAccentName;
string g_panelTitleName;
string g_panelSubtitleName;
int    g_listPage = 0;

#define RR_LIST_ROWS       6
#define RR_ROW_HEIGHT      26
#define RR_LIST_TOP_Y      242
#define RR_BUTTON_Y        32
#define RR_BUTTON_HEIGHT   46
#define RR_PANEL_X         8
#define RR_PANEL_Y         8
#define RR_PANEL_WIDTH     430
#define RR_PANEL_HEIGHT    334

struct RRTrade
  {
   int      id;
   string   greenName;
   string   redName;
   string   rrName;
   string   alertStateName;
   string   alertButtonName;
   bool     isBuy;
   bool     alertEnabled;
   bool     alertTriggered;
   bool     hasAlertQuote;
   double   lastAlertQuote;
   datetime tLeft;
   datetime tRight;
   double   entry;
   double   sl;
   double   tp;
   datetime prevGreenT0;
   datetime prevGreenT1;
   datetime prevRedT0;
   datetime prevRedT1;
   double   prevGreenP0;
   double   prevGreenP1;
   double   prevRedP0;
   double   prevRedP1;
  };

RRTrade g_trades[];
int     g_nextId = 1;
bool    g_ready  = false;

//+------------------------------------------------------------------+
int OnInit()
  {
   string safeTag = StringSubstr(InpInstanceTag, 0, 8);
   g_prefix    = "RRB_" + (string)ChartID() + "_" + IntegerToString((int)_Period) + "_" + safeTag;
   g_buyButton = g_prefix + "_BUY_BTN";
   g_sellButton= g_prefix + "_SELL_BTN";

   g_previousButton = g_prefix + "_LIST_PREV";
   g_nextButton     = g_prefix + "_LIST_NEXT";
   g_pageLabel      = g_prefix + "_LIST_PAGE";
   g_panelName      = g_prefix + "_PANEL";
   g_panelAccentName= g_prefix + "_PANEL_ACCENT";
   g_panelTitleName = g_prefix + "_PANEL_TITLE";
   g_panelSubtitleName = g_prefix + "_PANEL_SUBTITLE";

   CreatePanelChrome();
   CreateDirectionButton(g_buyButton,  "BUY",  20, clrSeaGreen);
   CreateDirectionButton(g_sellButton, "SELL", 224, clrIndianRed);
   CreateNavigationControls();

   ArrayResize(g_trades, 0);
   RemoveLegacyTextObjects();
   LoadExistingTrades();
   g_ready = true;
   RefreshTradeList();
   EventSetMillisecondTimer(250);
   ChartRedraw(0);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void CreatePanelChrome()
  {
   if(ObjectFind(0, g_panelName) < 0)
      ObjectCreate(0, g_panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panelName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, g_panelName, OBJPROP_XDISTANCE, RR_PANEL_X);
   ObjectSetInteger(0, g_panelName, OBJPROP_YDISTANCE, RR_PANEL_Y);
   ObjectSetInteger(0, g_panelName, OBJPROP_XSIZE, RR_PANEL_WIDTH);
   ObjectSetInteger(0, g_panelName, OBJPROP_YSIZE, RR_PANEL_HEIGHT);
   ObjectSetInteger(0, g_panelName, OBJPROP_BGCOLOR, C'36,41,50');
   ObjectSetInteger(0, g_panelName, OBJPROP_COLOR, C'63,71,83');
   ObjectSetInteger(0, g_panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, g_panelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_panelName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, g_panelName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, g_panelName, OBJPROP_BACK, false);
   ObjectSetInteger(0, g_panelName, OBJPROP_ZORDER, 1);

   if(ObjectFind(0, g_panelAccentName) < 0)
      ObjectCreate(0, g_panelAccentName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panelAccentName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, g_panelAccentName, OBJPROP_XDISTANCE, RR_PANEL_X);
   ObjectSetInteger(0, g_panelAccentName, OBJPROP_YDISTANCE, RR_PANEL_Y);
   ObjectSetInteger(0, g_panelAccentName, OBJPROP_XSIZE, 4);
   ObjectSetInteger(0, g_panelAccentName, OBJPROP_YSIZE, RR_PANEL_HEIGHT);
   ObjectSetInteger(0, g_panelAccentName, OBJPROP_BGCOLOR, C'64,190,150');
   ObjectSetInteger(0, g_panelAccentName, OBJPROP_COLOR, C'64,190,150');
   ObjectSetInteger(0, g_panelAccentName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, g_panelAccentName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_panelAccentName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, g_panelAccentName, OBJPROP_BACK, false);
   ObjectSetInteger(0, g_panelAccentName, OBJPROP_ZORDER, 2);

   CreatePanelLabel(g_panelTitleName, "RR BACKTEST", 24, 300, 13, clrWhite, "Tahoma Bold");
   CreatePanelLabel(g_panelSubtitleName, "TRADE MANAGER   /   DRAG LEVELS TO ADJUST RR", 24, 279, 8, C'166,181,199', "Tahoma");
  }

//+------------------------------------------------------------------+
void CreatePanelLabel(const string name,
                      const string text,
                      const int x,
                      const int y,
                      const int fontSize,
                      const color textColor,
                      const string fontName)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, fontName);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
  }

//+------------------------------------------------------------------+
void RemoveLegacyTextObjects()
  {
   // Remove labels/edit fields from older releases that displayed trade notes.
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, g_prefix) != 0) continue;
      int len = StringLen(name);
      if((len >= 9 && StringSubstr(name, len - 9) == "_STRATEGY") ||
         (len >= 11 && StringSubstr(name, len - 11) == "_STRAT_EDIT"))
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
void CreateDirectionButton(const string name,
                           const string caption,
                           const int xDistance,
                           const color background)
  {
   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
        {
         Print("RR tool: cannot create button ", name, ", error ", GetLastError());
         return;
        }
     }

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xDistance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, RR_BUTTON_Y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 194);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, RR_BUTTON_HEIGHT);
   ObjectSetString(0, name, OBJPROP_TEXT, caption);
   ObjectSetString(0, name, OBJPROP_FONT, "Tahoma Bold");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 13);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'80,88,99');
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
  }

//+------------------------------------------------------------------+
void CreateTrade(const bool isBuy)
  {
   int id = GetNextTradeId();
   RRTrade trade;
   trade.id             = id;
   trade.greenName      = g_prefix + "_T" + IntegerToString(id) + "_GREEN";
   trade.redName        = g_prefix + "_T" + IntegerToString(id) + "_RED";
   trade.rrName         = g_prefix + "_T" + IntegerToString(id) + "_RR";
   trade.alertStateName = UiNameById(id, "_ALERT_STATE");
   trade.alertButtonName= UiNameById(id, "_ALERT_BTN");
   trade.isBuy          = isBuy;
   trade.alertEnabled   = false;
   trade.alertTriggered = false;
   trade.hasAlertQuote  = false;
   trade.lastAlertQuote = 0.0;

   // Anchor new drawings to the center of the visible chart, which may be historical.
   int firstVisible = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR, 0);
   int visibleBars  = (int)ChartGetInteger(0, CHART_VISIBLE_BARS, 0);
   int totalBars    = Bars(_Symbol, _Period);
   int centerShift  = firstVisible - (int)MathMax(1, visibleBars / 2);
   if(centerShift < 0) centerShift = 0;
   if(totalBars > 0 && centerShift >= totalBars) centerShift = totalBars - 1;

   datetime centerTime = iTime(_Symbol, _Period, centerShift);
   double price = iClose(_Symbol, _Period, centerShift);
   if(centerTime <= 0)
     {
      centerTime = iTime(_Symbol, _Period, 0);
      price = (isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                     : SymbolInfoDouble(_Symbol, SYMBOL_BID));
     }
   if(centerTime <= 0) centerTime = TimeCurrent();
   if(price <= 0.0)
      price = (isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                     : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(price <= 0.0) price = 1.0;

   trade.entry = NormalizeDouble(price, _Digits);
   double rangeDistance = GetAverageCandleRange(centerShift) * MathMax(0.1, InpCandleRangeMultiplier);
   rangeDistance = MathMax(_Point, rangeDistance);
   double direction = (isBuy ? 1.0 : -1.0);
   // Both default SL and TP distances use multiplier x average range of the 20 prior closed candles.
   trade.sl = NormalizeDouble(trade.entry - direction * rangeDistance, _Digits);
   trade.tp = NormalizeDouble(trade.entry + direction * rangeDistance, _Digits);

   int seconds = PeriodSeconds(_Period);
   if(seconds <= 0) seconds = 60;
   int bars = (int)MathMax(3, InpBoxBars);
   datetime halfSpan = (datetime)(seconds * bars / 2);
   trade.tLeft  = centerTime - halfSpan;
   trade.tRight = centerTime + halfSpan;

   if(!CreateRectangle(trade.greenName, clrLimeGreen,
                       trade.tLeft, trade.entry, trade.tRight, trade.tp))
      return;
   if(!CreateRectangle(trade.redName, clrTomato,
                       trade.tLeft, trade.sl, trade.tRight, trade.entry))
     {
      ObjectDelete(0, trade.greenName);
      return;
     }

   CreateTextLabel(trade.rrName, clrWhite, 10, true);

   int n = ArraySize(g_trades);
   if(ArrayResize(g_trades, n + 1) != n + 1)
     {
      ObjectDelete(0, trade.greenName);
      ObjectDelete(0, trade.redName);
      ObjectDelete(0, trade.rrName);
      return;
     }
   g_trades[n] = trade;
   CreateAlertStateMarker(n, "0");
   g_trades[n].lastAlertQuote = GetAlertQuote(g_trades[n].isBuy);
   g_trades[n].hasAlertQuote = (g_trades[n].lastAlertQuote > 0.0);
   UpdateTradeObjects(n, true);
   g_listPage = 0;
   RefreshTradeList();
   Print("RR tool: created ", (isBuy ? "BUY" : "SELL"), " tool #", id);
  }

//+------------------------------------------------------------------+
double GetAverageCandleRange(const int referenceShift)
  {
   int period = (int)MathMax(1, InpAveragePeriod);
   int totalBars = Bars(_Symbol, _Period);
   double sum = 0.0;
   int count = 0;
   // Shift 0 is current bar. Use fully closed candles immediately before the chart anchor.
   for(int i = 1; i <= period; i++)
     {
      int shift = referenceShift + i;
      if(shift < 0 || shift >= totalBars) break;
      double candleHigh = iHigh(_Symbol, _Period, shift);
      double candleLow  = iLow(_Symbol, _Period, shift);
      if(candleHigh <= 0.0 || candleLow <= 0.0 || candleHigh < candleLow) continue;
      sum += (candleHigh - candleLow);
      count++;
     }
   if(count > 0) return(sum / count);

   // Fallback for a chart with insufficient downloaded history.
   return(MathMax(_Point, 100.0 * _Point));
  }

//+------------------------------------------------------------------+
int GetNextTradeId()
  {
   while(true)
     {
      string candidateGreen = g_prefix + "_T" + IntegerToString(g_nextId) + "_GREEN";
      string candidateRed   = g_prefix + "_T" + IntegerToString(g_nextId) + "_RED";
      if(ObjectFind(0, candidateGreen) < 0 && ObjectFind(0, candidateRed) < 0)
         break;
      g_nextId++;
     }
   int id = g_nextId;
   g_nextId++;
   return(id);
  }

//+------------------------------------------------------------------+
bool CreateRectangle(const string name,
                     const color boxColor,
                     const datetime t0,
                     const double p0,
                     const datetime t1,
                     const double p1)
  {
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t0, p0, t1, p1))
     {
      Print("RR tool: cannot create rectangle ", name, ", error ", GetLastError());
      return(false);
     }
   ObjectSetInteger(0, name, OBJPROP_COLOR, BlendBoxColor(boxColor));
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
   return(true);
  }

//+------------------------------------------------------------------+
void CreateTextLabel(const string name,
                     const color textColor,
                     const int fontSize,
                     const bool bold)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, TimeCurrent(), SymbolInfoDouble(_Symbol, SYMBOL_BID));
   ObjectSetString(0, name, OBJPROP_FONT, (bold ? "Tahoma Bold" : "Tahoma"));
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, (int)MathMax(8, fontSize));
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
  }

//+------------------------------------------------------------------+
string MakeRRText(const RRTrade &trade,
                  const double entry,
                  const double stop,
                  const double target)
  {
   double riskDistance = MathAbs(entry - stop);
   double rewardDistance = MathAbs(target - entry);
   if(riskDistance < _Point * 0.1)
      return((trade.isBuy ? "BUY" : "SELL") + " | RR --");

   double rr = rewardDistance / riskDistance;
   return(StringFormat("%s | RR 1:%.2f", (trade.isBuy ? "BUY" : "SELL"), rr));
  }

//+------------------------------------------------------------------+
void MoveLabels(const RRTrade &trade,
                const datetime tLeft,
                const datetime tRight,
                const double entry,
                const double stop,
                const double target)
  {
   // Keep the RR label outside the rectangle on its left edge; no points/pips are printed.
   if(ObjectFind(0, trade.rrName) < 0)
      CreateTextLabel(trade.rrName, clrWhite, 10, true);
   if(ObjectFind(0, trade.rrName) >= 0)
     {
      ObjectMove(0, trade.rrName, 0, tLeft, entry);
      ObjectSetString(0, trade.rrName, OBJPROP_TEXT, MakeRRText(trade, entry, stop, target));
      ObjectSetInteger(0, trade.rrName, OBJPROP_COLOR, C'245,247,250');
      ObjectSetInteger(0, trade.rrName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
     }
  }

//+------------------------------------------------------------------+
void UpdateTradeObjects(const int index, const bool moveRectangles)
  {
   if(index < 0 || index >= ArraySize(g_trades)) return;
   RRTrade trade = g_trades[index];

   if(moveRectangles)
     {
      if(ObjectFind(0, trade.greenName) >= 0)
        {
         ObjectMove(0, trade.greenName, 0, trade.tLeft, trade.entry);
         ObjectMove(0, trade.greenName, 1, trade.tRight, trade.tp);
        }
      if(ObjectFind(0, trade.redName) >= 0)
        {
         ObjectMove(0, trade.redName, 0, trade.tLeft, trade.sl);
         ObjectMove(0, trade.redName, 1, trade.tRight, trade.entry);
        }
     }

   MoveLabels(trade, trade.tLeft, trade.tRight, trade.entry, trade.sl, trade.tp);
   SaveSnapshot(index);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
void SaveSnapshot(const int index)
  {
   if(index < 0 || index >= ArraySize(g_trades)) return;
   if(ObjectFind(0, g_trades[index].greenName) >= 0)
     {
      g_trades[index].prevGreenT0 = (datetime)ObjectGetInteger(0, g_trades[index].greenName, OBJPROP_TIME, 0);
      g_trades[index].prevGreenT1 = (datetime)ObjectGetInteger(0, g_trades[index].greenName, OBJPROP_TIME, 1);
      g_trades[index].prevGreenP0 = ObjectGetDouble(0, g_trades[index].greenName, OBJPROP_PRICE, 0);
      g_trades[index].prevGreenP1 = ObjectGetDouble(0, g_trades[index].greenName, OBJPROP_PRICE, 1);
     }
   if(ObjectFind(0, g_trades[index].redName) >= 0)
     {
      g_trades[index].prevRedT0 = (datetime)ObjectGetInteger(0, g_trades[index].redName, OBJPROP_TIME, 0);
      g_trades[index].prevRedT1 = (datetime)ObjectGetInteger(0, g_trades[index].redName, OBJPROP_TIME, 1);
      g_trades[index].prevRedP0 = ObjectGetDouble(0, g_trades[index].redName, OBJPROP_PRICE, 0);
      g_trades[index].prevRedP1 = ObjectGetDouble(0, g_trades[index].redName, OBJPROP_PRICE, 1);
     }
  }

//+------------------------------------------------------------------+
bool ReadRectangle(const string name,
                   datetime &t0,
                   double &p0,
                   datetime &t1,
                   double &p1)
  {
   if(ObjectFind(0, name) < 0) return(false);
   t0 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
   t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
   p0 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
   p1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
   return(true);
  }

//+------------------------------------------------------------------+
bool PriceChanged(const double a, const double b)
  {
   return(MathAbs(a - b) > MathMax(_Point * 0.1, 0.0000000001));
  }

//+------------------------------------------------------------------+
bool TradeObjectsChanged(const int index,
                         const string objectName,
                         datetime &t0,
                         double &p0,
                         datetime &t1,
                         double &p1)
  {
   if(!ReadRectangle(objectName, t0, p0, t1, p1)) return(false);
   if(objectName == g_trades[index].greenName)
      return(t0 != g_trades[index].prevGreenT0 || t1 != g_trades[index].prevGreenT1 ||
             PriceChanged(p0, g_trades[index].prevGreenP0) || PriceChanged(p1, g_trades[index].prevGreenP1));
   return(t0 != g_trades[index].prevRedT0 || t1 != g_trades[index].prevRedT1 ||
          PriceChanged(p0, g_trades[index].prevRedP0) || PriceChanged(p1, g_trades[index].prevRedP1));
  }

//+------------------------------------------------------------------+
bool GetPreviewState(const int index,
                     datetime &tLeft,
                     datetime &tRight,
                     double &entry,
                     double &stop,
                     double &target)
  {
   if(index < 0 || index >= ArraySize(g_trades)) return(false);
   RRTrade trade = g_trades[index];
   tLeft = trade.tLeft;
   tRight = trade.tRight;
   entry = trade.entry;
   stop = trade.sl;
   target = trade.tp;

   datetime t0 = 0, t1 = 0;
   double p0 = 0.0, p1 = 0.0;
   bool changed = TradeObjectsChanged(index, trade.greenName, t0, p0, t1, p1);
   bool greenChanged = changed;
   bool redChanged = false;

   if(greenChanged)
     {
      bool c0 = PriceChanged(p0, trade.prevGreenP0);
      bool c1 = PriceChanged(p1, trade.prevGreenP1);
      double d0 = p0 - trade.prevGreenP0;
      double d1 = p1 - trade.prevGreenP1;
      double moveTol = MathMax(_Point * 3.0, MathMax(MathAbs(d0), MathAbs(d1)) * 0.02);
      if(c0 && c1 && MathAbs(d0 - d1) <= moveTol)
        {
         double delta = (d0 + d1) / 2.0;
         entry += delta; stop += delta; target += delta;
        }
      else
        {
         if(c0) entry = p0;
         if(c1) target = p1;
        }
      tLeft = t0;
      tRight = t1;
     }
   else
     {
      redChanged = TradeObjectsChanged(index, trade.redName, t0, p0, t1, p1);
      if(redChanged)
        {
         bool c0 = PriceChanged(p0, trade.prevRedP0);
         bool c1 = PriceChanged(p1, trade.prevRedP1);
         double d0 = p0 - trade.prevRedP0;
         double d1 = p1 - trade.prevRedP1;
         double moveTol = MathMax(_Point * 3.0, MathMax(MathAbs(d0), MathAbs(d1)) * 0.02);
         if(c0 && c1 && MathAbs(d0 - d1) <= moveTol)
           {
            double delta = (d0 + d1) / 2.0;
            entry += delta; stop += delta; target += delta;
           }
         else
           {
            if(c0) stop = p0;
            if(c1) entry = p1;
           }
         tLeft = t0;
         tRight = t1;
        }
     }
   return(greenChanged || redChanged);
  }

//+------------------------------------------------------------------+
void CommitDraggedRectangle(const int index, const string objectName)
  {
   if(index < 0 || index >= ArraySize(g_trades)) return;
   bool isGreen = (objectName == g_trades[index].greenName);
   datetime t0 = 0, t1 = 0;
   double p0 = 0.0, p1 = 0.0;
   if(!ReadRectangle(objectName, t0, p0, t1, p1)) return;

   double oldP0 = (isGreen ? g_trades[index].prevGreenP0 : g_trades[index].prevRedP0);
   double oldP1 = (isGreen ? g_trades[index].prevGreenP1 : g_trades[index].prevRedP1);
   bool c0 = PriceChanged(p0, oldP0);
   bool c1 = PriceChanged(p1, oldP1);
   double d0 = p0 - oldP0;
   double d1 = p1 - oldP1;
   double moveTol = MathMax(_Point * 3.0, MathMax(MathAbs(d0), MathAbs(d1)) * 0.02);

   // Dragging the body vertically shifts Entry, SL and TP together; moving
   // a single corner changes only that level. Horizontal movement shifts both boxes.
   if(c0 && c1 && MathAbs(d0 - d1) <= moveTol)
     {
      double delta = (d0 + d1) / 2.0;
      g_trades[index].entry += delta;
      g_trades[index].sl    += delta;
      g_trades[index].tp    += delta;
     }
   else
     {
      if(isGreen)
        {
         if(c0) g_trades[index].entry = p0;
         if(c1) g_trades[index].tp = p1;
        }
      else
        {
         if(c0) g_trades[index].sl = p0;
         if(c1) g_trades[index].entry = p1;
        }
     }

   g_trades[index].tLeft  = t0;
   g_trades[index].tRight = t1;
   g_trades[index].entry  = NormalizeDouble(g_trades[index].entry, _Digits);
   g_trades[index].sl     = NormalizeDouble(g_trades[index].sl, _Digits);
   g_trades[index].tp     = NormalizeDouble(g_trades[index].tp, _Digits);
   UpdateTradeObjects(index, true);
  }

//+------------------------------------------------------------------+
int FindTradeByObjectName(const string objectName)
  {
   for(int i = 0; i < ArraySize(g_trades); i++)
     {
      if(objectName == g_trades[i].greenName || objectName == g_trades[i].redName)
         return(i);
     }
   return(-1);
  }

//+------------------------------------------------------------------+
void LoadExistingTrades()
  {
   string marker = g_prefix + "_T";
   string suffix = "_GREEN";
   int total = ObjectsTotal(0, 0, -1);
   int ids[];
   for(int i = 0; i < total; i++)
     {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, marker) != 0) continue;
      int nameLen = StringLen(name);
      if(nameLen < StringLen(suffix) || StringSubstr(name, nameLen - StringLen(suffix)) != suffix)
         continue;
      int idStart = StringLen(marker);
      int idLen = nameLen - idStart - StringLen(suffix);
      if(idLen <= 0) continue;
      int id = (int)StringToInteger(StringSubstr(name, idStart, idLen));
      if(id <= 0) continue;
      bool exists = false;
      for(int k = 0; k < ArraySize(ids); k++) if(ids[k] == id) exists = true;
      if(!exists)
        {
         int n = ArraySize(ids);
         ArrayResize(ids, n + 1);
         ids[n] = id;
        }
     }

   for(int j = 0; j < ArraySize(ids); j++)
     {
      LoadTradeFromId(ids[j]);
      if(ids[j] >= g_nextId) g_nextId = ids[j] + 1;
     }
  }

//+------------------------------------------------------------------+
void LoadTradeFromId(const int id)
  {
   string base = g_prefix + "_T" + IntegerToString(id);
   RRTrade trade;
   trade.id              = id;
   trade.greenName       = base + "_GREEN";
   trade.redName         = base + "_RED";
   trade.rrName          = base + "_RR";
   trade.alertStateName  = UiNameById(id, "_ALERT_STATE");
   trade.alertButtonName = UiNameById(id, "_ALERT_BTN");
   trade.alertEnabled    = false;
   trade.alertTriggered  = false;
   trade.hasAlertQuote   = false;
   trade.lastAlertQuote  = 0.0;

   // Remove old visual labels from earlier versions.
   ObjectDelete(0, base + "_STRATEGY");
   ObjectDelete(0, UiNameById(id, "_STRAT_EDIT"));

   if(ObjectFind(0, trade.greenName) < 0 || ObjectFind(0, trade.redName) < 0)
      return;
   ObjectSetInteger(0, trade.greenName, OBJPROP_COLOR, BlendBoxColor(clrLimeGreen));
   ObjectSetInteger(0, trade.redName, OBJPROP_COLOR, BlendBoxColor(clrTomato));
   trade.tLeft = (datetime)ObjectGetInteger(0, trade.greenName, OBJPROP_TIME, 0);
   trade.tRight= (datetime)ObjectGetInteger(0, trade.greenName, OBJPROP_TIME, 1);
   trade.entry = ObjectGetDouble(0, trade.greenName, OBJPROP_PRICE, 0);
   trade.tp    = ObjectGetDouble(0, trade.greenName, OBJPROP_PRICE, 1);
   trade.sl    = ObjectGetDouble(0, trade.redName, OBJPROP_PRICE, 0);
   trade.isBuy = (trade.tp >= trade.entry);

   if(ObjectFind(0, trade.alertStateName) >= 0)
     {
      string saved = ObjectGetString(0, trade.alertStateName, OBJPROP_TEXT);
      trade.alertEnabled = (saved == "1" || saved == "2");
      trade.alertTriggered = (saved == "2");
     }
   else
      CreateAlertStateMarkerForName(trade.alertStateName, "0");

   trade.lastAlertQuote = GetAlertQuote(trade.isBuy);
   trade.hasAlertQuote = (trade.lastAlertQuote > 0.0);

   int n = ArraySize(g_trades);
   if(ArrayResize(g_trades, n + 1) != n + 1) return;
   g_trades[n] = trade;
   if(ObjectFind(0, trade.rrName) < 0) CreateTextLabel(trade.rrName, clrWhite, 10, true);
   UpdateTradeObjects(n, false);
  }

//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!g_ready) return;
   bool redraw = false;
   for(int i = 0; i < ArraySize(g_trades); i++)
     {
      datetime tLeft, tRight;
      double entry, stop, target;
      bool changed = GetPreviewState(i, tLeft, tRight, entry, stop, target);
      if(changed)
        {
         MoveLabels(g_trades[i], tLeft, tRight, entry, stop, target);
         redraw = true;
        }
      UpdateTradeRowSummary(i, entry, stop, target);
      CheckTradeAlert(i, stop, target);
     }
   if(redraw) ChartRedraw(0);
  }

//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == g_buyButton)
        {
         ObjectSetInteger(0, g_buyButton, OBJPROP_STATE, false);
         CreateTrade(true);
         return;
        }
      if(sparam == g_sellButton)
        {
         ObjectSetInteger(0, g_sellButton, OBJPROP_STATE, false);
         CreateTrade(false);
         return;
        }
      if(sparam == g_previousButton)
        {
         ObjectSetInteger(0, g_previousButton, OBJPROP_STATE, false);
         if(g_listPage > 0) g_listPage--;
         RefreshTradeList();
         return;
        }
      if(sparam == g_nextButton)
        {
         ObjectSetInteger(0, g_nextButton, OBJPROP_STATE, false);
         int pages = (int)MathCeil((double)ArraySize(g_trades) / RR_LIST_ROWS);
         if(g_listPage + 1 < pages) g_listPage++;
         RefreshTradeList();
         return;
        }

      int alertIndex = FindTradeByUiObject(sparam, "_ALERT_BTN");
      if(alertIndex >= 0)
        {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         g_trades[alertIndex].alertEnabled = !g_trades[alertIndex].alertEnabled;
         // Switching ON arms the next crossing; it will not fire immediately just because price is already beyond a level.
         g_trades[alertIndex].alertTriggered = false;
         g_trades[alertIndex].lastAlertQuote = GetAlertQuote(g_trades[alertIndex].isBuy);
         g_trades[alertIndex].hasAlertQuote = (g_trades[alertIndex].lastAlertQuote > 0.0);
         SaveAlertState(alertIndex);
         UpdateAlertButton(alertIndex);
         return;
        }

      int deleteIndex = FindTradeByUiObject(sparam, "_DEL");
      if(deleteIndex >= 0)
        {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         DeleteTradeAt(deleteIndex);
         return;
        }
     }

   if(id == CHARTEVENT_OBJECT_DRAG)
     {
      int index = FindTradeByObjectName(sparam);
      if(index >= 0)
        {
         CommitDraggedRectangle(index, sparam);
         UpdateTradeRowSummary(index, g_trades[index].entry, g_trades[index].sl, g_trades[index].tp);
         return;
        }
     }

   if(id == CHARTEVENT_CHART_CHANGE)
     {
      for(int i = 0; i < ArraySize(g_trades); i++)
        {
         datetime tLeft, tRight;
         double entry, stop, target;
         if(!GetPreviewState(i, tLeft, tRight, entry, stop, target))
           {
            tLeft = g_trades[i].tLeft; tRight = g_trades[i].tRight;
            entry = g_trades[i].entry; stop = g_trades[i].sl; target = g_trades[i].tp;
           }
         MoveLabels(g_trades[i], tLeft, tRight, entry, stop, target);
         UpdateTradeRowSummary(i, entry, stop, target);
        }
      ChartRedraw(0);
     }
  }

//+------------------------------------------------------------------+
color BlendBoxColor(const color foreground)
  {
   // OBJ_RECTANGLE has no native alpha-fill property in MT5. Blend the
   // requested foreground with chart background to visually approximate
   // InpBoxTransparency (60 means 40% foreground / 60% background).
   int transparency = InpBoxTransparency;
   if(transparency < 0) transparency = 0;
   if(transparency > 100) transparency = 100;
   double opacity = (100.0 - transparency) / 100.0;

   long bgValue = (long)clrWhite;
   ChartGetInteger(0, CHART_COLOR_BACKGROUND, 0, bgValue);
   color background = (color)bgValue;

   int fr = ((int)foreground) & 0xFF;
   int fg = (((int)foreground) >> 8) & 0xFF;
   int fb = (((int)foreground) >> 16) & 0xFF;
   int br = ((int)background) & 0xFF;
   int bg = (((int)background) >> 8) & 0xFF;
   int bb = (((int)background) >> 16) & 0xFF;

   int r = (int)MathRound(fr * opacity + br * (1.0 - opacity));
   int g = (int)MathRound(fg * opacity + bg * (1.0 - opacity));
   int b = (int)MathRound(fb * opacity + bb * (1.0 - opacity));
   return((color)(r | (g << 8) | (b << 16)));
  }

//+------------------------------------------------------------------+
string UiNameById(const int tradeId, const string suffix)
  {
   return(g_prefix + "_T" + IntegerToString(tradeId) + suffix);
  }

//+------------------------------------------------------------------+
void CreateNavigationControls()
  {
   if(ObjectFind(0, g_previousButton) < 0)
      ObjectCreate(0, g_previousButton, OBJ_BUTTON, 0, 0, 0);
   if(ObjectFind(0, g_nextButton) < 0)
      ObjectCreate(0, g_nextButton, OBJ_BUTTON, 0, 0, 0);
   if(ObjectFind(0, g_pageLabel) < 0)
      ObjectCreate(0, g_pageLabel, OBJ_LABEL, 0, 0, 0);

   ConfigureSmallButton(g_previousButton, "< PREV", 20, 22, clrSlateGray);
   ConfigureSmallButton(g_nextButton, "NEXT >", 98, 22, clrSlateGray);
   ObjectSetInteger(0, g_pageLabel, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, g_pageLabel, OBJPROP_XDISTANCE, 182);
   ObjectSetInteger(0, g_pageLabel, OBJPROP_YDISTANCE, 91);
   ObjectSetString(0, g_pageLabel, OBJPROP_FONT, "Tahoma");
   ObjectSetInteger(0, g_pageLabel, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, g_pageLabel, OBJPROP_COLOR, C'190,198,210');
   ObjectSetInteger(0, g_pageLabel, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, g_pageLabel, OBJPROP_ZORDER, 120);
  }

//+------------------------------------------------------------------+
void ConfigureSmallButton(const string name,
                          const string caption,
                          const int x,
                          const int y,
                          const color bg)
  {
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 70);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 21);
   ObjectSetString(0, name, OBJPROP_TEXT, caption);
   ObjectSetString(0, name, OBJPROP_FONT, "Tahoma Bold");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'84,91,103');
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 120);
  }

//+------------------------------------------------------------------+
void DeleteAllTradeListRows()
  {
   for(int i = 0; i < ArraySize(g_trades); i++)
     {
      ObjectDelete(0, UiNameById(g_trades[i].id, "_ROW"));
      ObjectDelete(0, UiNameById(g_trades[i].id, "_ROW_BG"));
      ObjectDelete(0, UiNameById(g_trades[i].id, "_ALERT_BTN"));
      ObjectDelete(0, UiNameById(g_trades[i].id, "_DEL"));
      ObjectDelete(0, UiNameById(g_trades[i].id, "_STRAT_EDIT"));
     }
  }

//+------------------------------------------------------------------+
string MakeListRowText(const int index,
                       const double entry,
                       const double stop,
                       const double target)
  {
   if(index < 0 || index >= ArraySize(g_trades)) return("");
   double risk = MathAbs(entry - stop);
   double reward = MathAbs(target - entry);
   string rr = "RR --";
   if(risk > _Point * 0.1)
      rr = StringFormat("RR 1:%.2f", reward / risk);
   return(StringFormat("#%d   %s   |   %s", g_trades[index].id,
                       (g_trades[index].isBuy ? "BUY" : "SELL"), rr));
  }

//+------------------------------------------------------------------+
void CreateTradeListRow(const int index, const int y)
  {
   if(index < 0 || index >= ArraySize(g_trades)) return;
   int id = g_trades[index].id;
   string rowName = UiNameById(id, "_ROW");
   string bgName = UiNameById(id, "_ROW_BG");
   string alertName = UiNameById(id, "_ALERT_BTN");
   string deleteName = UiNameById(id, "_DEL");

   if(ObjectFind(0, bgName) < 0)
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, 17);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 412);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'47,53,63');
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, C'57,65,77');
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_ZORDER, 15);

   if(ObjectFind(0, rowName) < 0)
      ObjectCreate(0, rowName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, rowName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, rowName, OBJPROP_XDISTANCE, 25);
   ObjectSetInteger(0, rowName, OBJPROP_YDISTANCE, y + 6);
   ObjectSetString(0, rowName, OBJPROP_TEXT,
                   MakeListRowText(index, g_trades[index].entry, g_trades[index].sl, g_trades[index].tp));
   ObjectSetString(0, rowName, OBJPROP_FONT, "Tahoma Bold");
   ObjectSetInteger(0, rowName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, rowName, OBJPROP_COLOR, (g_trades[index].isBuy ? C'119,220,171' : C'255,145,145'));
   ObjectSetInteger(0, rowName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, rowName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, rowName, OBJPROP_ZORDER, 110);

   if(ObjectFind(0, alertName) < 0)
      ObjectCreate(0, alertName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, alertName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, alertName, OBJPROP_XDISTANCE, 289);
   ObjectSetInteger(0, alertName, OBJPROP_YDISTANCE, y + 1);
   ObjectSetInteger(0, alertName, OBJPROP_XSIZE, 68);
   ObjectSetInteger(0, alertName, OBJPROP_YSIZE, 20);
   ObjectSetString(0, alertName, OBJPROP_FONT, "Tahoma Bold");
   ObjectSetInteger(0, alertName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, alertName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, alertName, OBJPROP_BORDER_COLOR, C'82,91,104');
   ObjectSetInteger(0, alertName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, alertName, OBJPROP_STATE, false);
   ObjectSetInteger(0, alertName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, alertName, OBJPROP_ZORDER, 120);
   UpdateAlertButton(index);

   if(ObjectFind(0, deleteName) < 0)
      ObjectCreate(0, deleteName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, deleteName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, deleteName, OBJPROP_XDISTANCE, 362);
   ObjectSetInteger(0, deleteName, OBJPROP_YDISTANCE, y + 1);
   ObjectSetInteger(0, deleteName, OBJPROP_XSIZE, 56);
   ObjectSetInteger(0, deleteName, OBJPROP_YSIZE, 20);
   ObjectSetString(0, deleteName, OBJPROP_TEXT, "DELETE");
   ObjectSetString(0, deleteName, OBJPROP_FONT, "Tahoma Bold");
   ObjectSetInteger(0, deleteName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, deleteName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, deleteName, OBJPROP_BGCOLOR, C'156,63,70');
   ObjectSetInteger(0, deleteName, OBJPROP_BORDER_COLOR, C'184,76,84');
   ObjectSetInteger(0, deleteName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, deleteName, OBJPROP_STATE, false);
   ObjectSetInteger(0, deleteName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, deleteName, OBJPROP_ZORDER, 120);
  }

//+------------------------------------------------------------------+
void RefreshTradeList()
  {
   DeleteAllTradeListRows();
   int total = ArraySize(g_trades);
   int pages = (int)MathCeil((double)total / RR_LIST_ROWS);
   if(pages < 1) pages = 1;
   if(g_listPage < 0) g_listPage = 0;
   if(g_listPage >= pages) g_listPage = pages - 1;

   int remaining = total - g_listPage * RR_LIST_ROWS;
   int shown = (int)MathMin(RR_LIST_ROWS, MathMax(0, remaining));
   for(int row = 0; row < shown; row++)
     {
      int index = total - 1 - (g_listPage * RR_LIST_ROWS + row);
      int y = RR_LIST_TOP_Y - row * RR_ROW_HEIGHT;
      CreateTradeListRow(index, y);
     }

   int navY = RR_LIST_TOP_Y - MathMax(0, shown - 1) * RR_ROW_HEIGHT - 31;
   ObjectSetInteger(0, g_previousButton, OBJPROP_YDISTANCE, navY);
   ObjectSetInteger(0, g_nextButton, OBJPROP_YDISTANCE, navY);
   ObjectSetInteger(0, g_pageLabel, OBJPROP_YDISTANCE, navY + 4);
   ObjectSetInteger(0, g_previousButton, OBJPROP_BGCOLOR, (g_listPage > 0 ? C'74,87,103' : C'55,60,68'));
   ObjectSetInteger(0, g_nextButton, OBJPROP_BGCOLOR, (g_listPage + 1 < pages ? C'74,87,103' : C'55,60,68'));
   ObjectSetString(0, g_pageLabel, OBJPROP_TEXT,
                   StringFormat("%d / %d    %d trades", g_listPage + 1, pages, total));
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
void UpdateTradeRowSummary(const int index,
                           const double entry,
                           const double stop,
                           const double target)
  {
   if(index < 0 || index >= ArraySize(g_trades)) return;
   string rowName = UiNameById(g_trades[index].id, "_ROW");
   if(ObjectFind(0, rowName) >= 0)
     {
      ObjectSetString(0, rowName, OBJPROP_TEXT, MakeListRowText(index, entry, stop, target));
      ObjectSetInteger(0, rowName, OBJPROP_COLOR, (g_trades[index].isBuy ? C'119,220,171' : C'255,145,145'));
     }
  }

//+------------------------------------------------------------------+
int FindTradeByUiObject(const string objectName, const string suffix)
  {
   for(int i = 0; i < ArraySize(g_trades); i++)
      if(objectName == UiNameById(g_trades[i].id, suffix)) return(i);
   return(-1);
  }

//+------------------------------------------------------------------+
void DeleteTradeAt(const int index)
  {
   if(index < 0 || index >= ArraySize(g_trades)) return;
   RRTrade trade = g_trades[index];
   ObjectDelete(0, trade.greenName);
   ObjectDelete(0, trade.redName);
   ObjectDelete(0, trade.rrName);
   ObjectDelete(0, trade.alertStateName);
   ObjectDelete(0, UiNameById(trade.id, "_ROW"));
   ObjectDelete(0, UiNameById(trade.id, "_ROW_BG"));
   ObjectDelete(0, UiNameById(trade.id, "_ALERT_BTN"));
   ObjectDelete(0, UiNameById(trade.id, "_DEL"));
   ObjectDelete(0, UiNameById(trade.id, "_STRAT_EDIT"));

   int total = ArraySize(g_trades);
   for(int i = index; i < total - 1; i++)
      g_trades[i] = g_trades[i + 1];
   ArrayResize(g_trades, total - 1);
   RefreshTradeList();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
void CreateAlertStateMarkerForName(const string name, const string value)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   // Keep the state in an off-screen label so it survives indicator reloads without showing in the UI.
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10000);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 10000);
   ObjectSetString(0, name, OBJPROP_TEXT, value);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 1);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
  }

//+------------------------------------------------------------------+
void CreateAlertStateMarker(const int index, const string value)
  {
   if(index < 0 || index >= ArraySize(g_trades)) return;
   CreateAlertStateMarkerForName(g_trades[index].alertStateName, value);
  }

//+------------------------------------------------------------------+
void SaveAlertState(const int index)
  {
   if(index < 0 || index >= ArraySize(g_trades)) return;
   string state = "0";
   if(g_trades[index].alertEnabled)
      state = (g_trades[index].alertTriggered ? "2" : "1");
   CreateAlertStateMarkerForName(g_trades[index].alertStateName, state);
  }

//+------------------------------------------------------------------+
void UpdateAlertButton(const int index)
  {
   if(index < 0 || index >= ArraySize(g_trades)) return;
   string name = g_trades[index].alertButtonName;
   if(ObjectFind(0, name) < 0) return;
   bool enabled = g_trades[index].alertEnabled;
   string caption = "ALERT OFF";
   color buttonColor = C'72,78,88';
   color borderColor = C'91,99,111';
   if(enabled && g_trades[index].alertTriggered)
     {
      caption = "ALERT HIT";
      buttonColor = C'163,103,42';
      borderColor = C'204,139,62';
     }
   else if(enabled)
     {
      caption = "ALERT ON";
      buttonColor = C'31,132,99';
      borderColor = C'55,172,132';
     }
   ObjectSetString(0, name, OBJPROP_TEXT, caption);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, buttonColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderColor);
  }

//+------------------------------------------------------------------+
double GetAlertQuote(const bool isBuy)
  {
   double quote = (isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   return(quote);
  }

//+------------------------------------------------------------------+
void CheckTradeAlert(const int index, const double stop, const double target)
  {
   if(index < 0 || index >= ArraySize(g_trades)) return;
   if(!g_trades[index].alertEnabled || g_trades[index].alertTriggered) return;

   double quote = GetAlertQuote(g_trades[index].isBuy);
   if(quote <= 0.0) return;
   if(!g_trades[index].hasAlertQuote)
     {
      g_trades[index].lastAlertQuote = quote;
      g_trades[index].hasAlertQuote = true;
      return;
     }

   double previous = g_trades[index].lastAlertQuote;
   bool stopHit = false;
   bool targetHit = false;
   if(g_trades[index].isBuy)
     {
      stopHit = (previous > stop && quote <= stop);
      targetHit = (previous < target && quote >= target);
     }
   else
     {
      stopHit = (previous < stop && quote >= stop);
      targetHit = (previous > target && quote <= target);
     }
   g_trades[index].lastAlertQuote = quote;

   if(!stopHit && !targetHit) return;
   g_trades[index].alertTriggered = true;
   SaveAlertState(index);
   string outcome = (stopHit ? "STOP LOSS" : "TAKE PROFIT");
   Alert(StringFormat("RR Backtest | %s #%d | %s reached at %s",
                      (g_trades[index].isBuy ? "BUY" : "SELL"),
                      g_trades[index].id, outcome, DoubleToString(quote, _Digits)));
   PlaySound("alert.wav");
   UpdateAlertButton(index);
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   // Check on price updates as well as the timer so brief level touches are less likely to be missed.
   if(g_ready)
     {
      for(int i = 0; i < ArraySize(g_trades); i++)
        {
         datetime tLeft, tRight;
         double entry, stop, target;
         if(!GetPreviewState(i, tLeft, tRight, entry, stop, target))
           {
            entry = g_trades[i].entry;
            stop = g_trades[i].sl;
            target = g_trades[i].tp;
           }
         CheckTradeAlert(i, stop, target);
        }
     }
   return(rates_total);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   // Keep RR drawings and alert status markers on chart for backtest review.
   ObjectDelete(0, g_buyButton);
   ObjectDelete(0, g_sellButton);
   ObjectDelete(0, g_previousButton);
   ObjectDelete(0, g_nextButton);
   ObjectDelete(0, g_pageLabel);
   ObjectDelete(0, g_panelName);
   ObjectDelete(0, g_panelAccentName);
   ObjectDelete(0, g_panelTitleName);
   ObjectDelete(0, g_panelSubtitleName);
   DeleteAllTradeListRows();
  }
//+------------------------------------------------------------------+
