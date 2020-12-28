# MT4_Forex_Trading_Bot_Template

## Goal
To get an understanding for the different parts of a robust trading system with MetaTrader 4.

## Outcome

## Ressources
- Kalle Halden (https://www.youtube.com/watch?v=-MHhA-Y3DSk)
- Algo101 (https://algotrading101.com/)

## Main Parts
# 1. Entries
  Enters if there was a quick pullback.
  ```
  if high_3_bars_ago > high_2_bars_ago && low_3_bars_ago < low_2_bars_ago && lastClose > high_3_bars_ago
  ```
  That rules looks like this on a chart.
  ![Entry Chart] (Entry.png)
 
# 2. Sizing Algorithm
  > output=fractalOfAccountToRisk*AccountEquity/lotSize* tickValue * stopRangeInTicks*adjustForTicks);

# 3. Exits
  - Stop Loss (in Ticks)
  > stopLoss=volMultiplier*VolATR/(K*Point);
  - same applies to Take Profit

## Backtest Results
![Backtest Results] (Screenshot_2020-12-28 Strategy Tester 32 Quick Pullback Pattern.png)
