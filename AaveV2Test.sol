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
        require(amountPleged[msg.sender] > 0, "Invalid address");
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
    mapping(address => uint) public amountPleged;
    mapping(address => uint) public donationTimeStamp;
    mapping(address => uint) public locks;

    constructor(uint _timeLock) {
        //provider is used for getting lending pool address, because it is upgradeable
        //addresses shouldn't be hardcoded, remix used to create contract
        //in hardhat i'll use .env to set addresses there
        WETHGateway = IWETHGateway(address(0xA61ca04DF33B72b235a8A28CfB535bb7A5271B70));
        provider = ILendingPoolAddressesProvider(address(0x88757f2f99175387aB4C6a4b3067c77A695b0349));
        LendingPool = ILendingPool(provider.getLendingPool());
        aWETH = IERC20(0x87b1f4cf9BD63f7BBD3eE1aD04E8F52540349347);  

        timeLock = _timeLock;     
    }   

    function addFunds() external payable {
        require(msg.value > 0, "Invalid pleged amount");
        if(msg.sender == address(0)){
            revert InvalidAddress();
        }

        uint amount = msg.value;
        address caller = msg.sender;

        amountPleged[caller] += amount;
        donationTimeStamp[caller] = block.timestamp;
        locks[msg.sender] = block.timestamp;
        totalAdded += amount;
        total += amount;

        WETHGateway.depositETH{value: msg.value}(address(LendingPool), address(this), 0);

        emit Deposit(caller, amount);
    }  

    function withdraw() external onlyLenders {
        require(amountPleged[msg.sender] > 0, "Zero funds");
        if(msg.sender == address(0)){
            revert InvalidAddress();
        }
        uint amountToWithdraw = getAmountToWithdraw(msg.sender);

        WETHGateway.withdrawETH(address(LendingPool), amountToWithdraw, msg.sender);

        total -= amountToWithdraw;
        totalAdded -= amountPleged[msg.sender];

        amountPleged[msg.sender] = 0;
        
        emit Withdraw(msg.sender, amountToWithdraw);
    }   

    function getReward() external onlyLenders {
        uint amountToWithdraw;

        //insures that you can withdraw reward once in every timelock period
        if(block.timestamp - locks[msg.sender] >= timeLock){
           locks[msg.sender] = block.timestamp;
           amountToWithdraw = getRewardAmount(msg.sender); 
        }

        WETHGateway.withdrawETH(address(LendingPool), amountToWithdraw, msg.sender);

    }

    //getters
    //gets total amount in aweth
    function getTotal() public view returns(uint) {
        return IERC20(aWETH).balanceOf(address(this));
    }

    //gets reward amount 
    function getRewardAmount(address account) public view returns(uint reward) {
        uint totalInContract = getTotal();
        uint pleged = total;
        uint usersPleged = amountPleged[account];

        //calculate total rewards (totalInContract - pleged)
        //get user share (usersPleged / pleged)
        reward = (totalInContract - pleged)*(usersPleged / pleged);         
    }

    //gets full or share of the deposit amount
    function getAmountToWithdraw(address account) public view returns(uint amount) {
        uint plegedTime = donationTimeStamp[account];
        uint pleged = amountPleged[msg.sender];

        if (block.timestamp >= plegedTime + timeLock) {
            //if locktime passed user can withdraw total amount
            //(pleged / totalAdded) used for getting share of total amount 
            amount = total * (pleged / totalAdded);
        } else {
            uint timePassed = block.timestamp - plegedTime;
            uint amountPerSec = pleged / timeLock;

            //amount to withdraw is 50% + timePassed*amountPerSec
            amount = (pleged + timePassed * amountPerSec) / 2;
        }
    }
}