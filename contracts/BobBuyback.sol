pragma solidity ^0.4.24;

import "./zeppelin/token/ERC20/ERC20.sol";
import './zeppelin/math/Math.sol';
import './zeppelin/math/SafeMath.sol';
import './zeppelin/ownership/Claimable.sol';        //Allows to safely transfer ownership
import './zeppelin/ownership/HasNoContracts.sol';   //Allows contracts accidentially sent to this contract
import './zeppelin/ownership/CanReclaimToken.sol';  //Allows to reclaim tokens accidentially sent to this contract
import './zeppelin/lifecycle/Destructible.sol';     //Allows to destroy this contract then not needed any more

/**
 * Automated buy back BOB tokens
 */
contract BobBuyback is Claimable, HasNoContracts, CanReclaimToken, Destructible {
    using SafeMath for uint256;    

    struct Deposit {
        uint256 amount;                 // Amount deposited (and not whitdrawn yet)
        uint64  timestamp;              // Timestamp of deposit tx
    }
    struct Holder {
        Deposit[] deposits;             // List of deposits
        uint256 lastProcessedRound;     // Last buyback round which is counted for this holder
        uint256 amount;                 // Sum of all deposits amounts
        uint256 weightSubstract;        // holderWeight = amount*now - weightSubstract. Calculated as deposits[0].amount*deposits[0].timestamp + deposits[1].amount*deposits[1].timestamp ...
    }
    struct BuybackRound {
        uint64  timestamp;              // Timestamp of this round
        uint256 ethAmount;              // How many ETH were sold during this round
        uint256 price;                  // Price of current buyback round. 1 ETH = price BOB
        uint256 totalWeight;            // Total weight of deposits during this round
        uint256 tokenWeight;            // Weight of 1 BOB wei during this round. If Holder weight is 1000 and tokenWeight = 10, we are buying 100 BOB weis from this holder
    }

    ERC20 public token;                         // Address of BOB token contract
    mapping(address => Holder) public holders;  // Map of holders
    address[] public holdersList;               // List of holders used to iterate map
    BuybackRound[] public buybacks;

    uint64 public nextBuybackTimestamp = 0;
    uint256 public boughtTokens;                // How many BOB tokens is bought by buyback program since last claim by contract's owner
    uint256 public soldEth;                     // How many ETH was sold to token holders

    modifier buybackNotScheduled() {
        require(nextBuybackTimestamp == 0);
        _;
    }


    constructor(ERC20 _token) public {
        token = _token;
    }


    /**
     * @notice Deposit tokens
     * @param _amount How much tokens wil be deposited
     */
    function deposit(uint256 _amount) buybackNotScheduled external {
        require(token.transferFrom(msg.sender, address(this), _amount), "Failed to transfer tokens");
        if(!isHolder(msg.sender)){
            holders[msg.sender].priceLimit = DEFAULT_PRICE_LIMIT;
        }
        holders[msg.sender].deposits.push(Deposit({amount: _amount, timestamp: uint64(now)}));
    }

    /**
     * @notice Whitdraw tokens
     * @param _amount How much tokens wil be whidrawn
     */
    function whitdraw(uint256 _amount) buybackNotScheduled external {
        require(isHolder(msg.sender), "Unregistered holder can not whitdraw");
        uint256 cd = currentDeposit(msg.sender);
        require(_amount <= cd, "Not enough tokens deposited");
        decreaseDeposit(msg.sender, _amount);
        uint256 newDeposit = currentDeposit(msg.sender);
        assert(cd.sub(_amount) == newDeposit);
        require(token.transfer(msg.sender, _amount), "Failed to transfer tokens");
    }
    /**
     * @notice Decreases deposit (for whidrawals and buybacks)
     * @param beneficiary Whos deposit we are decreasing
     * @param _amount How much tokens will be decreased
     */
    function decreaseDeposit(address beneficiary, uint256 _amount) internal {
        Holder storage h = holders[beneficiary];
        uint256 decreased = 0;
        for(uint256 i = h.deposits.length -1; i >=0; i--){
            if(_amount < decreased + h.deposits[i].amount){
                //This is the last deposit we are decreasing and something will be left on it
                h.deposits[i].amount -= _amount - decreased;
                return;
            }else{
                //Remove this deposit from the list
                decreased += h.deposits[i].amount;
                h.deposits.length -= 1;
                if(decreased == _amount) return;
            }
        }
        assert(false); //we should never reach this point
    }

    function calculateHolderProperties(address ha) view public(uint256 deposit, uint256 weightSubstract) {
        if(!isHolder(beneficiary)) return 0;
        Holder storage h = holders[ha];
        uint256 deposit = 0;
        uint256 weightSubstract = 0;
        for(uint256 i=0; i < h.deposits.length; i++){
            deposit += h.deposits[i].amount;  //Do not use SafeMath here because we are counting token amounts and results should always be less then token.totalSupply()
            weightSubstract += h.deposits[i].amount * h.deposits[i].timestamp;  //TODO: Think moe about (not) possible owerflow
        }
        return (deposit, weightSubstract);

    }



    function scheduleBuyback(uint64 _nextBuybackTimestamp) onlyOwner external {
        nextBuybackTimestamp = _nextBuybackTimestamp;
    }

    /**
     * @notice Claim bought tokens
     */
    function claimBoughtTokens() onlyOwner external {
        require(token.transfer(owner, boughtTokens));
        boughtTokens = 0;
    }

    /**
     * @notice Transfer all Ether held by the contract to the owner.
     * Can be used only in emergency
     */
    function reclaimEther() onlyOwner external {
        owner.transfer(address(this).balance);
    }

    function isHolder(address beneficiary) view internal returns(bool){
        return holders[beneficiary].deposits.length > 0;
    }

    function arrayIsAscSorted(uint256[] arr) pure internal returns(bool){
        require(arr.length > 0);
        for(uint256 i=0; i < arr.length-1; i++) {
            if(arr[i] > arr[i+1]) return false;
        }
        return true;
    }

}