/*
Solidity DAO contract for Spectra Gallery
Allow new user to request a vote to obtain a creator or thinker role 
The vote is open for 10 days and the user needs 50% of the votes to be accepted
The role are checked by an Access control proxy contract which has the roles: admin, creator, thinker, myself
If the role is granted the access control proxy contract will be updated to add the user address to the role
The admin role is allowed to add new admin, creator and thinker
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./AccessControl.sol";

contract DAO {
    AccessControl private accessControl;
    uint private voteDuration = 10 days;

    enum State {
        Pending,
        Active,
        Paused,
        Completed,
        Cancelled
    }

    enum Finance {
        awaitingPrimaryPayment,
        primaryPayed,
        awaitingFinalPayment,
        finalPayed,
        refunded
    }

    struct Vote {
        uint256 value;
        bool voted;
    }

    struct MembershipRequest {
        address user;
        uint voteCount;
        uint start;
        uint end;
        bool creator;
        bool thinker;
        bool approved;
        mapping(address => bool) hasVoted;
    }

    // struct to handle project requests
    struct ProjectRequest {
        bytes32 name;
        string description;
        address requester;
        address[] creators;
        State state;
        Finance finance;
        uint256 budget;
        uint256 funds;
        uint deadline;
        uint voteCount;
        uint start;
        uint end;
        bool approved;
        mapping(address => Vote) votes;
    }

    mapping(uint => MembershipRequest) private membershipRequests;

    mapping(uint => ProjectRequest) private projectRequests;

    uint private membershipRequestCount = 0;
    uint private projectRequestCount = 0;

    event CreatorMembershipRequest(
        uint indexed requestId,
        address indexed user,
        bool creator,
        bool thinker
    );
    event ProjectRequestCreated(
        uint indexed requestId,
        bytes32 name,
        string description,
        address requester,
        address[] creators,
        uint budget,
        uint deadline
    );
    event ProjectRequestVoted(
        uint indexed requestId,
        address indexed voter,
        uint funds
    );
    event ProjectRequestApproved(
        uint indexed requestId,
        address indexed approver
    );
    event revokedProjectRequest(uint indexed requestId, address indexed revoker);
    event VoteMembershipRequest(uint indexed requestId, address indexed voter);
    event MembershipRequestApproved(
        uint indexed requestId,
        address indexed approver
    );

    constructor(address _accessControl) {
        accessControl = AccessControl(_accessControl);
    }

    function requestCreatorMembership() public {
        require(
            !accessControl.hasRole(AccessControl.Role.Creator, msg.sender),
            "You are already a creator"
        );
        require(
            !membershipRequests[membershipRequestCount].creator,
            "You have already requested a creator membership"
        );

        membershipRequestCount++;
        MembershipRequest storage membershipRequest = membershipRequests[
            membershipRequestCount
        ];
        membershipRequest.user = msg.sender;
        membershipRequest.creator = true;
        membershipRequest.start = block.timestamp;
        membershipRequest.end = block.timestamp + voteDuration;

        emit CreatorMembershipRequest(
            membershipRequestCount,
            msg.sender,
            true,
            false
        );
    }

    function requestThinkerMembership() public {
        require(
            !accessControl.hasRole(AccessControl.Role.Thinker, msg.sender),
            "You are already a thinker"
        );
        require(
            !membershipRequests[membershipRequestCount].thinker,
            "You have already requested a thinker membership"
        );

        membershipRequestCount++;
        MembershipRequest storage membershipRequest = membershipRequests[
            membershipRequestCount
        ];
        membershipRequest.user = msg.sender;
        membershipRequest.thinker = true;
        membershipRequest.start = block.timestamp;
        membershipRequest.end = block.timestamp + voteDuration;

        emit CreatorMembershipRequest(
            membershipRequestCount,
            msg.sender,
            false,
            true
        );
    }

    function voteMembershipRequest(uint _requestId) public {
        require(
            accessControl.hasRole(AccessControl.Role.Admin, msg.sender) ||
                accessControl.hasRole(AccessControl.Role.Thinker, msg.sender) ||
                accessControl.hasRole(AccessControl.Role.Creator, msg.sender),
            "You are not a thinker or creator"
        );
        MembershipRequest storage membershipRequest = membershipRequests[
            _requestId
        ];
        require(
            membershipRequest.user != address(0),
            "Membership request does not exist"
        );
        require(
            membershipRequest.end > block.timestamp,
            "Membership request has expired"
        );
        require(
            !membershipRequest.hasVoted[msg.sender],
            "You have already voted"
        );

        membershipRequest.hasVoted[msg.sender] = true;
        membershipRequest.voteCount++;

        emit VoteMembershipRequest(_requestId, msg.sender);
    }

    // admin approve membership request
    function approveMembershipRequest(uint _requestId) public {
        require(
            accessControl.hasRole(AccessControl.Role.Admin, msg.sender),
            "You are not an admin"
        );
        MembershipRequest storage membershipRequest = membershipRequests[
            _requestId
        ];
        require(
            membershipRequest.voteCount >= accessControl.userCount() / 2,
            "Membership request has not been approved by the community"
        );
        require(
            membershipRequest.user != address(0),
            "Membership request does not exist"
        );
        require(
            membershipRequest.end > block.timestamp,
            "Membership request has expired"
        );

        membershipRequest.approved = true;

        if (membershipRequest.creator) {
            accessControl.grantRoleByDAO(
                AccessControl.Role.Creator,
                membershipRequest.user
            );
        } else if (membershipRequest.thinker) {
            accessControl.grantRoleByDAO(
                AccessControl.Role.Thinker,
                membershipRequest.user
            );
        }

        emit MembershipRequestApproved(_requestId, msg.sender);
    }

    function createProjectRequest(
        bytes32 _name,
        string memory _description,
        address[] memory _creators,
        uint _budget,
        uint _deadline
    ) public payable {
        require(
            accessControl.hasRole(AccessControl.Role.Admin, msg.sender) ||
                accessControl.hasRole(AccessControl.Role.Thinker, msg.sender) ||
                accessControl.hasRole(AccessControl.Role.Creator, msg.sender),
            "You are not a thinker or creator"
        );
        require(
            !projectRequests[projectRequestCount].approved,
            "You have already requested a project"
        );

        projectRequestCount++;
        ProjectRequest storage projectRequest = projectRequests[
            projectRequestCount
        ];
        projectRequest.name = _name;
        projectRequest.description = _description;
        projectRequest.requester = msg.sender;
        projectRequest.creators = _creators;
        projectRequest.budget = _budget;
        projectRequest.state = State.Pending;
        projectRequest.finance = Finance.awaitingPrimaryPayment;
        projectRequest.funds = 0;
        projectRequest.deadline = _deadline;
        projectRequest.start = block.timestamp;
        projectRequest.end = block.timestamp + voteDuration;

        emit ProjectRequestCreated(
            projectRequestCount,
            _name,
            _description,
            msg.sender,
            _creators,
            _budget,
            _deadline
        );
    }

    function voteProjectRequest(uint _requestId) public payable {
        require(
            accessControl.hasRole(AccessControl.Role.Admin, msg.sender) ||
                accessControl.hasRole(AccessControl.Role.Thinker, msg.sender) ||
                accessControl.hasRole(AccessControl.Role.Creator, msg.sender),
            "You are not a thinker or creator"
        );
        ProjectRequest storage projectRequest = projectRequests[_requestId];
        require(
            projectRequest.requester != address(0),
            "Project request does not exist"
        );
        if (projectRequest.end < block.timestamp) {
            projectRequest.state = State.Cancelled;
        }
     
        require(
            !projectRequest.votes[msg.sender].voted,
            "You have already voted"
        );
        require(msg.value > 0, "You need to send some ether to vote");

        projectRequest.votes[msg.sender].value = msg.value;
        projectRequest.votes[msg.sender].voted = true;
        projectRequest.voteCount++;
        projectRequest.funds += msg.value;

        emit ProjectRequestVoted(_requestId, msg.sender, msg.value);
    }

    // admin approve project request
    function approveProjectRequest(uint _requestId) public returns (string memory) {
        require(
            accessControl.hasRole(AccessControl.Role.Admin, msg.sender),
            "You are not an admin"
        );
        ProjectRequest storage projectRequest = projectRequests[_requestId];
        require(
            projectRequest.requester != address(0),
            "Project request does not exist"
        );
        require(
            projectRequest.voteCount >= accessControl.userCount() / 2,
            "Project request has not been approved by the community"
        );
        if (projectRequest.end < block.timestamp) {
            projectRequest.state = State.Cancelled;
            // refund the funds to all voters by iterating over the projectRequest.votes mapping
             for (uint i = 0; i < projectRequest.voteCount; i++) {
                // get address from votes mapping and transfer the value back to the voter
                
                
            }

            return
                "Project request has been cancelled, deadline has passed, refunding all voters";
        }
        if (projectRequest.funds < projectRequest.budget) {
            projectRequest.state = State.Cancelled;

            // refund the funds to all voters by iterating over the projectRequest.votes mapping
             for (uint i = 0; i < projectRequest.voteCount; i++) {
                
            }

            return
                "Project request has been cancelled, funds are not enough, refunding all voters";
        }

        projectRequest.approved = true;
        projectRequest.state = State.Active;
        projectRequest.finance = Finance.awaitingFinalPayment;

        // send 10% of the funds to the DAO
        payable(address(this)).transfer((projectRequest.funds * 10) / 100);

        emit ProjectRequestApproved(_requestId, msg.sender);
    }

    // revoke project request
    function revokeProjectRequest(uint _requestId) public {
        require(
            accessControl.hasRole(AccessControl.Role.Admin, msg.sender),
            "You are not an admin"
        );
        ProjectRequest storage projectRequest = projectRequests[_requestId];
        require(
            projectRequest.requester != address(0),
            "Project request does not exist"
        );
        // revoke if the deadline is not met yet
        require(
            projectRequest.end > block.timestamp,
            "Cannot revoke project request before request deadline"
        );

        projectRequest.approved = false;
        projectRequest.state = State.Cancelled;
        projectRequest.finance = Finance.refunded;

        emit revokedProjectRequest(_requestId, msg.sender);
    }

    function getProjectRequest(
        uint _requestId
    )
        public
        view
        returns (
            bytes32,
            string memory,
            address,
            address[] memory,
            uint,
            uint,
            uint,
            uint,
            bool
        )
    {
        ProjectRequest storage _projectRequest = projectRequests[_requestId];
        return (
            _projectRequest.name,
            _projectRequest.description,
            _projectRequest.requester,
            _projectRequest.creators,
            _projectRequest.budget,
            _projectRequest.deadline,
            _projectRequest.voteCount,
            _projectRequest.start,
            _projectRequest.approved
        );
    }

    function getProjectRequestCount() public view returns (uint) {
        return projectRequestCount;
    }

    function getProjectRequestVote(
        uint _requestId,
        address _voter
    ) public view returns (uint, bool) {
        ProjectRequest storage projectRequest = projectRequests[_requestId];
        return (
            projectRequest.votes[_voter].value,
            projectRequest.votes[_voter].voted
        );
    }

    function getMembershipRequest(
        uint _requestId
    ) public view returns (address, bool, bool, uint, uint, uint, bool) {
        MembershipRequest storage _membershipRequest = membershipRequests[
            _requestId
        ];
        return (
            _membershipRequest.user,
            _membershipRequest.creator,
            _membershipRequest.thinker,
            _membershipRequest.voteCount,
            _membershipRequest.start,
            _membershipRequest.end,
            _membershipRequest.approved
        );
    }

    function getMembershipRequestCount() public view returns (uint) {
        return membershipRequestCount;
    }

    function hasVoted(uint _requestId) public view returns (bool) {
        MembershipRequest storage membershipRequest = membershipRequests[
            _requestId
        ];
        return membershipRequest.hasVoted[msg.sender];
    }

    function getAccessControl() public view returns (AccessControl) {
        return accessControl;
    }

    function setAccessControl(address _accessControl) public {
        require(
            accessControl.hasRole(AccessControl.Role.Admin, msg.sender),
            "You are not an admin"
        );
        accessControl = AccessControl(_accessControl);
    }

    function withdraw() public {
        require(
            accessControl.hasRole(AccessControl.Role.Admin, msg.sender),
            "You are not an admin"
        );
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}
