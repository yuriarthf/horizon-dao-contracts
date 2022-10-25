// Utility functions for BigNumber type

// Import BigNumber
import { BigNumber, BigNumberish } from "@ethersproject/bignumber";

// Import randomBytes for random uint256 generation
import { randomBytes } from "crypto";

/**
 * @dev Add decimal points to number in solidity fashion
 *
 * @param num Number to concatenate with provided decimals
 * @param decimals Decimal points to add
 * @return BigNumber concatenated with given decimals
 */
export function addDecimalPoints(num: BigNumberish, decimals = 18): BigNumber {
  return BigNumber.from(num).mul(BigNumber.from(10).pow(decimals));
}

/**
 * @dev Truncate BigNumber to 256 bits
 *
 * @param bn BigNumber to be truncated
 * @return Truncated BigNumber
 */
export function uint256(bn: BigNumber): BigNumber {
  return bn.and(BigNumber.from(2).pow(256).sub(1));
}

/**
 * @dev Get a random uint256 BigNumber
 *
 * @return Random uint256 BigNumber
 */
export function randomUint256(): BigNumber {
  return BigNumber.from(randomBytes(32));
}
