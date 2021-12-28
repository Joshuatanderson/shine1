// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract Shine is Initializable, ERC20PausableUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    // set privileged wallets
    address public charityWallet;
    address public marketingWallet;

    uint256 public charityFee;
    uint256 public redistributionFee;
    uint256 public marketingFee;

    uint256 private _previousCharityFee;
    uint256 private _previousRedistributionFee;
    uint256 private _previousMarketingFee;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;
   
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;
    uint256 private _currentRate;

    mapping (address => bool) private _isFeeExempted;

    // TODO: add events

    function initialize() public initializer {
        __ERC20_init("Shine", "SHINE");
        __Ownable_init();
        __Pausable_init();

        _mint(msg.sender, 10000000000 * 10 ** decimals());

        charityFee = 3;
        redistributionFee = 2;
        marketingFee = 2;

        _previousCharityFee = 3;
        _previousRedistributionFee = 2;
        _previousMarketingFee = 2;

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
    }

    /******************
    * DO NOT REMOVE _authorizeUpgrade
    * REMOVING THIS FUNCTION WILL PERMANENTLY BREAK UPGRADEABILITY
    *****************/ 

    function _authorizeUpgrade(address newImplementation) internal
        override
        onlyOwner {}

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
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
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual override returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function isExcluded(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflect(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        return rAmount.div(_currentRate);
    }

    function exemptAddress (address account) public onlyOwner () {
        _isFeeExempted[account] = true;
    }

    function setCharityWallet (address charity) public onlyOwner () {
        charityWallet = charity;
        _isFeeExempted[charityWallet] = true;
    }

    function setMarketingWallet (address marketing) public onlyOwner () {
        marketingWallet = marketing;
        _isFeeExempted[marketingWallet] = true;
    } 

    function excludeAccount(address account) public onlyOwner() {
        require(!_isExcluded[account], "Account already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    // TODO: this is awful.  Should probably be optimized to mapping.
    function includeAccount(address account) external onlyOwner() {
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
        require(owner != address(0), "approve from the zero address");
        require(spender != address(0), "approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override{
        require(sender != address(0), "transfer from the zero address");
        require(recipient != address(0), "transfer to the zero address");
        require(amount > 0, "Transfer amount not > zero");

        if(_isFeeExempted[sender] || _isFeeExempted[sender]){
            _removeAllFees();
        }

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if(_isFeeExempted[sender] || _isFeeExempted[sender]){
            _restoreAllFees();
        }
    }

    function _takeFee(uint256 tFee, address recipient) private {
        _setRate();
        uint256 rAmount = tFee.mul(_currentRate);

        _rOwned[recipient] = _rOwned[recipient].add(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tFee);
    }

    function _removeAllFees() private {
        if(redistributionFee == 0 && charityFee == 0) {
            return;
        }
        charityFee = 0;
        marketingFee = 0;
        redistributionFee = 0;
    }

    function _restoreAllFees() private {
        charityFee = _previousCharityFee;
        marketingFee = _previousMarketingFee;
        redistributionFee = _previousRedistributionFee;
    }

    function _processFeeTransfers(uint256 tCharity, uint256 tMarketing, uint256 rFee, uint256 tFee) private {
        _takeFee(tCharity, charityWallet);     
        _takeFee(tMarketing, marketingWallet);     
        _reflectFee(rFee, tFee);
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tCharity, uint256 tMarketing) = _getValues(tAmount);

        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);    

        _processFeeTransfers(tCharity, tMarketing, rFee, tFee);
        
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tCharity, uint256 tMarketing) = _getValues(tAmount);

        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   

        _processFeeTransfers(tCharity, tMarketing, rFee, tFee);

        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tCharity, uint256 tMarketing) = _getValues(tAmount);

        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   

       _processFeeTransfers(tCharity, tMarketing, rFee, tFee);

        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tCharity, uint256 tMarketing) = _getValues(tAmount);

        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   

        _processFeeTransfers(tCharity, tMarketing, rFee, tFee);

        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tCharity, uint256 tMarketing) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tCharity, tMarketing);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tCharity, tMarketing);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256){
        if(_isFeeExempted[msg.sender]){
            return (tAmount, 0, 0, 0);
        }

        uint256 tFee = tAmount.mul(redistributionFee).div(100);
        uint256 tCharity = tAmount.mul(charityFee).div(100);
        uint256 tMarketing = tAmount.mul(marketingFee).div(100);

        uint256 tTransferAmount = tAmount.sub(tFee).sub(tCharity).sub(tMarketing);
        return (tTransferAmount, tFee, tCharity, tMarketing);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tCharity, uint256 tMarketing) private view returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(_currentRate);
        uint256 rFee = tFee.mul(_currentRate);
        uint256 rCharity = tCharity.mul(_currentRate);
        uint256 rMarketing = tMarketing.mul(_currentRate);

        uint256 rTransferAmount = rAmount.sub(rFee).sub(rCharity).sub(rMarketing);
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
    function airdrop(address[] memory users, uint256 amount)
        external
        onlyOwner
    {
        require(amount <= balanceOf(msg.sender), "insufficient funds");
        for (uint256 i = 0; i < users.length; i++) {
            _transfer(msg.sender, users[i], amount);
        }
    }
}

contract ShineV2 is Shine {
    function version() pure public returns (string memory) {
        return "v1.0.1";
    }
}