// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";

contract FeedRegistryMock {
    using Counters for Counters.Counter;

    mapping(address => mapping(address => uint8)) public decimals;
    mapping(address => mapping(address => int256)) public answers;
    mapping(address => mapping(address => Counters.Counter)) public roundIds;

    bool public mockUpdatedAt;
    bool public mockAnsweredInRound;

    uint256 public mockedUpdatedAt;
    uint80 public mockedAnsweredInRound;

    function useMockedValues(bool _mockUpdatedAt, bool _mockAnsweredInRound) external {
        mockUpdatedAt = _mockUpdatedAt;
        mockAnsweredInRound = _mockAnsweredInRound;
    }

    function setMockedValues(uint256 _mockedUpdatedAt, uint80 _mockedAnsweredInRound) external {
        mockedUpdatedAt = _mockedUpdatedAt;
        mockedAnsweredInRound = _mockedAnsweredInRound;
    }

    function setAnswerFor(address _base, address _quote, int256 _answer, uint8 _decimals) external {
        answers[_base][_quote] = _answer;
        decimals[_base][_quote] = _decimals;
    }

    function latestRoundData(
        address base,
        address quote
    )
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = uint80(roundIds[base][quote].current());
        answer = answers[base][quote];
        startedAt = block.timestamp;
        updatedAt = _updatedAt();
        answeredInRound = _answeredInRound(roundId);
    }

    function _updatedAt() internal view returns (uint256) {
        if (!mockUpdatedAt) return block.timestamp;
        return mockedUpdatedAt;
    }

    function _answeredInRound(uint80 roundId) internal view returns (uint80) {
        if (!mockAnsweredInRound) return roundId;
        return mockedAnsweredInRound;
    }
}
