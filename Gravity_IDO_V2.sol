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
    address constant public PROMO_ADDRESS = 0x8c7887BA91b359BC574525F05Cc403F51858c2E4;
    uint public totalWETHCollected; //How much WETH was collected in the IDO
    uint constant public priceInWEth = 25 * 10 ** 12;
    uint constant public maxAllocation = 5 * 10 ** 17;// 20,000 GFI
    uint constant public GFIforSale = 4 * 10 ** 25; //How much GFI is for sale
    uint public WETHifSoldOut = GFIforSale * priceInWEth / (10**18); //If the sale is sold out how much WETH would the contract get
    uint public saleStartTime = 1621404000;
    uint public saleEndTime = 1621490400;
    uint constant public timeToClaim = 5184000; //Approximately 2 months after IDO sale
    mapping(address => uint) public contributedBal;
    bool public ownerShareWithdrawn;
    
    event BuyStake(address buyer, uint totalStake); //Emits user address, and their TOTAL stake
    event ClaimStake(address claimer, uint GFIclaimed, uint WETHreturned); // Emits user address, and how much GFI, WETH they recieved
    event WETHUpdate(uint newTotal); //Emits new total of WETH in IDO contract
    
    constructor(address _WETH_ADDRESS, address _GFI_ADDRESS){
        WETH_ADDRESS = _WETH_ADDRESS;
        GFI_ADDRESS = _GFI_ADDRESS;
        WETH = IERC20(WETH_ADDRESS);
        GFI = IERC20(GFI_ADDRESS);
        IOU = new IOUToken("GFI_IDO_IOU", "GFI_IDO");
    }
    
    function getIOUAddress() external view returns(address){
        return address(IOU);
    }
    
    function setWETH_ADDRESS(address _address) external onlyOwner{
        require(block.timestamp <= saleStartTime, "IDO has started cannot change address!");
        WETH_ADDRESS = _address;
        WETH = IERC20(WETH_ADDRESS);
    }
    function setGFI_ADDRESS(address _address) external onlyOwner{
        require(block.timestamp <= saleStartTime, "IDO has started cannot change address!");
        GFI_ADDRESS = _address;
        GFI = IERC20(GFI);
    }

    function buyStake(uint _amount) external {
        require(block.timestamp >= saleStartTime, "IDO has not started!");
        require(block.timestamp <= saleEndTime, "IDO sale is finished!");
        require(GFI.balanceOf(address(this)) >= GFIforSale, "Contract does not hold enough GFI tokens to cover sale!");
        require((contributedBal[msg.sender] + _amount) <= maxAllocation, "Exceeds max allocation!");
        require(_amount > 0, "Amount must be greater than zero!");
        require(WETH.transferFrom(msg.sender, address(this), _amount), "WETH transferFrom Failed!");
        totalWETHCollected = totalWETHCollected + _amount; // Update here instead of using balanceOf in endIDO function
        contributedBal[msg.sender] = contributedBal[msg.sender] + _amount;
        IOU.mintIOU(msg.sender, _amount);
        emit BuyStake(msg.sender, contributedBal[msg.sender]);
        emit WETHUpdate(totalWETHCollected);
    }
    
    function claimStake() external {
        require(block.timestamp >= saleEndTime, "IDO sale is not over yet!");
        uint userBal = IOU.balanceOf(msg.sender);
        require(userBal > 0, "Caller has no WETH_GFI tokens to claim!");
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
        
        //Remove the last decimal place
        GFItoUser = GFItoUser/10;
        GFItoUser = GFItoUser*10;
        WETHtoReturn = WETHtoReturn/10;
        WETHtoReturn = WETHtoReturn*10;
        //Transfer tokens to user
        require(GFI.transfer(msg.sender, GFItoUser), "Failed to transfer GFI to claimer");
        if (WETHtoReturn > 0){
            require(WETH.transfer(msg.sender, WETHtoReturn), "Failed to return extra WETH to claimer");
        }
        emit ClaimStake(msg.sender, GFItoUser, WETHtoReturn);
    }
    
    function withdraw() external onlyOwner{
        require(!ownerShareWithdrawn, "Owner has already withdrawn their share!");
        require(block.timestamp >= saleEndTime, "IDO sale is not over yet!");
        ownerShareWithdrawn = true;
        if (totalWETHCollected >= WETHifSoldOut){
            // If all GFI are sold
            require(WETH.transfer(TREASURY_ADDRESS, WETHifSoldOut), "Failed to return WETH to Treasury wallet  ");
        }
        else {
            //Not all GFI tokens were sold.
            require(WETH.transfer(TREASURY_ADDRESS, totalWETHCollected), "Failed to return WETH to Treasury wallet");
            uint GFItoReturn = (10**18) * (WETHifSoldOut - totalWETHCollected)/priceInWEth;
            require(GFI.transfer(PROMO_ADDRESS, GFItoReturn), "Failed to transfer GFI to Promotion wallet");
        }
    }
    
    function withdrawAll() external onlyOwner{
        require((block.timestamp > (saleEndTime + timeToClaim)) || (IOU.totalSupply() == 0), "Owner must wait approx 2 months until they can claim remaining assets OR until all IOUs are fulfilled!");
        require(WETH.transfer(TREASURY_ADDRESS, WETH.balanceOf(address(this))), "Failed to return WETH to Treasury wallet");
        require(GFI.transfer(PROMO_ADDRESS, GFI.balanceOf(address(this))), "Failed to transfer GFI to Promotion wallet");
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
