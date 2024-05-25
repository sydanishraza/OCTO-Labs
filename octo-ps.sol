// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PreSale is Ownable, ReentrancyGuard {
    IERC20 public token;
    address public preSaleWallet;
    uint256 public rate; // Number of tokens per ETH
    uint256 public minContribution;
    uint256 public maxContribution;
    uint256 public startTime;
    uint256 public endTime;
    bool public finalized = false;

    mapping(address => uint256) public contributions;
    uint256 public totalContributions;

    event TokensPurchased(address indexed purchaser, uint256 value, uint256 amount);
    event PreSaleFinalized();
    event Debug(uint256 currentTime, uint256 startTime, uint256 endTime, uint256 value, uint256 minContribution, uint256 maxContribution);

    constructor(
        address _token,
        address _preSaleWallet,
        uint256 _rate,
        uint256 _minContribution,
        uint256 _maxContribution,
        uint256 _startTime,
        uint256 _endTime
    ) Ownable(msg.sender) { 
        require(_endTime > _startTime, "End time must be after start time");
        require(_rate > 0, "Rate must be greater than 0");
        require(_minContribution > 0, "Min contribution must be greater than 0");

        token = IERC20(_token);
        preSaleWallet = _preSaleWallet;
        rate = _rate;
        minContribution = _minContribution;
        maxContribution = _maxContribution;
        startTime = _startTime;
        endTime = _endTime;
    }

    receive() external payable {
        buyTokens();
    }

    fallback() external payable {
        buyTokens();
    }

    function buyTokens() public nonReentrant payable {
        emit Debug(block.timestamp, startTime, endTime, msg.value, minContribution, maxContribution);

        require(block.timestamp >= startTime && block.timestamp <= endTime, "Pre-sale is not active");
        require(msg.value >= minContribution, "Contribution is below minimum limit");
        require(contributions[msg.sender] + msg.value <= maxContribution, "Contribution exceeds maximum limit");

        uint256 tokenAmount = getTokenAmount(msg.value);
        contributions[msg.sender] += msg.value;
        totalContributions += msg.value;

        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }

    function getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        return weiAmount * rate;
    }

    function finalizePreSale() external onlyOwner {
        require(block.timestamp > endTime, "Pre-sale has not ended yet");
        require(!finalized, "Pre-sale already finalized");

        finalized = true;

        uint256 unsoldTokens = token.balanceOf(address(this));
        if (unsoldTokens > 0) {
            token.transfer(preSaleWallet, unsoldTokens);
        }

        payable(preSaleWallet).transfer(address(this).balance);

        emit PreSaleFinalized();
    }

    function claimTokens() external nonReentrant {
        require(finalized, "Pre-sale not finalized");
        require(contributions[msg.sender] > 0, "No tokens to claim");

        uint256 tokenAmount = getTokenAmount(contributions[msg.sender]);
        contributions[msg.sender] = 0;
        token.transfer(msg.sender, tokenAmount);
    }
}
