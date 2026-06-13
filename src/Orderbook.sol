// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IOrderbook} from "./IOrderbook.sol";

/// @dev Minimal ERC20 surface the orderbook needs. The provided `MockERC20`
///      implements all of these methods (plus `mint`).
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}



/// @title Orderbook (template)
/// @notice Skeleton to complete. The constructor, immutable
///         token wiring, and the two trivial getters are already done —
///         everything else reverts with `"NotImplemented"`.
///
///         You are free to add additional state, structs, errors, and
///         helper functions. The only hard constraints are:
///         (1) keep the `IOrderbook` ABI exactly as declared in the
///             interface (the grading harness depends on it), and
///         (2) keep `baseToken`/`quoteToken` as immutables set in the
///             constructor.
contract Orderbook is IOrderbook {
    IERC20 public immutable baseToken;
    IERC20 public immutable quoteToken;

    /// @dev Suggested events. These are a starting point — your
    ///      implementation may emit a different set, rename them, or omit
    ///      events entirely. Nothing in the grading harness depends on
    ///      these signatures.
    event OrderPlaced(
        uint256 indexed orderId,
        address indexed maker,
        Side side,
        uint256 price,
        uint256 amount
    );
    event OrderFilled(
        uint256 indexed orderId,
        address indexed taker,
        uint256 fillAmount,
        uint256 fillPrice
    );
    event OrderCleared();

    constructor(address _baseToken, address _quoteToken) {
        require(_baseToken != address(0), "baseToken=0");
        require(_quoteToken != address(0), "quoteToken=0");
        require(_baseToken != _quoteToken, "base==quote");
        baseToken = IERC20(_baseToken);
        quoteToken = IERC20(_quoteToken);
    }

    struct Order {
        address maker;
        uint256 price;
        uint256 amount;
        uint256 orderId;
    }

    Order[] bids;
    Order[] asks;
    uint256 next = 1;


    function getBaseToken() external view returns (address) {
        return address(baseToken);
    }

    function getQuoteToken() external view returns (address) {
        return address(quoteToken);
    }

    function placeLimitOrder(Side side, uint256 price, uint256 amount) external returns (uint256) {
        uint256 orderId = next++;
        uint256 remaining = amount;
        
        if (side == Side.BUY) {
            for (uint256 i = 0; i < asks.length && remaining > 0; i++) {
                Order storage order = asks[i];
                if (order.amount == 0){ 
                    continue;
                }
                if (price < order.price) {
                    break;
                }
                
                uint256 fillAmount = remaining < order.amount ? remaining : order.amount;
                uint256 quoteAmount = (fillAmount * order.price) / 1e18;
                
                quoteToken.transferFrom(msg.sender, order.maker, quoteAmount);
                baseToken.transfer(msg.sender, fillAmount);
                
                emit OrderFilled(order.orderId, msg.sender, fillAmount, order.price);
                
                remaining -= fillAmount;
                order.amount -= fillAmount;
            }
            
            if (remaining > 0) {//for edge case unfilled
                uint256 quoteRequired = (remaining * price) / 1e18;
                quoteToken.transferFrom(msg.sender, address(this), quoteRequired);
                
                Order memory newOrder = Order({
                    maker: msg.sender,
                    price: price,
                    amount: remaining,
                    orderId: orderId
                });
                bids.push(newOrder);
            }
        } else {
            for (uint256 i = 0; i < bids.length && remaining > 0; i++) {
                Order storage order = bids[i];
                if (order.amount == 0) continue;
                if (price > order.price) break;
                
                uint256 fillAmount = remaining < order.amount ? remaining : order.amount;
                uint256 quoteAmount = (fillAmount * order.price) / 1e18;
                
                baseToken.transferFrom(msg.sender, order.maker, fillAmount);
                quoteToken.transfer(msg.sender, quoteAmount);
                
                emit OrderFilled(order.orderId, msg.sender, fillAmount, order.price);
                
                remaining -= fillAmount;
                order.amount -= fillAmount;
            }
            
            if (remaining > 0) {
                baseToken.transferFrom(msg.sender, address(this), remaining);
                
                Order memory newOrder = Order({
                    maker: msg.sender,
                    price: price,
                    amount: remaining,
                    orderId: orderId
                });
                asks.push(newOrder);
            }
        }
        
        emit OrderPlaced(orderId, msg.sender, side, price, amount);
        return orderId;
    }

    function placeMarketOrder(Side side, uint256 amount) external {
        uint256 remaining = amount;
        
        if (side == Side.BUY) {
            // Market buy
            for (uint256 i = 0; i < asks.length && remaining > 0; i++) {
                Order storage order = asks[i];
                if (order.amount == 0) continue;
                
                uint256 fillAmount = remaining < order.amount ? remaining : order.amount;
                uint256 quoteAmount = (fillAmount * order.price) / 1e18;
                
                // transfer the money
                quoteToken.transferFrom(msg.sender, order.maker, quoteAmount);
                baseToken.transfer(msg.sender, fillAmount);
                
                emit OrderFilled(order.orderId, msg.sender, fillAmount, order.price);
                
                remaining -= fillAmount;
                order.amount -= fillAmount;
            }
        } else {
            // Market sell
            for (uint256 i = 0; i < bids.length && remaining > 0; i++) {
                Order storage order = bids[i];
                if (order.amount == 0) continue;  //skip teh fully filled orders
                
                uint256 fillAmount = remaining < order.amount ? remaining : order.amount;
                uint256 quoteAmount = (fillAmount * order.price) / 1e18;
                
                baseToken.transferFrom(msg.sender, order.maker, fillAmount);
                quoteToken.transfer(msg.sender, quoteAmount);
                
                emit OrderFilled(order.orderId, msg.sender, fillAmount, order.price);
                
                remaining -= fillAmount;
                order.amount -= fillAmount;
            }
        }
    }

    function clear() external {
        delete bids;    
        delete asks;
        emit OrderCleared();
    }

    function getBidsCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].amount > 0) count++;
        }
        return count;
    }

    function getAsksCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < asks.length; i++) {
            if (asks[i].amount > 0) count++;
        }
        return count;
        }

    function getMidPrice() external view returns (uint256) {
        require(bids.length > 0);
        require(asks.length > 0);
        uint256 bask = type(uint256).max;
        for (uint256 i = 0; i < asks.length; i++) {
            if (asks[i].amount > 0 && asks[i].price < bask) {
                bask = asks[i].price;
            }
        }


        uint256 bBid = 0;
        for (uint256 i = 0; i < bids.length; i++) {//basically a max function
            if (bids[i].amount > 0 && bids[i].price > bBid) {
                bBid = bids[i].price;
            }
        }


        
        require(bBid > 0); // sanity checking
        require(bask < type(uint256).max);
        return (bBid + bask) / 2;
    }



}
