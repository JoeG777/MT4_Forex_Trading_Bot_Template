//+------------------------------------------------------------------+
//|                                          Falcon EA Template v2.5
//|                                        Copyright 2017,Lucas Liew 
//|                                  lucas@blackalgotechnologies.com 
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, JoeG Traders"
#property link      "jojo.klettergooglemail.com"

/* 

Falcon v2.5: 
- Added function to show Dashboard (using the Comment function).

*/

//+------------------------------------------------------------------+
//| Setup                                               
//+------------------------------------------------------------------+
extern string  Header1 = "----------Trading Rules Variables-----------";
extern int     lookbackPeriodADX = 14;
extern double  ADXThresh = 20;
extern int     trendThresh = 35;
extern int     lookbackPeriodMA = 200;
extern int     validBars = 10;

extern string  Header2 = "----------Position Sizing Settings-----------";
extern string  Lot_explanation = "If IsSizingOn = true, Lots variable will be ignored";
extern double  Lots = 0.01;
extern bool    IsSizingOn = False;
extern double  Risk = 1; // Risk per trade (in percentage)
extern double  MaxLotsAllowed = 20; // Per Order
extern double  MinFreeMarginPerLot = 1500; // Note: 1000USD of margin required to open a 1 lot of EURUSD on a 100:1 leverage. 
extern bool    IsAdaptiveVolSizingOn = False; // Switch for our adaptive volatility function
extern bool    IsAdaptiveHRSizingOn = False; // Switch for our adaptive hit rate function

extern string  Header3="----------TP & SL Settings-----------";

extern bool    UseFixedStopLoss=True; // If this is false and IsSizingOn = True, sizing algo will not be able to calculate correct lot size. 
extern double  FixedStopLoss=0; // Hard Stop in Pips. Will be overridden if vol-based SL is true 
extern bool    IsVolatilityStopOn=True;
extern double  VolBasedSLMultiplier=3.0; // Stop Loss Amount in units of Volatility

extern bool    UseFixedTakeProfit=True;
extern double  FixedTakeProfit=0; // Hard Take Profit in Pips. Will be overridden if vol-based TP is true 
extern bool    IsVolatilityTakeProfitOn=True;
extern double  VolBasedTPMultiplier=3.0; // Take Profit Amount in units of Volatility

extern string  Header4="----------Breakeven Stops Settings-----------";
extern bool    UseBreakevenStops=False;
extern double  BreakevenBuffer=0; // In pips

extern string  Header5="----------Trailing Stops Settings-----------";
extern bool    UseTrailingStops=False;
extern double  TrailingStopDistance=0; // In pips
extern double  TrailingStopBuffer=0; // In pips

extern string  Header6="----------Volatility Trailing Stops Settings-----------";
extern bool    UseVolTrailingStops=False;
extern double  VolTrailingDistMultiplier=0; // In units of ATR
extern double  VolTrailingBuffMultiplier=0; // In units of ATR

extern string  Header7="----------Time Based Stop (Exit)-----------";
extern bool    UseTimeBasedExit = False;
extern int     exitAfterBars = 7;

extern string  Header8="----------Volatility Measurement Settings-----------";
extern int     atr_period=14;

extern string  Header9="----------Max Orders-----------";
extern bool    UseMaxPositions = false;
extern int     MaxPositionsAllowed = 1;

extern string  Header10="----------Set Max Loss Limit-----------";
extern bool    IsLossLimitActivated=False;
extern double  LossLimitPercent=50;

extern string  Header11="----------Set Max Volatility Limit-----------";
extern bool    IsVolLimitActivated=False;
extern double  VolatilityMultiplier=3; // In units of ATR
extern int     ATRTimeframe=60; // In minutes
extern int     ATRPeriod=14;

extern string  Header12="----------EA General Settings-----------";
extern string  EaName="Falcon 2.5"; // Added in Falcon 2.5
extern int     MagicNumber=12345;
extern int     Slippage=3; // In Pips
extern bool    IsECNbroker = false; // Is your broker an ECN
extern bool    OnJournaling = true; // Add EA updates in the Journal Tab
extern bool    IsBacktesting = True; // If you are backtesting (as opposed to live trading), switch to True. This is for our backtest timer.
extern bool    IsDashboardCommentOn = True; // Turn on Dashboard // Added in Falcon 2.5

string  InternalHeader1="----------Errors Handling Settings-----------";
int     RetryInterval=100; // Pause Time before next retry (in milliseconds)
int     MaxRetriesPerTick=10;

string  InternalHeader2="----------Service Variables-----------";

double Stop,Take;
double P,YenPairAdjustFactor;
double myATR;
double LotsToTrade;

bool tradeLock, newBar;
double trendStrength, trendDirection, lastClose, high3, high2, low3, low2;
double startingAccountBalance;
uint startTimeInMilliSeconds, endTimeInMilliSeconds, backtestTimeInMilliSeconds; // uint takes 4 bytes of memory and allows expressing integers from 0 to 4 294 967 295.
double backtestTimeInSeconds; 

int OrderNumber, object_id;
double VolTrailingList[][2]; // First dimension is for position ticket numbers, second is for recording of volatility amount (one unit of ATR) at the time of trade

//+------------------------------------------------------------------+
//| End of Setup                                          
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert Initialization                                    
//+------------------------------------------------------------------+
int init()
  {
   P=GetP(); // To account for 5 digit brokers. Used to convert pips to decimal place
   YenPairAdjustFactor=GetYenAdjustFactor(); // Adjust for YenPair
   startingAccountBalance = AccountBalance();
   
   if(UseVolTrailingStops) ArrayResize(VolTrailingList,MaxPositionsAllowed,0);
   if(IsBacktesting) startTimeInMilliSeconds = GetTickCount();
//----------(Hidden) TP, SL and Breakeven Stops Variables-----------  

   start();
   return(0);
  }
//+------------------------------------------------------------------+
//| End of Expert Initialization                            
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert Deinitialization                                  
//+------------------------------------------------------------------+
int deinit()
  {
//----
   if(IsBacktesting) {
      endTimeInMilliSeconds = GetTickCount();
      backtestTimeInMilliSeconds = endTimeInMilliSeconds - startTimeInMilliSeconds;
      backtestTimeInSeconds = (double) backtestTimeInMilliSeconds/1000;
      Print("Total Time of Backtest = " + backtestTimeInSeconds + " seconds");
      GlobalVariableSet("Duration of last backtest in seconds ", backtestTimeInSeconds);
   }
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| End of Expert Deinitialization                          
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert On Initialization of Tester                                  
//+------------------------------------------------------------------+
double OnTester(){
   return(NormalizeDouble((TesterStatistics(STAT_PROFIT) / startingAccountBalance) * 100, 2)/TesterStatistics(STAT_BALANCE_DDREL_PERCENT) );
}
//+------------------------------------------------------------------+
//|  End Off Initialization of Tester                                   
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert start                                             
//+------------------------------------------------------------------+
int start()
  {

//----------Variables to be Refreshed-----------

   OrderNumber=0; // OrderNumber used in Entry Rules

//----------Entry & Exit Variables-----------
   tradeLock      = false;
   newBar         = NewBar();
   trendDirection = iMA(Symbol(), Period(), lookbackPeriodMA, 0, MODE_SMA, PRICE_CLOSE, 1);
   trendStrength  = iADX(Symbol(), Period(), lookbackPeriodADX, PRICE_CLOSE, MODE_MAIN, 1);
   lastClose      = iClose(Symbol(), Period(), 1);
   
   high3          = iHigh(Symbol(), Period(), 3);
   high2          = iHigh(Symbol(), Period(), 2);
   low3           = iLow(Symbol(), Period(), 3);
   low2           = iLow(Symbol(), Period(), 2);

//----------TP, SL, Breakeven and Trailing Stops Variables-----------

   myATR=iATR(NULL,Period(),atr_period,1);

   if(UseFixedStopLoss==False) 
     {
      Stop=0;
        }  else {
      Stop=VolBasedStopLoss(IsVolatilityStopOn,FixedStopLoss,myATR,VolBasedSLMultiplier,P);
     }

   if(UseFixedTakeProfit==False) 
     {
      Take=0;
        }  else {
      Take=VolBasedTakeProfit(IsVolatilityTakeProfitOn,FixedTakeProfit,myATR,VolBasedTPMultiplier,P);
     }

   if(UseBreakevenStops) BreakevenStopAll(OnJournaling,RetryInterval,BreakevenBuffer,MagicNumber,P);
   if(UseTrailingStops) TrailingStopAll(OnJournaling,TrailingStopDistance,TrailingStopBuffer,RetryInterval,MagicNumber,P);
   if(UseVolTrailingStops) {
      UpdateVolTrailingList(OnJournaling,RetryInterval,MagicNumber);
      ReviewVolTrailingStop(OnJournaling,VolTrailingDistMultiplier,VolTrailingBuffMultiplier,RetryInterval,MagicNumber,P);
   }
//----------(Hidden) TP, SL, Breakeven and Trailing Stops Variables-----------  

   //Excluded in this Template
   
//----------Exit Rules (All Opened Positions)-----------
   if(UseMaxPositions && OrdersTotal() >= MaxPositionsAllowed) tradeLock=true;
   
   if(UseTimeBasedExit){
      for(int i = 0; i<OrdersTotal(); i++){
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
            if(OrderOpenTime() + (PeriodSeconds() * exitAfterBars) <= TimeCurrent()){
               CloseOrderPosition(OrderType(), OnJournaling, MagicNumber, Slippage, P, RetryInterval); 
            }
         }
      }
   }

//----------Entry Rules (Market and Pending) -----------

   if(IsLossLimitBreached(IsLossLimitActivated,LossLimitPercent,OnJournaling,1)==False) 
      if(IsVolLimitBreached(IsVolLimitActivated,VolatilityMultiplier,ATRTimeframe,ATRPeriod)==False)
         if(IsMaxPositionsReached(MaxPositionsAllowed,MagicNumber,OnJournaling)==False)
           {
            if(!tradeLock && newBar)
            {
               // --- Position Sizing Management ---
               LotsToTrade = GetLot(IsSizingOn,Lots,Risk,YenPairAdjustFactor,Stop,P);
               
               //if(IsAdaptiveVolSizingOn==True) LotsToTrade = LotsToTrade * AdaptiveVolSizingMultiplier(OnJournaling); // You can replace this with your own adaptive sizing algorithm               
               if(IsAdaptiveHRSizingOn==True) LotsToTrade = LotsToTrade * AdaptiveHRSizingMultiplier(OnJournaling, MagicNumber); // You can replace this with your own adaptive sizing algorithm               
               // ---
               
               if(high3 > high2 && low3 < low2 && lastClose > high3)
                 { // Open Long Positions
                  OrderNumber = OpenPositionMarket(OP_BUY,LotsToTrade,Stop,Take,MagicNumber,Slippage,OnJournaling,P,IsECNbroker,MaxRetriesPerTick,RetryInterval,MaxLotsAllowed,MinFreeMarginPerLot);
                  //OrderNumber = OpenPositionPending(OP_BUYLIMIT, Ask + myATR, TimeCurrent() + PeriodSeconds()* validBars, GetLot(IsSizingOn, Lots, Risk, YenPairAdjustFactor, Stop, P), Stop, Take, MagicNumber, Slippage, OnJournaling, P, IsECNbroker, MaxRetriesPerTick, RetryInterval, MaxLotsAllowed,MinFreeMarginPerLot);
                  
                  // Set Volatility Trailing Stop Level           
                  if(UseVolTrailingStops) SetVolTrailingStop(OnJournaling,RetryInterval,myATR,VolTrailingDistMultiplier,MagicNumber,P,OrderNumber);
                 }
      
               else if(low3 < low2 && high3 > high2 && lastClose < low3)
                 { // Open Short Positions
                  OrderNumber=OpenPositionMarket(OP_SELL,LotsToTrade,Stop,Take,MagicNumber,Slippage,OnJournaling,P,IsECNbroker,MaxRetriesPerTick,RetryInterval,MaxLotsAllowed,MinFreeMarginPerLot);
                  //OrderNumber = OpenPositionPending(OP_SELLLIMIT, Ask + myATR, TimeCurrent() + PeriodSeconds()* validBars, GetLot(IsSizingOn, Lots, Risk, YenPairAdjustFactor, Stop, P), Stop, Take, MagicNumber, Slippage, OnJournaling, P, IsECNbroker, MaxRetriesPerTick, RetryInterval, MaxLotsAllowed,MinFreeMarginPerLot);
                  
                  // Set Volatility Trailing Stop Level           
                  if(UseVolTrailingStops) SetVolTrailingStop(OnJournaling,RetryInterval,myATR,VolTrailingDistMultiplier,MagicNumber,P,OrderNumber);
                 }
             }
           }

//----------Pending Order Management-----------
/*
        Not Applicable (See Desiree for example of pending order rules).
   */

//----

   if(IsDashboardCommentOn==True) DashboardComment(EaName); // Added in Falcon 2.5
   
   return(0);
  }
//+------------------------------------------------------------------+
//| End of expert start function                                     |
//+------------------------------------------------------------------+
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//|                     FUNCTIONS LIBRARY                                   
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

/*

Content:
1) EntrySignal
2) ExitSignal
3) GetLot
4) CheckLot
5) CountPosOrders
6) CountClosedPosOrders
7) IsMaxPositionsReached
8) OpenPositionMarket
9) OpenPositionPending
10) CloseOrderPosition
11) GetP
12) GetYenAdjustFactor
13) VolBasedStopLoss
14) VolBasedTakeProfit
15) Crossed1 / Crossed2
16) IsLossLimitBreached
17) IsVolLimitBreached
22) BreakevenStopAll
25) TrailingStopAll
28) UpdateVolTrailingList
29) SetVolTrailingStop
30) ReviewVolTrailingStop
34) AdaptiveVolSizingMultiplier
35) AdaptiveHRSizingMultiplier
   NewBar
36) DashboardComment // Added in Falcon 2.5
37) HandleTradingEnvironment
38) GetErrorDescription

*/


//+------------------------------------------------------------------+
//| ENTRY SIGNAL                                                     |
//+------------------------------------------------------------------+
int EntrySignal(int CrossOccurred)
  {
// Type: Customisable 
// Modify this function to suit your trading robot

// This function checks for entry signals

   int   entryOutput=0;

   if(CrossOccurred==1)
     {
      entryOutput=1; 
     }

   if(CrossOccurred==2)
     {
      entryOutput=2;
     }

   return(entryOutput);
  }
//+------------------------------------------------------------------+
//| End of ENTRY SIGNAL                                              |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Exit SIGNAL                                                      |
//+------------------------------------------------------------------+
int ExitSignal(int CrossOccurred)
  {
// Type: Customisable 
// Modify this function to suit your trading robot

// This function checks for exit signals

   int   ExitOutput=0;

   if(CrossOccurred==1)
     {
      ExitOutput=1;
     }

   if(CrossOccurred==2)
     {
      ExitOutput=2;
     }

   return(ExitOutput);
  }
//+------------------------------------------------------------------+
//| End of Exit SIGNAL                                               
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Position Sizing Algo               
//+------------------------------------------------------------------+
// Type: Customisable 
// Modify this function to suit your trading robot

// This is our sizing algorithm

double GetLot(bool IsSizingOnTrigger,double FixedLots,double RiskPerTrade,int YenAdjustment,double STOP,int K) 
  {
   double output;

   if(IsSizingOnTrigger==true) 
     {
      output=RiskPerTrade*0.01*AccountEquity()/(MarketInfo(Symbol(),MODE_LOTSIZE)*MarketInfo(Symbol(),MODE_TICKVALUE)*STOP*K*Point); // Sizing Algo based on account size
      output=output*YenAdjustment; // Adjust for Yen Pairs
        } else {
      output=FixedLots;
     }
   output=NormalizeDouble(output,2); // Round to 2 decimal place
   return(output);
  }
//+------------------------------------------------------------------+
//| End of Position Sizing Algo               
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CHECK LOT
//+------------------------------------------------------------------+
double CheckLot(double Lot,bool Journaling, double MaximumLotsAllowed, double MinimumFreeMarginPerLot)
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function checks if our Lots to be trade satisfies any broker limitations, your lot size and margin limitations.

   double LotToOpen=0;
   LotToOpen=NormalizeDouble(Lot,2);
   LotToOpen=MathFloor(LotToOpen/MarketInfo(Symbol(),MODE_LOTSTEP))*MarketInfo(Symbol(),MODE_LOTSTEP);

   if(LotToOpen<MarketInfo(Symbol(),MODE_MINLOT)){ 
      LotToOpen=MarketInfo(Symbol(),MODE_MINLOT);
      if(Journaling)Print("EA Journaling: Trading Lot < Min Lot allowed by broker.");
   }
   if(LotToOpen>MarketInfo(Symbol(),MODE_MAXLOT)){
      LotToOpen=MarketInfo(Symbol(),MODE_MAXLOT);
      if(Journaling)Print("EA Journaling: Trading Lot > Max Lot allowed by broker.");
   }
   if(LotToOpen>MaximumLotsAllowed){
      LotToOpen=MaximumLotsAllowed;
      if(Journaling)Print("EA Journaling: Trading Lot > Max Lot allowed by trader.");
   }
   if(AccountFreeMargin() < (MinimumFreeMarginPerLot * Lot))Alert("Margin limitations breached. Free Margin = ", AccountFreeMargin()); 
   
   LotToOpen=NormalizeDouble(LotToOpen,2);

   if(Journaling && LotToOpen!=Lot)Print("EA Journaling: Trading Lot has been changed by CheckLot function. Requested lot: "+Lot+". Lot to open: "+LotToOpen);

   return(LotToOpen);
  }
//+------------------------------------------------------------------+
//| End of CHECK LOT
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| COUNT POSITIONS 
//+------------------------------------------------------------------+
int CountPosOrders(int Magic,int TYPE)
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function counts number of positions/orders of OrderType TYPE

   int Orders=0;
   for(int i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==TYPE)
         Orders++;
     }
   return(Orders);

  }
//+------------------------------------------------------------------+
//| End of COUNT POSITIONS
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| COUNT CLOSED POSITIONS 
//+------------------------------------------------------------------+
int CountClosedPosOrders(int Magic,int TYPE)
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function counts number of positions/orders that are closed. If TYPE is a pending order, this functions counts the deleted pending orders.

   int Orders=0;
   for(int i=0; i<OrdersHistoryTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==TYPE)
         Orders++;
     }
   
   return(Orders);

  }
//+------------------------------------------------------------------+
//| End of COUNT POSITIONS
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| MAX ORDERS                                              
//+------------------------------------------------------------------+
bool IsMaxPositionsReached(int MaxPositions,int Magic,bool Journaling)
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function checks the number of positions we are holding against the maximum allowed 

   bool result=False;
   if(CountPosOrders(Magic,OP_BUY)+CountPosOrders(Magic,OP_SELL)>MaxPositions) 
     {
      result=True;
      if(Journaling)Print("Max Orders Exceeded");
        } else if(CountPosOrders(Magic,OP_BUY)+CountPosOrders(Magic,OP_SELL)==MaxPositions) {
      result=True;
     }

   return(result);

/* Definitions: Position vs Orders
   
   Position describes an opened trade
   Order is a pending trade
   
   How to use in a sentence: Jim has 5 buy limit orders pending 10 minutes ago. The market just crashed. The orders were executed and he has 5 losing positions now lol.

*/
  }
//+------------------------------------------------------------------+
//| End of MAX ORDERS                                                
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| OPEN FROM MARKET
//+------------------------------------------------------------------+
int OpenPositionMarket(int TYPE,double LOT,double SL,double TP,int Magic,int Slip,bool Journaling,int K,bool ECN,int Max_Retries_Per_Tick,int Retry_Interval, double MaximumLotsAllowed, double MinimumFreeMarginPerLot)
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function submits new orders

   int tries=0;
   string symbol=Symbol();
   int cmd=TYPE;
   double volume=CheckLot(LOT,Journaling,MaximumLotsAllowed,MinimumFreeMarginPerLot);
   if(MarketInfo(symbol,MODE_MARGINREQUIRED)*volume>AccountFreeMargin())
     {
      Print("Can not open a trade. Not enough free margin to open "+volume+" on "+symbol);
      return(-1);
     }
   int slippage=Slip*K; // Slippage is in points. 1 point = 0.0001 on 4 digit broker and 0.00001 on a 5 digit broker
   string comment=" "+TYPE+"(#"+Magic+")";
   int magic=Magic;
   datetime expiration=0;
   color arrow_color=0;if(TYPE==OP_BUY)arrow_color=Blue;if(TYPE==OP_SELL)arrow_color=Green;
   double stoploss=0;
   double takeprofit=0;
   double initTP = TP;
   double initSL = SL;
   int Ticket=-1;
   double price=0;
   if(!ECN)
     {
      while(tries<Max_Retries_Per_Tick) // Edits stops and take profits before the market order is placed
        {
         RefreshRates();
         if(TYPE==OP_BUY)price=Ask;if(TYPE==OP_SELL)price=Bid;

         // Sets Take Profits and Stop Loss. Check against Stop Level Limitations.
         if(TYPE==OP_BUY && SL!=0)
           {
            stoploss=NormalizeDouble(Ask-SL*K*Point,Digits);
            if(Bid-stoploss<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
              {
               stoploss=NormalizeDouble(Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Stop Loss changed from "+initSL+" to "+MarketInfo(Symbol(),MODE_STOPLEVEL)/K+" pips");
              }
           }
         if(TYPE==OP_SELL && SL!=0)
           {
            stoploss=NormalizeDouble(Bid+SL*K*Point,Digits);
            if(stoploss-Ask<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
              {
               stoploss=NormalizeDouble(Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Stop Loss changed from "+initSL+" to "+MarketInfo(Symbol(),MODE_STOPLEVEL)/K+" pips");
              }
           }
         if(TYPE==OP_BUY && TP!=0)
           {
            takeprofit=NormalizeDouble(Ask+TP*K*Point,Digits);
            if(takeprofit-Bid<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
              {
               takeprofit=NormalizeDouble(Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Take Profit changed from "+initTP+" to "+MarketInfo(Symbol(),MODE_STOPLEVEL)/K+" pips");
              }
           }
         if(TYPE==OP_SELL && TP!=0)
           {
            takeprofit=NormalizeDouble(Bid-TP*K*Point,Digits);
            if(Ask-takeprofit<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
              {
               takeprofit=NormalizeDouble(Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Take Profit changed from "+initTP+" to "+MarketInfo(Symbol(),MODE_STOPLEVEL)/K+" pips");
              }
           }
         if(Journaling)Print("EA Journaling: Trying to place a market order...");
         HandleTradingEnvironment(Journaling,Retry_Interval);
         Ticket=OrderSend(symbol,cmd,volume,price,slippage,stoploss,takeprofit,comment,magic,expiration,arrow_color);
         if(Ticket>0)break;
         tries++;
        }
     }
   if(ECN) // Edits stops and take profits after the market order is placed
     {
      HandleTradingEnvironment(Journaling,Retry_Interval);
      if(TYPE==OP_BUY)price=Ask;if(TYPE==OP_SELL)price=Bid;
      if(Journaling)Print("EA Journaling: Trying to place a market order...");
      Ticket=OrderSend(symbol,cmd,volume,price,slippage,0,0,comment,magic,expiration,arrow_color);
      if(Ticket>0)
         if(Ticket>0 && OrderSelect(Ticket,SELECT_BY_TICKET)==true && (SL!=0 || TP!=0))
           {
            // Sets Take Profits and Stop Loss. Check against Stop Level Limitations.
            if(TYPE==OP_BUY && SL!=0)
              {
               stoploss=NormalizeDouble(OrderOpenPrice()-SL*K*Point,Digits);
               if(Bid-stoploss<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
                 {
                  stoploss=NormalizeDouble(Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
                  if(Journaling)Print("EA Journaling: Stop Loss changed from "+initSL+" to "+(OrderOpenPrice()-stoploss)/(K*Point)+" pips");
                 }
              }
            if(TYPE==OP_SELL && SL!=0)
              {
               stoploss=NormalizeDouble(OrderOpenPrice()+SL*K*Point,Digits);
               if(stoploss-Ask<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
                 {
                  stoploss=NormalizeDouble(Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
                  if(Journaling)Print("EA Journaling: Stop Loss changed from "+initSL+" to "+(stoploss-OrderOpenPrice())/(K*Point)+" pips");
                 }
              }
            if(TYPE==OP_BUY && TP!=0)
              {
               takeprofit=NormalizeDouble(OrderOpenPrice()+TP*K*Point,Digits);
               if(takeprofit-Bid<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
                 {
                  takeprofit=NormalizeDouble(Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
                  if(Journaling)Print("EA Journaling: Take Profit changed from "+initTP+" to "+(takeprofit-OrderOpenPrice())/(K*Point)+" pips");
                 }
              }
            if(TYPE==OP_SELL && TP!=0)
              {
               takeprofit=NormalizeDouble(OrderOpenPrice()-TP*K*Point,Digits);
               if(Ask-takeprofit<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
                 {
                  takeprofit=NormalizeDouble(Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
                  if(Journaling)Print("EA Journaling: Take Profit changed from "+initTP+" to "+(OrderOpenPrice()-takeprofit)/(K*Point)+" pips");
                 }
              }
            bool ModifyOpen=false;
            while(!ModifyOpen)
              {
               HandleTradingEnvironment(Journaling,Retry_Interval);
               ModifyOpen=OrderModify(Ticket,OrderOpenPrice(),stoploss,takeprofit,expiration,arrow_color);
               if(Journaling && !ModifyOpen)Print("EA Journaling: Take Profit and Stop Loss not set. Error Description: "+GetErrorDescription(GetLastError()));
              }
           }
     }
   if(Journaling && Ticket<0)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
   if(Journaling && Ticket>0)
     {
      Print("EA Journaling: Order successfully placed. Ticket: "+Ticket);
     }
   return(Ticket);
  }
//+------------------------------------------------------------------+
//| End of OPEN FROM MARKET   
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| OPEN PENDING ORDERS
//+------------------------------------------------------------------+
int OpenPositionPending(int TYPE,double OpenPrice,datetime expiration,double LOT,double SL,double TP,int Magic,int Slip,bool Journaling,int K,bool ECN,int Max_Retries_Per_Tick,int Retry_Interval, double MaximumLotsAllowed, double MinimumFreeMarginPerLot)
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function submits new pending orders
   OpenPrice= NormalizeDouble(OpenPrice,Digits);
   int tries=0;
   string symbol=Symbol();
   int cmd=TYPE;
   double volume=CheckLot(LOT,Journaling,MaximumLotsAllowed,MinimumFreeMarginPerLot);
   if(MarketInfo(symbol,MODE_MARGINREQUIRED)*volume>AccountFreeMargin())
     {
      Print("Can not open a trade. Not enough free margin to open "+volume+" on "+symbol);
      return(-1);
     }
   int slippage=Slip*K; // Slippage is in points. 1 point = 0.0001 on 4 digit broker and 0.00001 on a 5 digit broker
   string comment=" "+TYPE+"(#"+Magic+")";
   int magic=Magic;
   color arrow_color=0;if(TYPE==OP_BUYLIMIT || TYPE==OP_BUYSTOP)arrow_color=Blue;if(TYPE==OP_SELLLIMIT || TYPE==OP_SELLSTOP)arrow_color=Green;
   double stoploss=0;
   double takeprofit=0;
   double initTP = TP;
   double initSL = SL;
   int Ticket=-1;
   double price=0;

   while(tries<Max_Retries_Per_Tick) // Edits stops and take profits before the market order is placed
     {
      RefreshRates();

      // We are able to send in TP and SL when we open our orders even if we are using ECN brokers

      // Sets Take Profits and Stop Loss. Check against Stop Level Limitations.
      if((TYPE==OP_BUYLIMIT || TYPE==OP_BUYSTOP) && SL!=0)
        {
         stoploss=NormalizeDouble(OpenPrice-SL*K*Point,Digits);
         if(OpenPrice-stoploss<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
           {
            stoploss=NormalizeDouble(OpenPrice-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
            if(Journaling)Print("EA Journaling: Stop Loss changed from "+initSL+" to "+(OpenPrice-stoploss)/(K*Point)+" pips");
           }
        }
      if((TYPE==OP_BUYLIMIT || TYPE==OP_BUYSTOP) && TP!=0)
        {
         takeprofit=NormalizeDouble(OpenPrice+TP*K*Point,Digits);
         if(takeprofit-OpenPrice<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
           {
            takeprofit=NormalizeDouble(OpenPrice+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
            if(Journaling)Print("EA Journaling: Take Profit changed from "+initTP+" to "+(takeprofit-OpenPrice)/(K*Point)+" pips");
           }
        }
      if((TYPE==OP_SELLLIMIT || TYPE==OP_SELLSTOP) && SL!=0)
        {
         stoploss=NormalizeDouble(OpenPrice+SL*K*Point,Digits);
         if(stoploss-OpenPrice<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
           {
            stoploss=NormalizeDouble(OpenPrice+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
            if(Journaling)Print("EA Journaling: Stop Loss changed from " + initSL + " to " + (stoploss-OpenPrice)/(K*Point) + " pips");
           }
        }
      if((TYPE==OP_SELLLIMIT || TYPE==OP_SELLSTOP) && TP!=0)
        {
         takeprofit=NormalizeDouble(OpenPrice-TP*K*Point,Digits);
         if(OpenPrice-takeprofit<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
           {
            takeprofit=NormalizeDouble(OpenPrice-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
            if(Journaling)Print("EA Journaling: Take Profit changed from " + initTP + " to " + (OpenPrice-takeprofit)/(K*Point) + " pips");
           }
        }
      if(Journaling)Print("EA Journaling: Trying to place a pending order...");
      HandleTradingEnvironment(Journaling,Retry_Interval);

      //Note: We did not modify Open Price if it breaches the Stop Level Limitations as Open Prices are sensitive and important. It is unsafe to change it automatically.
      Ticket=OrderSend(symbol,cmd,volume,OpenPrice,slippage,stoploss,takeprofit,comment,magic,expiration,arrow_color);
      if(Ticket>0)break;
      tries++;
     }

   if(Journaling && Ticket<0)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
   if(Journaling && Ticket>0)
     {
      Print("EA Journaling: Order successfully placed. Ticket: "+Ticket);
     }
   return(Ticket);
  }
//+------------------------------------------------------------------+
//| End of OPEN PENDING ORDERS 
//+------------------------------------------------------------------+ 
//+------------------------------------------------------------------+
//| CLOSE/DELETE ORDERS AND POSITIONS
//+------------------------------------------------------------------+
bool CloseOrderPosition(int TYPE,bool Journaling,int Magic,int Slip,int K,int Retry_Interval)
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function closes all positions of type TYPE or Deletes pending orders of type TYPE
   int ordersPos=OrdersTotal();

   for(int i=ordersPos-1; i>=0; i--)
     {
      // Note: Once pending orders become positions, OP_BUYLIMIT AND OP_BUYSTOP becomes OP_BUY, OP_SELLLIMIT and OP_SELLSTOP becomes OP_SELL
      if(TYPE==OP_BUY || TYPE==OP_SELL)
        {
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==TYPE)
           {
            bool Closing=false;
            double Price=0;
            color arrow_color=0;if(TYPE==OP_BUY)arrow_color=Blue;if(TYPE==OP_SELL)arrow_color=Green;
            if(Journaling)Print("EA Journaling: Trying to close position "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling,Retry_Interval);
            if(TYPE==OP_BUY)Price=Bid; if(TYPE==OP_SELL)Price=Ask;
            Closing=OrderClose(OrderTicket(),OrderLots(),Price,Slip*K,arrow_color);
            if(Journaling && !Closing)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Closing)Print("EA Journaling: Position successfully closed.");
           }
        }
      else
        {
         bool Delete=false;
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==TYPE)
           {
            if(Journaling)Print("EA Journaling: Trying to delete order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling,Retry_Interval);
            Delete=OrderDelete(OrderTicket(),CLR_NONE);
            if(Journaling && !Delete)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Delete)Print("EA Journaling: Order successfully deleted.");
           }
        }
     }
   if(CountPosOrders(Magic, TYPE)==0)return(true); else return(false);
  }
//+------------------------------------------------------------------+
//| End of CLOSE/DELETE ORDERS AND POSITIONS 
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Check for 4/5 Digits Broker              
//+------------------------------------------------------------------+ 
int GetP() 
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function returns P, which is used for converting pips to decimals/points

   int output;
   if(Digits==5 || Digits==3) output=10;else output=1;
   return(output);

/* Some definitions: Pips vs Point

1 pip = 0.0001 on a 4 digit broker and 0.00010 on a 5 digit broker
1 point = 0.0001 on 4 digit broker and 0.00001 on a 5 digit broker
  
*/

  }
//+------------------------------------------------------------------+
//| End of Check for 4/5 Digits Broker               
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Yen Adjustment Factor             
//+------------------------------------------------------------------+ 
int GetYenAdjustFactor() 
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function returns a constant factor, which is used for position sizing for Yen pairs

   int output= 1;
   if(Digits == 3|| Digits == 2) output = 100;
   return(output);
  }
//+------------------------------------------------------------------+
//| End of Yen Adjustment Factor             
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Volatility-Based Stop Loss                                             
//+------------------------------------------------------------------+
double VolBasedStopLoss(bool isVolatilitySwitchOn,double fixedStop,double VolATR,double volMultiplier,int K)
  { // K represents our P multiplier to adjust for broker digits
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function calculates stop loss amount based on volatility

   double StopL;
   if(!isVolatilitySwitchOn)
     {
      StopL=fixedStop; // If Volatility Stop Loss not activated. Stop Loss = Fixed Pips Stop Loss
        } else {
      StopL=volMultiplier*VolATR/(K*Point); // Stop Loss in Pips
     }
   return(StopL);
  }
//+------------------------------------------------------------------+
//| End of Volatility-Based Stop Loss                  
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Volatility-Based Take Profit                                     
//+------------------------------------------------------------------+

double VolBasedTakeProfit(bool isVolatilitySwitchOn,double fixedTP,double VolATR,double volMultiplier,int K)
  { // K represents our P multiplier to adjust for broker digits
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function calculates take profit amount based on volatility

   double TakeP;
   if(!isVolatilitySwitchOn)
     {
      TakeP=fixedTP; // If Volatility Take Profit not activated. Take Profit = Fixed Pips Take Profit
        } else {
      TakeP=volMultiplier*VolATR/(K*Point); // Take Profit in Pips
     }
   return(TakeP);
  }
//+------------------------------------------------------------------+
//| End of Volatility-Based Take Profit                 
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Cross1                                                             
//+------------------------------------------------------------------+

// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function determines if a cross happened between 2 lines/data set

/* 

If Output is 0: No cross happened
If Output is 1: Line 1 crossed Line 2 from Bottom
If Output is 2: Line 1 crossed Line 2 from top 

*/

int Crossed1(double line1,double line2)
  {

   static int CurrentDirection1=0;
   static int LastDirection1=0;
   static bool FirstTime1=true;

//----
   if(line1>line2)
      CurrentDirection1=1;  // line1 above line2
   if(line1<line2)
      CurrentDirection1=2;  // line1 below line2
//----
   if(FirstTime1==true) // Need to check if this is the first time the function is run
     {
      FirstTime1=false; // Change variable to false
      LastDirection1=CurrentDirection1; // Set new direction
      return (0);
     }

   if(CurrentDirection1!=LastDirection1 && FirstTime1==false) // If not the first time and there is a direction change
     {
      LastDirection1=CurrentDirection1; // Set new direction
      return(CurrentDirection1); // 1 for up, 2 for down
     }
   else
     {
      return(0);  // No direction change
     }
  }
//+------------------------------------------------------------------+
// End of Cross                                                      
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Cross2                                                             
//+------------------------------------------------------------------+

// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function determines if a cross happened between 2 lines/data set

/* 

If Output is 0: No cross happened
If Output is 1: Line 1 crossed Line 2 from Bottom
If Output is 2: Line 1 crossed Line 2 from top 

*/

int Crossed2(double line1,double line2)
  {

   static int CurrentDirection2=0;
   static int LastDirection2=0;
   static bool FirstTime2=true;

//----
   if(line1>line2)
      CurrentDirection2=1;  // line1 above line2
   if(line1<line2)
      CurrentDirection2=2;  // line1 below line2
//----
   if(FirstTime2==true) // Need to check if this is the first time the function is run
     {
      FirstTime2=false; // Change variable to false
      LastDirection2=CurrentDirection2; // Set new direction
      return (0);
     }

   if(CurrentDirection2!=LastDirection2 && FirstTime2==false) // If not the first time and there is a direction change
     {
      LastDirection2=CurrentDirection2; // Set new direction
      return(CurrentDirection2); // 1 for up, 2 for down
     }
   else
     {
      return(0);  // No direction change
     }
  }
//+------------------------------------------------------------------+
// End of Cross                                                      
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Cross3                                                          
//+------------------------------------------------------------------+

// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function determines if a cross happened between 2 lines/data set

/* 

If Output is 0: No cross happened
If Output is 1: Line 1 crossed Line 2 from Bottom
If Output is 2: Line 1 crossed Line 2 from top 

*/

int Crossed3(double line1,double line2)
  {

   static int CurrentDirection1=0;
   static int LastDirection1=0;
   static bool FirstTime1=true;

//----
   if(line1>line2)
      CurrentDirection1=1;  // line1 above line2
   if(line1<line2)
      CurrentDirection1=2;  // line1 below line2
//----
   if(FirstTime1==true) // Need to check if this is the first time the function is run
     {
      FirstTime1=false; // Change variable to false
      LastDirection1=CurrentDirection1; // Set new direction
      return (0);
     }

   if(CurrentDirection1!=LastDirection1 && FirstTime1==false) // If not the first time and there is a direction change
     {
      LastDirection1=CurrentDirection1; // Set new direction
      return(CurrentDirection1); // 1 for up, 2 for down
     }
   else
     {
      return(0);  // No direction change
     }
  }
//+------------------------------------------------------------------+
// End of Cross                                                      
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Is Loss Limit Breached                                       
//+------------------------------------------------------------------+
bool IsLossLimitBreached(bool LossLimitActivated,double LossLimitPercentage,bool Journaling,int EntrySignalTrigger)
  {

// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function determines if our maximum loss threshold is breached

   static bool firstTick=False;
   static double initialCapital=0;
   double profitAndLoss=0;
   double profitAndLossPrint=0;
   bool output=False;

   if(LossLimitActivated==False) return(output);

   if(firstTick==False)
     {
      initialCapital=AccountEquity();
      firstTick=True;
     }

   profitAndLoss=(AccountEquity()/initialCapital)-1;

   if(profitAndLoss<-LossLimitPercentage/100)
     {
      output=True;
      profitAndLossPrint=NormalizeDouble(profitAndLoss,4)*100;
      if(Journaling)if(EntrySignalTrigger!=0) Print("Entry trade triggered but not executed. Loss threshold breached. Current Loss: "+profitAndLossPrint+"%");
     }

   return(output);
  }
//+------------------------------------------------------------------+
//| End of Is Loss Limit Breached                                     
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Is Volatility Limit Breached                                       
//+------------------------------------------------------------------+
bool IsVolLimitBreached(bool VolLimitActivated,double VolMulti,int ATR_Timeframe, int ATR_per)
  {

// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function determines if our maximum volatility threshold is breached

// 2 steps to this function: 
// 1) It checks the price movement between current time and the closing price of the last completed 1min bar (shift 1 of 1min timeframe).
// 2) Return True if this price movement > VolLimitMulti * VolATR

   bool output = False;
   if(VolLimitActivated==False) return(output);
   
   double priceMovement = MathAbs(Bid-iClose(NULL,PERIOD_M1,1)); // Not much difference if we use bid or ask prices here. We can also use iOpen at shift 0 here, it will be similar to using iClose at shift 1.
   double VolATR = iATR(NULL, ATR_Timeframe, ATR_per, 1);
   
   if(priceMovement > VolMulti*VolATR) output = True;

   return(output);
  }
//+------------------------------------------------------------------+
//| End of Is Volatility Limit Breached                                         
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Breakeven Stop
//+------------------------------------------------------------------+
void BreakevenStopAll(bool Journaling,int Retry_Interval,double Breakeven_Buffer,int Magic,int K)
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function sets breakeven stops for all positions

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      bool Modify=false;
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic)
        {
         RefreshRates();
         if(OrderType()==OP_BUY && (Bid-OrderOpenPrice())>(Breakeven_Buffer*K*Point))
           {
            if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling,Retry_Interval);
            Modify=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),0,CLR_NONE);
            if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Modify)Print("EA Journaling: Order successfully modified, breakeven stop updated.");
           }
         if(OrderType()==OP_SELL && (OrderOpenPrice()-Ask)>(Breakeven_Buffer*K*Point))
           {
            if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling,Retry_Interval);
            Modify=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),0,CLR_NONE);
            if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Modify)Print("EA Journaling: Order successfully modified, breakeven stop updated.");
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| End of Breakeven Stop
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Trailing Stop
//+------------------------------------------------------------------+

void TrailingStopAll(bool Journaling,double TrailingStopDist,double TrailingStopBuff,int Retry_Interval,int Magic,int K)
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function sets trailing stops for all positions

   for(int i=OrdersTotal()-1; i>=0; i--) // Looping through all orders
     {
      bool Modify=false;
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic)
        {
         RefreshRates();
         if(OrderType()==OP_BUY && (Bid-OrderStopLoss()>(TrailingStopDist+TrailingStopBuff)*K*Point))
           {
            if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling,Retry_Interval);
            Modify=OrderModify(OrderTicket(),OrderOpenPrice(),Bid-TrailingStopDist*K*Point,OrderTakeProfit(),0,CLR_NONE);
            if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Modify)Print("EA Journaling: Order successfully modified, trailing stop changed.");
           }
         if(OrderType()==OP_SELL && ((OrderStopLoss()-Ask>((TrailingStopDist+TrailingStopBuff)*K*Point)) || (OrderStopLoss()==0)))
           {
            if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling,Retry_Interval);
            Modify=OrderModify(OrderTicket(),OrderOpenPrice(),Ask+TrailingStopDist*K*Point,OrderTakeProfit(),0,CLR_NONE);
            if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Modify)Print("EA Journaling: Order successfully modified, trailing stop changed.");
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| End Trailing Stop
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Volatility Trailing Stops List                                     
//+------------------------------------------------------------------+
void UpdateVolTrailingList(bool Journaling,int Retry_Interval,int Magic) 
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function clears the elements of your VolTrailingList if the corresponding positions has been closed

   int ordersPos=OrdersTotal();
   int orderTicketNumber;
   bool doesPosExist;

// Check the VolTrailingList, match with current list of positions. Make sure the all the positions exists. 
// If it doesn't, it means there are positions that have been closed

   for(int x=0; x<ArrayRange(VolTrailingList,0); x++)
     { // Looping through all order number in list

      doesPosExist=False;
      orderTicketNumber=VolTrailingList[x,0];

      if(orderTicketNumber!=0)
        { // Order exists
         for(int y=ordersPos-1; y>=0; y--)
           { // Looping through all current open positions
            if(OrderSelect(y,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic)
              {
               if(orderTicketNumber==OrderTicket())
                 { // Checks order number in list against order number of current positions
                  doesPosExist=True;
                  break;
                 }
              }
           }

         if(doesPosExist==False)
           { // Deletes elements if the order number does not match any current positions
            VolTrailingList[x,0] = 0;
            VolTrailingList[x,1] = 0;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| End of Update Volatility Trailing Stops List                                          
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Set Volatility Trailing Stop
//+------------------------------------------------------------------+

void SetVolTrailingStop(bool Journaling,int Retry_Interval,double VolATR,double VolTrailingDistMulti,int Magic,int K,int OrderNum)
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function adds new volatility trailing stop level using OrderModify()

   double VolTrailingStopDist;
   bool Modify=False;
   bool IsVolTrailingStopAdded=False;
   
   VolTrailingStopDist=VolTrailingDistMulti*VolATR/(K*Point); // Volatility trailing stop amount in Pips

   if(OrderSelect(OrderNum,SELECT_BY_TICKET)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic) 
     {
      RefreshRates();
      if(OrderType()==OP_BUY)
        {
         if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
         HandleTradingEnvironment(Journaling,Retry_Interval);
         Modify=OrderModify(OrderTicket(),OrderOpenPrice(),Bid-VolTrailingStopDist*K*Point,OrderTakeProfit(),0,CLR_NONE);
         IsVolTrailingStopAdded=True;   
         if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
         if(Journaling && Modify)Print("EA Journaling: Order successfully modified, volatility trailing stop changed.");
        }
      if(OrderType()==OP_SELL)
        {
         if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
         HandleTradingEnvironment(Journaling,Retry_Interval);
         Modify=OrderModify(OrderTicket(),OrderOpenPrice(),Ask+VolTrailingStopDist*K*Point,OrderTakeProfit(),0,CLR_NONE);
         IsVolTrailingStopAdded=True;
         if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
         if(Journaling && Modify)Print("EA Journaling: Order successfully modified, volatility trailing stop changed.");
        } 
     
      // Records volatility measure (ATR value) for future use
      if(IsVolTrailingStopAdded==True) 
         {
         for(int x=0; x<ArrayRange(VolTrailingList,0); x++) // Loop through elements in VolTrailingList
           { 
            if(VolTrailingList[x,0]==0)  // Checks if the element is empty
              { 
               VolTrailingList[x,0]=OrderNum; // Add order number
               VolTrailingList[x,1]=VolATR/(K*Point); // Add volatility measure aka 1 unit of ATR
               break;
              }
           }
         }
     }     
  }
//+------------------------------------------------------------------+
//| End of Set Volatility Trailing Stop
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Review Volatility Trailing Stop
//+------------------------------------------------------------------+

void ReviewVolTrailingStop(bool Journaling, double VolTrailingDistMulti, double VolTrailingBuffMulti, int Retry_Interval, int Magic, int K)
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function updates volatility trailing stops levels for all positions (using OrderModify) if appropriate conditions are met

   bool doesVolTrailingRecordExist;
   int posTicketNumber;

   for(int i=OrdersTotal()-1; i>=0; i--) 
     { // Looping through all orders

      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic) 
        {
         doesVolTrailingRecordExist = False;
         posTicketNumber=OrderTicket();

         for(int x=0; x<ArrayRange(VolTrailingList,0); x++) 
           { // Looping through all order number in list 

            if(posTicketNumber==VolTrailingList[x,0]) 
              { // If condition holds, it means the position have a volatility trailing stop level attached to it

               doesVolTrailingRecordExist = True; 
               bool Modify=false;
               RefreshRates();

               // We update the volatility trailing stop record using OrderModify.
               if(OrderType()==OP_BUY && (Bid-OrderStopLoss()>(VolTrailingDistMulti*VolTrailingList[x,1]+VolTrailingBuffMulti*VolTrailingList[x,1])*K*Point))
                 {
                  if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
                  HandleTradingEnvironment(Journaling,Retry_Interval);
                  Modify=OrderModify(OrderTicket(),OrderOpenPrice(),Bid-VolTrailingDistMulti*VolTrailingList[x,1]*K*Point,OrderTakeProfit(),0,CLR_NONE);
                  if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
                  if(Journaling && Modify)Print("EA Journaling: Order successfully modified, volatility trailing stop changed.");
                 }
               if(OrderType()==OP_SELL && ((OrderStopLoss()-Ask>((VolTrailingDistMulti*VolTrailingList[x,1]+VolTrailingBuffMulti*VolTrailingList[x,1])*K*Point)) || (OrderStopLoss()==0)))
                 {
                  if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
                  HandleTradingEnvironment(Journaling,Retry_Interval);
                  Modify=OrderModify(OrderTicket(),OrderOpenPrice(),Ask+VolTrailingDistMulti*VolTrailingList[x,1]*K*Point,OrderTakeProfit(),0,CLR_NONE);
                  if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
                  if(Journaling && Modify)Print("EA Journaling: Order successfully modified, volatility trailing stop changed.");
                 }
               break;
              }
           }
        // If order does not have a record attached to it. Alert the trader.
        if(!doesVolTrailingRecordExist && Journaling) Print("EA Journaling: Error. Order "+posTicketNumber+" has no volatility trailing stop attached to it.");
        }
     }
  }
//+------------------------------------------------------------------+
//| End of Review Volatility Trailing Stop
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Adaptive Volatility Sizing
//+------------------------------------------------------------------+
double AdaptiveVolSizingMultiplier(bool Journaling)
  {
// Type: Customisable 
// Modify this function to suit your trading robot

// This function returns a multiplier to modify the lots to be traded using a volatility algorithm.


/* 
   Important Note: 
      This function serves just as a demonstration of how to implement an adaptive volatility function. There are many other ways to design an adaptive volatility algo.
      All parameter values used are arbitrary.
*/ 

   double volSizingMultiplier = 0;
   double curVol = 0;
   double pastVol = 0;
   
   curVol = iATR(NULL, 0, 14, 1); // Volatility measured using ATR shift 1
   pastVol = MathMax(0.0005, iATR(NULL, 0, 14, 11)); // Volatility measured using ATR shift 11. Minimum value of 5 pips to prevent zero divide error
   
   volSizingMultiplier = curVol/pastVol; 

   return volSizingMultiplier;
  }
//+------------------------------------------------------------------+
//| End of Adaptive Volatility Sizing
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Adaptive Volatility Sizing
//+------------------------------------------------------------------+
double AdaptiveHRSizingMultiplier(bool Journaling, int Magic)
  {
// Type: Customisable 
// Modify this function to suit your trading robot

// This function returns a multiplier to modify the lots to be traded using a hit rate algorithm.
// Returns 2 if last closed trade was profitable, 0.5 if otherwise. 
// Ie. We double the sizing if the last closed trade was profitable and half the sizing if profits <= 0.

/* 
   Important Note: 
      This function serves just as a demonstration of how to implement an adaptive hit rate function. There are many other ways to design an adaptive hit rate algo.
      All parameter values used are arbitrary.
*/ 
   static bool firstTrade = True;
   double HRSizingMultiplier = 0.5;
  
   if(firstTrade == True) {
      firstTrade = False;
      return HRSizingMultiplier = 1;    
   }
   
   if(OrderSelect(OrdersHistoryTotal()-1,SELECT_BY_POS,MODE_HISTORY)==true && 
   OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()<=1 && OrderProfit() > 0) HRSizingMultiplier = 2; // Returns 2 if last closed trade is profitable

   return HRSizingMultiplier;
  }
//+------------------------------------------------------------------+
//| End of Adaptive Volatility Sizing
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Start of New Bar (Checking)
//+------------------------------------------------------------------+
bool NewBar(){
   static datetime NewTime = 0;
   if(NewTime != Time[0]){
      NewTime = Time[0];
      return(true);
      }
      return(false);
}
//+------------------------------------------------------------------+
//| End of New Bar (Checking)
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Dashboard - Comment Version                                    
//+------------------------------------------------------------------+
void DashboardComment(string ea_Name) // Added in Falcon 2.5
  {
// Type: Customisable 
// Modify this function to suit your trading robot

// This function creates a dashboard showing information on your EA. It is done the Comment function.

string spacing = "\n"; // Change this to "\n\n" for double spacing

Comment(
        spacing 
      + "EA Name: " + ea_Name
      + spacing
      + "________________________________"  
      + spacing 
      + spacing
      + "Broker: " + AccountCompany()
      + spacing
      + "Brokers Time: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) // Convert from time to string
      + spacing        
      + "________________________________"  
      + spacing 
      + spacing
      + "Account Number " + (string) AccountNumber()
      + spacing 
      + "Account Currency: " + (string) AccountCurrency()   
      + spacing
      + "Decimal Quotes: " + (string) Digits
      + spacing   
      + "_______________________________"
      + spacing  
      + spacing         
      + "Account Balance: " + DoubleToString(AccountBalance(), 2) // Convert from double to string (2 decimal places).            
      + spacing 
      + "Account Equity: " + DoubleToString(AccountEquity(), 2) // Convert from double to string (2 decimal places).    
      + "");
      
      // Bonus exercise: Trying adding fields such as "Number of opening positions" and "Total current P&L from open positions" etc.   
  }

//+------------------------------------------------------------------+
//| End of Dashboard - Comment Version                                     
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| HANDLE TRADING ENVIRONMENT                                       
//+------------------------------------------------------------------+
void HandleTradingEnvironment(bool Journaling,int Retry_Interval)
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function checks for errors

   if(IsTradeAllowed()==true)return;
   if(!IsConnected())
     {
      if(Journaling)Print("EA Journaling: Terminal is not connected to server...");
      return;
     }
   if(!IsTradeAllowed() && Journaling)Print("EA Journaling: Trade is not alowed for some reason...");
   if(IsConnected() && !IsTradeAllowed())
     {
      while(IsTradeContextBusy()==true)
        {
         if(Journaling)Print("EA Journaling: Trading context is busy... Will wait a bit...");
         Sleep(Retry_Interval);
        }
     }
   RefreshRates();
  }
//+------------------------------------------------------------------+
//| End of HANDLE TRADING ENVIRONMENT                                
//+------------------------------------------------------------------+ 
//+------------------------------------------------------------------+
//| Start of marker                                                  |                           
//+------------------------------------------------------------------+ 
 void marker(int shift, double price, int direction)
  {   
   string clr = Blue;
      string object_id_string = string(object_id);
      if(direction < 0){
         clr = Red;
      }
      
      ObjectCreate(object_id_string, OBJ_ARROW, 0, Time[shift], price); //draw an up arrow
      ObjectSet(object_id_string, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet(object_id_string, OBJPROP_ARROWCODE, SYMBOL_ARROWUP);
      ObjectSet(object_id_string, OBJPROP_COLOR,clr); 
      object_id++;
   ChartRedraw(0);
   
   return;

  }
//+------------------------------------------------------------------+
//| End of marker                                                    |                                
//+------------------------------------------------------------------+ 
//+------------------------------------------------------------------+
//| ERROR DESCRIPTION                                                
//+------------------------------------------------------------------+
string GetErrorDescription(int error)
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function returns the exact error

   string ErrorDescription="";
//---
   switch(error)
     {
      case 0:     ErrorDescription = "NO Error. Everything should be good.";                                    break;
      case 1:     ErrorDescription = "No error returned, but the result is unknown";                            break;
      case 2:     ErrorDescription = "Common error";                                                            break;
      case 3:     ErrorDescription = "Invalid trade parameters";                                                break;
      case 4:     ErrorDescription = "Trade server is busy";                                                    break;
      case 5:     ErrorDescription = "Old version of the client terminal";                                      break;
      case 6:     ErrorDescription = "No connection with trade server";                                         break;
      case 7:     ErrorDescription = "Not enough rights";                                                       break;
      case 8:     ErrorDescription = "Too frequent requests";                                                   break;
      case 9:     ErrorDescription = "Malfunctional trade operation";                                           break;
      case 64:    ErrorDescription = "Account disabled";                                                        break;
      case 65:    ErrorDescription = "Invalid account";                                                         break;
      case 128:   ErrorDescription = "Trade timeout";                                                           break;
      case 129:   ErrorDescription = "Invalid price";                                                           break;
      case 130:   ErrorDescription = "Invalid stops";                                                           break;
      case 131:   ErrorDescription = "Invalid trade volume";                                                    break;
      case 132:   ErrorDescription = "Market is closed";                                                        break;
      case 133:   ErrorDescription = "Trade is disabled";                                                       break;
      case 134:   ErrorDescription = "Not enough money";                                                        break;
      case 135:   ErrorDescription = "Price changed";                                                           break;
      case 136:   ErrorDescription = "Off quotes";                                                              break;
      case 137:   ErrorDescription = "Broker is busy";                                                          break;
      case 138:   ErrorDescription = "Requote";                                                                 break;
      case 139:   ErrorDescription = "Order is locked";                                                         break;
      case 140:   ErrorDescription = "Long positions only allowed";                                             break;
      case 141:   ErrorDescription = "Too many requests";                                                       break;
      case 145:   ErrorDescription = "Modification denied because order too close to market";                   break;
      case 146:   ErrorDescription = "Trade context is busy";                                                   break;
      case 147:   ErrorDescription = "Expirations are denied by broker";                                        break;
      case 148:   ErrorDescription = "Too many open and pending orders (more than allowed)";                    break;
      case 4000:  ErrorDescription = "No error";                                                                break;
      case 4001:  ErrorDescription = "Wrong function pointer";                                                  break;
      case 4002:  ErrorDescription = "Array index is out of range";                                             break;
      case 4003:  ErrorDescription = "No memory for function call stack";                                       break;
      case 4004:  ErrorDescription = "Recursive stack overflow";                                                break;
      case 4005:  ErrorDescription = "Not enough stack for parameter";                                          break;
      case 4006:  ErrorDescription = "No memory for parameter string";                                          break;
      case 4007:  ErrorDescription = "No memory for temp string";                                               break;
      case 4008:  ErrorDescription = "Not initialized string";                                                  break;
      case 4009:  ErrorDescription = "Not initialized string in array";                                         break;
      case 4010:  ErrorDescription = "No memory for array string";                                              break;
      case 4011:  ErrorDescription = "Too long string";                                                         break;
      case 4012:  ErrorDescription = "Remainder from zero divide";                                              break;
      case 4013:  ErrorDescription = "Zero divide";                                                             break;
      case 4014:  ErrorDescription = "Unknown command";                                                         break;
      case 4015:  ErrorDescription = "Wrong jump (never generated error)";                                      break;
      case 4016:  ErrorDescription = "Not initialized array";                                                   break;
      case 4017:  ErrorDescription = "DLL calls are not allowed";                                               break;
      case 4018:  ErrorDescription = "Cannot load library";                                                     break;
      case 4019:  ErrorDescription = "Cannot call function";                                                    break;
      case 4020:  ErrorDescription = "Expert function calls are not allowed";                                   break;
      case 4021:  ErrorDescription = "Not enough memory for temp string returned from function";                break;
      case 4022:  ErrorDescription = "System is busy (never generated error)";                                  break;
      case 4050:  ErrorDescription = "Invalid function parameters count";                                       break;
      case 4051:  ErrorDescription = "Invalid function parameter value";                                        break;
      case 4052:  ErrorDescription = "String function internal error";                                          break;
      case 4053:  ErrorDescription = "Some array error";                                                        break;
      case 4054:  ErrorDescription = "Incorrect series array using";                                            break;
      case 4055:  ErrorDescription = "Custom indicator error";                                                  break;
      case 4056:  ErrorDescription = "Arrays are incompatible";                                                 break;
      case 4057:  ErrorDescription = "Global variables processing error";                                       break;
      case 4058:  ErrorDescription = "Global variable not found";                                               break;
      case 4059:  ErrorDescription = "Function is not allowed in testing mode";                                 break;
      case 4060:  ErrorDescription = "Function is not confirmed";                                               break;
      case 4061:  ErrorDescription = "Send mail error";                                                         break;
      case 4062:  ErrorDescription = "String parameter expected";                                               break;
      case 4063:  ErrorDescription = "Integer parameter expected";                                              break;
      case 4064:  ErrorDescription = "Double parameter expected";                                               break;
      case 4065:  ErrorDescription = "Array as parameter expected";                                             break;
      case 4066:  ErrorDescription = "Requested history data in updating state";                                break;
      case 4067:  ErrorDescription = "Some error in trading function";                                          break;
      case 4099:  ErrorDescription = "End of file";                                                             break;
      case 4100:  ErrorDescription = "Some file error";                                                         break;
      case 4101:  ErrorDescription = "Wrong file name";                                                         break;
      case 4102:  ErrorDescription = "Too many opened files";                                                   break;
      case 4103:  ErrorDescription = "Cannot open file";                                                        break;
      case 4104:  ErrorDescription = "Incompatible access to a file";                                           break;
      case 4105:  ErrorDescription = "No order selected";                                                       break;
      case 4106:  ErrorDescription = "Unknown symbol";                                                          break;
      case 4107:  ErrorDescription = "Invalid price";                                                           break;
      case 4108:  ErrorDescription = "Invalid ticket";                                                          break;
      case 4109:  ErrorDescription = "EA is not allowed to trade is not allowed. ";                             break;
      case 4110:  ErrorDescription = "Longs are not allowed. Check the expert properties";                      break;
      case 4111:  ErrorDescription = "Shorts are not allowed. Check the expert properties";                     break;
      case 4200:  ErrorDescription = "Object exists already";                                                   break;
      case 4201:  ErrorDescription = "Unknown object property";                                                 break;
      case 4202:  ErrorDescription = "Object does not exist";                                                   break;
      case 4203:  ErrorDescription = "Unknown object type";                                                     break;
      case 4204:  ErrorDescription = "No object name";                                                          break;
      case 4205:  ErrorDescription = "Object coordinates error";                                                break;
      case 4206:  ErrorDescription = "No specified subwindow";                                                  break;
      case 4207:  ErrorDescription = "Some error in object function";                                           break;
      default:    ErrorDescription = "No error or error is unknown";
     }
   return(ErrorDescription);
  }
//+------------------------------------------------------------------+
//| End of ERROR DESCRIPTION                                         
