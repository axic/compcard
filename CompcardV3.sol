// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "./Base64.sol";

/// This creates non-transferable immutable 1/1 NFTs.
contract CompcardV3Factory {
    address public immutable implementation;

    event CompcardDeployed(string name, string symbol, address token, uint256 tokenId);

    error DeployFailed();
    error NotSupported();

    constructor() {
        // TODO: use salt for vanity address or pass in the implementation address
        implementation = address(new CompcardV3());
    }

    /// Claim a new Compcard PFP.
    /// @param url A URL pointing to your image, preferably on a content-addressible URL, such as IPFS.
    /// @return token The minted token address.
    /// @return tokenId The minted tokenId (always 1).
    function claim(string calldata name, string calldata symbol, string calldata url) external returns (address token, uint256 tokenId) {
        if (bytes(name).length > 256) revert NotSupported();
        if (bytes(symbol).length > 256) revert NotSupported();

        uint256 payloadLength = 45 + 20 + 2 + bytes(name).length + bytes(symbol).length + bytes(url).length;

        bytes memory bytecode = abi.encodePacked(
            // TODO: use more efficient code (and vanity address)
            hex"3d61",
            uint8(payloadLength >> 8),
            uint8(payloadLength & 0xff),
            hex"80600b3d3981f3363d3d373d3d3d363d73",
            implementation,
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
        tokenId = 1;
        emit CompcardDeployed(name, symbol, token, tokenId);
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
contract CompcardV3 is IERC721, IERC721Metadata, IERC721Enumerable, ERC165 {
    uint256 private constant RUNTIME_CODE_LENGTH = 45; // TODO: add proper length

    error NotSupported();

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
        require(tokenId == 1);
        // TODO: this is wasting memory by loading everything
        (, , ret) = readSettings();
    }

    function balanceOf(address owner) external override view returns (uint256) {
        return (owner == readOwner()) ? 1 : 0;
    }

    function ownerOf(uint256 tokenId) external override view returns (address) {
        require(tokenId == 1);
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

    function totalSupply() external override pure returns (uint) {
        return 1;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) external override view returns (uint256 tokenId) {
        return ((owner == readOwner()) && (index == 0)) ? 1 : 0;
    }

    function tokenByIndex(uint256 index) external view returns (uint256) {
        return (index == 0) ? 1 : 0;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
