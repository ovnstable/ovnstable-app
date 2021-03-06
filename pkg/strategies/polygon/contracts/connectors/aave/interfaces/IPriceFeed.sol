// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

interface IPriceFeed {
  function latestAnswer() external view returns (int256);
}