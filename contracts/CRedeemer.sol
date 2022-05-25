pragma solidity ^0.6.5;

import {SafeERC20, SafeMath, IERC20, Address} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";

interface ICToken {
    function transfer(address dst, uint256 amount) external returns (bool);
    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function underlying() external view returns (address);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function balanceOfUnderlying(address owner) external returns (uint256);
    function exchangeRateCurrent() external returns (uint);
}

contract CRedeemer {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    event NewGovernance(address governance);
    event Retrieved(uint amount);

    address public gov = 0xC0E2830724C946a6748dDFE09753613cd38f6767;
    mapping(address => uint) public minAmounts; // min amount worth claiming in underlying

    constructor() public {
        address _scDAI = address(0x8D9AED9882b4953a0c9fa920168fa1FDfA0eBE75);
        minAmounts[_scDAI] = 1e17;
    }

    function redeemMax(address _cToken) external {
        require(shouldRedeem(_cToken));

        ICToken cToken = ICToken(_cToken);
        IERC20 underlying = IERC20(cToken.underlying());
        uint256 ourBalance = cToken.balanceOfUnderlying(address(this));
        uint256 liquidity = underlying.balanceOf(_cToken);
        uint256 amount = ourBalance <=  liquidity ? type(uint256).max : liquidity;

        _redeem(_cToken, amount);

        
    }

    function redeemExact(address _cToken, uint amount) external {
        require(shouldRedeem(_cToken));
        _redeem(_cToken, amount);
    }

    function _redeem(address _cToken, uint amount) internal {
        ICToken cToken = ICToken(_cToken);
        IERC20 underlying = IERC20(cToken.underlying());
        if(amount == type(uint256).max){
            cToken.redeem(cToken.balanceOf(address(this)));
        }else{
            cToken.redeemUnderlying(amount);
        }
        
        
        uint amountRedeemed = underlying.balanceOf(address(this));
        if(amountRedeemed > 0){
            underlying.safeTransfer(gov, amountRedeemed);
        }
        
        emit Retrieved(amountRedeemed);
    }

    function shouldRedeem(address _cToken) public view returns (bool) {
        ICToken cToken = ICToken(_cToken);
        IERC20 underlying = IERC20(cToken.underlying());
        uint liquidity = underlying.balanceOf(address(cToken));
        uint balance = convertToUnderlying(_cToken, cToken.balanceOf(address(cToken)));
        if(liquidity >= minAmounts[_cToken] && balance >= minAmounts[_cToken]){
            return true;
        }
        return false;
    }

    function convertFromUnderlying(address _cToken, uint256 amountOfUnderlying) public view returns (uint256 balance){
        ICToken cToken = ICToken(_cToken);
        if (amountOfUnderlying == 0) {
            balance = 0;
        } else {
            balance = amountOfUnderlying.mul(1e18).div(cToken.exchangeRateStored());
        }
    }

    function convertToUnderlying(address _cToken, uint256 cTokenAmount) public view returns (uint256 balance){
        ICToken cToken = ICToken(_cToken);
        if (cTokenAmount == 0) {
            balance = 0;
        } else {
            balance = cTokenAmount.mul(cToken.exchangeRateStored()).div(1e18);
        }
    }

    function retrieveToken(address _token) external {
        require(msg.sender == gov, "!governance");
        retrieveTokenExact(_token, IERC20(_token).balanceOf(address(this)));
    }

    function retrieveTokenExact(address _token, uint _amount) public {
        require(msg.sender == gov, "!governance");
        IERC20(_token).safeTransfer(gov, _amount);
    }

    function setGovernance(address _gov) external {
        require(msg.sender == gov, "!governance");
        gov = _gov;
    }

    function setMinAmount(address _cToken, uint _amount) external {
        require(msg.sender == gov, "!governance");
        minAmounts[_cToken] = _amount;
    }
}