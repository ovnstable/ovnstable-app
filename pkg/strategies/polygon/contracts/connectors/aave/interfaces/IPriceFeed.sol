// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

interface IPriceFeed {
  // price in USD with 2 additional digits
  function latestAnswer() external view returns (int256);
}
