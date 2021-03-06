#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\OrderInfo.mqh>

CTrade              Trade;
CSymbolInfo         Symbol_Info;
COrderInfo          Order_Info;

input datetime  Input_Open_Date     = D'2020.01.01 00:00:00'; //Open Date and Time
input datetime  Input_Close_Date    = D'2020.01.01 00:00:00'; //Close Date and Time
input double    Input_Volume        = 0.22;     // Volume
input ushort    Input_Distance      = 10;       // Distance from the price (in pips)
input ushort    Input_Take_Profit   = 85;       // Take Profit (in pips)
input ushort    Input_Stop_Loss     = 85;       // Stop Loss (in pips)

bool    Open_Buy_Order_Not_Placed   = true;
bool    Open_Sell_Order_Not_Placed  = true;

double  Delta_Distance          = NULL;
double  Delta_Stop_Loss         = NULL;
double  Delta_Take_Profit       = NULL;

ulong   Magic_Number    = 244888906;
ulong   Deviation       = 0;


int OnInit()
{
    if(Period() == PERIOD_H1)
    {
        // Init m_trade object
        Trade.SetExpertMagicNumber(Magic_Number);
        Trade.SetMarginMode();
        Trade.SetTypeFilling(1);
        Trade.SetDeviationInPoints(Deviation);

        // Init m_symbol object
        Symbol_Info.Name(Symbol());
        Symbol_Info.RefreshRates();

        // Set pip size    
        int digits_adjust = 1;
        if(Symbol_Info.Digits() == 3 || Symbol_Info.Digits() == 5) digits_adjust = 10;
        
        double pip_size = Symbol_Info.Point() * digits_adjust;
    
        // Adjust Delta variables according to pip size
        Delta_Distance      = Symbol_Info.NormalizePrice(Input_Distance    * pip_size);
        Delta_Take_Profit   = Symbol_Info.NormalizePrice(Input_Take_Profit * pip_size);
        Delta_Stop_Loss     = Symbol_Info.NormalizePrice(Input_Stop_Loss   * pip_size);
    
        return INIT_SUCCEEDED;
    }
    else return false;
}

void OnTick()
{
    Symbol_Info.RefreshRates();
    
    string current_date_time = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);

    Schedule(current_date_time);
}

void Schedule(string current_date_time)
{
    

    if(StringCompare(current_date_time, TimeToString(Input_Open_Date, TIME_DATE|TIME_MINUTES)) == 0)
    {
        Print(" ");
        Print("current_date_time: " + current_date_time);
        Print("input_date_time:   " + TimeToString(Input_Open_Date, TIME_DATE|TIME_MINUTES));
        Print(" ");
    
        Open_Event(current_date_time);
    }
    else
    {
        Open_Buy_Order_Not_Placed   = true;
        Open_Sell_Order_Not_Placed  = true;
    }

    if(StringCompare(current_date_time, TimeToString(Input_Close_Date, TIME_DATE|TIME_MINUTES)) == 0)
    {
       Close_Event();
    }
}

void Open_Event(string current_date_time)
{
    double price, stop_loss, take_profit;
    int digits = Symbol_Info.Digits();
    
    if(Open_Buy_Order_Not_Placed)
    {
        double ask   = Symbol_Info.Ask();
        price        = Symbol_Info.NormalizePrice(ask + Delta_Distance);
        stop_loss    = Symbol_Info.NormalizePrice(ask + Delta_Distance - Delta_Stop_Loss);
        take_profit  = Symbol_Info.NormalizePrice(ask + Delta_Distance + Delta_Take_Profit);
        
        Print(" ");
        Print("Buy Stop:");
        Print("=========");
        Print("Date and Time:     " + current_date_time);
        Print("Delta_Distance:    " + DoubleToString(Delta_Distance, digits));
        Print("Delta_Take_Profit: " + DoubleToString(Delta_Take_Profit, digits));
        Print("Ask:               " + DoubleToString(ask, digits));
        Print("Price:             " + DoubleToString(price, digits)         + "(Ask + Delta_Distance)");
        Print("Stop Loss:         " + DoubleToString(stop_loss, digits)     + "(Ask + Delta_Distance - Delta_Stop_Loss)");
        Print("Take Profit:       " + DoubleToString(take_profit, digits)   + "(Ask + Delta_Distance + Delta_Take_Profit)");
        
        if(Trade.BuyStop(Input_Volume, price, Symbol_Info.Name(), stop_loss, take_profit, ORDER_TIME_GTC))
            Open_Buy_Order_Not_Placed = false;
        else
            Print("!!! 'Buy Stop' Order Failed.");
        
        Print(" ");
    }
    
    if(Open_Sell_Order_Not_Placed)
    {
        double bid  = Symbol_Info.Bid();
        price       = Symbol_Info.NormalizePrice(bid - Delta_Distance);
        stop_loss   = Symbol_Info.NormalizePrice(bid - Delta_Distance + Delta_Stop_Loss);
        take_profit = Symbol_Info.NormalizePrice(bid - Delta_Distance - Delta_Take_Profit);
        
        Print(" ");
        Print("Sell Stop:");
        Print("==========");
        Print("Date and Time:      " + current_date_time);
        Print("Delta_Distance:     " + DoubleToString(Delta_Distance, digits));
        Print("Delta_Take_Profit:  " + DoubleToString(Delta_Take_Profit, digits));
        Print("Bid:                " + DoubleToString(bid, digits));
        Print("Price:              " + DoubleToString(price, digits)        + "(Bid - Delta_Distance)");
        Print("Stop Loss:          " + DoubleToString(stop_loss, digits)    + "(Bid - Delta_Distance + Delta_Stop_Loss)");
        Print("Take Profit:        " + DoubleToString(take_profit, digits)  + "(Bid - Delta_Distance - Delta_Take_Profit)");
 
        if(Trade.SellStop(Input_Volume, price, Symbol_Info.Name(), stop_loss, take_profit, ORDER_TIME_GTC))
            Open_Sell_Order_Not_Placed = false;
        else
            Print("!!! 'Sell Stop' Order Failed.");
        
        Print(" ");
    }
}

void Close_Event()
{
    int order_count = OrdersTotal();

    for(int i = 0; i < order_count; i++)
    {
        if(Order_Info.SelectByIndex(i) && Order_Info.Symbol() == Symbol_Info.Name() && Order_Info.Magic() == Magic_Number)
        {
            string order_type = Order_Info.TypeDescription();
        
            if(order_type == "buy stop" || order_type == "sell stop")
            {
                ulong ticket = Order_Info.Ticket();
            
                Trade.OrderDelete(ticket);
                
                Print("Order of type: '" + order_type + "', with ticket id: '" + IntegerToString(Order_Info.Ticket()) + "' - Cancelled.");
            }
        }
    }
}


