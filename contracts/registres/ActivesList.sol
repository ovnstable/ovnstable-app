// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;
import "../interfaces/IActivesList.sol";
import "../OwnableExt.sol";
/// @title ActivesList - mantains list of actives in system
/// @author @stanta
/// @notice CRUU for actives. Unpublishing insrtead of Deleting

contract ActivesList is OwnableExt, IActivesList {

    mapping (address => uint256) actPos;
    Active[] actList;

    function actAdd (address _addrAct, 
                     address _connector,
                     address _poolPrice, 
                     address _poolStake, 
                     uint16 _minSh, 
                     uint16 _maxSh, 
                     uint256 _initBal, 
                     address[] memory _ders  )external override onlyOwner {
        actList.push (Active (_addrAct, _connector, _poolPrice, _poolStake, _initBal,  _minSh,  _maxSh, 1, _ders));
        actPos[_addrAct] = actList.length - 1;
    }

    function editAct (address _addrAct,address _connector, address _poolPrice, address _poolStake,  uint16 _minSh, uint16 _maxSh, uint8 _isW) external override  onlyOwner {
        
        actList[actPos[_addrAct]].connector = _connector;
        actList[actPos[_addrAct]].poolPrice = _poolPrice;
        actList[actPos[_addrAct]].poolStake = _poolStake;
        actList[actPos[_addrAct]].minShare = _minSh;
        actList[actPos[_addrAct]].maxShare = _maxSh;
        actList[actPos[_addrAct]].isWork = _isW;
    }

    function editActaddDerivate (address _addrAct, address _derivative) external override {
      actList[actPos[_addrAct]].derivatives.push(_derivative) ;
    }

    function changeBal (address _active, int128 _balance) external override   {
        uint p = actPos[_active];

        actList[p].balance = uint128(int128(uint128(actList[p].balance)) + _balance);
    }

    function getActive (address _addrAct) external override view returns (Active memory) {

        return (actList[actPos[_addrAct]] );
    }

    function getAllActives () external override view returns (Active[] memory ) {
        return actList;
    }

}