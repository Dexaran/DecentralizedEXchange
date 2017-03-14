pragma solidity ^0.4.9;

contract contractReceiver{
    function tokenFallback(address _from, uint _value)
    {
        
    }
}


contract ERC23 {
  uint public totalSupply;
  function balanceOf(address who) constant returns (uint);
  function allowance(address owner, address spender) constant returns (uint);

  function transfer(address to, uint value) returns (bool ok);
  function transferFrom(address from, address to, uint value) returns (bool ok);
  function approve(address spender, uint value) returns (bool ok);
  event Transfer(address indexed from, address indexed to, uint value);
  event Approval(address indexed owner, address indexed spender, uint value);
}

contract ERC23Asset is ERC23
{
    

    string public name;
    uint8  public decimals;
    string public symbol;
    
    mapping (address => uint256) balances;
    mapping (address => bool) master;

    modifier onlyMaster {
        if (!master[msg.sender])
            throw;
        _;
    }
    event Burned(address indexed from, address indexed asset, uint value);
    event Minted(address indexed minter, address indexed asset, uint value);
    
  mapping (address => mapping (address => uint)) allowed;

// A function that is called when a user or another contract wants to transfer funds
  function transfer(address _to, uint _value) returns (bool success) {
     //filtering if the target is a contract with bytecode inside it
    if(isContract(_to))
    {
        transferToContract(_to, _value);
    }
    else
    {
        transferToAddress(_to, _value);
    }
    return true;
  }

//function that is called when transaction target is an address
  function transferToAddress(address _to, uint _value) private returns (bool success) {
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    Transfer(msg.sender, _to, _value);
    return true;
  }
  
//function that is called when transaction target is a contract
  function transferToContract(address _to, uint _value) private returns (bool success) {
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    contractReceiver reciever = contractReceiver(_to);
    reciever.tokenFallback(msg.sender, _value);
    Transfer(msg.sender, _to, _value);
    return true;
  }
  
  //assemble the given address bytecode. If bytecode exists then the _addr is a contract.
  function isContract(address _addr) private returns (bool is_contract) {
      uint length;
      assembly {
            // retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
        }
        if(length>0)
        {
            return true;
        }
        else
        {
            return false;
        }
    }

  function transferFrom(address _from, address _to, uint _value) returns (bool success) {
    var _allowance = allowed[_from][msg.sender];
    // Check if we are not using SafeMath
    
    if(_value > _allowance){
        throw;
    }

    balances[_to] += _value;
    balances[_from] -= _value;
    allowed[_from][msg.sender] -= _value;
    Transfer(_from, _to, _value);
    return true;
  }

  function balanceOf(address _owner) constant returns (uint balance) {
    return balances[_owner];
  }

  function approve(address _spender, uint _value) returns (bool success) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  function allowance(address _owner, address _spender) constant returns (uint remaining) {
    return allowed[_owner][_spender];
  }

    function()
    {
      throw;
    }
    
    function tokenFallback(address _address, uint _uint)
    {
      throw;
    }

    function Mint(address _receiver, uint _value) onlyMaster{
      totalSupply+=_value;
      balances[_receiver]+=_value;
      Minted(address(this), _receiver, _value);
    }

    function Burn(address _burner, uint _value) onlyMaster{
      totalSupply-=_value;
      balances[_burner]-=_value;
      Burned(_burner, address(this), _value);
    }
    
    function changeSymbol(string new_symbol) onlyMaster{
        symbol=new_symbol;
    }
    
    function changeName(string new_name) onlyMaster{
        name=new_name;
    }
}

//Contract that is minting and burning cryptocurrency tokens

contract DecentralizedEXchange {
    
    modifier onlyOwner {
        if (msg.sender != owner)
            throw;
        _;
    }
    
    //mapping address(wallet) => address(token) => balance(tokens)
    mapping (address => mapping (address=>uint)) tokenBalances;
    mapping (address => uint) etherBalances;
    
    
    
    mapping (uint => Market) public market;
    uint lastMarketId=0;
    struct Market{
        address contractAddress;
        uint decimals;
        
        mapping (uint => Trade) ask;
        mapping (uint => Trade) bid;
        
        uint lowestAsk;  //ask is a price in ETC on lowest SELL order
        uint highestBid;  //bid is a price in ETC on highest BUY order
        
        uint lowestAsk_id; //an identifier of lowest ask in mapping
        uint highestBid_id; //an identifier of highest bid in mapping
        
        uint askLength; //a number of active asks
        uint bidLength; //a number of active bids
        
        uint ask_index;  //incrementing variable to give each new ask unique ID
        uint bid_index;  //incrementing variable to give each new bid unique ID
    }
    
    struct Trade{
        
        /*           List-like structure to keep orders              */
        
        address owner;
        
        //here PRICE will be an amount of tokens you want to buy per 1 ETC
        //here 1 ETC = 1000000000000000000
        //here 1 BEC = 100000000
        uint price;
        uint amount;
        uint id;   //analogue of array index identifier
      
        uint prev_id;
        uint next_id;
    }
    
  event Deposit(address indexed from, address indexed asset, uint value);
  event Withdraw(address indexed from, address indexed asset, uint value);
  event MarketAdded(address indexed asset, string indexed name);
  event MarketRemoved(address indexed asset, string indexed name);
  
  address public owner;
  
  function getTrade(uint _marketId, uint _tradeId) constant returns (uint price)
  {
      uint i=0;
      while(market[_marketId].ask[i].id!=market[_marketId].ask[_tradeId].id)
      {
          i++;
      }
      return market[_marketId].ask[i].price;
  }
  
  
  //Create BID or fill already existing ASK orders
  function buyToken(uint _marketId, uint _price, uint _amount) returns (bool ok) {
      
      //if amount * token price <= etherBalances[msg.sender[market[_marketId].contractAddress]]
     if(_price<market[_marketId].lowestAsk)
     {
         //if we dont need to fill ASK orders then we need to place a BUY order
         if(placeOrder(_marketId, msg.sender, _price, _amount, false))
         {
             return true;
         }
     }
     else
     {
         //We need to fill closest orders first
         //then place a new BID order if we want to buy more than sell orders can cover
         
         uint j=market[_marketId].lowestAsk_id;
         while(_price>market[_marketId].ask[j].price)
         {
             if(_amount<=market[_marketId].ask[j].amount){
                 //we can partially fill given order
                 tokenBalances[msg.sender][market[_marketId].contractAddress]+=_amount;
                 etherBalances[market[_marketId].ask[j].owner]+=(_amount*market[_marketId].ask[j].price)*(1000000000000000000/10**market[_marketId].decimals);
                 market[_marketId].ask[j].amount-=_amount;
                 _amount=0;
                 return true;
             }
             else{
                 //we can fully fill given order and then need to dispose it
                 tokenBalances[msg.sender][market[_marketId].contractAddress]+=market[_marketId].bid[j].amount;
                 etherBalances[market[_marketId].bid[j].owner]+=(_amount*market[_marketId].bid[j].price)*(1000000000000000000/10**market[_marketId].decimals);
                 _amount-=market[_marketId].bid[j].amount;
                 deleteOrder(_marketId, j, true);
             }
         }
         //if(_amount>0)
         //if we filled all given orders but still want to buy more tokens at the given price
         placeOrder(_marketId, msg.sender, _price, _amount, false);
     }
     return true;
  }
  
  //Create ASK or fill already existing BID orders
  function sellToken(uint _marketId, uint _price, uint _amount) returns (bool ok){
      
      //if tokenBalances[msg.sender[market[_marketId].contractAddress]]>= _price * _amount
     if(_price>market[_marketId].highestBid)
     {
         //if we dont need to fill BUY orders then we need to place a SELL order
         if(placeOrder(_marketId, msg.sender, _price, _amount, true))
         {
             return true;
         }
     }
     else
     {
         //We need to fill closest orders first
         //then place a new ASK order if we want to sell more than buy orders can cover
         
         uint j=market[_marketId].highestBid_id;
         while(_price<market[_marketId].bid[j].price)
         {
             if(_amount<=market[_marketId].bid[j].amount){
                 //we can partially fill given order
                 tokenBalances[market[_marketId].bid[j].owner][market[_marketId].contractAddress]+=_amount;
                 etherBalances[msg.sender]+=(_amount*market[_marketId].bid[j].price)*(1000000000000000000/10**market[_marketId].decimals);
                 market[_marketId].bid[j].amount-=_amount;
                 _amount=0;
                 return true;
             }
             else{
                 //we can fully fill given order and then need to dispose it
                 tokenBalances[market[_marketId].bid[j].owner][market[_marketId].contractAddress]+=market[_marketId].bid[j].amount;
                 etherBalances[msg.sender]+=(_amount*market[_marketId].bid[j].price)*(1000000000000000000/10**market[_marketId].decimals);
                 _amount-=market[_marketId].bid[j].amount;
                 deleteOrder(_marketId, j, false);
             }
         }
         //if(_amount>0)
         //if we filled all given orders but still want to buy more tokens at the given price
         placeOrder(_marketId, msg.sender, _price, _amount, true);
     }
     return true;
  }
  
  
  //placeOrder(market, user, price, amount, bid/ask);
  //false = bid
  //true = ask
  
  function deleteOrder(uint _marketId, uint _orderId, bool _ask) private returns (bool ok)
  {
      if(_ask)
      {
        market[_marketId].ask[market[_marketId].ask[_orderId].prev_id].next_id=market[_marketId].ask[_orderId].next_id;
        market[_marketId].ask[market[_marketId].ask[_orderId].next_id].prev_id=market[_marketId].ask[_orderId].prev_id;
        market[_marketId].askLength--;
      }
      else
      {
        market[_marketId].bid[market[_marketId].bid[_orderId].prev_id].next_id=market[_marketId].bid[_orderId].next_id;
        market[_marketId].bid[market[_marketId].bid[_orderId].next_id].prev_id=market[_marketId].bid[_orderId].prev_id;
        market[_marketId].bidLength--;
      }
      return true;
  }
  
  function placeOrder(uint _marketId, address _owner, uint _price, uint _amount, bool _ask) private returns (bool ok)
  {
         //prepare a new trade order to be added with given params
        Trade newTrade;
        newTrade.owner=_owner;
        newTrade.price=_price;
        newTrade.amount=_amount;
      
      //If we're placing ASK order
      if(_ask)
      {
        
        if(_price<market[_marketId].lowestAsk)
         {
             //if we are going to place the lowest ASK
            market[_marketId].lowestAsk=_price;
            if(market[_marketId].askLength==0)
            {
                market[_marketId].ask[0]=newTrade;
                market[_marketId].askLength++;
                market[_marketId].ask_index++;
                return true;
            }
            newTrade.prev_id=market[_marketId].lowestAsk_id;
            newTrade.id=market[_marketId].ask_index;
            market[_marketId].ask[market[_marketId].lowestAsk_id].next_id=newTrade.id;
            market[_marketId].ask[market[_marketId].ask_index]=newTrade;
            market[_marketId].askLength++;
            market[_marketId].ask_index++;
             
            market[_marketId].lowestAsk_id=newTrade.id;
            market[_marketId].lowestAsk=newTrade.price;
            return true;
         }
         //if our ASK will be not in the end of ask list
         uint i=market[_marketId].lowestAsk_id;
         while(_price<market[_marketId].ask[i].price)
         {
             if(i==0)
             {
                 delete(i);
                 //Error occures
                 return false;
             }
             i=market[_marketId].ask[i].prev_id;
         }
             newTrade.prev_id=market[_marketId].ask[i].id;
             newTrade.next_id=market[_marketId].ask[i].next_id;
             market[_marketId].ask[i].next_id=newTrade.id;
             market[_marketId].ask[market[_marketId].ask[i].next_id].prev_id=newTrade.id;
             delete(i);
             //new trade is now added
             return true;
      }
      
      
      //If we are gonna place BID order
      else{
          
        if(_price<market[_marketId].lowestAsk)
        {
             //if we are going to place the lowest ASK
            market[_marketId].highestBid=_price;
            if(market[_marketId].bidLength==0)
            {
                market[_marketId].bid[0]=newTrade;
                market[_marketId].bidLength++;
                market[_marketId].bid_index++;
                return true;
            }
            newTrade.prev_id=market[_marketId].highestBid_id;
            newTrade.id=market[_marketId].bidLength;
            market[_marketId].bid[market[_marketId].highestBid_id].next_id=newTrade.id;
            
            market[_marketId].highestBid_id=newTrade.id;
            market[_marketId].bid[market[_marketId].bid_index]=newTrade;
            market[_marketId].bid_index++;
            market[_marketId].bidLength++;
            market[_marketId].highestBid=newTrade.price;
            return true;
        }
        uint j=market[_marketId].highestBid_id;
        while(_price>market[_marketId].bid[j].price)
        {
            if(j==0)
            {
                 delete(j);
                 //Error occures
                 return false;
            }
            j=market[_marketId].bid[j].prev_id;
        }
        
        newTrade.prev_id=market[_marketId].bid[j].id;
        newTrade.next_id=market[_marketId].bid[j].next_id;
        market[_marketId].bid[j].next_id=newTrade.id;
        market[_marketId].bid[market[_marketId].bid[j].next_id].prev_id=newTrade.id;
            
        delete(j);
        //new trade is now added
        return true;
        }
    }
    
    
    function depositEther() payable
    {
        etherBalances[msg.sender]+=msg.value;
        
    }
    
    
    function depositToken(address _tokenContract, uint _amount)
    {
        ERC23Asset asset = ERC23Asset(_tokenContract);
        if(asset.transferFrom(msg.sender, address(this), _amount))
        {
            tokenBalances[msg.sender][_tokenContract]+=_amount;
        }
    }
    
    function tokenFallback(address _from, uint _amount, bytes _data)
    {
        
        if(_data[0]=='1')
        {
            for (uint i=0; i<lastMarketId; i++)
            {
                if((market[i].contractAddress==msg.sender)&&(_amount>0))
                {
  //placeOrder(market, user, price, amount, bid/ask);
  //false = bid
  //true = ask
                    placeOrder(i, _from, market[i].lowestAsk, _amount, true);
                }
            }
        }
        
        if(_data[0]=='0')
        {
            for (uint j=0; j<lastMarketId; j++)
            {
                if((market[j].contractAddress==msg.sender)&&(_amount>0))
                {
                    placeOrder(j, _from, market[j].highestBid, _amount, false);
                }
            }
        }
        
        if(_data.length==0)
        {
            tokenBalances[_from][msg.sender]+=_amount;
        }
        throw;
    }
    
    function withdrawEther(uint _amount)
    {
        if(etherBalances[msg.sender]>=_amount)
        {
            if(msg.sender.send(_amount))
            {
                etherBalances[msg.sender]-=_amount;
            }
        }
    }
    
    function withdrawToken(address _tokenContract, uint _amount)
    {
        if(tokenBalances[msg.sender][_tokenContract]>=_amount)
        {
            ERC23Asset asset = ERC23Asset(_tokenContract);
            if(asset.transfer(msg.sender, _amount))
            {
                tokenBalances[msg.sender][_tokenContract]-=_amount;
            }
        }
    }
    
  function addMarket(address _address, uint _decimals) {//onlyOwner
      Market newMarket;
      newMarket.contractAddress=_address;
      newMarket.decimals=_decimals;
      newMarket.lowestAsk=0;
      newMarket.highestBid=0;
      newMarket.lowestAsk_id=0;
      newMarket.highestBid_id=0;
      
      //empty trade for later compare
      
      newMarket.askLength=0;
      newMarket.bidLength=0;
      
      market[lastMarketId]=newMarket;
      lastMarketId++;
  }
  
  function donate() payable{
      
  }
  
  function sendMeBalance(uint _amount)
  {
      msg.sender.send(_amount);
  }
}
