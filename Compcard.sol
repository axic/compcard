// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract CompcardV1 is ERC721 {
    mapping (uint256 => string) private cards;

    /// The next claimable tokenId.
    uint256 public nextTokenId;

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
}
