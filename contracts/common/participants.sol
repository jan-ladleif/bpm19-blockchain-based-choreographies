pragma solidity ^0.4.23;

import "interfaces.sol";

/*
 * Instances of this class are used by choreographies to authorize requests and responses.
 * A participant can register with their address for a specific role, and linked choreographies
 * will check this address when actions on a choreography are taken.
 */
contract ParticipantsContainer is Participants {
    /*
     * Struct with information about each participant. Could include a URL etc.
     * in the future.
     */
    struct Participant {
        address id;
    }

    uint8 roleCount; // number of roles
    uint256 registered; // mask specifying which roles were already registered
    mapping(uint8 => Participant) participants; // mapping each participant to their address

    /*
     * @param numberOfRoles Number of roles this container should manage.
     */
    constructor(uint8 numberOfRoles)
        public
    {
        roleCount = numberOfRoles;
    }

    /*
     * @returns The address of the participant having the given role.
     */
    function get(uint8 role)
        external
        view
        returns (address addi)
    {
        addi = participants[role].id;
    }

    /*
     * Claims the given role for the sender of the transaction. Also resolves if the
     * sender has previously claimed the role.
     * @param role Role to claim.
     * @throws If the role does not exist or has been claimed already by someone else.
     */
    function registerParticipant(uint8 role)
        external
    {
        require(role < roleCount);
        if (participants[role].id == 0x0) {
            participants[role] = Participant(msg.sender);
            registered |= uint256(1) << role;
            emit ParticipantRegistered(msg.sender, role);
        } else {
            require(participants[role].id == msg.sender);
        }
    }

    /*
     * @param roles Mask of roles.
     * @returns True if all of the given roles are registered.
     */
    function rolesAreRegistered(uint256 roles)
        external
        view
        returns (bool)
    {
        return (registered & roles == roles);
    }
    
    /*
     * @param id Ethereum address to check for.
     * @param role Role to check for.
     * @returns True if the given address is registered for the given role.
     */
    function hasRole(address id, uint8 role)
        external
        view
        returns (bool)
    {
        return participants[role].id == id;
    }

    /*
     * @param id Ethereum address to check for.
     * @param roles Roles to check for.
     * @returns True if the given address is registered for one of the given roles.
     */
    function hasOneRoleOf(address id, uint256 roles)
        external
        view
        returns (bool)
    {
        for (uint8 i = 0; i < roleCount; i++) {
            if (participants[i].id == id && (uint256(1) << i) & roles > 0) {
                return true;
            }
        }
        return false;
    }
}