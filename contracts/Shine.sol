// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

/*
This is a no-bot contract.  Bots and scammers will be blacklisted, and their balance will be frozen.
For more details, visit shinemine.io.
The ShineMine team & ShineMine DAO reserve the right to complete discretion over who to blacklist & unblacklist.
Any bots interacting with this contract may permanently lose access to tokens they purchase, with no recourse
*/

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract Shine is ERC20PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeMathUpgradeable for uint256;

    // set privileged wallets
        // a privileged wallet mapping was used instead of individual addresses for space reasons
    mapping (uint256 => address) public privilegedWallets; 
    // address public charityWallet;
    // address public marketingWallet;
    // address public liquidityWallet;

    // due to space limitations in solidity contracts, we opted to use a single, non-updatable fee variable.
    // this is because all SHINE fees happened to be 2% anyways.  
    // because of this, adjusting the amount of fees will require a contract upgrade
    uint256 public feePercentage;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;
   
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;
    uint256 private _currentRate;
    bool private _feesEnabled;

    mapping (address => bool) private _isFeeExempted;
    mapping (address => bool) private _isBlackListed;
    mapping (address => uint256) public _airdropUnlockTime;
    // uint256 public presaleReleaseTime;
    uint256 private _bPreventionTime;
    // bot preventionTime
    // if time is before botPrevention
    // add to blacklist

    // TODO: add events

    function initialize() public initializer {
        __ERC20_init("ShineMine", "SHINE");
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _mint(msg.sender, 10000000000 * 10 ** decimals());

        feePercentage = 2;

        // init reflection variables
        uint256 MAX = ~uint256(0); // maximum possible value of uint256 type
        _tTotal = 10000000000 * 10 ** decimals();
        _rTotal = (MAX - (MAX % _tTotal));  // this is basically an arbitrary, magic value
        _rOwned[msg.sender] = _rTotal;
        _tOwned[msg.sender] = _tTotal;
        _setRate();

        // exclude owner and this contract from fee
        excludeAccount(msg.sender);
        _isFeeExempted[msg.sender] = true;
        _isFeeExempted[address(this)] = true;
        // @dev - hardlocked airdrop release time for prerelease funds
        // presaleReleaseTime = block.timestamp + 90 days;
    }

    modifier isNotTimelocked {
        require(block.timestamp > _airdropUnlockTime[msg.sender], "Is timelocked address");
        _;
    }

    // if transfer is in first minute
    // capture Asset, send to reward pool

    /******************
    * DO NOT REMOVE _authorizeUpgrade
    * REMOVING THIS FUNCTION WILL PERMANENTLY BREAK UPGRADEABILITY
    *****************/ 

    function _authorizeUpgrade(address newImplementation) internal
        override
        onlyOwner {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }


    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function setBotTrap(uint256 trapLength) public onlyOwner {
        _bPreventionTime = block.timestamp + trapLength * 1 minutes;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "Transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual override returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "Decreased allowance below zero"));
        return true;
    }

    function isExcluded(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function setFeePercentage(uint256 newFee) public onlyOwner {
        feePercentage = newFee;
    }

    function reflect(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Is excluded address");
        (uint256 rAmount,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount >= supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function blacklist(address account) public onlyOwner {
        _isBlackListed[account] = true;
    }

    function unBlacklist(address goodActor) public onlyOwner {
        _isBlackListed[goodActor] = true;
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Must be less than reflections");
        return rAmount.div(_currentRate);
    }

    function exemptAddress (address account) public onlyOwner () {
        _isFeeExempted[account] = true;
    }

    // function setCharityWallet (address charity) public onlyOwner () {
    //     charityWallet = charity;
    //     _isFeeExempted[charityWallet] = true;
    // }

    // function setMarketingWallet (address marketing) public onlyOwner {
    //     marketingWallet = marketing;
    //     _isFeeExempted[marketingWallet] = true;
    // } 

    // function setLiquidityWallet (address liquidity) public onlyOwner {
    //     liquidityWallet = liquidity;
    //     _isFeeExempted[liquidityWallet] = true;
    // } 

    function setPrivilegedWallet(address privileged, uint256 index) public onlyOwner () {
        privilegedWallets[index] = privileged;
    }

    function privilegedWallet(uint256 index) public view returns (address) {
        return privilegedWallets[index];
    }

    function excludeAccount(address account) public onlyOwner {
        require(!_isExcluded[account], "Account already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeAccount(address account) external onlyOwner {
        require(_isExcluded[account], "Account already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _approve(address owner, address spender, uint256 amount) internal override {
        require(owner != address(0), "approve from zero address");
        require(spender != address(0), "approve to zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override isNotTimelocked {

        require(sender != address(0), "transfer from zero address");
        require(recipient != address(0), "transfer to zero address");
        require(amount > 0, "Transfer amount not > zero");

        // blacklist all bots that are frontrunning or buying in first minute;
        // @dev - magic address is pancakeSwap
        if(block.timestamp < _bPreventionTime && sender != 0x10ED43C718714eb63d5aA57B78B54704E256024E && sender != owner()){
            _isBlackListed[sender] = true;
        }

        require(!_isBlackListed[sender], "You are blacklisted");

        if(_isFeeExempted[sender] || _isFeeExempted[sender]){
            _feesEnabled = false;
        }

        (
            uint256 rAmount, 
            uint256 rTransferAmount, 
            uint256 rFee, 
            uint256 tTransferAmount, 
            uint256 tFee
        ) = _getValues(amount);

        // @dev in all transations, rOwned is adjusted for both parties
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);  
        // @dev in all transactions where recipient is excluded from rewards, tRecipient is adjusted
        if(_isExcluded[recipient]){
            _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        }

        // @dev in all transactions where the sender is excluded from rewards, tSender is adjusted.
        if(_isExcluded[sender]){
            _tOwned[sender] = _tOwned[sender].sub(amount);
        }

        _processFeeTransfers(rFee, tFee);

        emit Transfer(sender, recipient, tTransferAmount);

        _feesEnabled = true;
    }

    function _takeFee(uint256 tFee, address recipient) private {
        _setRate();
        uint256 rAmount = tFee.mul(_currentRate);

        _rOwned[recipient] = _rOwned[recipient].add(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tFee);
    }

    function _processFeeTransfers( uint256 rFee, uint256 tFee) private {
        _takeFee(tFee, privilegedWallets[0]);     
        _takeFee(tFee, privilegedWallets[1]);     
        _takeFee(tFee, privilegedWallets[2]);
        _reflectFee(rFee, tFee);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256){
        if(_isFeeExempted[msg.sender]){
            return (tAmount, 0);
        }

        uint256 tFee = tAmount.mul(feePercentage).div(100);

        uint256 tTransferAmount = tAmount.sub(feePercentage).sub(feePercentage).sub(feePercentage).sub(feePercentage); // 100% - 2% * 4, for all fees
        return (tTransferAmount, tFee);
    }

    function _getRValues(uint256 tAmount, uint256 tFee) private view returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(_currentRate);
        uint256 rFee = tFee.mul(_currentRate);

        uint256 rTransferAmount = rAmount.sub(rFee).sub(rFee).sub(rFee).sub(rFee);
        return (rAmount, rTransferAmount, rFee);
    }

    function _setRate() private {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        _currentRate = rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    // airdrops the amount to each user in the array.  
    // Should only be used for small arrays due to gas costs.
    function airdrop(address[] memory users, uint256 amount, uint256 daysLocked)
        external
        onlyOwner
    {
        require(amount <= balanceOf(msg.sender), "insufficient funds");
        for (uint256 i = 0; i < users.length; i++) {
            _transfer(msg.sender, users[i], amount);
            _airdropUnlockTime[users[i]] = block.timestamp + daysLocked * 1 days;
        }
    }
}