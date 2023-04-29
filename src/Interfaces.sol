//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;


// interface for WETHGateway contract
interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IWETHGateway 
{
    function depositETH(
      address lendingPool,
      address onBehalfOf,
      uint16 referralCode
    ) external payable;

    function withdrawETH(
      address lendingPool,
      uint256 amount,
      address to
    ) external;

}

interface ILendingPoolAddressesProvider 
{
   function getLendingPool() external view returns (address);
}

interface IERC20 {

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface ILendingPool {
 
  event Deposit(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referral
  );

  event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);

  function deposit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external returns (uint256);

}


