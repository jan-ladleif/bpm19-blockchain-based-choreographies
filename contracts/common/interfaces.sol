pragma solidity ^0.4.23;

/*
 * Common interface for all choreography contracts. Only these functions and events
 * should be used to communicate with or monitor a choreography.
 */
interface Choreography {
    // events
    event Created(bytes data);
    event Started();
    event Finished(bytes data);
    event TaskRequest(uint8 task, bytes message);
    event TaskResponse(uint8 task, bytes message);
    event SubChoreographyCreated(uint8 subChoreo, bytes data, address subChoreoAddress);
    event SubChoreographyFinished(uint8 subChoreo, bytes data, bool interrupted);
    event ThrewTrigger(uint8 correlation, bytes data);
    event CaughtTrigger(uint8 correlation, bytes data, address origin);
    event UncaughtTrigger(uint8 correlation, bytes data, address origin);
    event Interrupted();
    event Interrupting();

    // external interface methods
    function start() external;
    function sendRequest(uint8 task, bytes message) external;
    function sendResponse(uint8 task, bytes message) external;

    // state methods
    function getTokens() external view returns (uint256 tokens);
    function getParticipants() external view returns (Participants participants);

    // debug events
    event DebugTokens(uint256 tokens);
    event DebugFlowExecuted(uint8 flow);
}

/*
 * Common interface for all choreography factories.
 */
interface ChoreographyFactory {
    event ChoreographyCreated(address choreoAddress, bytes data);
    function create(bytes data) external returns (address choreoAddress);
}

/**
 * Contract that maps the roles of a choreography to actual Ethereum addresses.
 * In practice, instances of this contract could be reused between different
 * instances of the same choreography so participants do not have to register
 * again each time.
 */
interface Participants {
    event ParticipantRegistered(address id, uint8 role);
    
    function registerParticipant(uint8 role)         external;
    function get(uint8 role)                         external view returns (address addr);
    function rolesAreRegistered(uint256 roles)       external view returns (bool result);
    function hasRole(address id, uint8 role)         external view returns (bool result);
    function hasOneRoleOf(address id, uint256 roles) external view returns (bool result);
}