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
input int      K=3;
input int      ema1=24;
input int      ema2=120;
input int      rsiv=9;
input int      d=8;
input int      strategy=1;
input int      risk=5;
input int      rr_ratio=2;
input int      TrailingStop = 0;
input int      MaxAPeriods = 4;
int period = 1; //cumulative periods
double atr = 0;
double sl_pips=0;
int _BUY   = 1;
int _SELL  = 2;
int _MAGIKN= 8478237;
datetime LastActiontime;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   atr = iATR(NULL,0,24,0);
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
   double stocCurrM = iStochastic(NULL,0,K,d,3,MODE_EMA,1,MODE_MAIN,0);
   double stocPrevM = iStochastic(NULL,0,K,d,3,MODE_EMA,1,MODE_MAIN,1);
   double stocCurrS = iStochastic(NULL,0,K,d,3,MODE_EMA,1,MODE_SIGNAL,0);
   double stocPrevS = iStochastic(NULL,0,K,d,3,MODE_EMA,1,MODE_SIGNAL,1);
   
   double rsiCurrM  = iRSI(NULL,0,rsiv,PRICE_CLOSE,0);
   double rsiPrevM  = iRSI(NULL,0,rsiv,PRICE_CLOSE,1);
//---
   if(LastActiontime!=Time[0]){ 
      if ( ( iRSI(NULL,0,rsiv,PRICE_CLOSE,0) > 70 ) &&
           ( stocCurrM > 80 && stocPrevM > 80 ) &&
           ( stocCurrM < stocCurrS) && (stocPrevM > stocPrevS)
         ) 
            strategy1( _SELL, risk, rr_ratio);
      else if ( ( rsiCurrM < 30 )  &&
               ( stocCurrM < 20 && stocPrevM < 20 ) &&
               ( stocCurrM > stocCurrS) && (stocPrevM < stocPrevS) 
          )
           
           strategy1( _BUY, risk, rr_ratio);
      
      
      
     }
   }
//+------------------------------------------------------------------+
//| Calculate lot size according to risk and risk reward ratio
//+------------------------------------------------------------------+
double getLotSize(int risk_p, int rrratio) {

   double positionsize = 0;
   int leverage = AccountLeverage();
   double balance  = AccountBalance();
   atr = iATR(NULL,0,9,0)*MarketInfo(Symbol(),MODE_LOTSIZE);
   double atrT = iATR(NULL,0,9,0);
   
   //calculate position size

   //Print("rrratio: ",rrratio);
   sl_pips = (atrT/(double)rrratio)*(MarketInfo(Symbol(),MODE_LOTSIZE));
   
   double tickvalue = (MarketInfo(Symbol(),MODE_TICKVALUE));
   if(Digits == 5 || Digits == 3){
      tickvalue = tickvalue*10;
   }
   
   double riskcapital = AccountBalance()*risk/100;
   //Print("risk_P",risk_p, " rrratio: ", rrratio, " riskcapital: ", riskcapital, " sl_pips: ",sl_pips, " tickvalue: ", tickvalue);
   double Lots=(riskcapital/(double)sl_pips)/tickvalue;

   if( Lots < 0.1 )          // is money enough for opening 0.1 lot?
      if( ( AccountFreeMarginCheck( Symbol(), OP_BUY,  0.1 ) < 10. ) || 
          ( AccountFreeMarginCheck( Symbol(), OP_SELL, 0.1 ) < 10. ) || 
          ( GetLastError() == 134 ) )
                  Lots = 0.0; // not enough
      else        Lots = 0.1; // enough; open 0.1
   else           Lots = NormalizeDouble( Lots, 2 ); 

   //Print("balance ",AccountBalance(),", risk ",riskcapital,", sl_pips ",sl_pips,", Lots ",Lots,", tickvalue ",tickvalue);

   return Lots;
   
}


bool strategy1 (int action,int risk_p, int rrratio ) {
   int ticket;
   atr = iATR(NULL,0,9,0)*MarketInfo(Symbol(),MODE_LOTSIZE);
   double atrT = iATR(NULL,0,9,0);
   double lots = getLotSize(risk_p,rrratio);
   double SL = 0;
   double TP = 0;
   //Check if opened positions
   int total=OrdersTotal();
   if(total<1)
     {
      Print("No hay ordenes hay que abrir orden");
      //--- no opened orders identified
      if ( OrderSelect(OrdersHistoryTotal()-1, SELECT_BY_POS,MODE_HISTORY) ) {
             if ( OrderProfit()  < 0 ) {
                  Print("Previous order was a loss reset to period 1");
                  period = 1;
            }
      }
      if(AccountFreeMargin()<(1000*lots))
        {
         Print("We have no money. Free Margin = ",AccountFreeMargin());
         return false;
        }
      //--- check for long position (BUY) possibility
      if(action==_BUY )
        {
          //SL = MathAbs(Bid-(TakeProfit/2));
          SL = NormalizeDouble(Bid-sl_pips*Point,Digits);
          TP = NormalizeDouble(Ask+atr*Point,Digits);
          Print ("SL: ",SL, " Ask: ",Ask," TP: ",TP," Lots: ",lots*period," period: ",period," atr: ",atr);
          ticket=OrderSend(Symbol(),OP_BUY,lots * period,Ask,3,SL,TP,"stoc_rsi_mm",16384,0,Green);
         if(ticket>0)
         {
            if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
               Print("BUY order opened : ",OrderOpenPrice());
               if ( period < MaxAPeriods ) {
                  Print("Period increased by 1");
                  period+=1;
               }
               else {
                  Print("Period reset");
                  period = 1;
               }
         }
         else
            Print("Error opening BUY order : ",GetLastError());
         return false;
        }
      //--- check for short position (SELL) possibility
      if(action == _SELL)
        {
          //SL = MathAbs(Ask+(TakeProfit/2));
           SL = NormalizeDouble(Ask+sl_pips*Point,Digits);
           TP = NormalizeDouble(Bid-atr*Point,Digits);
          Print ("SL: ",SL, "Ask: ",Ask, " TP: ",TP," Lots: ",lots*period," period: ",period, " atr: ",atr);
         ticket=OrderSend(Symbol(),OP_SELL,lots * period  ,Bid,3,SL,TP,"stoc_rsi_mm",16384,0,Red);
         if(ticket>0)
           {
            if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)) {
               Print("SELL order opened : ",OrderOpenPrice());
               if ( period < MaxAPeriods ){
                  Print("Period increased by 1");
                  period+=1;
               }
               else{
                  Print("Period reset");
                  period = 1;
               }
             }
           }
         else
            Print("Error opening SELL order : ",GetLastError());
        
      //--- exit from the "no opened orders" block
      return false;
     }   
 }
 else { 
         Print("hay ordenes vamos a cerrar");
         for(int cnt=0;cnt<total;cnt++) {
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
                        return false;
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
                              return false;
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
                        return false;
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
                              return false;
                             }
                          }
                       } 
                 }
            
               }
      
         }
 
 }
 return true;
}