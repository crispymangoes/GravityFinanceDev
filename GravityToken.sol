 // SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract GravityToken is ERC20, Ownable{
    
    address public GOVERNANCE_ADDRESS;
    iGovernance private govenor;
    bool public applyGovernanceForwarding;
    
    modifier onlyGovernance(){
        require(msg.sender == GOVERNANCE_ADDRESS, "Only the governance contract can call this function!");
        _;
    }
    
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) { 
        _mint(msg.sender, 12000000000000000000000000);
    }
    
    function setGovernanceAddress(address _address) external onlyOwner{
        GOVERNANCE_ADDRESS = _address;
        govenor = iGovernance(GOVERNANCE_ADDRESS);
    }
    
    function changeGovernanceForwarding(bool _bool) public onlyOwner {
        applyGovernanceForwarding = _bool;
    }
    
    function governanceTransfer(address sender, address recipient, uint256 amount) public onlyGovernance returns (bool) {
        _transfer(sender, recipient, amount);
        return true;
    }
    
    function governanceTransferFrom(address original_sender, address sender, address recipient, uint256 amount) public onlyGovernance returns (bool) {
        _transfer(sender, recipient, amount);
        
        uint256 currentAllowance = allowance(sender, original_sender);
        //uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }
    
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        if(applyGovernanceForwarding){
            govenor.govAuthTransfer(msg.sender, recipient, amount);
        }
        else{
            _transfer(_msgSender(), recipient, amount);
            return true;
        }
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        
        if(applyGovernanceForwarding){
            govenor.govAuthTransferFrom(msg.sender, sender, recipient, amount);
        }
        else{
            _transfer(sender, recipient, amount);
            uint256 currentAllowance = allowance(sender, _msgSender()); //Had to change this because erro thrown with _allowances
            //uint256 currentAllowance = _allowances[sender][_msgSender()];
            require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
            _approve(sender, _msgSender(), currentAllowance - amount);
    
            return true;
        }
    }
    
    
    function burn(uint _amount) external returns(bool){
        _burn(msg.sender, _amount);
        return true;
    }
}

interface iGovernance{
    function govAuthTransfer(address sender, address recipient, uint256 amount) external returns (bool); // calls governanceTransfer after fee ledger update
    function govAuthTransferFrom(address original_sender, address sender, address recipient, uint256 amount) external returns (bool); // calls governanceTransferFrom after fee ledger update
}
