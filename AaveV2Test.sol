// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Interfaces.sol";

error InvalidAddress();

contract AaveV2Test {

    //events
    event Deposit(address indexed lender, uint amount);
    event Withdraw(address indexed lender, uint amount);
    event GetReward(address indexed lender, uint reward);

    //modifiers
    modifier onlyLenders {
        require(amountPledged[msg.sender] > 0, "Invalid address");
        _;
    }

    //addresses to work with AAVE and WETH
    IWETHGateway public WETHGateway;
    ILendingPoolAddressesProvider public provider;
    ILendingPool public LendingPool; 
    IERC20 public aWETH;

    uint timeLock;
    uint total;
    //totalAdded used for calculating amount to withdraw
    uint totalAdded;
    mapping(address => uint) public amountPledged;
    mapping(address => uint) public donationTimeStamp;
    mapping(address => uint) public locks;

    /// @notice setting timelock and getting needed contracts
    /// @param _timeLock is minimum time needed to pass if lender wants full amount pledged
    constructor(uint _timeLock) {
        //provider is used for getting lending pool address
        //addresses shouldn't be hardcoded
        WETHGateway = IWETHGateway(address(0xA61ca04DF33B72b235a8A28CfB535bb7A5271B70));
        provider = ILendingPoolAddressesProvider(address(0x88757f2f99175387aB4C6a4b3067c77A695b0349));
        //getting lending pool
        LendingPool = ILendingPool(provider.getLendingPool());
        //getting aWETH contract
        aWETH = IERC20(0x87b1f4cf9BD63f7BBD3eE1aD04E8F52540349347);  

        timeLock = _timeLock;     
    }   

    /// @notice Function for adding ETH in Aave lending pool
    function addFunds() external payable {
        require(msg.value > 0, "Invalid pledged amount");
        if(msg.sender == address(0)){
            revert InvalidAddress();
        }

        uint amount = msg.value;
        address caller = msg.sender;

        amountPledged[caller] += amount;
        donationTimeStamp[caller] = block.timestamp;
        locks[msg.sender] = block.timestamp;
        totalAdded += amount;
        total += amount;
        
        //deposit ETH to Aave lending pool
        WETHGateway.depositETH{value: msg.value}(address(LendingPool), address(this), 0);

        emit Deposit(caller, amount);
    }  

    /// @notice Function to withdraw funds from Aave lending pool
    function withdraw() external onlyLenders {
        require(amountPledged[msg.sender] > 0, "Zero funds");
        if(msg.sender == address(0)){
            revert InvalidAddress();
        }
        uint amountToWithdraw = getAmountToWithdraw(msg.sender);

        WETHGateway.withdrawETH(address(LendingPool), amountToWithdraw, msg.sender);

        total -= amountToWithdraw;
        totalAdded -= amountPledged[msg.sender];

        amountPledged[msg.sender] = 0;
        
        emit Withdraw(msg.sender, amountToWithdraw);
    }   

    /// @notice Functions enables lenders to withdraw interest from Aave
    function getReward() external onlyLenders {
        uint amountToWithdraw;

        //insures that you can withdraw reward once in every timelock period
        if(block.timestamp - locks[msg.sender] >= timeLock){
           locks[msg.sender] = block.timestamp;
           amountToWithdraw = getRewardAmount(msg.sender); 
        }

        WETHGateway.withdrawETH(address(LendingPool), amountToWithdraw, msg.sender);
    
        emit GetReward(msg.sender, amountToWithdraw);
    }

    //getters
    //gets total amount in aweth
    function getTotal() public view returns(uint) {
        return IERC20(aWETH).balanceOf(address(this));
    }

    //gets reward amount 
    function getRewardAmount(address account) public view returns(uint reward) {
        uint totalInContract = getTotal();
        uint pledged = total;
        uint usersPledged = amountPledged[account];

        //calculate total rewards (totalInContract - pledged)
        //get user share (usersPledged / pledged)
        reward = (totalInContract - pledged)*(usersPledged / pledged);         
    }

    //gets full or share of the deposit amount
    function getAmountToWithdraw(address account) public view returns(uint amount) {
        uint pledgedTime = donationTimeStamp[account];
        uint pledged = (total * amountPledged[account]) / (totalAdded);

        if (block.timestamp >= pledgedTime + timeLock) {
            //if locktime passed user can withdraw total amount
            //(pledged / totalAdded) used for getting share of total amount 
            amount = total * (pledged / totalAdded);
        } else {
            uint timePassed = block.timestamp - pledgedTime;
            uint amountPerSec = pledged / timeLock;

            //amount to withdraw is 50% + timePassed*amountPerSec
            amount = (pledged + timePassed * amountPerSec) / 2;
        }
    }
}
