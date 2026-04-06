// SPDX-license-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/erc20/ERC20.sol";

contract ERC4626test is ERC20 {
    IERC20 private immutable asset;
    constructor(address assets) ERC20("VaultToken","VTX"){
        asset = IERC20(assets);
    }


    function deposit(uint256 _amount) public {
        require(_amount > 0,"not enough amount");
        huint256 sharesToReturn = convertAssetToShare(_amount);
        require(sharesToReturn > 0,"__");
        asset.transferFrom(msg.sender,address(this),_amount);
        _mint(msg.sender,sharesToReturn);

    };

    function withdraw( uint256 _shares) public{
        require(balanceOf(msg.sender) >= _shares && _shares > 0,"not enough Shares");
        uint256 assetToReturn = convertSharesToAsset(_shares);
        require(assetToReturn > 0 && assetToReturn < asset.balanceOf(address(this)) ,"not enough asset");
        _burn(msg.sender,_shares);
        asset.transfer(msg.sender,assetToReturn);
        

    }

    function convertAssetToShare(uint256 _amount) public view returns(uint256){
            uint256 sharesToReturn = totalSupply()==0? _amount:
           ( _amount * totalSupply())/totalAsset();
           return sharesToReturn;
        }

    function convertSharesToAsset(uint256 _shares) public view returns (uint256){
        if(totalSupply() == 0){
            return 0;
        }
        return  (_shares * totalAsset())/totalSupply();
    }

    function totalAsset() public view  returns (uint256){
        return asset.balanceOf(address(this));
    }

}
