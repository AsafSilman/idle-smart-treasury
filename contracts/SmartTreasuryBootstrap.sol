// SPDX-License-Identifier: MIT

pragma solidity = 0.6.6;
pragma experimental ABIEncoderV2;

import "./interfaces/ISmartTreasuryBootstrap.sol";
import "./interfaces/BalancerInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SmartTreasuryBootstrap is ISmartTreasuryBootstrap {
  bool initialised;

  address admin;
  address crpaddress;

  IBFactory private balancer_bfactory;
  ICRPFactory private balancer_crpfactory;

  IERC20 private idle;
  IERC20 private weth;

  constructor (address _balancer_bfactory, address _balancer_crpfactory, address _idle, address _weth) public {
    admin = msg.sender;

    balancer_bfactory = IBFactory(_balancer_bfactory);
    balancer_crpfactory = ICRPFactory(_balancer_crpfactory);

    idle = IERC20(_idle);
    weth = IERC20(_weth);

    initialised = false;
  }

  function initialise() external override {
    require(msg.sender == admin, "Caller is not admin");

    address[] memory tokens = new address[](2);
    tokens[0] = address(idle);
    tokens[1] = address(weth);

    uint[] memory balances = new uint[](2);
    // TODO: This should definetely be changed
    balances[0] = idle.balanceOf(address(this));
    balances[1] = weth.balanceOf(address(this));

    uint[] memory weights = new uint[](2);
    weights[0] = 99 * 10 ** 18;
    weights[1] = 1  * 10 ** 18;

    ICRPFactory.PoolParams memory params = ICRPFactory.PoolParams({
      poolTokenSymbol: "ISTT",
      poolTokenName: "Idle Smart Treasury Token",
      constituentTokens: tokens,
      tokenBalances: balances,
      tokenWeights: weights,
      swapFee: 5 * 10**16 // .5% fee = 50000000000000000
    });

    ICRPFactory.Rights memory rights = ICRPFactory.Rights({
      canPauseSwapping:   true,
      canChangeSwapFee:   true,
      canChangeWeights:   true,
      canAddRemoveTokens: true,
      canWhitelistLPs:    true,
      canChangeCap:       true
    });
    
    ConfigurableRightsPool crp = balancer_crpfactory.newCrp(
      address(balancer_bfactory),
      params,
      rights
    );

    crpaddress = address(crp);

    idle.approve(crpaddress, balances[0]); // approve transfer of idle
    weth.approve(crpaddress, balances[1]); // approve transfer of idle
  }
  function swap() external override {}
  function bootstrap() external override {
    require(msg.sender == admin, "Caller is not admin");

    ConfigurableRightsPool crp = ConfigurableRightsPool(crpaddress);

    crp.createPool(
        1000 * 10 ** 18, 
        3 days,
        3 days
    );
  }
  function renounce() external override {}
}
