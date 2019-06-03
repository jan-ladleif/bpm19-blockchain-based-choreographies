pragma solidity ^0.4.23;

import "base.sol";



//    ___        _
//   | __|_ _ __| |_ ___ _ _ _  _
//   | _/ _` / _|  _/ _ \ '_| || |
//   |_|\__,_\__|\__\___/_|  \_, |
//                           |__/
contract Factory_InterlineAgreement_root_0 is ChoreographyFactory {
    function create(bytes data)
        external
        returns (address newContract)
    {
        newContract = new InterlineAgreement_root_0(msg.sender, data);
        ChoreographyCreated(newContract, data);
    }
}

//     ___ _                                        _
//    / __| |_  ___ _ _ ___ ___  __ _ _ _ __ _ _ __| |_ _  _
//   | (__| ' \/ _ \ '_/ -_) _ \/ _` | '_/ _` | '_ \ ' \ || |
//    \___|_||_\___/_| \___\___/\__, |_| \__,_| .__/_||_\_, |
//                              |___/         |_|       |__/
contract InterlineAgreement_root_0 is BaseChoreography {
    // -------------------------------------------------------------------------
    // data object storage
    // -------------------------------------------------------------------------
    uint32 total_charge;

    // -------------------------------------------------------------------------
    // message storage
    // -------------------------------------------------------------------------
    uint8 request_noOfSeats;
    uint32 offer_pricePerSeat;

    // -------------------------------------------------------------------------
    // constants
    // -------------------------------------------------------------------------
    uint8 private constant FLOW_COUNT = 9;
    uint8 private constant SUB_CHOREO_COUNT = 0;
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
    BaseChoreography parent; // address of the parent choreography instance

    // -------------------------------------------------------------------------
    // constructor
    // -------------------------------------------------------------------------
    constructor(address addr, bytes memory data) public {
        parent = BaseChoreography(addr);
        participants = parent.participants();
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
        require (participants.hasRole(msg.sender, [0, 1, 1, 0, 0][task]));

        // check if task is enabled and consume token
        uint16 incoming = (uint16(1) << [0, 2, 2, 6, 6][task]);
        require (tokens & incoming > 0);
        tokens ^= incoming;

        // save message data
        if (task == 0) {
            assembly {sstore(request_noOfSeats_slot,or(and(sload(request_noOfSeats_slot),not(mul(0xff, exp(256, request_noOfSeats_offset)))),mul(and(calldataload(69),0xff),exp(256, request_noOfSeats_offset))))}
        }
        else if (task == 2) {
            assembly {sstore(offer_pricePerSeat_slot,or(and(sload(offer_pricePerSeat_slot),not(mul(0xffffffff, exp(256, offer_pricePerSeat_offset)))),mul(and(calldataload(72),0xffffffff),exp(256, offer_pricePerSeat_offset))))}
        }

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


    function bubbleTrigger(uint8 correlation, bytes data, address origin)
        external
        returns (bool interrupt)
    {
        // check if the caller is a valid sub-choreography or the contract itself
        require(msg.sender == address(this));
        emit ThrewTrigger(correlation, data);


        // bubble up
        return parent.bubbleTrigger(correlation, data, origin);
    }

    function interrupt()
        external
    {
        require (msg.sender == address(this) || msg.sender == address(parent));

        if (msg.sender == address(parent)) {
            clear();
            state = State.INTERRUPTED;
            emit Interrupted();
        } else
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
        delete tokens;
        delete waitingForResponse;
    }



    function finishTask(uint8 task)
        private
    {
        // propagate the enablement of all outgoing sequence flows
        propagateFlow([
            1, 3, 4, 7, 8
        ][task]);
    }

    function executeFlow(uint8 flowIndex)
        private
        returns (bool interrupt)
    {
        bytes memory data;
        if (flowIndex == 3) {
            data = new bytes(0);
            interrupt = this.bubbleTrigger(0, data, address(this));
        }
        else if (flowIndex == 4) {
            total_charge = request_noOfSeats * offer_pricePerSeat;
        }
        else if (flowIndex == 7) {
            data = new bytes(0);
            interrupt = this.bubbleTrigger(0, data, address(this));
        }
            }

    function propagateFlow(uint8 flowIndex)
        private
    {
        uint16[FLOW_COUNT] memory successors = [
            uint16(0x0), 0x4, 0x0, 0x0, 0x20, 0x40, 0x0, 0x0, 0x0
        ];
        uint16[FLOW_COUNT] memory consumeMaps = [
            uint16(0x1), 0x2, 0x4, 0x08, 0x10, 0x20, 0x40, 0x080, 0x100
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
                if (toVisit & ~uint16(0x45) & (uint16(1) << i) > 0) {
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
                waitingForResponse == 0)
            {
                // mark the choreography as finished
                if (state == State.INTERRUPTING) {
                    state = State.INTERRUPTED;
                    parent.finishSubChoreography(true, new bytes(0));
                    emit Interrupted();
                    return;
                }
                state = State.FINISHED;
                bytes memory data = new bytes(4);
                assembly {mstore(add(data, 32),mul(and(div(sload(total_charge_slot),exp(256, total_charge_offset)),0xffffffff),exp(256, 28)))}
                parent.finishSubChoreography(false, data);
                emit Finished(data);
            }
        }
    }
}