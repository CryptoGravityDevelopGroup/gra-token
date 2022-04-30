// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TimeVesting {
    using SafeMath for uint256;
    using SafeMath for uint16;

    constructor(ERC20 _token) {
        require(address(_token) != address(0));
        owner = msg.sender;
        token = _token;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyValidAddress(address _recipient) {
        require(_recipient != address(0) && _recipient != address(this) && _recipient != address(token), "not valid _recipient");
        _;
    }

    uint256 constant internal SECONDS_PER_DAY = 86400;

    // 授予锁仓记录
    struct Grant {
        uint256 startTime; // 锁仓开始时间
        uint256 amount; // 锁仓总额度
        uint16 vestingDuration; // 归属期限
        uint16 vestingCliff; // 锁仓开始解禁时间
        uint16 daysClaimed; // 持有Token天数
        uint256 totalClaimed; // 已经解锁的token
        address recipient; // 授予人
    }

    event GrantAdded(address indexed recipient, uint256 vestingId);
    event GrantTokensClaimed(address indexed recipient, uint256 amountClaimed);
    event GrantRemoved(address recipient, uint256 amountVested, uint256 amountNotVested);
    event ChangedOwner(address owner);

    ERC20 public token;

    mapping(uint256 => Grant) public tokenGrants;
    mapping(address => uint[]) private activeGrants;
    address public owner;
    uint256 public totalVestingCount;

    function addTokenGrant(
        address _recipient,
        uint256 _startTime,
        uint256 _amount,
        uint16 _vestingDurationInDays,
        uint16 _vestingCliffInDays
    )
    external
    onlyOwner
    {
        require(_vestingCliffInDays <= 10 * 365, "more than 10 years");
        require(_vestingDurationInDays <= 25 * 365, "more than 25 years");
        require(_vestingDurationInDays >= _vestingCliffInDays, "Duration < Cliff");

        uint256 amountVestedPerDay = _amount.div(_vestingDurationInDays);
        require(amountVestedPerDay > 0, "amountVestedPerDay > 0");

        // Transfer the grant tokens under the control of the vesting contract
        // 将token从owner地址转移到锁仓单地址
        require(token.transferFrom(owner, address(this), _amount), "transfer failed");

        Grant memory grant = Grant({
        startTime : _startTime == 0 ? currentTime() : _startTime,
        amount : _amount,
        vestingDuration : _vestingDurationInDays,
        vestingCliff : _vestingCliffInDays,
        daysClaimed : 0,
        totalClaimed : 0,
        recipient : _recipient
        });
        tokenGrants[totalVestingCount] = grant;
        activeGrants[_recipient].push(totalVestingCount);
        emit GrantAdded(_recipient, totalVestingCount);
        totalVestingCount++;
    }

    function getActiveGrants(address _recipient) public view returns (uint256[] memory){
        return activeGrants[_recipient];
    }

    /// @notice Calculate the vested and unclaimed months and tokens available for `_grantId` to claim
    /// Due to rounding errors once grant duration is reached, returns the entire left grant amount
    /// Returns (0, 0) if cliff has not been reached
    /// @notice 计算“授予ID”未释放的锁仓token数量和剩余的锁仓日
    /// 一旦达到授权期限，返回整个剩余仓token数量
    /// 返回 (0, 0) 如果cliff日未到
    function calculateGrantClaim(uint256 _grantId) public view returns (uint16, uint256) {
        // 锁仓记录
        Grant storage tokenGrant = tokenGrants[_grantId];

        // For grants created with a future start date, that hasn't been reached, return 0, 0
        // 授予锁仓开始时间大于当前时间，不能取出
        if (currentTime() < tokenGrant.startTime) {
            return (0, 0);
        }

        // Check cliff was reached
        // 剩余时间 = 当前时间戳 - 锁仓开始时间
        uint elapsedTime = currentTime().sub(tokenGrant.startTime);
        // 剩余天数 = 剩余秒数 / 86400 秒
        uint elapsedDays = elapsedTime.div(SECONDS_PER_DAY);

        // 如果剩余天数 < 赠与的cliff日期，返回 (剩余天数, 0个token)
        if (elapsedDays < tokenGrant.vestingCliff) {
            return (uint16(elapsedDays), 0);
        }

        // If over vesting duration, all tokens vested
        // 如果超过归属期限，所有的token都归属
        if (elapsedDays >= tokenGrant.vestingDuration) {
            // 剩余的所有token
            uint256 remainingGrant = tokenGrant.amount.sub(tokenGrant.totalClaimed);
            return (tokenGrant.vestingDuration, remainingGrant);
        } else {
            uint16 daysVested = uint16(elapsedDays.sub(tokenGrant.daysClaimed));
            uint256 amountVestedPerDay = tokenGrant.amount.div(uint256(tokenGrant.vestingDuration));
            uint256 amountVested = uint256(daysVested.mul(amountVestedPerDay));
            return (daysVested, amountVested);
        }
    }

    /// @notice Allows a grant recipient to claim their vested tokens. Errors if no tokens have vested
    /// It is advised recipients check they are entitled to claim via `calculateGrantClaim` before calling this
    /// @notice 允许从授予ID中释放一笔锁仓token，如果无token可释放则报错
    /// 建议被授予人调用前通过“calculateGrantClaim”函数检查他们是否有权解锁token
    function claimVestedTokens(uint256 _grantId) external {
        uint16 daysVested;
        uint256 amountVested;
        (daysVested, amountVested) = calculateGrantClaim(_grantId);
        // 已无token可获取
        require(amountVested > 0, "amountVested is 0");

        Grant storage tokenGrant = tokenGrants[_grantId];
        tokenGrant.daysClaimed = uint16(tokenGrant.daysClaimed.add(daysVested));
        tokenGrant.totalClaimed = uint256(tokenGrant.totalClaimed.add(amountVested));

        require(token.transfer(tokenGrant.recipient, amountVested), "no tokens");
        emit GrantTokensClaimed(tokenGrant.recipient, amountVested);
    }

    /// @notice Terminate token grant transferring all vested tokens to the `_grantId`
    /// and returning all non-vested tokens to the owner
    /// Secured to the owner only
    /// @param _grantId grantId of the token grant recipient
    /// @notice 终止该Token锁仓单即转移所有释放的token到锁仓单中允许提现，转移锁仓中的token到owner
    /// 只有Owner可以进行操作
    function removeTokenGrant(uint256 _grantId)
    external
    onlyOwner
    {
        Grant storage tokenGrant = tokenGrants[_grantId];
        address recipient = tokenGrant.recipient;
        uint16 daysVested;
        uint256 amountVested;
        (daysVested, amountVested) = calculateGrantClaim(_grantId);

        uint256 amountNotVested = (tokenGrant.amount.sub(tokenGrant.totalClaimed)).sub(amountVested);

        require(token.transfer(recipient, amountVested));
        require(token.transfer(owner, amountNotVested));

        tokenGrant.startTime = 0;
        tokenGrant.amount = 0;
        tokenGrant.vestingDuration = 0;
        tokenGrant.vestingCliff = 0;
        tokenGrant.daysClaimed = 0;
        tokenGrant.totalClaimed = 0;
        tokenGrant.recipient = address(0);

        emit GrantRemoved(recipient, amountVested, amountNotVested);
    }

    function currentTime() private view returns (uint256) {
        return block.timestamp;
    }

    // 每天释放的锁仓Token数量 = 锁仓单数量 / 归属期限
    function tokensVestedPerDay(uint256 _grantId) public view returns (uint256) {
        Grant storage tokenGrant = tokenGrants[_grantId];
        return tokenGrant.amount.div(uint256(tokenGrant.vestingDuration));
    }

    function changeOwner(address _newOwner)
    external
    onlyOwner
    onlyValidAddress(_newOwner)
    {
        owner = _newOwner;
        emit ChangedOwner(_newOwner);
    }

}