//+------------------------------------------------------------------+
//|                                            stochastic_rsi_mm.mq4 |
//|             Copyright 2018, Juan Gallego juan.gallego@vozanet.co |
//|                                           https://www.vozanet.co |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Juan Gallego juan.gallego@vozanet.co"
#property link      "https://www.vozanet.co"
#property version   "1.00"
#property strict
//--- input parameters
input int      K=4;
input int      ema1=24;
input int      ema2=120;
input int      rsiv=9;
input int      d=9;
input int      strategy=1;
input int      risk=5;
input int      TrailingStop = 0;
int period = 1; //cumulative periods
int _BUY   = 1;
int _SELL  = 2;
int _MAGIKN= 8478237;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Calculate lot size according to risk and risk reward ratio
//+------------------------------------------------------------------+
double getLotSize(int risk_p, int rr_ratio) {

   double positionsize = 0;
   int leverage = AccountLeverage();
   int balance  = AccountBalance();
   double atr = 0;
   int sl_pips;
   //calculate position size

   atr = iATR(NULL,0,24,0);
   sl_pips = atr/rr_ratio;
   double tickvalue = (MarketInfo(Symbol(),MODE_TICKVALUE));
   if(Digits == 5 || Digits == 3){
      tickvalue = tickvalue*10;
   }
   
   double riskcapital = AccountBalance()*risk/100;
   
   double Lots=(riskcapital/sl_pips)/tickvalue;

   if( Lots < 0.1 )          // is money enough for opening 0.1 lot?
      if( ( AccountFreeMarginCheck( Symbol(), OP_BUY,  0.1 ) < 10. ) || 
          ( AccountFreeMarginCheck( Symbol(), OP_SELL, 0.1 ) < 10. ) || 
          ( GetLastError() == 134 ) )
                  Lots = 0.0; // not enough
      else        Lots = 0.1; // enough; open 0.1
   else           Lots = NormalizeDouble( Lots, 2 ); 

   Comment("balance ",AccountBalance(),", risk ",riskcapital,", sl_pips ",sl_pips,", Lots ",Lots,", tickvalue ",tickvalue);

   return Lots;
   
}


bool strategy1 (int action, bool close,int risk_p, int rr_ratio ) {
   
   double lots = getLotSize(risk_p,rr_ratio);
   //Check if opened positions
   total=OrdersTotal();
   for(cnt=0;cnt<total;cnt++) {
      if(!OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderType()<=OP_SELL &&   // check for opened position 
         OrderSymbol()==Symbol())  // check for symbol
      {
         if(OrderType()==OP_BUY)
         {
            //--- should it be closed?
            if(action == _BUY )
            {
                  //--- close order and exit
                  if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,Violet)) 
                     Print("OrderClose error ",GetLastError());
                  else if ( OrderProfit()  < 0 || period >= MaxAPeriods) {
                        Print("Order closed and period reset");
                        period = 1;
                  }
                  return;
            }
            if(TrailingStop>0)
            {
                  if(Bid-OrderOpenPrice()>Point*TrailingStop)
                  {
                     if(OrderStopLoss()<Bid-Point*TrailingStop)
                     {
                        //--- modify order and exit
                        if(!OrderModify(OrderTicket(),OrderOpenPrice(),Bid-Point*TrailingStop,OrderTakeProfit(),0,Green))
                           Print("OrderModify error ",GetLastError());
                        return;
                     }
                  }
             } 
           }
           else {
              if( action == _SELL )
                 {
                  //--- close order and exit
                  if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,Violet))
                     Print("OrderClose error ",GetLastError());
                  else if ( OrderProfit()  < 0 || period >= MaxAPeriods) {
                        period = 1;
                  }
                  return;
                 }
               //--- check for trailing stop
               
               if(TrailingStop>0)
                 {
                  if((OrderOpenPrice()-Ask)>(Point*TrailingStop))
                    {
                     if((OrderStopLoss()>(Ask+Point*TrailingStop)) || (OrderStopLoss()==0))
                       {
                        //--- modify order and exit
                        if(!OrderModify(OrderTicket(),OrderOpenPrice(),Ask+Point*TrailingStop,OrderTakeProfit(),0,Red))
                           Print("OrderModify error ",GetLastError());
                        return;
                       }
                    }
                 } 
           }
      
         }

   }
}