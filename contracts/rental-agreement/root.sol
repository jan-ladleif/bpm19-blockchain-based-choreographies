pragma solidity ^0.4.23;

import "base.sol";




//     ___ _                                        _
//    / __| |_  ___ _ _ ___ ___  __ _ _ _ __ _ _ __| |_ _  _
//   | (__| ' \/ _ \ '_/ -_) _ \/ _` | '_/ _` | '_ \ ' \ || |
//    \___|_||_\___/_| \___\___/\__, |_| \__,_| .__/_||_\_, |
//                              |___/         |_|       |__/
contract RentalAgreement_root is BaseChoreography {
    // -------------------------------------------------------------------------
    // data object storage
    // -------------------------------------------------------------------------
    uint16 tenancyAgreement_bond;
    uint16 tenancyAgreement_weeklyRent;

    // -------------------------------------------------------------------------
    // message storage
    // -------------------------------------------------------------------------
    uint32 paymentReceipt_receiptID;
    int32 transferDetailsTenant_timestamp;
    uint32 transferDetailsTenant_transferID;
    int32 transferDetailsLandlord_timestamp;
    uint32 transferDetailsLandlord_transferID;
    uint32 disputeNo_disputeNo;

    // -------------------------------------------------------------------------
    // constants
    // -------------------------------------------------------------------------
    uint8 private constant FLOW_COUNT = 16;
    uint8 private constant SUB_CHOREO_COUNT = 1;
    uint16 private constant INTERRUPTING_FLOWS = 0x0;
    uint16 private constant SELF_INTERRUPTING_FLOWS = 0x0;

    // -------------------------------------------------------------------------
    // member variables
    // -------------------------------------------------------------------------
    enum State {
        WAITING_FOR_PARTICIPANTS,
        RUNNING,
        INTERRUPTING,
        INTERRUPTED,
        FINISHED
    }

    State state; // current state of the choreography
    Participants public participants; // participants container
    uint16 tokens; // token map
    uint8 waitingForResponse; // map indicating tasks waiting for a response
    uint8 subChoreographyCount = 0; // count of currently running sub-choreographies
    mapping(address => uint8) subChoreographies; // map from contract instance to sub-choreo index (+1)
    mapping(uint8 => address) subChoreographiesInverse; // map from sub-choreo index to contract instance

    // -------------------------------------------------------------------------
    // constructor
    // -------------------------------------------------------------------------
    constructor(address addr, bytes memory data) public {
        participants = Participants(addr);

        // assign the global input data objects
        assembly {sstore(tenancyAgreement_bond_slot,or(and(sload(tenancyAgreement_bond_slot),not(mul(0xffff, exp(256, tenancyAgreement_bond_offset)))),mul(and(mload(add(data,2)),0xffff),exp(256, tenancyAgreement_bond_offset))))sstore(tenancyAgreement_weeklyRent_slot,or(and(sload(tenancyAgreement_weeklyRent_slot),not(mul(0xffff, exp(256, tenancyAgreement_weeklyRent_offset)))),mul(and(mload(add(data,4)),0xffff),exp(256, tenancyAgreement_weeklyRent_offset))))}
        emit Created(data);
    }

    // -------------------------------------------------------------------------
    // external view functions
    // -------------------------------------------------------------------------
    function getTokens()
        external
        view
        returns (uint256)
    {
        return uint256(tokens);
    }

    function getParticipants()
        external
        view
        returns (Participants)
    {
        return participants;
    }

    // -------------------------------------------------------------------------
    // external interface functions
    // -------------------------------------------------------------------------
    function start()
        external
    {
        require(state == State.WAITING_FOR_PARTICIPANTS);
        require(participants.rolesAreRegistered(0x0));

        // start the choreography
        state = State.RUNNING;
        emit Started();
            propagateFlow(0);
    }

    function sendRequest(uint8 task, bytes message)
        external
    {
        require(state == State.RUNNING || state == State.INTERRUPTING);

        // check if the sender is allowed to send this request
        require (participants.hasRole(msg.sender, [0, 1, 2, 1, 0, 2, 0][task]));

        // check if task is enabled and consume token
        uint16 incoming = (uint16(1) << [3, 8, 9, 8, 12, 13, 12][task]);
        require (tokens & incoming > 0);
        tokens ^= incoming;

        // save message data
        if (task == 0) {
            assembly {sstore(paymentReceipt_receiptID_slot,or(and(sload(paymentReceipt_receiptID_slot),not(mul(0xffffffff, exp(256, paymentReceipt_receiptID_offset)))),mul(and(calldataload(72),0xffffffff),exp(256, paymentReceipt_receiptID_offset))))}
        }
        else if (task == 2) {
            assembly {sstore(transferDetailsTenant_timestamp_slot,or(and(sload(transferDetailsTenant_timestamp_slot),not(mul(0xffffffff, exp(256, transferDetailsTenant_timestamp_offset)))),mul(and(calldataload(72),0xffffffff),exp(256, transferDetailsTenant_timestamp_offset))))sstore(transferDetailsTenant_transferID_slot,or(and(sload(transferDetailsTenant_transferID_slot),not(mul(0xffffffff, exp(256, transferDetailsTenant_transferID_offset)))),mul(and(calldataload(76),0xffffffff),exp(256, transferDetailsTenant_transferID_offset))))}
        }
        else if (task == 5) {
            assembly {sstore(transferDetailsLandlord_timestamp_slot,or(and(sload(transferDetailsLandlord_timestamp_slot),not(mul(0xffffffff, exp(256, transferDetailsLandlord_timestamp_offset)))),mul(and(calldataload(72),0xffffffff),exp(256, transferDetailsLandlord_timestamp_offset))))sstore(transferDetailsLandlord_transferID_slot,or(and(sload(transferDetailsLandlord_transferID_slot),not(mul(0xffffffff, exp(256, transferDetailsLandlord_transferID_offset)))),mul(and(calldataload(76),0xffffffff),exp(256, transferDetailsLandlord_transferID_offset))))}
        }

        // log the request
        emit TaskRequest(task, message);

            // indicate we are waiting for a response or finish the task
            if (0x40 & (uint8(1) << task) > 0) {
                waitingForResponse |= (uint8(1) << task);
            } else {
                finishTask(task);
            }
    }

    function sendResponse(uint8 task, bytes message)
        external
    {
        require(state == State.RUNNING || state == State.INTERRUPTING);
        require(waitingForResponse & (uint8(1) << task) > 0);

        // check if the sender is allowed to send this response
        require (participants.hasRole(msg.sender, [2, 2, 0, 2, 2, 1, 2][task]));

        // save message data
        if (task == 6) {
            assembly {sstore(disputeNo_disputeNo_slot,or(and(sload(disputeNo_disputeNo_slot),not(mul(0xffffffff, exp(256, disputeNo_disputeNo_offset)))),mul(and(calldataload(72),0xffffffff),exp(256, disputeNo_disputeNo_offset))))}
        }

        // log the response
        emit TaskResponse(task, message);

            // finish the task
            waitingForResponse ^= (uint8(1) << task);
            finishTask(task);
    }

    // -------------------------------------------------------------------------
    // external inter-contract functions
    // -------------------------------------------------------------------------
    function participants()
        external
        returns (Participants)
    {
        return participants;
    }

    function finishSubChoreography(bool interrupted, bytes data)
        external
    {
        if (state != State.RUNNING) {
            return;
        }

        // check if the caller is a valid sub-choreography
        require(subChoreographies[msg.sender] > 0);
        uint8 subChoreo = subChoreographies[msg.sender] - 1;


        // stop the sub-choreography which called this method
        unlinkSubChoreography(subChoreo);
        subChoreographyCount--;
        emit SubChoreographyFinished(subChoreo, data, interrupted);

        // propagate regular flow if the subchoreo has not been interrupted
            if (!interrupted) {
                propagateFlow([6][subChoreo]);
            }
    }

    function bubbleTrigger(uint8 correlation, bytes data, address origin)
        external
        returns (bool interrupt)
    {
        // check if the caller is a valid sub-choreography or the contract itself
        require(subChoreographies[msg.sender] > 0 || msg.sender == address(this));
        if (msg.sender == address(this)) {
            emit ThrewTrigger(correlation, data);
        }


        // trigger could not be caught
        emit UncaughtTrigger(correlation, data, origin);
    }

    function interrupt()
        external
    {
        require (msg.sender == address(this));
        if (state == State.RUNNING) {
            clear();
            state = State.INTERRUPTING;
            emit Interrupting();
        }
    }

    // -------------------------------------------------------------------------
    // private functions
    // -------------------------------------------------------------------------
    function clear()
        private
    {
        // interrupt all children
        for (uint8 i = 0; i < SUB_CHOREO_COUNT; i++) {
            if (subChoreographiesInverse[i] != 0x0) {
                BaseChoreography(subChoreographiesInverse[i]).interrupt();
                unlinkSubChoreography(i);
            }
        }
        delete subChoreographyCount;
        delete tokens;
        delete waitingForResponse;
    }


    function unlinkSubChoreography(uint8 subChoreo)
        private
    {
        delete subChoreographies[subChoreographiesInverse[subChoreo]];
        delete subChoreographiesInverse[subChoreo];
    }

    function startSubChoreography(uint8 subChoreo)
        private
    {
        // make sure the subchoreo is not currently running
        // (should not happen for 1-safe choreos)
        require(subChoreographiesInverse[subChoreo] == 0x0);

        // acquire the input data for the sub-choreography
        bytes memory data = new bytes(0);
            if (subChoreo == 0) {
                data = new bytes(4);
                assembly {mstore(add(data, 32),mul(and(div(sload(tenancyAgreement_bond_slot),exp(256, tenancyAgreement_bond_offset)),0xffff),exp(256, 30)))mstore(add(data, 34),mul(and(div(sload(tenancyAgreement_weeklyRent_slot),exp(256,tenancyAgreement_weeklyRent_offset)),0xffff),exp(256, 30)))}
            }

        // create the subchoreography contract
        address subChoreoAddress = ChoreographyFactory(
            [0x7fAa6179f663EB000bd4CD39f68c21aCdDd39413][subChoreo]
        ).create(data);
        subChoreographies[subChoreoAddress] = subChoreo + 1;
        subChoreographiesInverse[subChoreo] = subChoreoAddress;
        subChoreographyCount++;
        emit SubChoreographyCreated(subChoreo, data, subChoreoAddress);
    }

    function finishTask(uint8 task)
        private
    {
        // propagate the enablement of all outgoing sequence flows
        propagateFlow([
            5, 9, 10, 11, 13, 14, 15
        ][task]);
    }

    function executeFlow(uint8 flowIndex)
        private
        returns (bool interrupt)
    {
        bytes memory data;
        if (flowIndex == 2) {
            data = new bytes(0);
            interrupt = this.bubbleTrigger(0, data, address(this));
        }
        else if (flowIndex == 4) {
            startSubChoreography(0);
        }
        else if (flowIndex == 15) {
            data = new bytes(0);
            interrupt = this.bubbleTrigger(1, data, address(this));
        }
            }

    function propagateFlow(uint8 flowIndex)
        private
    {
        uint16[FLOW_COUNT] memory successors = [
            uint16(0x6), 0x18, 0x0, 0x0, 0x0, 0x080, 0x080, 0x100, 0x0, 0x0, 0x0, 0x1000, 0x0, 0x0, 0x0, 0x0
        ];
        uint16[FLOW_COUNT] memory consumeMaps = [
            uint16(0x1), 0x2, 0x4, 0x08, 0x10, 0x60, 0x60, 0x080, 0x100, 0x200, 0x400, 0x0800, 0x1000, 0x2000, 0x4000, 0x08000
        ];

        uint16 curTokens = tokens;
        uint16 toVisit = (uint16(1) << flowIndex);
        uint16 toVisitNext;

        // while we still have flows to visit
        while (toVisit > 0) {
            // mark current set as visited
            curTokens |= toVisit;
            toVisitNext = 0;

            // get all the successors of the nodes we are visiting
            for (uint8 i = 0; i < FLOW_COUNT; i++) {
                if (toVisit & ~uint16(0x3308) & (uint16(1) << i) > 0) {
                    // perform data-based exclusive split
                    if (i == 0) {
                        if (tenancyAgreement_bond > 4 * tenancyAgreement_weeklyRent) {
                            toVisitNext |= uint16(4);
                        }
                        else {
                            toVisitNext |= uint16(2);
                        }
                        curTokens &= ~uint16(0x1);
                        continue;
                    }
                    // propagate the flow if possible
                    if (curTokens | consumeMaps[i] == curTokens)
                    {
                        toVisitNext |= successors[i];
                        if (executeFlow(i) || state == State.INTERRUPTED) {
                            // interrupt
                            toVisitNext = 0;
                            curTokens = tokens;
                            break;
                        }
                        curTokens ^= consumeMaps[i];
                    }
                }
            }

            toVisit = toVisitNext;
        }

        // commit the propagation
        if (state == State.INTERRUPTING || state == State.RUNNING) {
            tokens = curTokens;

            // potentially finish this choreo
            if (tokens == 0 &&
                subChoreographyCount == 0 &&
                waitingForResponse == 0)
            {
                // mark the choreography as finished
                if (state == State.INTERRUPTING) {
                    state = State.INTERRUPTED;
                    emit Interrupted();
                    return;
                }
                state = State.FINISHED;
                emit Finished(new bytes(0));
            }
        }
    }
}