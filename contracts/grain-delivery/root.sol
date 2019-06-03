pragma solidity ^0.4.23;

import "base.sol";

contract GrainDelivery_Root is BaseChoreography {
  // data object storage
  uint16 depositAmount_amount;
  uint8 summary_grade;
  uint16 summary_tonnes;
  uint16 refund_amount;
  uint16 payment_amount;
  uint8 orderDetails_grade;
  uint16 orderDetails_tonnes;
  uint16 orderDetails_tolerance;
  uint16 orderDetails_price;
  address grainTitle_addr;

  // constants
  uint8 private constant FLOW_COUNT = 19;
  uint8 private constant SUB_CHOREO_COUNT = 4;
  uint24 private constant INTERRUPTING_FLOWS = 0x0;
  uint24 private constant SELF_INTERRUPTING_FLOWS = 0x0;

  // member variables
  enum State {
    WAITING_FOR_PARTICIPANTS,
    RUNNING,
    INTERRUPTING,
    INTERRUPTED,
    FINISHED
  }

  State state;
  Participants public participants;
  uint24 tokens;
  uint8 waitingForResponse;
  uint8 subChoreographyCount = 0;
  mapping(address => uint8) subChoreographies;
  mapping(uint8 => address) subChoreographiesInverse;

  // constructor
  constructor(address addr, bytes memory data) public {
    participants = Participants(addr);

    // assign the global input data objects
    assembly {
      sstore(orderDetails_grade_slot,or(and(sload(orderDetails_grade_slot),not(mul(0xff, exp(256, orderDetails_grade_offset)))),mul(and(mload(add(data,1)),0xff),exp(256, orderDetails_grade_offset))))
      sstore(orderDetails_tonnes_slot,or(and(sload(orderDetails_tonnes_slot),not(mul(0xffff, exp(256, orderDetails_tonnes_offset)))),mul(and(mload(add(data,3)),0xffff),exp(256, orderDetails_tonnes_offset))))
      sstore(orderDetails_tolerance_slot,or(and(sload(orderDetails_tolerance_slot),not(mul(0xffff, exp(256, orderDetails_tolerance_offset)))),mul(and(mload(add(data,5)),0xffff),exp(256, orderDetails_tolerance_offset))))
      sstore(orderDetails_price_slot,or(and(sload(orderDetails_price_slot),not(mul(0xffff, exp(256, orderDetails_price_offset)))),mul(and(mload(add(data,7)),0xffff),exp(256, orderDetails_price_offset))))
      sstore(grainTitle_addr_slot,or(and(sload(grainTitle_addr_slot),not(mul(0xffffffffffffffffffffffffffffffffffffffff, exp(256, grainTitle_addr_offset)))),mul(and(mload(add(data,27)),0xffffffffffffffffffffffffffffffffffffffff),exp(256, grainTitle_addr_offset))))
    }
    emit Created(data);
  }

  // external view functions
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

  // external interface functions
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
    require (participants.hasRole(msg.sender, [0][task]));

    // check if task is enabled and consume token
    uint24 incoming = (uint24(1) << [0][task]);
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

  // external inter-contract functions
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

    if (subChoreo == 1) {
      assembly {
        sstore(summary_grade_slot,or(and(sload(summary_grade_slot),not(mul(0xff, exp(256, summary_grade_offset)))),mul(and(calldataload(69),0xff),exp(256, summary_grade_offset))))
        sstore(summary_tonnes_slot,or(and(sload(summary_tonnes_slot),not(mul(0xffff, exp(256, summary_tonnes_offset)))),mul(and(calldataload(71),0xffff),exp(256, summary_tonnes_offset))))
      }
    }

    // stop the sub-choreography which called this method
    unlinkSubChoreography(subChoreo);
    subChoreographyCount--;
    emit SubChoreographyFinished(subChoreo, data, interrupted);

    // propagate regular flow if the subchoreo has not been interrupted
    if (!interrupted) {
      propagateFlow([7, 8, 15, 16][subChoreo]);
    }
  }

  function bubbleTrigger(uint8 correlation, bytes data, address origin)
    external
    returns (bool interrupt)
  {
    // check if the caller is a valid sub-choreography
    // or the contract itself
    require(subChoreographies[msg.sender] > 0 ||
            msg.sender == address(this));
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

  // private functions
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
      data = new bytes(2);
      assembly {
        mstore(add(data, 32),mul(and(div(sload(depositAmount_amount_slot),exp(256, depositAmount_amount_offset)),0xffff),exp(256, 30)))
      }
    }
    else if (subChoreo == 2) {
      data = new bytes(2);
      assembly {
        mstore(add(data, 32),mul(and(div(sload(refund_amount_slot),exp(256, refund_amount_offset)),0xffff),exp(256, 30)))
      }
    }
    else if (subChoreo == 3) {
      data = new bytes(2);
      assembly {
        mstore(add(data, 32),mul(and(div(sload(payment_amount_slot),exp(256, payment_amount_offset)),0xffff),exp(256, 30)))
      }
    }

    // create the subchoreography contract
    address subChoreoAddress = ChoreographyFactory([
      0x8a86fF3507786098F293d28c8887092384b39454,
      0xf592F55fCbc14c4C8f1d422543be7C9632ABB0fA,
      0xAFe4C496436DD3e2F3137F7afB64fCF9425Eb0Ef,
      0x7114a0bF5343A0Ce9C76939c779b63D1e4a190e6
    ][subChoreo]).create(data);
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
      1
    ][task]);
  }

  function executeFlow(uint8 flowIndex)
    private
    returns (bool interrupt)
  {
    bytes memory data;
    if (flowIndex == 2) {
      depositAmount_amount = (orderDetails_tonnes + orderDetails_tolerance) * orderDetails_price;
    }
    else if (flowIndex == 3) {
      data = new bytes(0);
      interrupt = this.bubbleTrigger(0, data, address(this));
    }
    else if (flowIndex == 4) {
      startSubChoreography(0);
    }
    else if (flowIndex == 5) {
      grainTitle_addr.call(bytes4(keccak256("unlock()")));
    }
    else if (flowIndex == 6) {
      data = new bytes(0);
      interrupt = this.bubbleTrigger(1, data, address(this));
    }
    else if (flowIndex == 7) {
      startSubChoreography(1);
    }
    else if (flowIndex == 9) {
      payment_amount = summary_tonnes * orderDetails_price; refund_amount = depositAmount_amount - payment_amount;
    }
    else if (flowIndex == 10) {
      grainTitle_addr.call(bytes4(keccak256("assign(address)")), 0x0);
    }
    else if (flowIndex == 11) {
      data = new bytes(0);
      interrupt = this.bubbleTrigger(2, data, address(this));
    }
    else if (flowIndex == 13) {
      startSubChoreography(2);
    }
    else if (flowIndex == 14) {
      startSubChoreography(3);
    }
    else if (flowIndex == 17) {
      grainTitle_addr.call(bytes4(keccak256("assign(address)")), participants.get(1));
    }
  }

  function propagateFlow(uint8 flowIndex)
    private
  {
    uint24[FLOW_COUNT] memory successors = [
      uint24(0x0), 0x0c, 0x10, 0x0, 0x0, 0x40, 0x0, 0x0, 0x600, 0x1000, 0x0800, 0x0, 0x6000, 0x0, 0x0, 0x20000, 0x20000, 0x40000, 0x0
    ];
    uint24[FLOW_COUNT] memory consumeMaps = [
      uint24(0x1), 0x2, 0x4, 0x08, 0x10, 0x20, 0x40, 0x080, 0x100, 0x200, 0x400, 0x0800, 0x1000, 0x2000, 0x4000, 0x18000, 0x18000, 0x20000, 0x40000
    ];

    uint24 curTokens = tokens;
    uint24 toVisit = (uint24(1) << flowIndex);
    uint24 toVisitNext;

    // while we still have flows to visit
    while (toVisit > 0) {
      // mark current set as visited
      curTokens |= toVisit;
      toVisitNext = 0;

      // get all the successors of the nodes we are visiting
      for (uint8 i = 0; i < FLOW_COUNT; i++) {
        if (toVisit & ~uint24(0x1) & (uint24(1) << i) > 0) {
          // perform data-based exclusive split
          if (i == 1) {
            if (!grainTitle_addr.call(bytes4(keccak256("amTrustee()")))) {
              toVisitNext |= uint24(8);
            }
            else {
              toVisitNext |= uint24(4);
            }
            curTokens &= ~uint24(0x2);
            continue;
          }
          // perform data-based exclusive split
          else if (i == 8) {
            if ((summary_tonnes >= orderDetails_tonnes - orderDetails_tolerance) && (summary_tonnes <= orderDetails_tonnes + orderDetails_tolerance) && (summary_grade >= orderDetails_grade)) {
              toVisitNext |= uint24(512);
            }
            else {
              toVisitNext |= uint24(1024);
            }
            curTokens &= ~uint24(0x100);
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