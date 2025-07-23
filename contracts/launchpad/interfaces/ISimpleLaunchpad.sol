pragma solidity 0.8.27;

interface ISimpleLaunchpad {
    function increaseStake(address account, uint96 shares) external;
    function decreaseStake(address account, uint96 shares) external;
    function endRewards() external;
}
