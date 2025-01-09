// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUIDValidatorLibrary} from "./UUIDValidatorLibrary.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error DigitalP2P_NotOwnerOrAdmin();
error DigitalP2P_NotOwner();
error DigitalP2P_InvalidAddress();
error DigitalP2P_InvalidAmount();
error DigitalP2P_AmountShouldBeGreaterThanZero();
error DigitalP2P_AmountShouldBeGreaterThanMinimumAmount();
error DigitalP2P_AmountShouldBeLessThanMaximumAmount();
error DigitalP2P_AmountExpectedDoesNotMatch();
error DigitalP2P_TransferNotProccessed();
error DigitalP2P_InvalidOrderId();
error DigitalP2P_OrderAlreadyExists();
error DigitalP2P_InvalidOrderStatus();
error DigitalP2P_OrderDoesNotExist();
error DigitalP2P_AdminAddressAlreadyExists();
error DigitalP2P_InsufficientUsdtBalance();

/// @title DigitalP2P exchange to buy and sell USDT on Polygon network
/// @author DigitalP2P by Jonathan Díaz jonthdiaz, jonthdiaz@gmail.com
/// @notice This contract is a not KYC exchange to buy and sell USDT on Polygon network
contract DigitalP2P is Ownable {
    using UUIDValidatorLibrary for string;
    // type declarations

    enum orderStatus {
        Pending,
        Completed,
        Fraud,
        PriceMismatch
    }
    // state vars

    // Represent 0.006 as 6 with a multiplier of 1e3
    uint256 constant BOT_FEE = 6; // 0.6%
    uint256 constant PRECISION = 1e3; //1000
    uint256 constant USDT_DECIMAL_PLACES = 1e6; // 1 usdt
    uint256 private s_MinimumAmountUSD = USDT_DECIMAL_PLACES; // 1 usdt
    uint256 private s_MaximumAmountUSD = 500e6; // 500 usdt
    mapping(address => address) private s_admins;

    struct Order {
        string id;
        uint256 cryptoAmount;
        orderStatus status;
        address tokenAddress;
    }
    // The order only can be exist once

    mapping(string orderId => Order order) private s_Orders;

    // *********************** EVENTS ***********************
    event orderCreated(
        orderStatus indexed status,
        string orderId,
        uint256 cryptoAmount
    );
    event orderReleased(string orderId, uint256 cryptoAmount);
    event orderChangeStatus(
        string orderId,
        address user,
        string description,
        orderStatus oldStatus,
        orderStatus newStatus
    );
    // ********************** END OF EVENTS ***********************

    // Here we need to trigger events when
    // - the owner changes
    // - the minimum amount changes
    // - the maximum amount changes
    // errors
    // modifiers
    modifier validAddress(address _address) {
        if (_address == address(0)) revert DigitalP2P_InvalidAddress();
        _;
    }

    modifier onlyOwnerOrAdmin() {
        if (msg.sender == owner() || s_admins[msg.sender] != address(0)) {
            _;
        } else {
            revert DigitalP2P_NotOwnerOrAdmin();
        }
    }

    // functions
    constructor() Ownable(msg.sender) {}

    receive() external payable {}

    /// @notice Process the order to buy USDT
    /// @param _orderId The order id
    /// @param cryptoAmount The amount of USDT sent by the user. value should contain 6 decimal places
    /// @param tokenAddress The address of the token to buy
    /// @dev The usdtToken approve should be done before calling this function
    function processOrder(
        string memory _orderId,
        uint256 cryptoAmount,
        address tokenAddress
    ) public validAddress(tokenAddress) {
        if (cryptoAmount <= 0) {
            revert DigitalP2P_AmountShouldBeGreaterThanZero();
        }
        if (cryptoAmount < s_MinimumAmountUSD) {
            revert DigitalP2P_AmountShouldBeGreaterThanMinimumAmount();
        }
        if (cryptoAmount > s_MaximumAmountUSD) {
            revert DigitalP2P_AmountShouldBeLessThanMaximumAmount();
        }
        if (!_orderId.isValidUUIDv4()) revert DigitalP2P_InvalidOrderId();
        if (
            keccak256(abi.encodePacked(s_Orders[_orderId].id)) ==
            keccak256(abi.encodePacked(_orderId))
        ) {
            revert DigitalP2P_OrderAlreadyExists();
        }

        IERC20 usdtToken = IERC20(tokenAddress);

        bool success = usdtToken.transferFrom(
            msg.sender,
            address(this),
            cryptoAmount
        );
        if (!success) revert DigitalP2P_TransferNotProccessed();

        s_Orders[_orderId] = Order({
            id: _orderId,
            cryptoAmount: cryptoAmount,
            status: orderStatus.Pending,
            tokenAddress: tokenAddress
        });
        emit orderCreated(orderStatus.Pending, _orderId, cryptoAmount);
    }

    /// @notice This function should be triggered by the seller to release the order.
    /// @param _orderId The order id
    /// @param buyer The address of the buyer
    /// @dev Only the seller can release the order
    function releaseOrder(
        string memory _orderId,
        address buyer
    ) public onlyOwnerOrAdmin {
        if (!_orderId.isValidUUIDv4()) revert DigitalP2P_InvalidOrderId();
        if (buyer == address(0)) revert DigitalP2P_InvalidAddress();
        Order storage order = s_Orders[_orderId];
        if (bytes(order.id).length == 0) revert DigitalP2P_OrderDoesNotExist();
        if (order.status != orderStatus.Pending) {
            revert DigitalP2P_InvalidOrderStatus();
        }
        IERC20 usdtToken = IERC20(order.tokenAddress);
        uint256 fee = getBotFee(order.cryptoAmount);
        uint256 amountToTransfer = order.cryptoAmount - fee;
        bool success = usdtToken.transfer(buyer, amountToTransfer);
        if (!success) revert DigitalP2P_TransferNotProccessed();
        emit orderReleased(_orderId, order.cryptoAmount);
        delete s_Orders[_orderId];
    }

    function updateOrderStatus(
        string memory _orderId,
        orderStatus _status
    ) public onlyOwnerOrAdmin {
        if (!_orderId.isValidUUIDv4()) revert DigitalP2P_InvalidOrderId();
        Order storage order = s_Orders[_orderId];
        if (bytes(order.id).length == 0) revert DigitalP2P_OrderDoesNotExist();
        emit orderChangeStatus(
            _orderId,
            msg.sender,
            string(abi.encodePacked("from", order.status, " to ", _status)),
            order.status,
            _status
        );
        order.status = _status;
    }

    /*
    falback() external payable {

    }*/

    /// @notice Set the minimum amount of USDT that can be traded
    /// @param _amount The minimum amount of USDT that can be traded
    /// @dev Only the owner can set the minimum amount
    /// @dev The amount is in USDT not int smallest unit
    function setMinimumAmount(uint256 _amount) external onlyOwnerOrAdmin {
        uint256 amount = _amount * USDT_DECIMAL_PLACES;
        if (amount < USDT_DECIMAL_PLACES) revert DigitalP2P_InvalidAmount();
        s_MinimumAmountUSD = amount;
    }

    /// @notice Set the maximum amount of USDT that can be traded
    /// @param _amount The maximum amount of USDT that can be traded
    /// @dev Only the owner can set the minimum amount
    /// @dev The amount is in USDT not int smallest unit
    function setMaximumAmount(uint256 _amount) external onlyOwnerOrAdmin {
        uint256 amount = _amount * USDT_DECIMAL_PLACES;
        if (amount < USDT_DECIMAL_PLACES) revert DigitalP2P_InvalidAmount();
        if (s_MinimumAmountUSD > amount) revert DigitalP2P_InvalidAmount();
        s_MaximumAmountUSD = amount;
    }

    /// @notice Change the owner of the contract
    /// @param _newOwner The new owner of the contract
    function changeOwner(
        address _newOwner
    ) public onlyOwner validAddress(_newOwner) {
        transferOwnership(_newOwner);
    }

    /// @notice Add an admin to the contract
    /// @param adminAddress The address of the admin
    function addAdmin(
        address adminAddress
    ) public onlyOwner validAddress(adminAddress) {
        if (adminAddress == address(0)) revert DigitalP2P_InvalidAddress();
        if (s_admins[adminAddress] != address(0)) {
            revert DigitalP2P_AdminAddressAlreadyExists();
        }
        s_admins[adminAddress] = adminAddress;
    }

    /// @notice Remove an admin from the contract
    /// @param adminAddress The address of the admin
    function removeAdmin(
        address adminAddress
    ) public onlyOwner validAddress(adminAddress) {
        if (adminAddress == address(0)) revert DigitalP2P_InvalidAddress();
        if (s_admins[adminAddress] == address(0)) {
            revert DigitalP2P_AdminAddressAlreadyExists();
        }
        delete s_admins[adminAddress];
    }

    /// @notice Withdraw the USDT from the contract
    /// @param recipient The address to send the USDT
    /// @param _amount The amount of USDT to send
    function withDrawToken(
        address recipient,
        uint256 _amount,
        address tokenAddress
    ) public onlyOwner validAddress(tokenAddress) {
        IERC20 usdtToken = IERC20(tokenAddress);
        if (usdtToken.balanceOf(address(this)) < _amount) {
            revert DigitalP2P_InsufficientUsdtBalance();
        }
        if (recipient == address(0)) revert DigitalP2P_InvalidAddress();
        if (_amount <= 0) revert DigitalP2P_AmountShouldBeGreaterThanZero();
        usdtToken.transfer(recipient, _amount);
    }

    // @notice Function to withdraw all native tokens to the owner's address
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // functions are first grouped by
    // - external
    // - public
    // - internal
    // - private
    // note how the external functions "descend" in order of how much they can modify or interact with the state

    /// @notice Get the minimum amount of USDT that can be traded by a user
    function getMinimumAmount() external view returns (uint256) {
        return s_MinimumAmountUSD;
    }

    /// @notice Get the maximum amount of USDT that can be traded by a user
    function getMaximumAmount() external view returns (uint256) {
        return s_MaximumAmountUSD;
    }

    /// @notice Get the owner of the contract
    function getOwner() external view returns (address) {
        return owner();
    }

    /// @notice Get the order by id
    /// @param orderId The order id
    function getOrder(
        string memory orderId
    ) external view returns (Order memory) {
        return s_Orders[orderId];
    }

    /// @notice Get the balance of the contract
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Get the balance of the contract

    function getUSDTBalance(
        address tokenAddress
    ) external view validAddress(tokenAddress) returns (uint256) {
        //TODO validate the token address is a valid ERC20 token
        IERC20 usdtToken = IERC20(tokenAddress);
        return usdtToken.balanceOf(address(this));
    }

    /// @notice Get the balance of the user
    /// @param userAddress The user address
    function getUserBalance(
        address userAddress,
        address tokenAddress
    )
        external
        view
        validAddress(tokenAddress)
        validAddress(userAddress)
        returns (uint256)
    {
        IERC20 usdtToken = IERC20(tokenAddress);
        return usdtToken.balanceOf(userAddress);
    }

    /// @notice Get the allowance of the user to the contract
    /// @param userAddress The user address
    /// @param tokenAddress The token address USDT, USDC
    function getUserAllowance(
        address userAddress,
        address tokenAddress
    )
        external
        view
        validAddress(userAddress)
        validAddress(tokenAddress)
        returns (uint256)
    {
        IERC20 usdtToken = IERC20(tokenAddress);
        return usdtToken.allowance(userAddress, address(this));
    }

    /// @notice Get the admin by address
    /// @param adminAddress The admin address
    function getAdmin(address adminAddress) public view returns (address) {
        return s_admins[adminAddress];
    }

    function getBotFee(uint256 amount) public pure returns (uint256) {
        uint256 totalPrecision = 1e9;
        uint256 fee = (amount * (BOT_FEE * PRECISION)) / totalPrecision;
        return fee;
    }

    // internal functions
    // internal view functions
    // internal pure functions
    // private functions
    // private view functions
    // private pure functions
}
