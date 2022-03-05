pragma solidity 0.8.4;

interface ITokenConstructorFactory {
    function isGoodRouter(address) external view returns (bool);
}