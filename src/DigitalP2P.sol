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
error DigitalP2P_UserIsNotAllowedToReleaseFunds();
error DigitalP2P_OrderDoesNotExist();
error DigitalP2P_AdminAddressAlreadyExists();

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

    uint256 constant USDT_DECIMAL_PLACES = 1e6; // 1 usdt
    uint256 private s_MinimumAmountUSD = USDT_DECIMAL_PLACES; // 1 usdt
    uint256 private s_MaximumAmountUSD = 500e6; // 500 usdt
    mapping(address => address) private s_admins;

    struct Order {
        string id;
        address buyer;
        address seller;
        uint256 cryptoAmount;
        orderStatus status;
    }
    // The order only can be exist once

    mapping(string orderId => Order order) private s_Orders;
    IERC20 public usdtToken;

    // events
    event orderCreated(
        string indexed orderId,
        orderStatus indexed status,
        address buyer,
        address seller,
        uint256 cryptoAmount
    );
    event orderReleased(
        string indexed orderId,
        address indexed seller,
        address indexed buyer,
        uint256 cryptoAmount
    );
    event orderChangeStatus(
        string indexed orderId,
        address indexed user,
        string indexed description,
        orderStatus oldStatus,
        orderStatus newStatus
    );
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
    constructor(address _usdtTokenAddress) Ownable(msg.sender) {
        usdtToken = IERC20(_usdtTokenAddress);
    }

    receive() external payable {}

    /// @notice Process the order to buy USDT
    /// @param _orderId The order id
    /// @param _seller The seller address
    /// @param _userUsdtAmountSent The amount of USDT sent by the user
    /// @param _orderUsdtAmount The amount of USDT that the user should send
    /// @dev The usdtToken approve should be done before calling this function
    function processOrder(
        string memory _orderId,
        address _seller,
        uint256 _userUsdtAmountSent,
        uint256 _orderUsdtAmount
    ) public payable {
        uint256 userUsdtAmountSent = _userUsdtAmountSent * USDT_DECIMAL_PLACES;
        uint256 orderUsdtAmount = _orderUsdtAmount * USDT_DECIMAL_PLACES;
        if (userUsdtAmountSent <= 0)
            revert DigitalP2P_AmountShouldBeGreaterThanZero();
        if (userUsdtAmountSent < s_MinimumAmountUSD) {
            revert DigitalP2P_AmountShouldBeGreaterThanMinimumAmount();
        }
        if (userUsdtAmountSent > s_MaximumAmountUSD) {
            revert DigitalP2P_AmountShouldBeLessThanMaximumAmount();
        }
        if (userUsdtAmountSent != orderUsdtAmount) {
            revert DigitalP2P_AmountExpectedDoesNotMatch();
        }
        if (!_orderId.isValidUUIDv4()) revert DigitalP2P_InvalidOrderId();
        if (_seller == address(0)) revert DigitalP2P_InvalidAddress();
        if (
            keccak256(abi.encodePacked(s_Orders[_orderId].id)) ==
            keccak256(abi.encodePacked(_orderId))
        ) {
            revert DigitalP2P_OrderAlreadyExists();
        }
        bool success = usdtToken.transferFrom(
            _seller,
            address(this),
            userUsdtAmountSent
        );
        if (!success) revert DigitalP2P_TransferNotProccessed();

        s_Orders[_orderId] = Order({
            id: _orderId,
            buyer: msg.sender,
            seller: _seller,
            cryptoAmount: userUsdtAmountSent,
            status: orderStatus.Pending
        });
        emit orderCreated(
            _orderId,
            orderStatus.Pending,
            msg.sender,
            _seller,
            userUsdtAmountSent
        );
    }

    /// @notice This function should be triggered by the seller to release the order.
    /// @param _orderId The order id
    /// @dev Only the seller can release the order

    function releaseOrder(string memory _orderId) public onlyOwnerOrAdmin {
        if (!_orderId.isValidUUIDv4()) revert DigitalP2P_InvalidOrderId();
        Order storage order = s_Orders[_orderId];
        if (bytes(order.id).length == 0) revert DigitalP2P_OrderDoesNotExist();
        if (!_orderId.isValidUUIDv4()) revert DigitalP2P_InvalidOrderId();
        if (order.status != orderStatus.Pending) {
            revert DigitalP2P_InvalidOrderStatus();
        }
        if (order.seller != msg.sender) {
            revert DigitalP2P_UserIsNotAllowedToReleaseFunds();
        }

        bool success = usdtToken.transfer(order.buyer, order.cryptoAmount);
        if (!success) revert DigitalP2P_TransferNotProccessed();
        emit orderReleased(
            _orderId,
            order.seller,
            order.buyer,
            order.cryptoAmount
        );
        delete s_Orders[_orderId];
    }

    function updateOrderStatus(
        string memory _orderId,
        orderStatus _status
    ) public onlyOwnerOrAdmin {
        if (!_orderId.isValidUUIDv4()) revert DigitalP2P_InvalidOrderId();
        Order storage order = s_Orders[_orderId];
        if (bytes(order.id).length == 0) revert DigitalP2P_OrderDoesNotExist();
        emit orderChangeStatus(_orderId, msg.sender, string(abi.encodePacked("from", order.status, " to ", _status)), order.status, _status);
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
        if (s_admins[adminAddress] != address(0))
            revert DigitalP2P_AdminAddressAlreadyExists();
        s_admins[adminAddress] = adminAddress;
    }

    /// @notice Remove an admin from the contract
    /// @param adminAddress The address of the admin
    function removeAdmin(
        address adminAddress
    ) public onlyOwner validAddress(adminAddress) {
        if (adminAddress == address(0)) revert DigitalP2P_InvalidAddress();
        if (s_admins[adminAddress] == address(0))
            revert DigitalP2P_AdminAddressAlreadyExists();
        delete s_admins[adminAddress];
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

    function getUSDTBalance() external view returns (uint256) {
        return usdtToken.balanceOf(address(this));
    }

    /// @notice Get the balance of the user
    /// @param userAddress The user address
    function getUserBalance(
        address userAddress
    ) external view returns (uint256) {
        return usdtToken.balanceOf(userAddress);
    }

    /// @notice Get the allowance of the user to the contract
    /// @param userAddress The user address
    function getUserAllowance(
        address userAddress
    ) external view returns (uint256) {
        return usdtToken.allowance(userAddress, address(this));
    }

    /// @notice Get the admin by address
    /// @param adminAddress The admin address
    function getAdmin(address adminAddress) public view returns (address) {
        return s_admins[adminAddress];
    }

    // internal functions
    // internal view functions
    // internal pure functions
    // private functions
    // private view functions
    // private pure functions
}
