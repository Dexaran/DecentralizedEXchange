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
    uint etherBalance=0;
    
    function Bid(address _master, address _market, bytes32 _id, uint256 _price, address _owner) {
        master=_master;
        market=_market;
        id=_id;
        price=_price;
        owner=_owner;
    }
    
    function() payable {
        //Trade is triggered when token is deposited
        if(msg.sender==master) {
            etherBalance += msg.value;
        }
        
        else {
            if(msg.sender == owner) {
                etherBalance += msg.value;
                orderUpdate();
            }
            throw;
        }
    }
    
    
    function tokenFallback(address _from, uint _value, bytes _data) tokenPayable returns (bool result) {
        ERC23 asset = ERC23(market);
        if((_value * price) > etherBalance) {
            if(_from.send(etherBalance) && asset.transfer(owner, etherBalance/price) && asset.transfer(_from, _value - (etherBalance/price))) {
                orderDispose();
            }
            return true;
        }
        else {
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
        /*ERC23 asset = ERC23(market);
        if(asset.balanceOf(address(this))>0) {
            asset.transfer(owner, asset.balanceOf(address(this)));
        }
        DEXchange exchange = DEXchange(master);
        exchange.onOrdedDispose(market, id);
        */
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
    
    function Ask(address _master, address _market, bytes32 _id, uint256 _price, address _owner) {
        master=_master;
        owner=_owner;
        market=_market;
        id=_id;
        price=_price;
    }
    
    function() payable {
        //Trade is triggered when Ether is deposited
        if(msg.sender == master) {
            throw;
        }
        else {
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
    }
    
    
    function tokenFallback(address _from, uint _value, bytes _data) tokenPayable returns (bool result) {
        if(_from == owner) {
            tokenBalance += _value;
            orderUpdate();
            return true;
        }
        else if(_from == master) {
            tokenBalance += _value;
            return true;
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
  function balanceOf(address who) constant returns (uint);
  function transfer(address to, uint value) returns (bool ok);
}
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
    uint256 public orderplaceGas=100000; //specified amount of gas for order placement
    
    
    //A function that will help you to find your orders.
    function whatTheHash(address _market, address _owner, uint _price, bool _ask) constant returns (bytes32) {
        return sha256(_market, _owner, _price, _ask);
    }
    
    function tokenFallback(address _from, uint _value, bytes _data) returns (bool result) {
        if((_data.length!=0) && (market[msg.sender])) {
            uint _price = parseSingleUintArg(_data);
            bytes32 signer = sha256(msg.sender, _from, _price, true);
            if(ordersBySigner[signer]==0x0) {
                createNewAsk(msg.sender, signer, _price, _from, _value);
            }
            else {
                updateAsk(signer, _value, msg.sender);
            }
            return true;
        }
        
        //throw transactions with no _price specified on data
        throw;
    }
    
    function placeBid(uint _price, address _market) payable {
        if(market[_market]) {
            bytes32 signer = sha256(_market, msg.sender, _price, false);
            if(ordersBySigner[signer]==0x0) {
                createNewBid(_market, signer, _price, msg.sender, msg.value);
            }
            else {
                updateBid(signer, msg.value, _market);
            }
        }
    }
    
    function createNewAsk(address _market, bytes32 _signer, uint _price, address _owner, uint _amount) {
        address newAsk = new Ask(address(this), _market, _signer, _price, _owner);
        ordersBySigner[_signer]=newAsk;
        ERC23 asset = ERC23(_market);
        if(asset.transfer(ordersBySigner[_signer], _amount)) {
            OrderPlaced(_market, _signer);
        }
        else {
            throw;
        }
    }
    
    function updateAsk(bytes32 _signer, uint _amount, address _market) private {
        ERC23 asset = ERC23(_market);
        if(asset.transfer(ordersBySigner[_signer], _amount)) {
            OrderUpdated(_market, _signer);
        }
        else {
            throw;
        }
    }
    
    function createNewBid(address _market, bytes32 _signer, uint _price, address _owner, uint _amount) private {
        address newBid = new Bid(address(this), _market, _signer, _price, _owner);
        ordersBySigner[_signer] = newBid;
        if(ordersBySigner[_signer].call.gas(orderplaceGas).value(_amount)()) {
            OrderPlaced(_market, _signer);
        }
        else {
            throw;
        }
    }
    
    function updateBid(bytes32 _signer, uint _amount, address _market) private {
        if(ordersBySigner[_signer].call.gas(orderplaceGas).value(_amount)()) {
            OrderUpdated(_market, _signer);
        }
        else {
            throw;
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
        //for later use market adding will not be free
        market[_contract]=true;
        MarketAdded(_contract, _decimals);
    }
    
    function() {
        throw;
    }
}
