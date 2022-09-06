// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Launcher {
    uint256 constant COST_PER_VIEW = 1 ether; // cost per advert view
    uint256 constant MINIMUM_DEPOSIT = 5 ether; // mimimum deposit advertiser must pay for advert creation
    uint256 counter = 0;
    uint256[] activeAdverts;
    mapping(uint256 => Advert) allAdverts;
    mapping(uint256 => mapping(address => bool)) alreadyViewed;
    address payable platformAccount;
    uint256 accumulatedViews;

    struct Advert {
        address owner;
        string name;
        string description;
        string imageUrl;
        uint256 balance;
        uint256 views;
    }

    modifier isPlatformAccount() {
        require(
            payable(msg.sender) == platformAccount,
            "Action authorized to only platform account"
        );
        _;
    }

    constructor() {
        platformAccount = payable(msg.sender);
    }

    // create a new advert and send to platform
    function createAdvert(
        string memory name,
        string memory description,
        string memory imageUrl
    ) public payable {
        require(
            msg.value >= MINIMUM_DEPOSIT,
            "Amount sent must be greater or equal to minimum deposit"
        );
        allAdverts[counter] = Advert(
            msg.sender,
            name,
            description,
            imageUrl,
            msg.value,
            0
        );
        activeAdverts.push(counter);
        counter += 1;
    }

    // simulates the viewing of an advertisement
    // In real life, this could be some videos, images, or GIFs
    function viewAdvert(uint256 advertIndex) public {
        require(
            allAdverts[advertIndex].owner != msg.sender,
            "You can't view your own advert"
        );
        require(
            !alreadyViewed[advertIndex][msg.sender],
            "You have already viewed this advert"
        );
        bool isActive = false;
        // first check if advert is still active (advert still has enough funds to pay both platform and viewer)
        for (uint256 i = 0; i < activeAdverts.length; i++) {
            if (activeAdverts[i] == advertIndex) {
                isActive = true;
                break;
            }
        }
        // proceed with transaction only when the advert is still active
        require(isActive, "Advert is not active");
        // deduct the cost of this view from the advert balance first
        allAdverts[advertIndex].balance -= COST_PER_VIEW;
        // increase advert view count
        allAdverts[advertIndex].views += 1;
        // keep track of views
        accumulatedViews += 1;
        // pay the viewer for viewing the advert
        uint256 value = COST_PER_VIEW / 2;
        payable(msg.sender).transfer(value);
        // prevent users from viewing advert more than once
        alreadyViewed[advertIndex][msg.sender] = true;

        // check if advert still has enough funds for the next round
        uint256 adBal = allAdverts[advertIndex].balance;
        // deactivate advert if it does not have enough funds to pay both viewer and platform
        if (adBal < COST_PER_VIEW) {
            // first get advert index from array of active adverts
            int256 index = -1;
            for (uint256 i = 0; i < activeAdverts.length; i++) {
                if (i == advertIndex) {
                    index = int256(i);
                    break;
                }
            }
            // remove index from array if it exists
            if (index >= 0) {
                activeAdverts[uint256(index)] = activeAdverts[
                    activeAdverts.length - 1
                ];
                activeAdverts.pop();
            }
        }
    }

    // Add funds to an advert balance
    function creditAdvert(uint256 advertIndex) public payable {
        require(
            allAdverts[advertIndex].owner == msg.sender,
            "Only advert owner can add funds to advert"
        );
        require(
            msg.value >= 1 ether,
            "Amount sent not enough. Minimum is 1 ether"
        );
        // update advert balance
        allAdverts[advertIndex].balance += msg.value;
        bool isActive = false;
        // active advert after topping up
        for (uint256 i = 0; i < activeAdverts.length; i++) {
            if (activeAdverts[i] == advertIndex) {
                isActive = true;
                break;
            }
        }
        // add advert to array to active adverts
        if (!isActive) {
            activeAdverts.push(advertIndex);
        }
    }

    // Users check list of all available adverts they can view
    // Only the indexes of the adverts are displayed
    function allActiveAdverts() public view returns (uint256[] memory) {
        return activeAdverts;
    }

    // Display advert details
    // Only displayed to the owner of advert and platform account
    function advertDetails(uint256 advertIndex)
        public
        view
        returns (
            address,
            string memory,
            string memory,
            string memory,
            uint256,
            uint256
        )
    {
        require(
            (msg.sender == allAdverts[advertIndex].owner) ||
                (msg.sender == platformAccount),
            "Unauthorized to call this function"
        );
        return (
            allAdverts[advertIndex].owner,
            allAdverts[advertIndex].name,
            allAdverts[advertIndex].description,
            allAdverts[advertIndex].imageUrl,
            allAdverts[advertIndex].balance,
            allAdverts[advertIndex].views
        );
    }

    // claim the platform fees stored in contract
    function claimFees() public isPlatformAccount {
        uint256 accumulatedFees = (accumulatedViews * 1 ether) / 2;
        payable(platformAccount).transfer(accumulatedFees);
        // reset accumulated views
        accumulatedViews = 0;
    }

    // check accumulated fees stored in contract
    function viewAccumulatedFees()
        public
        view
        isPlatformAccount
        returns (uint256)
    {
        return address(this).balance;
    }

    // check total views accumulated
    function viewAccumulatedViews()
        public
        view
        isPlatformAccount
        returns (uint256)
    {
        return accumulatedViews;
    }

    // check the minimum deposit on an advert
    function viewMinimumDeposit() public pure returns (uint256) {
        return MINIMUM_DEPOSIT;
    }
}
