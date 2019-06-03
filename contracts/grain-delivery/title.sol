pragma solidity ^0.4.24;

// generic stub grain title contract that contains logic to securely
// transfer ownership over the title to different addresses using a
// third-party trustee
contract GrainTitle {
  // current owner of the title
  address private owner;
  // currently appointed trustee for title transfers
  address private trustee;

  constructor() public {
    owner = msg.sender;
  }

  // lock the title for a transfer with the given trustee
  function lock(address newTrustee) external {
    require(msg.sender == owner,
            "only the owner can lock a title");
    require(trustee == 0x0, "the title is already locked");
    trustee = newTrustee;
  }

  // transfer the title to a new owner
  function assign(address newOwner) external {
    require(msg.sender == trustee,
            "only the trustee can assign a new owner");
    owner = newOwner;
    delete trustee;
  }

  // cancel the transfer process
  function unlock() external {
    require(msg.sender == trustee,
            "only the trustee can unlock the title");
    delete trustee;
  }

  // check if the caller is the current trustee
  function amTrustee() external view {
    require(msg.sender == trustee, "caller is not the trustee");
  }
}