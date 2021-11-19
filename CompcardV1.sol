// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./Base64.sol";

contract CompcardV1 is ERC721 {
    mapping (uint256 => string) private cards;

    /// The next claimable tokenId.
    uint256 public nextTokenId;

    error NotSupported();

    constructor() ERC721("Compcard V1", "CCV1") {
    }

    /// Claim a new Compcard PFP.
    /// @param url A URL pointing to your image, preferably on a content-addressible URL, such as IPFS.
    /// @return tokenId The minted tokenId.
    function claim(string calldata url) external returns (uint256 tokenId) {
        tokenId = ++nextTokenId;
        cards[tokenId] = url;
        _safeMint(msg.sender, tokenId);
    }

    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        return cards[tokenId];
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
