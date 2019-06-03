pragma solidity ^0.4.23;

import "base.sol";



//    ___        _
//   | __|_ _ __| |_ ___ _ _ _  _
//   | _/ _` / _|  _/ _ \ '_| || |
//   |_|\__,_\__|\__\___/_|  \_, |
//                           |__/
contract Factory_RentalAgreement_root_0 is ChoreographyFactory {
    function create(bytes data)
        external
        returns (address newContract)
    {
        newContract = new RentalAgreement_root_0(msg.sender, data);
        ChoreographyCreated(newContract, data);
    }
}

//     ___ _                                        _
//    / __| |_  ___ _ _ ___ ___  __ _ _ _ __ _ _ __| |_ _  _
//   | (__| ' \/ _ \ '_/ -_) _ \/ _` | '_/ _` | '_ \ ' \ || |
//    \___|_||_\___/_| \___\___/\__, |_| \__,_| .__/_||_\_, |
//                              |___/         |_|       |__/
contract RentalAgreement_root_0 is BaseChoreography {
    // -------------------------------------------------------------------------
    // data object storage
    // -------------------------------------------------------------------------
    uint16 tenancyAgreementInner_bond;
    uint16 tenancyAgreementInner_weeklyRent;

    // -------------------------------------------------------------------------
    // message storage
    // -------------------------------------------------------------------------
    uint32 paymentReceipt_receiptID;

    // -------------------------------------------------------------------------
    // constants
    // -------------------------------------------------------------------------
    uint8 private constant FLOW_COUNT = 5;
    uint8 private constant SUB_CHOREO_COUNT = 0;
    uint8 private constant INTERRUPTING_FLOWS = 0x0;
    uint8 private constant SELF_INTERRUPTING_FLOWS = 0x0;

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
    uint8 tokens; // token map
    uint8 waitingForResponse; // map indicating tasks waiting for a response
    BaseChoreography parent; // address of the parent choreography instance

    // -------------------------------------------------------------------------
    // constructor
    // -------------------------------------------------------------------------
    constructor(address addr, bytes memory data) public {
        parent = BaseChoreography(addr);
        participants = parent.participants();

        // assign the global input data objects
        assembly {sstore(tenancyAgreementInner_bond_slot,or(and(sload(tenancyAgreementInner_bond_slot),not(mul(0xffff, exp(256, tenancyAgreementInner_bond_offset)))),mul(and(mload(add(data,2)),0xffff),exp(256, tenancyAgreementInner_bond_offset))))sstore(tenancyAgreementInner_weeklyRent_slot,or(and(sload(tenancyAgreementInner_weeklyRent_slot),not(mul(0xffff, exp(256, tenancyAgreementInner_weeklyRent_offset)))),mul(and(mload(add(data,4)),0xffff),exp(256, tenancyAgreementInner_weeklyRent_offset))))}
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
        require (participants.hasRole(msg.sender, [0, 0][task]));

        // check if task is enabled and consume token
        uint8 incoming = (uint8(1) << [3, 3][task]);
        require (tokens & incoming > 0);
        tokens ^= incoming;

        // save message data
        if (task == 0) {
            assembly {sstore(paymentReceipt_receiptID_slot,or(and(sload(paymentReceipt_receiptID_slot),not(mul(0xffffffff, exp(256, paymentReceipt_receiptID_offset)))),mul(and(calldataload(72),0xffffffff),exp(256, paymentReceipt_receiptID_offset))))}
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
            1, 4
        ][task]);
    }

    function executeFlow(uint8 flowIndex)
        private
        returns (bool interrupt)
    {
        bytes memory data;
            }

    function propagateFlow(uint8 flowIndex)
        private
    {
        uint8[FLOW_COUNT] memory successors = [
            uint8(0x4), 0x4, 0x08, 0x0, 0x0
        ];
        uint8[FLOW_COUNT] memory consumeMaps = [
            uint8(0x1), 0x2, 0x4, 0x08, 0x10
        ];

        uint8 curTokens = tokens;
        uint8 toVisit = (uint8(1) << flowIndex);
        uint8 toVisitNext;

        // while we still have flows to visit
        while (toVisit > 0) {
            // mark current set as visited
            curTokens |= toVisit;
            toVisitNext = 0;

            // get all the successors of the nodes we are visiting
            for (uint8 i = 0; i < FLOW_COUNT; i++) {
                if (toVisit & ~uint8(0x08) & (uint8(1) << i) > 0) {
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
                parent.finishSubChoreography(false, new bytes(0));
                emit Finished(new bytes(0));
            }
        }
    }
}