pragma solidity ^0.4.9;
contract Bid {
    modifier tokenPayable {
        if (msg.sender!=market)
            throw;
        _;
    }
    
    address public master;  //an exchange address
    address public owner;  //order placer address
    address public market; //token contract address
    bytes32 public id;
    uint256 public price;  //price is the amount of WEI that is earned per each token
    uint256 etherBalance=0;
    bool public disposed=false;  //DEBUG variable
    
    
    function getMarket() constant returns (address) {return market; }
    function getEtherBalance() constant returns (uint256) {return etherBalance; }
    
    function Bid(address _market, bytes32 _id, uint256 _price, address _owner) {
        master=msg.sender;
        owner=_owner;
        market=_market;
        id=_id;
        price=_price;
    }
    
    function() payable {
        //Bid order.
        //The trade is triggered when tokens are deposited.
        //We only need to update order when deposit from owner occurs.
        
        if(msg.sender==master) {
            etherBalance+=msg.value;
        }
        
        //Check if deposited amount is larger than tokens could be bought.
        else if(msg.sender==owner) {
            etherBalance+=msg.value;
            orderUpdate();
        }
    }
    
    
    function tokenFallback(address _from, uint _value, bytes _data) tokenPayable returns (bool result) {
        //Trade is triggered by token deposit.
        ERC23 asset = ERC23(market);
        if((_value * price) > etherBalance) {
            //Full fill order and refund extra tokens.
            if(_from.send(etherBalance) && asset.transfer(owner, etherBalance/price) && asset.transfer(_from, _value - (etherBalance/price))) {
                orderDispose();
            }
            return true;
        }
        else {
            //Partially fill order.
            if(_from.send(_value * price) && asset.transfer(owner, _value)) {
                etherBalance-=_value * price;
                if(etherBalance==0) {
                    orderDispose;
                }
                else {
                    orderUpdate();
                }
                return true;
            }
        }
    }
    
    function orderUpdate() {
        DEXchange exchange = DEXchange(master);
        exchange.onOrdedUpdate(market, id);
    }
    
    function orderDispose() private {
        ERC23 asset = ERC23(market);
        if(asset.balanceOf(address(this))>0) {
            asset.transfer(owner, asset.balanceOf(address(this)));
        }
        DEXchange exchange = DEXchange(master);
        exchange.onOrdedDispose(market, id);
        selfdestruct(master);
    }
}

contract Ask {
    modifier tokenPayable {
        if (msg.sender!=market)
            throw;
        _;
    }
    
    address public master;  //an exchange address
    address public owner;  //order placer address
    address public market; //token contract address
    bytes32 public id;
    uint256 public price;  //price is the amount of WEI that is earned per each token
    uint256 tokenBalance=0;
    bool public disposed=false;  //DEBUG variable
    
    
    function getMarket() constant returns (address) {return market; }
    function getTokenBalance() constant returns (uint256) {return tokenBalance; }
    
    function Ask(address _market, bytes32 _id, uint256 _price, address _owner) {
        master=msg.sender;
        owner=_owner;
        market=_market;
        id=_id;
        price=_price;
    }
    
    function() payable {
        //Ask order.
        //The trade is triggered when Ether is deposited
        
        //Check if deposited amount is larger than tokens could be bought
        ERC23 asset = ERC23(market);
        if(msg.value > tokenBalance * price) {
            if(owner.send(tokenBalance * price) && msg.sender.send(msg.value - tokenBalance * price) && asset.transfer(msg.sender, tokenBalance)) {
                orderDispose();
            }
        }
        else {
            if(asset.transfer(msg.sender, msg.value/price) && owner.send(msg.value)) {
                tokenBalance-=msg.value/price;
                orderUpdate();
            }
        }
    }
    
    
    function tokenFallback(address _from, uint _value, bytes _data) tokenPayable returns (bool result) {
        if(_from==owner){
            tokenBalance+=_value;
            orderUpdate();
            return true;
        }
        else {
            throw;
        }
    }
    
    function orderUpdate() {
        DEXchange exchange = DEXchange(master);
        exchange.onOrdedUpdate(market, id);
    }
    
    function orderDispose() private {
        ERC23 asset = ERC23(market);
        if(asset.balanceOf(address(this))>0) {
            asset.transfer(owner, asset.balanceOf(address(this)));
        }
        DEXchange exchange = DEXchange(master);
        exchange.onOrdedDispose(market, id);
        selfdestruct(master);
    }
}

contract ERC23 {
  uint public totalSupply;
  function balanceOf(address who) constant returns (uint);
  function allowance(address owner, address spender) constant returns (uint);

  function transfer(address to, uint value) returns (bool ok);
  function transfer(address to, uint value, bytes data) returns (bool ok);
  function transferFrom(address from, address to, uint value) returns (bool ok);
  function approve(address spender, uint value) returns (bool ok);
  event Transfer(address indexed from, address indexed to, uint value);
  event Approval(address indexed owner, address indexed spender, uint value);
}

//Contract that is minting and burning cryptocurrency tokens

contract DEXchange {

    event OrderPlaced(address indexed _market, bytes32 _signer);
    event OrderUpdated(address indexed _market, bytes32 _signer);
    event OrderDisposed(address indexed _market, bytes32 _signer);
    event Trade(address indexed _market, uint256 indexed _price, uint256 indexed _amount);
    event MarketAdded(address indexed _contract, uint indexed _decimals);
    
    address public owner;
    mapping (address => bool) public market;
    mapping (address => uint) public marketDecimals;
    mapping (address => bytes32) public ordersByAddress;
    mapping (bytes32 => address) public ordersBySigner;
    
    
    //A function that will help you to find your orders.
    function whatTheHash(address _market, address _owner, uint _price) constant returns (bytes32) {
        return sha256(_market, _owner, _price);
    }
    
    function placeOrder(address _owner, address _market, uint _price, uint _amount, bool _ask) returns (bool ok){
        
        bytes32 signer = sha256(_market, _owner, _price, _ask);
        if(_ask) {
            
            //If the order is new place it.
            if(ordersBySigner[signer]==0x0) {
                address newAsk = new Ask(_market, signer, _price, _owner);
                ordersBySigner[signer]=newAsk;
            
                //ordersByAddress[newAsk]=signer;
            }
            //Otherwise update an existing one.
            //It will prevent users from placing multiple
            //orders with same price on one market
            ERC23 asset = ERC23(_market);
            if(asset.transfer(newAsk, _amount)) {
                OrderPlaced(_market, signer);
                return true;
            }
        }
        else {
            if(ordersBySigner[signer]==0x0) {
                address newBid = new Bid(_market, signer, _price, _owner);
                ordersBySigner[signer]=newBid;
            }
            if(ordersBySigner[signer].send(_amount)) {
                OrderPlaced(_market, signer);
                return true;
            }
        }
        throw;
    }
    
    function tokenFallback(address _from, uint _value, bytes _data) returns (bool result) {
        if(_data.length!=0) {
            uint _price = parseSingleUintArg(_data);
            if(market[msg.sender]) {
                return placeOrder(_from, msg.sender, _price, _value, true);
            }
        }
        throw;
    }
    
    function placeBid(uint _price, address _market) payable {
        if(market[_market]) {
            if(!placeOrder(msg.sender, _market, _price, msg.value, false)){
                throw;
            }
        }
    }
    
    function parseSingleUintArg(bytes _data) private returns (uint)
    {
        uint x = 0;
        for (uint i = 0; i < 32; i++) {
            uint b = uint(_data[35 - i]);
            x += b * 256**i;
        }
        return x;
    }
    
    function onOrdedUpdate(address _market, bytes32 _signer) {
        OrderUpdated(_market, _signer);
    }
    
    function onOrdedDispose(address _market, bytes32 _signer) {
        OrderDisposed(_market, _signer);
        ordersBySigner[_signer]=0x0;
    }
    
    function addMarket(address _contract, uint _decimals) payable {
        market[_contract]=true;
        MarketAdded(_contract, _decimals);
    }
    
    function() {
        throw;
    }
}