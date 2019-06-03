pragma solidity ^0.4.23;

import "interfaces.sol";

/*
 * Abstract base contract of all choreographies. Provides default implementations
 * of several inter-contract methods needed for managing triggers and sub-
 * choreography creation.
 */
contract BaseChoreography is Choreography {
    // -------------------------------------------------------------------------
    // default inter-contract interface implementations
    // -------------------------------------------------------------------------
    function participants()
        external
        returns (Participants)
    {
    }

    function finishSubChoreography(bool interrupted, bytes data)
        external
    {
    }

    function bubbleTrigger(uint8 correlation, bytes data, address origin)
        external
        returns (bool interrupt)
    {
    }

    function interrupt()
        external
    {
    }
}