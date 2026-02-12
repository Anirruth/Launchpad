// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./VestingVault.sol";

contract TokenSale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable raiseToken;
    IERC20 public immutable saleToken;
    address public immutable treasury;
    uint256 public immutable price;
    uint256 public immutable startTime;
    uint256 public immutable endTime;
    uint256 public immutable softCap;
    uint256 public immutable hardCap;
    uint256 public immutable vestingStart;
    uint256 public immutable vestingCliff;
    uint256 public immutable vestingDuration;
    VestingVault public immutable vestingVault;
    uint256 public totalRaised;
    bool public finalized;
    bool public saleFailed;
    mapping(address => uint256) public purchased;
    mapping(address => bool) public claimed;
    mapping(address => bool) public refunded;
    event Buy(address indexed buyer, uint256 raiseAmount);
    event Finalized(bool success, uint256 totalRaised);
    event TokensClaimed(address indexed buyer, uint256 tokenAmount);
    event Refunded(address indexed buyer, uint256 amount);

    constructor(
        address _raiseToken,
        address _saleToken,
        address _treasury,
        uint256 _price,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _vestingStart,
        uint256 _vestingCliff,
        uint256 _vestingDuration,
        address _vestingVault
    ) Ownable(msg.sender) {
        require(_startTime < _endTime, "Invalid time window");
        require(_softCap <= _hardCap, "Soft cap > hard cap");
        require(_price > 0, "Price must be > 0");
        require(_raiseToken != address(0), "Zero raise token");
        require(_saleToken != address(0), "Zero sale token");
        require(_treasury != address(0), "Zero treasury");
        require(_vestingVault != address(0), "Zero vesting vault");
        require(_vestingDuration > 0, "Vesting duration must be > 0");

        raiseToken = IERC20(_raiseToken);
        saleToken = IERC20(_saleToken);
        treasury = _treasury;
        price = _price;
        startTime = _startTime;
        endTime = _endTime;
        softCap = _softCap;
        hardCap = _hardCap;
        vestingStart = _vestingStart;
        vestingCliff = _vestingCliff;
        vestingDuration = _vestingDuration;
        vestingVault = VestingVault(_vestingVault);
    }

    function buy(uint256 amount) external nonReentrant {
        require(!finalized, "Sale finalized");
        require(block.timestamp >= startTime, "Not started");
        require(block.timestamp <= endTime, "Ended");
        require(amount > 0, "Zero amount");
        require(totalRaised + amount <= hardCap, "Hard cap reached");
        purchased[msg.sender] += amount;
        totalRaised += amount;
        raiseToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Buy(msg.sender, amount);
    }

    function finalize() external onlyOwner {
        require(!finalized, "Already finalized");
        require(
            block.timestamp > endTime || totalRaised >= hardCap,
            "Sale still active"
        );

        finalized = true;

        if (totalRaised >= softCap) {
            raiseToken.safeTransfer(treasury, totalRaised);
            emit Finalized(true, totalRaised);
        } else {
            saleFailed = true;
            emit Finalized(false, totalRaised);
        }
    }

    function claimTokens() external nonReentrant {
        require(finalized && !saleFailed, "Sale not successful");
        require(purchased[msg.sender] > 0, "Nothing purchased");
        require(!claimed[msg.sender], "Already claimed");
        claimed[msg.sender] = true;
        uint256 tokenAmount = (purchased[msg.sender] * 1e18) / price;
        vestingVault.addVesting(
            msg.sender,
            tokenAmount,
            vestingStart,
            vestingCliff,
            vestingDuration
        );

        emit TokensClaimed(msg.sender, tokenAmount);
    }

    function refund() external nonReentrant {
        require(finalized && saleFailed, "Refunds not enabled");
        require(purchased[msg.sender] > 0, "Nothing to refund");
        require(!refunded[msg.sender], "Already refunded");
        refunded[msg.sender] = true;
        uint256 amount = purchased[msg.sender];
        raiseToken.safeTransfer(msg.sender, amount);
        emit Refunded(msg.sender, amount);
    }

    function tokenAllocation(address _buyer) external view returns (uint256) {
        return (purchased[_buyer] * 1e18) / price;
    }
}
