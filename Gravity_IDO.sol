// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract GravityIDO is Ownable {
    
    IERC20 private WETH;
    IERC20 private GFI;
    IOUToken private IOU; //Token used to show WETH contribution in IDO sale
    address public WETH_ADDRESS;
    address public GFI_ADDRESS;
    address constant public TREASURY_ADDRESS = 0xE471f43De327bF352b5E922FeA92eF6D026B4Af0;
    bool public IDO_DONE; //bool to show if the IDO is over
    bool public IDO_STARTED; //bool to show if IDO has started
    uint public totalWETHCollected; //How much WETH was collected in the IDO
    uint constant public priceInWEth = 25 * 10 ** 12;
    uint constant public maxAllocation = 5 * 10 ** 17;// 20,000 GFI
    uint constant public GFIforSale = 4 * 10 ** 25; //How much GFI is for sale
    uint public WETHifSoldOut; //If the sale is sold out how much WETH would the contract get
    uint public saleEndTime;
    uint constant public saleLength = 86400;
    //uint constant public timeToClaim = 5184000; //Approximately 2 months after IDO sale
    uint constant public timeToClaim = 86400; // FOR DEVELOPMENT TESTING ONLY!!!!
    mapping(address => uint) public contributedBal;
    
    constructor(address _WETH_ADDRESS, address _GFI_ADDRESS){
        WETH_ADDRESS = _WETH_ADDRESS;
        GFI_ADDRESS = _GFI_ADDRESS;
        WETH = IERC20(WETH_ADDRESS);
        GFI = IERC20(GFI_ADDRESS);
        IOU = new IOUToken("GFI_IDO_IOU", "WETH_GFI");
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
        require(block.timestamp < saleEndTime, "IDO sale is finished!");
        require((contributedBal[msg.sender] + _amount) <= maxAllocation, "Exceeds max allocation!");
        require(_amount > 0, "Amount must be greater than zero!");
        require(WETH.transferFrom(msg.sender, address(this), _amount), "WETH transferFrom Failed!");
        totalWETHCollected = totalWETHCollected + _amount; // Update here isntead of using balanceOf in endIDO function
        contributedBal[msg.sender] = contributedBal[msg.sender] + _amount;
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
            WETHtoReturn = userBal - (GFItoUser*priceInWEth/(10**18));
        }
        else {
            GFItoUser = (10**18) * userBal / priceInWEth;
        }
        
        //Transfer tokens to user
        require(GFI.transfer(msg.sender, GFItoUser), "Failed to transfer GFI to claimer");
        if (WETHtoReturn > 0){
            require(WETH.transfer(msg.sender, WETHtoReturn), "Failed to return extra WETH to claimer");
        }
    }
    
    function startIDO() external onlyOwner{
        require(!IDO_STARTED, "IDO sale already started!");
        require(GFI.balanceOf(address(this)) >= GFIforSale, "IDO Contract does not have enough GFI to start sale!");
        saleEndTime = block.timestamp + saleLength;
        IDO_STARTED = true;
    }
    
    function endIDO() external onlyOwner{
        require(IDO_STARTED, "Sale has to begin before you can end it!");
        require(block.timestamp >= saleEndTime, "Minimum Sale Time has not passed!");
        require(!IDO_DONE, "IDO sale already ended!");
        require(GFI.balanceOf(address(this)) >= GFIforSale, "Contract does not hold enough GFI tokens!");
        require(WETH.balanceOf(address(this)) > 0, "Contract holds no WETH!");
        
        WETHifSoldOut = GFIforSale * priceInWEth / (10**18);
        IDO_DONE = true;
    }
    
    function withdraw() external onlyOwner{
        require(IDO_DONE, "IDO sale is not over yet!");
        if (totalWETHCollected >= WETHifSoldOut){
            // If all GFI are sold
            require(WETH.transfer(TREASURY_ADDRESS, WETHifSoldOut), "Failed to return WETH to Owner");
        }
        else {
            //Not all GFI tokens were sold.
            require(WETH.transfer(TREASURY_ADDRESS, totalWETHCollected), "Failed to return WETH to Owner");
            uint GFItoReturn = (10**18) * (WETHifSoldOut - totalWETHCollected)/priceInWEth; //Need to confirm this is correct
            require(GFI.transfer(TREASURY_ADDRESS, GFItoReturn), "Failed to transfer GFI to Owner");
        }
    }
    
    function withdrawAll() external onlyOwner{
        require(block.timestamp > (saleEndTime + timeToClaim), "Owner must wait approx 2 months until they can claim remaining assets!");
        require(WETH.transfer(TREASURY_ADDRESS, WETH.balanceOf(address(this))), "Failed to return WETH to Owner");
        require(GFI.transfer(TREASURY_ADDRESS, GFI.balanceOf(address(this))), "Failed to transfer GFI to Owner");
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
