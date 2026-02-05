// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Owned} from "../libraries/Owned.sol";

contract TrancheRegistry is Owned {
    error NotFactory();
    error ZeroAddress();

    struct ProductInfo {
        address controller;
        address seniorToken;
        address juniorToken;
        address vault;
        address teller;
        address manager;
        address asset;
        bytes32 paramsHash;
    }

    address public factory;
    ProductInfo[] private _products;

    event FactoryUpdated(address indexed oldFactory, address indexed newFactory);
    event ProductCreated(
        uint256 indexed productId,
        address indexed controller,
        address seniorToken,
        address juniorToken,
        address indexed vault,
        address teller,
        address manager,
        address asset,
        bytes32 paramsHash
    );

    constructor(address owner_, address factory_) {
        _initOwner(owner_);
        factory = factory_;
    }

    modifier onlyFactory() {
        if (msg.sender != factory) revert NotFactory();
        _;
    }

    function setFactory(address newFactory) external onlyOwner {
        if (newFactory == address(0)) revert ZeroAddress();
        emit FactoryUpdated(factory, newFactory);
        factory = newFactory;
    }

    function registerProduct(ProductInfo calldata info) external onlyFactory returns (uint256 productId) {
        productId = _products.length;
        _products.push(info);
        emit ProductCreated(
            productId,
            info.controller,
            info.seniorToken,
            info.juniorToken,
            info.vault,
            info.teller,
            info.manager,
            info.asset,
            info.paramsHash
        );
    }

    function productCount() external view returns (uint256) {
        return _products.length;
    }

    function products(uint256 id) external view returns (ProductInfo memory) {
        return _products[id];
    }

    function getProducts(uint256 offset, uint256 limit) external view returns (ProductInfo[] memory) {
        uint256 total = _products.length;
        if (offset >= total) {
            return new ProductInfo[](0);
        }
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        uint256 size = end - offset;
        ProductInfo[] memory page = new ProductInfo[](size);
        for (uint256 i = 0; i < size; i++) {
            page[i] = _products[offset + i];
        }
        return page;
    }
}
