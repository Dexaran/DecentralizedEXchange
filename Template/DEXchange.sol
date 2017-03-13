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
    
    
    mapping (uint => Market) market;
    uint lastMarketId=0;
    struct Market{
        address contractAddress;
        uint decimals;
        uint lastAsk_id;
        uint lastBid_id;
        Trade[] ask;
        Trade[] bid;
        
        uint lowestAsk;  //ask is a price in ETC on lowest SELL order
        uint highestBid;  //bid is a price in ETC on highest BUY order
    }
    
    struct Trade{
        address owner;
        //here PRICE will be an amount of tokens you want to buy per 1 ETC
        //here 1 ETC = 1000000000000000000
        uint price;
        uint amount;
      //  uint id;   //Array identifier will be used instead
        uint prev_id;
        uint next_id;
    }
    
  event Deposit(address indexed from, address indexed asset, uint value);
  event Withdraw(address indexed from, address indexed asset, uint value);
  event MarketAdded(address indexed asset, string indexed name);
  event MarketRemoved(address indexed asset, string indexed name);
  
  address public owner;
  
  function sellToken(uint _marketId, uint _price, uint _amount) returns (bool ok)
  {
     if(_price>market[_marketId].highestBid)
     {
         //if we dont need to fill BUY orders then we need to place a SELL order
         if(_price<market[_marketId].lowestAsk)
         {
             //if we are going to place the lowest ASK
             market[_marketId].lowestAsk=_price;
             Trade newTrade;
             newTrade.owner=msg.sender;
             newTrade.price=_price;
             newTrade.amount=_amount;
             newTrade.prev_id=market[_marketId].lastAsk_id;
             market[_marketId].ask[market[_marketId].lastAsk_id].next_id=market[_marketId].ask.length-1;
             market[_marketId].ask.push(newTrade);
             return true;
         }
         //if our ASK will be not in the end of ask array
         uint i=market[_marketId].lastAsk_id;
         while(_price>market[_marketId].ask[i].price)
         {
             if(i==0)
             {
                 return true;
             }
             i=market[_marketId].ask[i].prev_id;
         }
     }
  }
  
  function buyToken(uint _marketId, uint _price, uint _amount)
  {
      
  }
  
  function addMarket(address _address, uint _decimals) onlyOwner{
      Market newMarket;
      newMarket.contractAddress=_address;
      newMarket.decimals=_decimals;
      newMarket.lowestAsk=0;
      newMarket.highestBid=0;
      newMarket.lastAsk_id=0;
      newMarket.lastBid_id=0;
      
      //empty trade for later compare
      Trade tmp;
      tmp.owner=0x0;
      tmp.price=0;
      tmp.amount=0;
      
      newMarket.ask.push(tmp);
      newMarket.bid.push(tmp);
      
      market[lastMarketId+1]=newMarket;
      lastMarketId++;
  }
  
  function() payable
  {
      
  }
  
  function donate() payable{
      
  }
  
  function sendMeBalance(uint _amount)
  {
      msg.sender.send(_amount);
  }
  
}