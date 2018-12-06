pragma solidity ^0.4.24;

import '../zeppelin/ownership/Ownable.sol';
import '../zeppelin/token/ERC20/ERC20.sol';
import '../zeppelin/token/ERC20/SafeERC20.sol';
import '../zeppelin/math/SafeMath.sol';
import './FundableJob.sol';

/**
 * @title Staking Pool contract
 */
contract StakingPool is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    struct StakerProperties {
        uint256 amount;                 //Amount of BOB staked (already distributed)
        uint256 bonus;                  //Amount of stake bonus
        uint256 lastDistributedReward;  //Number of reward which is already accounted for this staker
    }
    struct Reward {
        address job;
        uint256 amount;
        uint256 currentDistributedAmount;
        uint256 currentUndistributedAmount;
        uint256 currentTotalBonus;
    }

    ERC20 token;        //BOB contract address

    mapping(address => StakerProperties) public stakers;   //Mapping of staker address to properties
    Reward[] public rewards;                               //Array of Rewards for each Job completed

    uint256 totalDistributedAmount;     //How much BOB are accounted inside "amount" properties = total distributed stakes
    uint256 totalUndistributedAmount;   //How much BOB are not distributed yet
    uint256 totalBonus;         //How much bonuses are granted
    uint256 public totalLoans;  //How much BOB is loaned


    address public manager;
    uint16 constant public PERCENT_DIVIDER = 10000; // pecent_value = some_value * percent / PERCENT_DIVIDER. Using 10000 to allow prercent less then 1, up to 0.01%
    uint16 public rewardPercent;                    // See PERCENT_DIVIDER

    modifier onlyManager(){
        require(msg.sender == manager);
        _;
    }
    modifier onlyOwnerOrManager(){
        require(msg.sender == owner || msg.sender == manager);
        _;
    }

    constructor(ERC20 _token) public {
        token = _token;
        manager = owner;
    }

    function lastReward() view public returns(uint256){
        return rewards.length - 1;
    }

    function setManager(address _manager) onlyOwner external {
        manager = _manager;
    }
    function setRewardPercent(uint16 _percent) onlyOwner external {
        rewardPercent = _percent;
    }

    /**
     * @notice Put BOB to staking pool
     * @dev Approvement for this contract to spend amount BOB is required.
     * @param amount How much BOB to put
     */
    function addStake(uint256 amount) external {
        addStakeFrom(msg.sender, amount);
    }
    /**
     * @notice Put BOB to staking pool
     * @dev Approvement for this contract to spend amount BOB is required.
     * @param from Who is staking his BOBs
     * @param amount How much BOB to put
     */
    function addStakeFrom(address from, uint256 amount) internal {
        token.safeTransferFrom(from, address(this), amount);
        StakerProperties storage sp = stakers[from];
        if(sp.amount == 0){         //Nothing is staked yet
            sp.amount = amount;
            sp.bonus = 0;
            sp.lastDistributedReward = lastReward();
            totalDistributedAmount = totalDistributedAmount.add(amount);
        }else{                      //Something is already staked
            // TODO Handle this somehow
            revert();
        }
    }
    function setBonus(address staker, uint256 bonus) onlyOwnerOrManager external {
        StakerProperties storage sp = stakers[staker];
        if(sp.bonus != bonus){
            totalBonus = totalBonus.sub(sp.bonus).add(bonus);
            sp.bonus = bonus;
        }
    }

    /**
     * @notice Take BOB from staking pool
     */
    function claimStake(uint256 amount) external {
        distributeRewards(msg.sender);
        StakerProperties storage sp = stakers[msg.sender];
        require(amount <= sp.amount);
        sp.amount = sp.amount.sub(amount);
        token.safeTransfer(msg.sender, amount);
    }


    function distributeRewards(address staker) public {
        StakerProperties storage sp = stakers[staker];
        assert(sp.lastDistributedReward <= lastReward());
        for(uint256 r = sp.lastDistributedReward; r < rewards.length; r++){  // TODO Handle to much rewards undistributed and reach block gas limit
            Reward storage rw = rewards[r];
            uint256 stakerPoints = sp.amount.add(sp.bonus);
            uint256 totalPoints = rw.currentDistributedAmount.add(rw.currentTotalBonus).add(rw.currentUndistributedAmount);
            uint256 stakerReward = rw.amount.mul(stakerPoints).div(totalPoints);

            sp.amount = sp.amount.add(stakerReward);
            sp.lastDistributedReward = lastReward();
            totalUndistributedAmount = totalUndistributedAmount.sub(stakerReward);
        }
    }


    /**
     * @notice Fund a job
     */
    function fundJob(FundableJob job, uint16 milestone, uint16 proposal) onlyManager external {
        //TODO Modify workflow to charge Staker fee after job is complete
        uint256 proposalAmount = job.getProposalAmount(milestone, proposal);
        uint256 reward = percent(proposalAmount, rewardPercent);

        token.safeTransferFrom(msg.sender, address(this), reward);
        totalUndistributedAmount = totalUndistributedAmount.add(reward);
        rewards.push(Reward({
            job: job,
            amount: reward,
            currentDistributedAmount: totalDistributedAmount,
            currentUndistributedAmount: totalUndistributedAmount,
            currentTotalBonus: totalBonus
        }));

        token.approve(job, proposalAmount);
        job.confirmProposalAndFetchFunds(milestone, proposal);
        totalLoans = totalLoans.add(proposalAmount);
    }

    /**
     * @notice Claims funds from complete milestone back to the pool
     */
    function claimLoanedFunds(uint256 amount) public returns(bool){
        //TODO somehow check correctness of amount
        token.safeTransferFrom(msg.sender, address(this), amount);
        totalLoans = totalLoans.sub(amount);
    }
    function claimLoanedFunds(FundableJob job, uint256 amount) onlyManager external returns(bool){
        //TODO somehow check correctness of amount
        token.safeTransferFrom(job, address(this), amount);
        totalLoans = totalLoans.sub(amount);
    }

    function getPoolRewardForAmount(uint256 amount) view public returns(uint256){
        return percent(amount, rewardPercent);
    }

    function percent(uint256 value, uint16 _percent) pure internal returns(uint256){
        return value.mul(_percent).div(PERCENT_DIVIDER);
    }
}