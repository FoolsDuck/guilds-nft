// SPDX-License-Identifier: MIT

import "./ERC1155Supply.sol";
import "./UseStrings.sol";

pragma solidity ^0.8.7;

contract Guilds is ERC1155Supply, UseStrings {
    string public name;
    string public symbol;
    uint256 private _lastModId;
    uint256 private _totalGuilds;
    uint256 private _lastTicket;
    address private deployerOne;
    address private deployerTwo;
    uint256 public minimumMintRate;

    struct Guild {
        uint256 TokenId;
        string GuildName;
        string GuildDesc;
        address Admin;
        address[] GuildMembers;
        address[] GuildMods;
        string GuildType;
        uint256[] Appeals;
        uint256 UnlockDate;
        uint256 LockDate;
        string GuildRules;
        bool FreezeMetaData;
        address[] Kicked;
    }

    struct CourtOfAppeals {
        uint256 id;
        uint256 TokenId;
        address Kicked;
        string Message;
        uint256 For;
        uint256 Against;
        uint256 TimeStamp;
        address[] Voters;
    }

    mapping(uint256 => Guild) AllGuilds;
    mapping(uint256 => CourtOfAppeals) CourtTickets;
    mapping(address => uint256[]) MemberTickets;
    mapping(address => uint256[]) private KickedFrom;
    mapping(address => uint256[]) private GuildsByAddress;
    mapping(string => uint256) private GuildByName;
    mapping(uint256 => address) public ModAddressById;
    mapping(uint256 => mapping(address => uint256)) public ModMintLimit;
    mapping(uint256 => address) public tokenAdmin;

    function initialize() public virtual initializer {
        _transferOwnership(_msgSender());
        name = "Guilds";
        symbol = "GUILDS";
        _lastModId = 1526;
        _lastTicket = 9048;
        deployerOne = 0x76e763f6Ff933fDFBAe0a51DDc9740B47048CcDA;
        deployerTwo = 0xd04FCf03971aC82fC9eAacB2BBdc863479ea134b;
        minimumMintRate = 0;
    }

    // PUBLIC READ FUNCTIONS:

    function totalGuilds() public view virtual returns (uint256) {
        return _totalGuilds;
    }

    function lastModId() public view virtual returns (uint256) {
        return _lastModId;
    }

    function getGuildsByMember(address _address)
        public
        view
        returns (uint256[] memory)
    {
        return GuildsByAddress[_address];
    }

    function getMemberTickets(address _address)
        public
        view
        returns (uint256[] memory)
    {
        return MemberTickets[_address];
    }

    function getKickedByMember(address _address)
        public
        view
        returns (uint256[] memory)
    {
        return KickedFrom[_address];
    }

    function getGuildByName(string memory _name) public view returns (uint256) {
        return GuildByName[_name];
    }

    function getIndexOfMember(uint256 _id, address _account)
        public
        view
        returns (uint256)
    {
        return indexOfAddress(AllGuilds[_id].GuildMembers, _account);
    }

    function getAppealByTicket(uint256 _ticket, uint256 _tokenId)
        public
        view
        returns (CourtOfAppeals memory)
    {
        require(
            indexOfAddress(AllGuilds[_tokenId].GuildMembers, msg.sender) >= 0 ||
                indexOfAddress(AllGuilds[_tokenId].GuildMods, msg.sender) >= 0,
            "Only guild members can display appeals"
        );
        return CourtTickets[_ticket];
    }

    function getGuildById(uint256 _id) public view returns (Guild memory) {
        return AllGuilds[_id];
    }

    // GUILD MASTER FUNCTIONS:

    function removeAppealFromCourt(uint256 _ticketId, uint256 _tokenId)
        public
        onlyRole(ADMIN, _tokenId)
    {
        require(
            block.timestamp >= (CourtTickets[_ticketId].TimeStamp + 7 days),
            "Can remove appeal only after 7 days"
        );

        delete CourtTickets[_ticketId];
    }

    function removeMemberFromBlacklist(address _address, uint256 _tokenId)
        public
        onlyRole(ADMIN, _tokenId)
    {
        removeItemFromAddressArray(
            AllGuilds[_tokenId].Kicked,
            indexOfAddress(AllGuilds[_tokenId].Kicked, _address)
        );
        removeItemFromUintArray(
            KickedFrom[_address],
            indexOfUint256(KickedFrom[_address], _tokenId)
        );
    }

    function lockSpots(
        uint256 _tokenId,
        uint256 _unlockDate,
        uint256 _lockDate
    ) public onlyRole(ADMIN, _tokenId) {
        require(_lockDate >= block.timestamp, "Can't lock the past");
        require(
            AllGuilds[_tokenId].UnlockDate <= block.timestamp,
            "Guild spots are already locked"
        );
        AllGuilds[_tokenId].UnlockDate = _unlockDate;
        AllGuilds[_tokenId].LockDate = _lockDate;
    }

    function freezeMetaData(uint256 _tokenId) public onlyRole(ADMIN, _tokenId) {
        AllGuilds[_tokenId].FreezeMetaData = true;
    }

    function setGuildRules(string memory _rules, uint256 _tokenId)
        public
        onlyRole(ADMIN, _tokenId)
    {
        AllGuilds[_tokenId].GuildRules = _rules;
    }

    function adminMint(uint256 _amount, uint256 _id)
        public
        payable
        onlyRole(ADMIN, _id)
    {
        require(
            block.timestamp >= (AllGuilds[_id].UnlockDate) ||
                block.timestamp <= (AllGuilds[_id].LockDate),
            "Guild spots are locked"
        );
        uint256 ownerFee = _amount * minimumMintRate;
        require(msg.value >= ownerFee, "Not enough ethers sent");
        _mint(tokenAdmin[_id], _id, _amount, "");
    }

    function assignModerator(
        address _account,
        uint256 _id,
        uint256 _mintLimit
    ) public onlyRole(ADMIN, _id) {
        require(
            indexOfAddress(AllGuilds[_id].GuildMembers, _account) >= 0,
            "Not a member"
        );
        _lastModId += 1;
        _grantRole(MODERATOR, _account, _id);
        ModAddressById[_lastModId] = _account;
        ModMintLimit[_id][_account] = _mintLimit;
        AllGuilds[_id].GuildMods.push(_account);
        removeItemFromAddressArray(
            AllGuilds[_id].GuildMembers,
            indexOfAddress(AllGuilds[_id].GuildMembers, _account)
        );
    }

    function bulkAssignModerators(
        address[] memory _addresses,
        uint256 _id,
        uint256 _limit
    ) public onlyRole(ADMIN, _id) {
        for (uint256 i = 0; i < _addresses.length; ++i) {
            assignModerator(_addresses[i], _id, _limit);
        }
    }

    function adminSetModMintLimit(
        uint256 _id,
        address _account,
        uint256 _mintLimit
    ) public onlyRole(ADMIN, _id) {
        _setModMintLimit(_id, _account, _mintLimit);
    }

    function revokeRole(
        bytes32 _role,
        address _account,
        uint256 _id
    ) public onlyRole(ADMIN, _id) {
        uint256 _modIndexInGuild = indexOfAddress(
            AllGuilds[_id].GuildMods,
            _account
        );
        if (_role == MODERATOR) {
            removeItemFromAddressArray(
                AllGuilds[_id].GuildMods,
                _modIndexInGuild
            );
            ModMintLimit[_id][_account] = 0;
            // new member
            addMemberToGuild(_account, _id);
            addGuildToMember(_account, _id);
        }
        _revokeRole(_role, _account, _id);
    }

    function burn(
        uint256 _id,
        uint256 _amount,
        address _address
    ) public onlyRole(ADMIN, _id) {
        require(
            compareStrings(AllGuilds[_id].GuildType, "democracy") ||
                compareStrings(AllGuilds[_id].GuildType, "monarchy"),
            "Cannot kick from meritocracy guild"
        );
        _burn(_address, _id, _amount);
        AllGuilds[_id].Kicked.push(_address);
        addGuildToKickedFrom(_address, _id);
    }

    function editMetadata(
        string memory _name,
        string memory _desc,
        string memory _uri,
        uint256 _id
    ) public onlyRole(ADMIN, _id) {
        // If name is not being changed:
        if (getGuildByName(lower(_name)) != _id) {
            require(getGuildByName(lower(_name)) == 0, "Name already exists");
        } else {
            // Update guild name:
            string memory oldName = AllGuilds[_id].GuildName;
            GuildByName[lower(oldName)] = 0;
            GuildByName[lower(_name)] = _id;
        }

        require(
            validateString(_name),
            "Guild name must not contain spaces on side"
        );
        AllGuilds[_id].GuildName = _name;
        AllGuilds[_id].GuildDesc = _desc;
        setNewTokenUri(_id, _uri);
    }

    function setNewTokenUri(uint256 _id, string memory _newUri)
        public
        onlyRole(ADMIN, _id)
    {
        require(!AllGuilds[_id].FreezeMetaData, "Guild metadata is frozen");
        _setURI(_newUri, _id);
        emit URI(_newUri, _id);
    }

    // MODERATOR FUNCTIONS:

    function modMint(uint256 _amount, uint256 _id)
        public
        payable
        onlyRole(MODERATOR, _id)
    {
        require(
            block.timestamp >= (AllGuilds[_id].UnlockDate) ||
                block.timestamp <= (AllGuilds[_id].LockDate),
            "Guild spots are locked"
        );
        uint256 ownerFee = _amount * minimumMintRate;
        uint256 _modMintLimit = ModMintLimit[_id][msg.sender];
        require(_modMintLimit >= _amount, "Cant mint specified amount");
        require(msg.value >= ownerFee, "Not enough ethers sent");
        _setModMintLimit(_id, msg.sender, (_modMintLimit - _amount));
        _mint(msg.sender, _id, _amount, "");
    }

    // PUBLIC WRITE:

    function appealToCourt(uint256 _tokenId, string memory _message) public {
        uint256[] memory senderKickedFrom = KickedFrom[msg.sender];
        require(
            indexOfUint256(senderKickedFrom, _tokenId) >= 0,
            "Cant appeal for the specified guild"
        );
        require(
            compareStrings(AllGuilds[_tokenId].GuildType, "democracy"),
            "Guild governance is monarchy"
        );
        _lastTicket += 1;
        MemberTickets[msg.sender].push(_lastTicket);
        AllGuilds[_tokenId].Appeals.push(_lastTicket);
        CourtTickets[_lastTicket].id = _lastTicket;
        CourtTickets[_lastTicket].TokenId = _tokenId;
        CourtTickets[_lastTicket].Kicked = msg.sender;
        CourtTickets[_lastTicket].Message = _message;
        CourtTickets[_lastTicket].For = 0;
        CourtTickets[_lastTicket].Against = 0;
        CourtTickets[_lastTicket].TimeStamp = block.timestamp;
        CourtTickets[_lastTicket].Voters;
    }

    function voteForAppeal(uint256 _ticketId, uint256 _value) public {
        uint256 ticketGuild = CourtTickets[_ticketId].TokenId;
        require(
            msg.sender != AllGuilds[ticketGuild].Admin,
            "Guild master cannot vote for appeal"
        );
        require(
            indexOfAddress(AllGuilds[ticketGuild].GuildMembers, msg.sender) >=
                0 ||
                indexOfAddress(AllGuilds[ticketGuild].GuildMods, msg.sender) >=
                0,
            "Only guild members can vote"
        );
        require(
            addressNotIndexed(CourtTickets[_ticketId].Voters, msg.sender) >= 0,
            "Cannot vote for the same ticket more than one time"
        );
        if (_value == 0) {
            CourtTickets[_ticketId].For += 1;
        } else if (_value == 1) {
            CourtTickets[_ticketId].Against += 1;
        } else {
            revert("Can vote only for or againt");
        }
        CourtTickets[_ticketId].Voters.push(msg.sender);
    }

    function createNewGuild(
        uint256 _amount,
        string memory _uri,
        string memory _name,
        string memory _desc,
        string memory _guildType
    ) public payable {
        require(
            msg.value >= (_amount * minimumMintRate),
            "Not enough ethers sent"
        );
        uint256 _id = totalGuilds() + 1;
        _totalGuilds = _id;
        _grantAdminRole(ADMIN, msg.sender, _id);
        setNewGuild(_id, msg.sender, _name, _desc, _guildType);
        tokenAdmin[_id] = msg.sender;
        _mint(msg.sender, _id, _amount, "");
        setTokenUri(_id, _uri);
    }

    function bulkSendSpots(
        address[] memory _addresses,
        uint256 _id,
        uint256 _amount
    ) public {
        for (uint256 i = 0; i < _addresses.length; ++i) {
            _safeTransferFrom(msg.sender, _addresses[i], _id, _amount, "0x0");
        }
    }

    // PRIVATE WRITE:

    function removeItemFromAddressArray(
        address[] storage _addresses,
        uint256 index
    ) private {
        address[] storage AddArr = _addresses;
        AddArr[index] = AddArr[AddArr.length - 1];
        AddArr.pop();
    }

    function removeItemFromUintArray(uint256[] storage _uints, uint256 index)
        private
    {
        uint256[] storage UintsArr = _uints;
        UintsArr[index] = UintsArr[UintsArr.length - 1];
        UintsArr.pop();
    }

    function setNewGuild(
        uint256 _id,
        address _initiator,
        string memory _name,
        string memory _desc,
        string memory _guildType
    ) private {
        require(
            compareStrings(_guildType, "democracy") ||
                compareStrings(_guildType, "monarchy") ||
                compareStrings(_guildType, "meritocracy"),
            "Unrecognized guild type"
        );
        require(
            validateString(_name),
            "Guild name must not contain spaces on sides"
        );

        string memory clearGuildName = lower(_name);
        require(getGuildByName(clearGuildName) == 0, "Name already exists");
        AllGuilds[_id].TokenId = _id;
        AllGuilds[_id].GuildName = _name;
        AllGuilds[_id].GuildDesc = _desc;
        AllGuilds[_id].GuildMembers;
        AllGuilds[_id].Admin = _initiator;
        AllGuilds[_id].GuildMods;
        AllGuilds[_id].GuildType = _guildType;
        AllGuilds[_id].GuildRules;
        AllGuilds[_id].FreezeMetaData = false;
        AllGuilds[_id].Kicked;
        AllGuilds[_id].LockDate = block.timestamp;
        AllGuilds[_id].UnlockDate = block.timestamp;
        GuildByName[clearGuildName] = _id;
    }

    function _setModMintLimit(
        uint256 _id,
        address _account,
        uint256 _mintLimit
    ) private {
        ModMintLimit[_id][_account] = _mintLimit;
    }

    function setTokenUri(uint256 _id, string memory _uri) private {
        require(exists(_id), "Token is not exists");
        _setURI(_uri, _id);
        emit URI(_uri, _id);
    }

    function addMemberToGuild(address _address, uint256 _id) private {
        AllGuilds[_id].GuildMembers.push(_address);
    }

    function addGuildToMember(address _address, uint256 _id) private {
        GuildsByAddress[_address].push(_id);
    }

    function addGuildToKickedFrom(address _address, uint256 _id) private {
        KickedFrom[_address].push(_id);
    }

    function _grantAdminRole(
        bytes32 _role,
        address _account,
        uint256 _id
    ) private {
        _grantRole(_role, _account, _id);
    }

    // Owners:

    function setMinimumMintRate(uint256 _mintRate) external onlyOwner {
        minimumMintRate = _mintRate;
    }

    function manuallyAdd(address _address, uint256 _id) public onlyOwner {
        addMemberToGuild(_address, _id);
        addGuildToMember(_address, _id);
    }

    function withdraw() public {
        require(
            msg.sender == deployerOne || msg.sender == deployerTwo,
            "Sender is not deployer"
        );
        uint256 balance1 = address(this).balance / 2;
        uint256 balance2 = address(this).balance / 2;
        payable(deployerOne).transfer(balance1);
        payable(deployerTwo).transfer(balance2);
    }

    // Hooks:

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; ++i) {
            if (address(0) != from) {
                // remove the sender if no tokens left and revoke roles:
                uint256 _tokensLeft = balanceOf(from, ids[i]);
                // Kick:
                if (_tokensLeft == amounts[i]) {
                    // If MOD:
                    if (
                        roles[
                            0x58c8e11deab7910e89bf18a1168c6e6ef28748f00fd3094549459f01cec5e0aa
                        ][from][ids[i]]
                    ) {
                        _revokeRole(MODERATOR, from, ids[i]);
                        removeItemFromAddressArray(
                            AllGuilds[ids[i]].GuildMods,
                            indexOfAddress(AllGuilds[ids[i]].GuildMods, from)
                        );
                    } else if (tokenAdmin[ids[i]] == from && address(0) != to) {
                        // If is admin:
                        _revokeRole(ADMIN, from, ids[i]);
                        tokenAdmin[ids[i]] = to;
                        AllGuilds[ids[i]].Admin = to;
                        _grantAdminRole(ADMIN, to, ids[i]);
                    } else {
                        // remove member from guild
                        removeItemFromAddressArray(
                            AllGuilds[ids[i]].GuildMembers,
                            indexOfAddress(AllGuilds[ids[i]].GuildMembers, from)
                        );
                    }
                    // remove guild from member
                    removeItemFromUintArray(
                        GuildsByAddress[from],
                        indexOfUint256(GuildsByAddress[from], ids[i])
                    );
                }
            }

            if (address(0) != to) {
                // If guild exists:
                if (exists(ids[i])) {
                    // Add new member:
                    if (balanceOf(to, ids[i]) == 0) {
                        // new member
                        if (to != tokenAdmin[ids[i]]) {
                            addMemberToGuild(to, ids[i]);
                        }
                        addGuildToMember(to, ids[i]);
                    }
                }
            }
        }
    }
}
