bool          cci_highest      = FALSE;
bool          cci_lowest       = FALSE;
bool          trade_sell       = FALSE;
bool          trade_buy        = FALSE;
double        last_order_price = 0;
double        band_high        = 0;
double        band_low         = 0;
double        i_lots           = 0;
int           initial_deposit  = 0;
int           total_orders     = 0;
int           iterations       = 0;
int           lotdecimal       = 2;
int           prev_time        = 0;
int           timeout          = 999999999;
int           order__time      = 0;
int           magic_num        = 2222;
int           error            = 0;
int           slip             = 1000;
extern int    cci_max          = 130;
extern int    cci_min          = -130;
extern int    cci_period       = 13;
extern int    cci_ma           = 3;
extern double bands_dev        = 0.3;
extern double exp              = 1.3;
extern double lots             = 0.01;
uint          time_start       = GetTickCount();
string        name             = "Ilan1.6";

int init()
{
    initial_deposit = AccountBalance();
    UpdateBeforeOrder();
    UpdateAfterOrder();
    Debug();
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
    if (prev_time == Time[0]) return 0;
    prev_time = Time[0];
    UpdateBeforeOrder();

    /* Closes all orders if there are any */
    RefreshRates();
    if (AccountProfit() > 0.01 && trade_buy  && !cci_lowest ) CloseAllOrders();
    if (AccountProfit() > 0.01 && trade_sell && !cci_highest) CloseAllOrders();

    /* First order */
    if (OrdersTotal() == 0)
    {
        if (cci_highest) SendOrder(OP_SELL);
        if (cci_lowest) SendOrder(OP_BUY);
        return 0;
    }

    /* Checks Timeout */
    if (OrdersTotal() > 0 && Time[0] - order__time > timeout && IsTesting())
        CloseAllOrders();

    /* Proceeding orders */
    if (trade_sell && cci_highest && band_low  > last_order_price) SendOrder(OP_SELL);
    if (trade_buy  && cci_lowest  && band_high < last_order_price) SendOrder(OP_BUY );
    return 0;
}

void UpdateBeforeOrder()
{
    band_high      = Ask * (1 + bands_dev / 100);
    band_low       = Bid * (1 - bands_dev / 100);
    double cci     = iCCI(0, 0, cci_period, PRICE_TYPICAL, 1);
    double cci_avg = 0;

    for (int i = 1; i <= cci_ma; i++)
        cci_avg += iCCI(0, 0, cci_period, PRICE_TYPICAL, i);

    cci_avg /= cci_ma;

    if (cci_avg > cci_max && cci < cci_avg) cci_highest = 1; else cci_highest = 0;
    if (cci_avg < cci_min && cci > cci_avg) cci_lowest  = 1; else cci_lowest  = 0;
}

void UpdateAfterOrder()
{
    double multiplier = MathPow(exp, OrdersTotal());
    i_lots            = NormalizeDouble(lots * multiplier, lotdecimal);

    error = OrderSelect(OrdersTotal() - 1, SELECT_BY_POS, MODE_TRADES);
    last_order_price = OrderOpenPrice();

    /* In case user modifies a previous order */
    for (int i = 0; i < OrdersTotal() - 1; i++)
    {
        error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

        if (OrderOpenPrice() > last_order_price && OrderType() == OP_SELL)
            last_order_price = OrderOpenPrice();
        if (OrderOpenPrice() < last_order_price && OrderType() == OP_BUY)
            last_order_price = OrderOpenPrice();
    }

    if (OrdersTotal() == 0)
    {
        total_orders     = 0;
        order__time      = Time[0];
        trade_sell       = FALSE;
        trade_buy        = FALSE;
    }
    else if (OrderType() == OP_SELL)
    {
        total_orders     = OrdersTotal();
        order__time      = Time[0];
        trade_sell       = TRUE;
        trade_buy        = FALSE;
    }
    else if (OrderType() == OP_BUY)
    {
        total_orders     = OrdersTotal();
        order__time      = Time[0];
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
    if (OP_TYPE == OP_SELL)
        error = OrderSend(Symbol(), OP_TYPE, i_lots, Bid, slip, 0, 0, name,
                          magic_num, 0, clrHotPink);
    if (OP_TYPE == OP_BUY)
        error = OrderSend(Symbol(), OP_TYPE, i_lots, Ask, slip, 0, 0, name,
                          magic_num, 0, clrLimeGreen);

    if (IsTesting()  && error < 0) Kill();
    if (!IsTesting() && error < 0) Print("Order failed.");
    UpdateAfterOrder();
}

void CloseAllOrders()
{
    color clr = clrBlue;
    if (Time[0] - order__time > timeout) clr = clrGold;

    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        if (OrderType() == OP_BUY)
            error = OrderClose(OrderTicket(), OrderLots(), Bid, slip, clr);
        if (OrderType() == OP_SELL)
            error = OrderClose(OrderTicket(), OrderLots(), Ask, slip, clr);
    }
    UpdateAfterOrder();
}

void Kill()
{
    CloseAllOrders();
    while (AccountBalance() >= initial_deposit - 1)
    {
        error = OrderSend(Symbol(), OP_BUY, 0.01, Ask, 0, 0, 0, 0, 0, 0, 0);
        CloseAllOrders();
    }
    ExpertRemove();
}

void Debug()
{
    UpdateBeforeOrder();
    int time_difference = TimeCurrent() - Time[0];
    Comment("\n- "      +
            "Lots: "    + i_lots                         + " - " +
            "Timeout: " + (Time[0] - order__time) / 3600 + " - " +
            "Last: "    + last_order_price               + " - " +
            "Time: "    + time_difference                + " - " +
            "");
}
