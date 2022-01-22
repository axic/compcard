// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "./Base64.sol";

/// This creates non-transferable immutable 1/1 NFTs.
///
/// Should transferability be preferred, the owner field should moved to be a storage item.
///
/// The design is a proxy contract, which contains most of the details as "immutables"
/// concatenated at the end of the contract. The layout is specific:
/// - 20 bytes: owner
/// - 1 byte: length of name
/// - 1 byte: length of symbol
/// - n bytes: name
/// - n bytes: symbol
/// - the remaining bytes: url
contract CompcardV3 is IERC721, IERC721Metadata, ERC165 {
    uint256 private constant RUNTIME_CODE_LENGTH = 45; // TODO: add proper length

    event CompcardDeployed(string name, string symbol, address token);

    error DeployFailed();
    error NotSupported();

    /// Claim a new Compcard PFP.
    /// @param url A URL pointing to your image, preferably on a content-addressible URL, such as IPFS.
    /// @return token The minted token address.
    /// @return tokenId The minted tokenId (always 0).
    //
    // TODO: should separate this out into a factory
    function claim(string calldata name, string calldata symbol, string calldata url) external returns (address token, uint256 tokenId) {
        if (bytes(name).length > 256) revert NotSupported();
        if (bytes(symbol).length > 256) revert NotSupported();

        bytes memory bytecode = abi.encodePacked(
            // TODO: use more efficient code (and vanity address)
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            address(this),
            hex"5af43d82803e903d91602b57fd5bf3",
            msg.sender,
            uint8(bytes(name).length),
            uint8(bytes(symbol).length),
            name,
            symbol,
            url
        );
        assembly {
            token := create(0, add(bytecode, 32), mload(bytecode))
        }
        if (token == address(0)) {
            revert DeployFailed();
        }
        emit CompcardDeployed(name, symbol, token);
    }

    function readOwner() private view returns (address owner) {
        uint256 proxyLength = RUNTIME_CODE_LENGTH;
        assembly {
            // Read into the scratch space
            extcodecopy(address(), 0, proxyLength, 20)
            owner := shr(96, mload(0))
        }
    }

    function readSettings() private view returns (string memory name, string memory symbol, string memory data) {
        uint256 proxyLength = RUNTIME_CODE_LENGTH;
        uint256 codeLength = address(this).code.length;
        uint256 length = codeLength - proxyLength;

        // These are wasting memory but we don't care.
        name = new string(256);
        symbol = new string(256);
        data = new string(length);

        assembly {
            // We skip the owner.
            let offset := add(proxyLength, 20)

            // Load sizes to scratch space.
            mstore(0, 0)
            extcodecopy(address(), 0, offset, 2)
            offset := add(offset, 2)

            let nameLength := byte(0, mload(0))
            let symbolLength := byte(1, mload(0))

            mstore(name, nameLength)
            extcodecopy(address(), add(name, 32), offset, nameLength)
            offset := add(offset, nameLength)

            mstore(symbol, symbolLength)
            extcodecopy(address(), add(symbol, 32), offset, symbolLength)
            offset := add(offset, symbolLength)

            length := sub(codeLength, offset)
            mstore(data, length)
            extcodecopy(address(), add(data, 32), offset, length)
        }
    }

    function name() public view virtual override returns (string memory ret) {
        // TODO: this is wasting memory by loading everything
        (ret, , ) = readSettings();
    }

    function symbol() public view virtual override returns (string memory ret) {
        // TODO: this is wasting memory by loading everything
        (, ret, ) = readSettings();
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory ret) {
        require(tokenId == 0);
        // TODO: this is wasting memory by loading everything
        (, , ret) = readSettings();
    }

    function balanceOf(address owner) external override view returns (uint256) {
        require(owner == readOwner());
        return 0;
    }

    function ownerOf(uint256 tokenId) external override view returns (address) {
        require(tokenId == 0);
        return readOwner();
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external override {
        revert();
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external override {
        revert();
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external override {
        revert();
    }
     function approve(address to, uint256 tokenId) external override {
        revert();
    }

    function getApproved(uint256 tokenId) external override view returns (address operator) {
    }

    function setApprovalForAll(address operator, bool _approved) external override {
        revert();
    }

    function isApprovedForAll(address owner, address operator) external override view returns (bool) {
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// This can be used to convert an image into a data URL.
    /// Ideally this is used off-chain.
    function toDataURL(bytes calldata image) external pure returns (string memory) {
        bool jpeg;
        if (image[0] == 0xff && image[1] == 0xd8 && image[2] == 0xff) {
            jpeg = true;
        } else if (keccak256(image[0:8]) != keccak256(hex"89504e470d0a1a0a")) {
            revert NotSupported();
        }

        return string(bytes.concat(
            "data:",
            jpeg ? bytes("image/jpeg;base64,") : bytes("image/png;base64,"),
            bytes(Base64.encode(image))
        ));
    }
}
