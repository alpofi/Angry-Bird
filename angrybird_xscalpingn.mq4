bool cci_highest = FALSE;
bool cci_lowest  = FALSE;
bool trade_sell  = FALSE;
bool trade_buy   = FALSE;
bool cci_high    = FALSE;
bool cci_low     = FALSE;
double last_order_price = 0;
double band_high        = 0;
double band_low         = 0;
double i_lots           = 0;
int initial_deposit = 0;
int magic_num       = 2222;
int total_orders    = 0;
int iterations      = 0;
int lotdecimal      = 2;
int prev_time       = 0;
int slip            = 100;
int error           = 0;
uint time_start = GetTickCount();
string name = "Ilan1.6";
extern int cci_max      = 190;
extern int cci_min      = -230;
extern int cci_period   = 18;
extern int cci_ma       = 2;
extern int bands_period = 4;
extern double exp       = 1.2;
extern double lots      = 0.01;

int init()
{
    initial_deposit = AccountBalance();
    UpdateBeforeOrder();
    UpdateAfterOrder();
    Debug();
    ObjectCreate("band_high", OBJ_HLINE, 0, 0, band_high);
    ObjectCreate("band_low" , OBJ_HLINE, 0, 0, band_low );
    return 0;
}

int deinit()
{
    uint time_elapsed = GetTickCount() - time_start;
    Print("Time Elapsed: " + time_elapsed);
    Print("Iterations: "   + iterations  );
    return 0;
}

int start()
{
    if (!IsTesting() || IsVisualMode()) Debug();

    /* Idle conditions */
    if (prev_time == Time[0]) return 0; prev_time = Time[0];
    UpdateBeforeOrder();

    /* Closes all orders if there are any*/
    if (AccountProfit() > 0) CloseAllOrders();

    /* First order */
    if (total_orders == 0 && cci_lowest ) SendOrder(OP_BUY );
    if (total_orders == 0 && cci_highest) SendOrder(OP_SELL);

    /* Proceeding orders */
    if (trade_sell && cci_highest && band_low  > last_order_price) SendOrder(OP_SELL);
    if (trade_buy  && cci_lowest  && band_high < last_order_price) SendOrder(OP_BUY );
    return 0;
}

void UpdateBeforeOrder()
{
    double spread     = MarketInfo(0, MODE_SPREAD) * Point;
    double high_index = iHighest(0, 0, MODE_HIGH, bands_period, 1);
    double low_index  = iLowest (0, 0, MODE_LOW , bands_period, 1);
    band_high         = iHigh(0, 0, high_index) + spread;
    band_low          = iLow (0, 0, low_index ) - spread;
    double cci        = iCCI(0, 0, cci_period, PRICE_TYPICAL, 1);
    double cci_avg    = 0;
    
    for (int i = 1; i <= cci_ma; i++)
    {
        cci_avg += iCCI(0, 0, cci_period, PRICE_TYPICAL, i);
    }
    cci_avg /= cci_ma;

    if (cci_avg > cci_max && cci < cci_avg) cci_highest = 1; else cci_highest = 0;
    if (cci_avg < cci_min && cci > cci_avg) cci_lowest  = 1; else cci_lowest  = 0;
    if (cci     > cci_min && cci < cci_avg) cci_high    = 1; else cci_high    = 0;
    if (cci     < cci_max && cci > cci_avg) cci_low     = 1; else cci_low     = 0;
}

void UpdateAfterOrder()
{
    double multiplier = MathPow(exp, OrdersTotal());
    i_lots            = NormalizeDouble(lots * multiplier, lotdecimal);

    error = OrderSelect(OrdersTotal() - 1, SELECT_BY_POS, MODE_TRADES);
    if (OrdersTotal() == 0)
    {
        last_order_price = 0;
        total_orders     = 0;
        trade_sell       = FALSE;
        trade_buy        = FALSE;
    }
    else if (OrderType() == OP_SELL)
    {
        last_order_price = OrderOpenPrice();
        total_orders     = OrdersTotal();
        trade_sell       = TRUE;
        trade_buy        = FALSE;
    }
    else if (OrderType() == OP_BUY)
    {
        last_order_price = OrderOpenPrice();
        total_orders     = OrdersTotal();
        trade_sell       = FALSE;
        trade_buy        = TRUE;
    }
    else
    {
        Alert("Critical error " + GetLastError());
    }
}

void SendOrder(int OP_TYPE)
{
    double price = 0;
    double clr   = 0;

    if (OP_TYPE == OP_SELL)
    {
        price = Bid;
        clr   = clrHotPink;
    }
    if (OP_TYPE == OP_BUY)
    {
        price = Ask;
        clr   = clrLimeGreen;
    }
    error = OrderSend(Symbol(), OP_TYPE, i_lots, price, slip, 0, 0, name, magic_num, 0, clr);
    if (IsTesting() && error < 0) Kill();
    UpdateAfterOrder();
}

void CloseAllOrders()
{
    color  clr    = clrBlue;
    double ticket = 0;
    double lots_  = 0;

    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        error  = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        ticket = OrderTicket();
        lots_  = OrderLots();

        if (OrderType() == OP_BUY ) error = OrderClose(ticket, lots_, Bid, slip, clr);
        if (OrderType() == OP_SELL) error = OrderClose(ticket, lots_, Ask, slip, clr);
    }
    UpdateAfterOrder();
}

void Kill()
{

    CloseAllOrders();
    while (AccountBalance() >= initial_deposit - 1)
    {
        double lots_ = AccountFreeMargin() / Ask;
        error = OrderSend(Symbol(), OP_BUY, lots_, Ask, 0, 0, 0, 0, 0, 0, 0);
        CloseAllOrders();
    }
    ExpertRemove();
}

void Debug()
{
    UpdateAfterOrder();
    UpdateBeforeOrder();
    
    ObjectSet("band_high", OBJPROP_PRICE1, band_high);
    ObjectSet("band_low" , OBJPROP_PRICE1, band_low );
    
    int time_difference = TimeCurrent() - Time[0];
    Comment("lots: " + i_lots + " Time: " + time_difference);
}
