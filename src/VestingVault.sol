// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VestingVault is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    struct Vesting {
        uint256 total;
        uint256 claimed;
        uint256 start;
        uint256 cliff;
        uint256 duration;
    }

    mapping(address => Vesting) public vestings;
    uint256 public totalAllocated;

    event VestingAdded(address indexed user, uint256 total, uint256 start, uint256 cliff, uint256 duration);
    event Claimed(address indexed user, uint256 amount);

    constructor(address _token, address _owner) Ownable(_owner) {
        require(_token != address(0), "Zero token address");
        token = IERC20(_token);
    }

    function addVesting(
        address _user,
        uint256 _total,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration
    ) external onlyOwner {
        require(vestings[_user].total == 0, "Vesting already exists");
        require(_total > 0, "Amount must be > 0");
        require(_duration > 0, "Duration must be > 0");
        require(_cliff >= _start, "Cliff before start");

        vestings[_user] = Vesting({
            total: _total,
            claimed: 0,
            start: _start,
            cliff: _cliff,
            duration: _duration
        });

        totalAllocated += _total;
        require(
            token.balanceOf(address(this)) >= totalAllocated,
            "Insufficient token balance in vault"
        );

        emit VestingAdded(_user, _total, _start, _cliff, _duration);
    }

    function claim() external nonReentrant {
        Vesting storage v = vestings[msg.sender];
        require(v.total > 0, "No vesting");

        uint256 vested = _vestedAmount(v);
        uint256 amount = vested - v.claimed;
        require(amount > 0, "Nothing to claim");

        v.claimed += amount;
        token.safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }

    function vestedAmount(address _user) external view returns (uint256) {
        return _vestedAmount(vestings[_user]);
    }

    function claimable(address _user) external view returns (uint256) {
        Vesting storage v = vestings[_user];
        return _vestedAmount(v) - v.claimed;
    }

    function _vestedAmount(Vesting storage v) internal view returns (uint256) {
        if (block.timestamp < v.cliff) {
            return 0;
        }
        if (block.timestamp >= v.start + v.duration) {
            return v.total;
        }
        return (v.total * (block.timestamp - v.start)) / v.duration;
    }
}
