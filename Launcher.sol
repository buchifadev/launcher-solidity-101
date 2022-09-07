// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Launcher {
    uint256 constant COST_PER_VIEW = 1 ether; // cost per advert view
    uint256 constant MINIMUM_DEPOSIT = 5 ether; // mimimum deposit advertiser must pay for advert creation
    uint256 advertsCounter = 0;
    mapping(uint256 => bool) activeAdverts;
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

    /// @dev create a new advert and send to platform
    function createAdvert(
        string calldata name,
        string calldata description,
        string calldata imageUrl
    ) external payable {
        require(bytes(name).length > 0, "Empty name");
        require(bytes(description).length > 0, "Empty description");
        require(bytes(imageUrl).length > 0, "Empty image Url");
        require(
            msg.value >= MINIMUM_DEPOSIT,
            "Amount sent must be greater or equal to minimum deposit"
        );
        allAdverts[advertsCounter] = Advert(
            msg.sender,
            name,
            description,
            imageUrl,
            msg.value,
            0
        );
        activeAdverts[advertsCounter] = true;
        advertsCounter += 1;
    }

    /**
     * @dev simulates the viewing of an advertisement
     * In real life, this could be some videos, images, or GIFs
     */
    function viewAdvert(uint256 advertIndex) external payable {
        // proceed with transaction only when the advert is still active
        require(activeAdverts[advertIndex], "Advert is not active");
        Advert storage currentAdvert = allAdverts[advertIndex];
        require(
            currentAdvert.owner != msg.sender,
            "You can't view your own advert"
        );
        require(
            !alreadyViewed[advertIndex][msg.sender],
            "You have already viewed this advert"
        );

        // deduct the cost of this view from the advert balance first
        uint balanceLeft = currentAdvert.balance - COST_PER_VIEW;
        currentAdvert.balance = balanceLeft;
        // increase advert view count
        currentAdvert.views += 1;
        // keep track of views
        accumulatedViews += 1;
        // prevent users from viewing advert more than once
        alreadyViewed[advertIndex][msg.sender] = true;

        // check if advert still has enough funds for the next round
        // deactivate advert if it does not have enough funds to pay both viewer and platform
        if (currentAdvert.balance < COST_PER_VIEW) {
            activeAdverts[advertIndex] = false;
        }
        // pay the viewer for viewing the advert
        uint256 value = COST_PER_VIEW / 2;
        (bool success, ) = payable(msg.sender).call{value: value}("");
        require(success, "Payment of advert failed");
    }

    /**
     * @dev Add funds to an advert balance
     * @notice value sent with transaction will be the amount credited to balance of advert
     *  */
    function creditAdvert(uint256 advertIndex) public payable {
        Advert storage currentAdvert = allAdverts[advertIndex];
        require(
            currentAdvert.owner == msg.sender,
            "Only advert owner can add funds to advert"
        );
        require(
            msg.value >= 1 ether,
            "Amount sent not enough. Minimum is 1 ether"
        );
        // update advert balance
        uint newBalance = currentAdvert.balance + msg.value;
        currentAdvert.balance = newBalance;
        // if advert wasn't active, it is set back to active
        if (!activeAdverts[advertIndex]) {
            activeAdverts[advertIndex] = true;
        }
    }

    /**
     * @dev Users check list of all available adverts they can view
     * @return status of advert with index of advertIndex
     *  */
    function allActiveAdverts(uint256 advertIndex) public view returns (bool) {
        return activeAdverts[advertIndex];
    }

    /**
     * @return advert details
     * */
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
        return (
            allAdverts[advertIndex].owner,
            allAdverts[advertIndex].name,
            allAdverts[advertIndex].description,
            allAdverts[advertIndex].imageUrl,
            allAdverts[advertIndex].balance,
            allAdverts[advertIndex].views
        );
    }

    /// @dev claim the platform fees stored in contract
    function claimFees() public payable isPlatformAccount {
        uint256 accumulatedFees = accumulatedViews * 0.5 ether;
        // reset accumulated views
        accumulatedViews = 0;
        (bool success, ) = payable(platformAccount).call{
            value: accumulatedFees
        }("");
        require(success, "Failed to claim due fees");
    }

    /// @return accumulated fees and views in contract
    function viewAccumulationDetails()
        public
        view
        isPlatformAccount
        returns (uint256, uint256)
    {
        return (accumulatedViews, accumulatedViews * 0.5 ether);
    }

    /// @dev check the minimum deposit on an advert
    function viewMinimumDeposit() public pure returns (uint256) {
        return MINIMUM_DEPOSIT;
    }
}
