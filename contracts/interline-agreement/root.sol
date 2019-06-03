pragma solidity ^0.4.23;

import "base.sol";




//     ___ _                                        _
//    / __| |_  ___ _ _ ___ ___  __ _ _ _ __ _ _ __| |_ _  _
//   | (__| ' \/ _ \ '_/ -_) _ \/ _` | '_/ _` | '_ \ ' \ || |
//    \___|_||_\___/_| \___\___/\__, |_| \__,_| .__/_||_\_, |
//                              |___/         |_|       |__/
contract InterlineAgreement_root is BaseChoreography {
    // -------------------------------------------------------------------------
    // data object storage
    // -------------------------------------------------------------------------
    uint32 chargeA_charge;
    uint32 chargeB_charge;
    uint32 history_debtA;
    uint32 history_debtB;
    uint64 history_lastSettlement;
    int40 tally_tally;


    // -------------------------------------------------------------------------
    // constants
    // -------------------------------------------------------------------------
    uint8 private constant FLOW_COUNT = 31;
    uint8 private constant SUB_CHOREO_COUNT = 2;
    uint32 private constant INTERRUPTING_FLOWS = 0x084;
    uint32 private constant SELF_INTERRUPTING_FLOWS = 0x0;
    uint8 private constant EVENT_CATCH_BLOOM = 0x1;

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
    uint32 tokens; // token map
    uint8 waitingForResponse; // map indicating tasks waiting for a response
    uint8 subChoreographyCount = 0; // count of currently running sub-choreographies
    mapping(address => uint8) subChoreographies; // map from contract instance to sub-choreo index (+1)
    mapping(uint8 => address) subChoreographiesInverse; // map from sub-choreo index to contract instance

    // -------------------------------------------------------------------------
    // constructor
    // -------------------------------------------------------------------------
    constructor(address addr, bytes memory data) public {
        participants = Participants(addr);
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
            propagateFlow(5);
            propagateFlow(10);
            propagateFlow(16);
    }

    function sendRequest(uint8 task, bytes message)
        external
    {
        require(state == State.RUNNING || state == State.INTERRUPTING);

        // check if the sender is allowed to send this request
        require (participants.hasRole(msg.sender, [0, 1, 0, 1, 0, 1][task]));

        // check if task is enabled and consume token
        uint32 incoming = (uint32(1) << [11, 12, 18, 18, 25, 26][task]);
        require (tokens & incoming > 0);
        tokens ^= incoming;


        // log the request
        emit TaskRequest(task, message);

            // indicate we are waiting for a response or finish the task
            if (0x0 & (uint8(1) << task) > 0) {
                waitingForResponse |= (uint8(1) << task);
            } else {
                finishTask(task);
            }
    }

    function sendResponse(uint8 task, bytes message)
        external
    {
        revert();
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

        if (subChoreo == 0) {
            assembly {sstore(chargeA_charge_slot,or(and(sload(chargeA_charge_slot),not(mul(0xffffffff, exp(256, chargeA_charge_offset)))),mul(and(calldataload(72),0xffffffff),exp(256, chargeA_charge_offset))))}
        }
        else if (subChoreo == 1) {
            assembly {sstore(chargeB_charge_slot,or(and(sload(chargeB_charge_slot),not(mul(0xffffffff, exp(256, chargeB_charge_offset)))),mul(and(calldataload(72),0xffffffff),exp(256, chargeB_charge_offset))))}
        }

        // stop the sub-choreography which called this method
        unlinkSubChoreography(subChoreo);
        subChoreographyCount--;
        emit SubChoreographyFinished(subChoreo, data, interrupted);

        // propagate regular flow if the subchoreo has not been interrupted
            if (!interrupted) {
                propagateFlow([3, 8][subChoreo]);
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

        // quick bloom filter to check if we even have a catching event for this trigger
        if (EVENT_CATCH_BLOOM & (uint8(1) << correlation) > 0) {
            int16 flow = -1;

            // catch boundary events
            uint8 subChoreo = subChoreographies[msg.sender];
            if (subChoreo == 1) {
                if (correlation == 0) {
                    flow = 2;
                }
            }
            else if (subChoreo == 2) {
                if (correlation == 0) {
                    flow = 7;
                }
            }


            // if we caught a trigger, perform the associated actions
            if (flow >= 0) {
                emit CaughtTrigger(correlation, data, origin);

                // interrupt ourselves if necessary
                if (SELF_INTERRUPTING_FLOWS & (uint32(1) << flow) > 0) {
                    this.interrupt();
                    propagateFlow(uint8(flow));
                    return true;
                }

                // interrupt a subchoreo if necessary
                if (INTERRUPTING_FLOWS & (uint32(1) << flow) > 0) {
                    BaseChoreography(msg.sender).interrupt();
                    unlinkSubChoreography(subChoreo - 1);
                    subChoreographyCount--;
                    interrupt = true;
                }

                    propagateFlow(uint8(flow));
                return;
            }
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

        // create the subchoreography contract
        address subChoreoAddress = ChoreographyFactory(
            [0x5D9D099993c5890344403D71FDFC3E35eFEf1EA0, 0xFF44b1b32b5767De2605126B70E261401920DC52][subChoreo]
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
            13, 14, 19, 20, 28, 29
        ][task]);
    }

    function executeFlow(uint8 flowIndex)
        private
        returns (bool interrupt)
    {
        bytes memory data;
        if (flowIndex == 1) {
            startSubChoreography(0);
        }
        else if (flowIndex == 3) {
            history_debtA += chargeA_charge;
        }
        else if (flowIndex == 6) {
            startSubChoreography(1);
        }
        else if (flowIndex == 8) {
            history_debtB += chargeB_charge;
        }
        else if (flowIndex == 15) {
            data = new bytes(0);
            interrupt = this.bubbleTrigger(1, data, address(this));
        }
        else if (flowIndex == 22) {
            tally_tally = history_debtA - history_debtB;history_debtA = 0;history_debtB = 0;history_lastSettlement = uint64(now);
        }
            }

    function propagateFlow(uint8 flowIndex)
        private
    {
        uint32[FLOW_COUNT] memory successors = [
            uint32(0x2), 0x0, 0x2, 0x10, 0x2, 0x40, 0x0, 0x40, 0x200, 0x40, 0x1800, 0x0, 0x0, 0x08000, 0x08000, 0x0, 0x20000, 0x40000, 0x0, 0x200000, 0x200000, 0x0c00000, 0x1000000, 0x20000, 0x0e000000, 0x0, 0x0, 0x40000000, 0x40000000, 0x40000000, 0x20000
        ];
        uint32[FLOW_COUNT] memory consumeMaps = [
            uint32(0x1), 0x2, 0x4, 0x08, 0x10, 0x20, 0x40, 0x080, 0x100, 0x200, 0x400, 0x0800, 0x1000, 0x6000, 0x6000, 0x08000, 0x10000, 0x20000, 0x40000, 0x080000, 0x100000, 0x200000, 0x400000, 0x0800000, 0x1000000, 0x2000000, 0x4000000, 0x08000000, 0x10000000, 0x20000000, 0x40000000
        ];

        uint32 curTokens = tokens;
        uint32 toVisit = (uint32(1) << flowIndex);
        uint32 toVisitNext;

        // while we still have flows to visit
        while (toVisit > 0) {
            // mark current set as visited
            curTokens |= toVisit;
            toVisitNext = 0;

            // get all the successors of the nodes we are visiting
            for (uint8 i = 0; i < FLOW_COUNT; i++) {
                if (toVisit & ~uint32(0x6041800) & (uint32(1) << i) > 0) {
                    // perform data-based exclusive split
                    if (i == 21) {
                        if (now < history_lastSettlement + 30 days) {
                            toVisitNext |= uint32(8388608);
                        }
                        else {
                            toVisitNext |= uint32(4194304);
                        }
                        curTokens &= ~uint32(0x200000);
                        continue;
                    }
                    // perform data-based exclusive split
                    else if (i == 24) {
                        if (tally_tally > 0) {
                            toVisitNext |= uint32(33554432);
                        }
                        else if (tally_tally < 0) {
                            toVisitNext |= uint32(67108864);
                        }
                        else {
                            toVisitNext |= uint32(134217728);
                        }
                        curTokens &= ~uint32(0x1000000);
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