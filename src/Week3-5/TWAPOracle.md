# UNiswap V2 TWAP Oracle

Link to article: https://www.rareskills.io/post/twap-uniswap-v2

The article goes into detail how the TWAP oracle works. So this markdown will attempt to answer the following questions:
1. Why does the `price0CumulativeLast` and `price1CumulativeLast` never decrement
2. Why are `price0CumulativeLast` and `price1CumulativeLast` sroted separately? Why not just calculate `price1CumulativeLast = 1/price0CumulativeLast`?

The code of interest: (UniswapV2Pair.sol)
```
    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'UniswapV2: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }
```

## 1. Why does the `price0CumulativeLast` and `price1CumulativeLast` never decrement
The price0CumulativeLast and price1CumulativeLast are cumulative price variables that represent the cumulative sum of the time-weighted average prices (TWAP) for each token pair. In the contract, these variables are updated every time the _update function is called.

Recall, that in a pair: foo/bar: price(foo) = balance(bar)/balance(foo)

When calculating a Time Weighted Average Price, we need to be able to query for an arbitrary interval: one day, one week, one hour, one year, etc. Its impractical to store every permuation of a lookback period. The solution is to store the numerator value (Price * TimeInterval) every time a change in the liquidity ration happens (mint, burn, swap or sync are called). This records the new price and how long the previous price lasted (TimeInterval == time elapsed since last update).

So `price0CumulativeLast` and `price1CumulativeLast` essentially only keep increasing based on the function, and they accumulate prices constantly whenever there is an update.

## 2. Why are `price0CumulativeLast` and `price1CumulativeLast` sroted separately? Why not just calculate `price1CumulativeLast = 1/price0CumulativeLast`?
As per the article, in calculating the prices of each token in a pair, the price of one token cannot simply be the inverse of the other token when we are accumulating pricing. If you were to calculate `price1CumulativeLast` as the inverse of `price0CumulativeLast`, it would introduce rounding errors and potential inaccuracies. This is especially true in blockchain applications where floating-point arithmetic is not as precise, and fixed-point arithmetic is the norm.

Storing `price0CumulativeLast and `price1CumulativeLast` separately provides a more accurate and reliable measurement for each token’s price relative to the other. Also, since liquidity pools on Uniswap can expereince shifts in liquidity and price that are not symmetric, the individual tracking of each token's price is necessary to accurately reflect the state of the pool.

For example, a pool may start with equal amounts of Token A and B. If a large amount of Token B is added to the liquidity pool, but no additional Token A is added, this shifts the liquidity (changes price ratio between A and B).

Token A's prices increases because the supply of Token B increases while the supply of Token A remains the same. And Token B's prices decreases because the supply of Token A remains the same while the supply of Token B increases.

The addition of Token B directly impacts the price of Token A in the pool but NOT vice versa. Thus, the cumulative prices of Token A (`price0CumulativeLast`) and Token B (`price1CumulativeLast`) will change differently. If `price1CumulativeLast` were simply the inverse of `price0CumulativeLast`, this asymmetrical shift in liquidity and price wouldn't be accurately represented. Each token's price needs its own tracking to reflect its unique supply and demand dynamics within the pool.

