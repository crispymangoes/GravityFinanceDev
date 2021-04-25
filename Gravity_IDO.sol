// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract GravityIDO is Ownable {
    
    IERC20 private WETH;
    IERC20 private GFI;
    IOUToken private IOU;
    address public WETH_ADDRESS;
    address public GFI_ADDRESS;
    bool public IDO_DONE;
    bool public IDO_STARTED;
    uint public totalWETHCollected;
    uint public priceInEth;
    uint public GFIforSale;
    uint public WETHifSoldOut;
    
    constructor(address _WETH_ADDRESS, address _GFI_ADDRESS, uint _priceInEth){
        WETH_ADDRESS = _WETH_ADDRESS;
        GFI_ADDRESS = _GFI_ADDRESS;
        WETH = IERC20(WETH_ADDRESS);
        GFI = IERC20(GFI_ADDRESS);
        IOU = new IOUToken("GFI_IDO_IOU", "WETH_GFI");
        priceInEth = _priceInEth;
    }
    
    function getIOUAddress() external view returns(address){
        return address(IOU);
    }
    
    function setWETH_ADDRESS(address _address) external onlyOwner{
        require(!IDO_STARTED, "IDO is already started!");
        WETH_ADDRESS = _address;
        WETH = IERC20(WETH_ADDRESS);
    }
    function setGFI_ADDRESS(address _address) external onlyOwner{
        require(!IDO_STARTED, "IDO is already started!");
        GFI_ADDRESS = _address;
        GFI = IERC20(GFI);
    }
    
    function buyStake(uint _amount) external {
        require(IDO_STARTED, "IDO has not started!");
        require(!IDO_DONE, "IDO sale is finished!");
        require(WETH.transferFrom(msg.sender, address(this), _amount), "WETH transferFrom Failed!");
        IOU.mintIOU(msg.sender, _amount);
    }
    
    function claimStake() external {
        require(IDO_DONE, "IDO sale is not over yet!");
        uint userBal = IOU.balanceOf(msg.sender);
        require(IOU.transferFrom(msg.sender, address(this), userBal), "Failed to transfer IOU to contract!"); //Not sure if this is needed, could just burn the tokens form the user address
        IOU.burnIOU(address(this), userBal);
        uint GFItoUser;
        uint WETHtoReturn;
        if (totalWETHCollected > WETHifSoldOut){
            uint userPercent = (10**18) * userBal / totalWETHCollected;
            GFItoUser = userPercent * GFIforSale / (10 ** 18);
            WETHtoReturn = userBal - (GFItoUser*priceInEth);
        }
        else {
            GFItoUser = (10**18) * userBal / priceInEth;
        }
        
        //Transfer tokens to user
        require(GFI.transferFrom(address(this), msg.sender, GFItoUser), "Failed to transfer GFI to claimer");
        if (WETHtoReturn > 0){
            require(WETH.transferFrom(address(this), msg.sender, WETHtoReturn), "Failed to return extra WETH to claimer");
        }
    }
    
    function startIDO() external onlyOwner{
        require(!IDO_STARTED, "IDO sale already started!");
        IDO_STARTED = true;
    }
    
    function endIDO() external onlyOwner{
        require(!IDO_DONE, "IDO sale already ended!");
        require(GFI.balanceOf(address(this)) > 0, "Contract holds no GFI tokens!");
        require(WETH.balanceOf(address(this)) > 0, "Contract holds no WETH!");
        
        GFIforSale = GFI.balanceOf(address(this));
        totalWETHCollected = WETH.balanceOf(address(this));
        WETHifSoldOut = GFIforSale * priceInEth;
        IDO_DONE = true;
    }
}

contract IOUToken is ERC20, Ownable {
    
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}
    
    function mintIOU( address _address, uint _amount) external onlyOwner{
        _mint(_address, _amount);
    }
    
    function burnIOU(address _address, uint _amount) external onlyOwner {
        _burn(_address, _amount);
    }
}
