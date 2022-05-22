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
        gov = msg.sender;
        address _dai = address(0x8D9AED9882b4953a0c9fa920168fa1FDfA0eBE75);
        minAmounts[_dai] = 1e17;
    }

    function shouldRedeem(address _cToken) public returns (bool) {
        ICToken cToken = ICToken(_cToken);
        IERC20 underlying = IERC20(cToken.underlying());
        uint balance = underlying.balanceOf(address(cToken));
        uint allowance = cToken.allowance(gov, address(this));
        if (allowance == 0){
            return false;
        }
        if(balance >= minAmounts[_cToken] && allowance >= minAmounts[_cToken]){
            return true;
        }
        return false;
    }

    function redeemMax(address _cToken) external {
        require(shouldRedeem(_cToken));
        ICToken cToken = ICToken(_cToken);
        IERC20 underlying = IERC20(cToken.underlying());
        uint toTransfer = Math.min(cToken.allowance(gov, address(this)), cToken.balanceOf(gov));
        uint amount = Math.min(toTransfer, convertFromUnderlying(_cToken, underlying.balanceOf(address(cToken))));

        _redeem(_cToken, amount);
    }

    function redeemExact(address _cToken, uint amount) external {
        require(shouldRedeem(_cToken));
        _redeem(_cToken, amount);
    }

    function _redeem(address _cToken, uint amount) internal {
        ICToken cToken = ICToken(_cToken);
        IERC20 underlying = IERC20(cToken.underlying());

        cToken.transferFrom(gov, address(this), amount);
        cToken.redeem(amount);
        
        uint amountRedeemed = underlying.balanceOf(address(this));
        underlying.transfer(gov, amountRedeemed);
        emit Retrieved(amountRedeemed);
    }

    function convertFromUnderlying(address _cToken, uint256 amountOfUnderlying) public view returns (uint256 balance){
        ICToken cToken = ICToken(_cToken);
        if (amountOfUnderlying == 0) {
            balance = 0;
        } else {
            balance = amountOfUnderlying.mul(1e18).div(cToken.exchangeRateStored());
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
}