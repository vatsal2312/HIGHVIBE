// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.11;

import "./VIBESToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract VIBESStaking is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    VIBESToken private VIBES;
    VIBESToken private SVIBES;
    

    constructor(address vibesContract, address svibesContract, uint256 initialRate) {
        require(vibesContract != address(0x0), "ERC20: VIBES contract not identified");
        require(svibesContract != address(0x0), "ERC20: SVIBES contract not identified");
        require(interestRate > 0, "Interest rate should be bigger than 0!");

        VIBES = VIBESToken(vibesContract);
        SVIBES = VIBESToken(svibesContract);
        changeInterestRate(initialRate);

        stakeholders.push();
    }

    receive() external payable {}

    fallback() external payable {}


    function stake(uint256 amount) public nonReentrant returns (bool){
        require(VIBES.balanceOf(msg.sender) >= amount * 10 ** 18, "Not enough balance!");

        _stake(amount * 10 ** 18);
        VIBES.transferFrom(msg.sender, address(this), amount * 10 ** 18);
        mintSVIBES(msg.sender, amount * 10 ** 18);
        return true;
    }

    function unstakeSelected(uint256 index) public nonReentrant returns (bool){
        burnSVIBES(msg.sender, _getSelectedStakeAmount(msg.sender, index));
        uint256 amount_to_mint = _withdrawSelectedStake(index);
        VIBES.transfer(msg.sender, amount_to_mint);
        return true;
    }

    function unstakeAll() public nonReentrant returns (bool){
        burnSVIBES(msg.sender, _getAllStakeAmount(msg.sender));
        uint256 amount_to_mint = _withdrawAllStakes();
        VIBES.transfer(msg.sender, amount_to_mint);
        return true;
    }

    function reStakeSelected(uint256 index) public nonReentrant returns (bool){
        _reStakeSelected(index);
        return true;
    }

    function reStakeAll() public nonReentrant returns (bool){
        _reStakeAll();
        return true;
    }
    
    function totalStaked(address _staker) public view returns (uint256){
        uint256 totalStakedAmount = _getAllStakeAmount(_staker);
        return totalStakedAmount;
    }


    function claimSelectedReward(uint256 index) public nonReentrant returns (bool){
        uint256 amount_to_mint = _claimRewardbyIndex(index);
        VIBES.transfer(msg.sender, amount_to_mint);
        return true;
    }

    function claimAllRewards() public nonReentrant returns (bool){
        uint256 amount_to_mint = _claimRewards();
        VIBES.transfer(msg.sender, amount_to_mint);
        return true;
    }

    function distributeReward(address _staker) public nonReentrant onlyOwner returns (bool){
        uint256 amount_to_mint = _distributeReward(_staker);
        VIBES.transfer(msg.sender, amount_to_mint);
        return true;
    }

    function SVIBESMinted(address _staker) public view returns (uint256){        
        uint256 SVIBESAmount = SVIBES.balanceOf(_staker);
        return SVIBESAmount;
    }

    function hasRewards(address _staker) public view returns (uint256){
        uint256  amount = _hasRewards(_staker);
        return amount;
    }

    function hasStakes(address _staker) public view returns (StakingSummary memory){     
        StakingSummary memory summary = _hasStakes(_staker);
        return summary;
    }

      function getTime() internal view returns (uint256){
        return block.timestamp;
    }
    
    function isTimeUp(uint256 time) internal view returns (bool){
        return block.timestamp > time;
    }

    
    function changeInterestRate(uint256 _interestRate) public onlyOwner {
        interestRate = _interestRate;
    }
 
    struct Stake{
        address user;
        uint256 amount;
        uint256 since;
        uint256 claimable;
        uint256 stakeRate;
    }
    
    struct Stakeholder{
        address user;
        Stake[] address_stakes;
        
    }
    
     struct StakingSummary{
         uint256 total_amount;
         Stake[] stakes;
     }

    
    Stakeholder[] internal stakeholders;
   
    mapping(address => uint256) internal stakes;
    
     event Staked(address indexed user, uint256 amount, uint256 index, uint256 timestamp, uint256 rate);

  
    uint256 internal interestRate = 10;


    function _addStakeholder(address staker) internal returns (uint256){
        stakeholders.push();
        uint256 userIndex = stakeholders.length - 1;
        stakeholders[userIndex].user = staker;
        stakes[staker] = userIndex;
        return userIndex; 
    }

    function _stake(uint256 _amount) internal{
        require(_amount > 0, "Stake amount should be bigger than 0.");
        
        uint256 index = stakes[msg.sender];
        uint256 timestamp = block.timestamp;
        uint256 rate = interestRate;
        if(index == 0){
            index = _addStakeholder(msg.sender);
        }

        stakeholders[index].address_stakes.push(Stake(msg.sender, _amount, timestamp, 0, rate));
        emit Staked(msg.sender, _amount, index,timestamp,rate);
    }

  
    function calculateStakeReward(Stake memory _current_stake) internal view returns(uint256){
        uint256 periodCount = (block.timestamp.sub(_current_stake.since)) / 8 hours;
        uint256 compoundedStake;
        compoundedStake = compoundedStake.add(_current_stake.amount); 
        for (uint256 i=0; i< periodCount; i++) {
            uint256 reward = compoundedStake.mul(_current_stake.stakeRate);
            reward = reward.div(100);
            compoundedStake = compoundedStake.add(reward);
        }
          return compoundedStake.sub(_current_stake.amount);
      }

  
    function _withdrawSelectedStake(uint256 index) internal returns(uint256){
        uint256 amount;
        Stake memory current_stake = stakeholders[stakes[msg.sender]].address_stakes[index];

        uint256 reward = calculateStakeReward(current_stake);
        amount = current_stake.amount;
        delete stakeholders[stakes[msg.sender]].address_stakes[index];
        return amount.add(reward);
     }

    function _withdrawAllStakes() internal returns(uint256){
        uint256 totalStakeAmount; 
        StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[msg.sender]].address_stakes);
        for (uint256 s = 0; s < summary.stakes.length; s += 1){
           if(summary.stakes[s].stakeRate != 0){
                totalStakeAmount = totalStakeAmount.add(_withdrawSelectedStake(s)); 
            }
       }
        delete stakeholders[stakes[msg.sender]].address_stakes;
        return totalStakeAmount;
    }

    function _reStakeSelected(uint256 index) internal returns(uint256){
        uint256 reStake = _withdrawSelectedStake(index);
        _stake(reStake);
        return reStake;
    }

    function _reStakeAll() internal returns(uint256){
        uint256 reStake = _withdrawAllStakes();
        _stake(reStake);
        return reStake;
    }

    function _claimRewardbyIndex(uint256 index) internal returns(uint256){
        Stake memory current_stake = stakeholders[stakes[msg.sender]].address_stakes[index];
        uint256 reward = calculateStakeReward(current_stake);
        stakeholders[stakes[msg.sender]].address_stakes[index].since = block.timestamp;
        stakeholders[stakes[msg.sender]].address_stakes[index].stakeRate = interestRate; 
        return reward;
    }
    
    function _claimRewards() internal returns(uint256){
        uint256 totalRewardAmount; 
        uint256 availableReward;
        StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[msg.sender]].address_stakes);
        for (uint256 s = 0; s < summary.stakes.length; s += 1){
           if(summary.stakes[s].stakeRate != 0){
                availableReward = calculateStakeReward(summary.stakes[s]);
                summary.stakes[s].claimable = 0;
                totalRewardAmount = totalRewardAmount.add(availableReward);
                stakeholders[stakes[msg.sender]].address_stakes[s].since = block.timestamp;
                stakeholders[stakes[msg.sender]].address_stakes[s].stakeRate = interestRate; 
            }
       }
        return totalRewardAmount;
    }

    function _distributeReward(address _staker) public onlyOwner returns(uint256){
        uint256 totalRewardAmount; 
        uint256 availableReward;
        StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[_staker]].address_stakes);
        for (uint256 s = 0; s < summary.stakes.length; s += 1){
           if(summary.stakes[s].stakeRate != 0){
                availableReward = calculateStakeReward(summary.stakes[s]);
                summary.stakes[s].claimable = 0;
                totalRewardAmount = totalRewardAmount.add(availableReward);
                stakeholders[stakes[msg.sender]].address_stakes[s].since = block.timestamp;
                stakeholders[stakes[msg.sender]].address_stakes[s].stakeRate = interestRate; 
            }
       }
        return totalRewardAmount;
    }

     function _hasRewards(address _staker) internal view returns(uint256){
        uint256 totalRewardAmount; 
        StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[_staker]].address_stakes);
        for (uint256 s = 0; s < summary.stakes.length; s += 1){
           if(summary.stakes[s].stakeRate != 0){
                uint256 availableReward = calculateStakeReward(summary.stakes[s]);
                summary.stakes[s].claimable = availableReward;
                totalRewardAmount = totalRewardAmount.add(summary.stakes[s].claimable);
            }
       }
        return totalRewardAmount;
    }

    function _hasStakes(address _staker) internal view returns(StakingSummary memory){
        uint256 totalStakeAmount; 
        StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[_staker]].address_stakes);
        for (uint256 s = 0; s < summary.stakes.length; s += 1){
            if(summary.stakes[s].stakeRate != 0){
                uint256 availableReward = calculateStakeReward(summary.stakes[s]);
                summary.stakes[s].claimable = availableReward;
                totalStakeAmount = totalStakeAmount.add(summary.stakes[s].amount);
            }
       }
       summary.total_amount = totalStakeAmount;
        return summary;
    }

    function _getSelectedStakeAmount(address _staker, uint256 index) internal view returns(uint256){
        Stake memory current_stake = stakeholders[stakes[_staker]].address_stakes[index];

        return current_stake.amount;
     }

    function _getAllStakeAmount(address _staker) internal view returns(uint256){
        uint256 totalStakeAmount; 
        StakingSummary memory summary = StakingSummary(0, stakeholders[stakes[_staker]].address_stakes);
        for (uint256 s = 0; s < summary.stakes.length; s += 1){
           if(summary.stakes[s].stakeRate != 0){
                totalStakeAmount = totalStakeAmount.add(summary.stakes[s].amount);
            }
       }
        return totalStakeAmount;
    }

    function mintSVIBES(address to, uint256 amount) internal {
        SVIBES.mint(to, amount);
    }
    function burnSVIBES(address from, uint256 amount) internal {
        SVIBES.burn(from, amount);
    }

}
 
   
   