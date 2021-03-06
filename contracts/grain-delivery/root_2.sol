pragma solidity ^0.4.23;

import "base.sol";

contract Factory_GrainDelivery_Withdrawal is ChoreographyFactory {
    function create(bytes data)
        external
        returns (address newContract)
    {
        newContract = new GrainDelivery_Withdrawal(msg.sender, data);
        ChoreographyCreated(newContract, data);
    }
}

contract GrainDelivery_Withdrawal is BaseChoreography {
    // -------------------------------------------------------------------------
    // data object storage
    // -------------------------------------------------------------------------
    uint16 withdrawalAmount_amount;

    // -------------------------------------------------------------------------
    // message storage
    // -------------------------------------------------------------------------
    uint16 accountDetails_bsb;
    uint32 accountDetails_account;

    // -------------------------------------------------------------------------
    // constants
    // -------------------------------------------------------------------------
    uint8 private constant FLOW_COUNT = 3;
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
        assembly {sstore(withdrawalAmount_amount_slot,or(and(sload(withdrawalAmount_amount_slot),not(mul(0xffff, exp(256, withdrawalAmount_amount_offset)))),mul(and(mload(add(data,2)),0xffff),exp(256, withdrawalAmount_amount_offset))))}
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
        require (participants.hasRole(msg.sender, [0, 2][task]));

        // check if task is enabled and consume token
        uint8 incoming = (uint8(1) << [0, 1][task]);
        require (tokens & incoming > 0);
        tokens ^= incoming;

        // save message data
        if (task == 0) {
            assembly {sstore(accountDetails_bsb_slot,or(and(sload(accountDetails_bsb_slot),not(mul(0xffff, exp(256, accountDetails_bsb_offset)))),mul(and(calldataload(70),0xffff),exp(256, accountDetails_bsb_offset))))sstore(accountDetails_account_slot,or(and(sload(accountDetails_account_slot),not(mul(0xffffffff, exp(256, accountDetails_account_offset)))),mul(and(calldataload(74),0xffffffff),exp(256, accountDetails_account_offset))))}
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
            1, 2
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
            uint8(0x0), 0x0, 0x0
        ];
        uint8[FLOW_COUNT] memory consumeMaps = [
            uint8(0x1), 0x2, 0x4
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
                if (toVisit & ~uint8(0x3) & (uint8(1) << i) > 0) {
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
