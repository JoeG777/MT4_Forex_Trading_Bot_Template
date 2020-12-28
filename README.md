# MT4_Forex_Trading_Bot_Template

## Goal
To get an understanding for the different parts of a robust trading system with MetaTrader 4.

## Outcome

## Ressources
- [Kalle Halden](https://www.youtube.com/watch?v=-MHhA-Y3DSk)
- [AlgoTrading 101](https://algotrading101.com/)

## Main Parts
# 1. Entries
  Enters if there was a quick pullback.
  ```
  if high_2_bars_ago > high_1_bar_ago && low_2_bars_ago < low_1_bar_ago && lastClose > high_2_bars_ago
  ```
  That rules looks like this on a chart.
  
  ![Entry](https://github.com/JoeG777/MT4_Forex_Trading_Bot_Template/blob/main/Entry.PNG)
 
# 2. Sizing Algorithm
  > output=fractalOfAccountToRisk*AccountEquity/lotSize* tickValue * stopRangeInTicks*adjustForTicks);

# 3. Exits
  - Stop Loss (in Ticks)
  > stopLoss=volMultiplier*VolATR/(K*Point);
  - same applies to Take Profit

## Backtest Results
![Backtest](https://github.com/JoeG777/MT4_Forex_Trading_Bot_Template/blob/main/Screenshot_2020-12-28%20Strategy%20Tester%2032%20Quick%20Pullback%20Pattern.png)

### Thank you very much and have fun playing around
