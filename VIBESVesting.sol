// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract VIBESVesting is Ownable, ReentrancyGuard{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    struct VestingSchedule{
        bool initialized;
        address  beneficiary;
        uint256  start;
        uint256  duration;
        uint256 amountTotal;
        uint256  released;
        bool revoked;
    }

    IERC20 immutable private _token;

    bytes32[] private vestingSchedulesIds;
    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    uint256 private vestingSchedulesTotalAmount;
    mapping(address => uint256) private holdersVestingCount;

    event Released(uint256 amount);
    event Revoked();

    
    modifier onlyIfVestingScheduleExists(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true);
        _;
    }

    modifier onlyIfVestingScheduleNotRevoked(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true);
        require(vestingSchedules[vestingScheduleId].revoked == false);
        _;
    }

    constructor(address vibesContract) {
        require(vibesContract != address(0x0));
        _token = IERC20(vibesContract);
    }

    receive() external payable {}

    fallback() external payable {}

   
    function getVestingSchedulesCountByBeneficiary(address _beneficiary)
    external
    view
    returns(uint256){
        return holdersVestingCount[_beneficiary];
    }

    
    function getVestingIdAtIndex(uint256 index)
    external
    view
    returns(bytes32){
        require(index < getVestingSchedulesCount(), "exceeded the count of schedules");
        return vestingSchedulesIds[index];
    }

  
    function getVestingScheduleByAddressAndIndex(address holder, uint256 index)
    external
    view
    returns(VestingSchedule memory){
        return getVestingSchedule(computeVestingScheduleIdForAddressAndIndex(holder, index));
    }


    function getVestingSchedulesTotalAmount()
    external
    view
    returns(uint256){
        return vestingSchedulesTotalAmount;
    }

    function getToken()
    external
    view
    returns(address){
        return address(_token);
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _duration,
        uint256 _amount
    )
        public
        onlyOwner{
        require(
            this.getWithdrawableAmount() >= _amount,
            "Insufficient tokens!"
        );
        require(_duration > 0, "Duration must be > 0");
        require(_amount > 0, "Amount must be > 0");
        bytes32 vestingScheduleId = this.computeNextVestingScheduleIdForHolder(_beneficiary);
        vestingSchedules[vestingScheduleId] = VestingSchedule(
            true,
            _beneficiary,
            _start,
            _duration,
            _amount,
            0,
            false
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.add(_amount);
        vestingSchedulesIds.push(vestingScheduleId);
        uint256 currentVestingCount = holdersVestingCount[_beneficiary];
        holdersVestingCount[_beneficiary] = currentVestingCount.add(1);
    }

    function revoke(bytes32 vestingScheduleId)
        public
        onlyOwner
        onlyIfVestingScheduleNotRevoked(vestingScheduleId){
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        uint256 unreleased = vestingSchedule.amountTotal.sub(vestingSchedule.released);
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(unreleased);
        vestingSchedule.revoked = true;
    }

  
    function withdraw(uint256 amount)
        public
        nonReentrant
        onlyOwner{
        require(this.getWithdrawableAmount() >= amount, "Not enough withdrawable funds");
        _token.safeTransfer(owner(), amount);
    }

  
    function release(bytes32 vestingScheduleId)
        public
        nonReentrant
        onlyIfVestingScheduleNotRevoked(vestingScheduleId){
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        bool isBeneficiary = msg.sender == vestingSchedule.beneficiary;
        bool isOwner = msg.sender == owner();
        require(
            isBeneficiary || isOwner,
            "Only beneficiary and owner can release vested tokens"
        );
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        require(vestedAmount > 0, "Cannot release tokens, time is not up or not enough token.");
        vestingSchedule.released = vestingSchedule.released.add(vestedAmount);
        address payable beneficiaryPayable = payable(vestingSchedule.beneficiary);
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(vestedAmount);
        _token.safeTransfer(beneficiaryPayable, vestedAmount);
    }

    function getVestingSchedulesCount()
        public
        view
        returns(uint256){
        return vestingSchedulesIds.length;
    }


    function getVestingSchedule(bytes32 vestingScheduleId)
        public
        view
        returns(VestingSchedule memory){
        return vestingSchedules[vestingScheduleId];
    }

    function getWithdrawableAmount()
        public
        view
        returns(uint256){
        return _token.balanceOf(address(this)).sub(vestingSchedulesTotalAmount);
    }

    function computeNextVestingScheduleIdForHolder(address holder)
        public
        view
        returns(bytes32){
        return computeVestingScheduleIdForAddressAndIndex(holder, holdersVestingCount[holder]);
    }

    function getLastVestingScheduleForHolder(address holder)
        public
        view
        returns(VestingSchedule memory){
        return vestingSchedules[computeVestingScheduleIdForAddressAndIndex(holder, holdersVestingCount[holder] - 1)];
    }

    function computeVestingScheduleIdForAddressAndIndex(address holder, uint256 index)
        public
        pure
        returns(bytes32){
        return keccak256(abi.encodePacked(holder, index));
    }

    function _computeReleasableAmount(VestingSchedule memory vestingSchedule)
    internal
    view
    returns(uint256){
        uint256 currentTime = getCurrentTime();
        if (vestingSchedule.revoked == true) {
            return 0;
        } else if (currentTime >= vestingSchedule.start.add(vestingSchedule.duration)) {
            return vestingSchedule.amountTotal;
        }else{
            return 0;
        }
    }

    function getCurrentTime()
        internal
        virtual
        view
        returns(uint256){
        return block.timestamp;
    }

}