// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BasicNft is ERC721 {
    //Although everyone who mints the NFT's get the same DOG NFT but they still are unique to make them unique we use the token counter
    uint256 public s_tokenCounter;

    //To keep track of tokenURI w.r.t the TokenId
    mapping (uint256 tokenId => string tokenURI) public _tokenIdToUri;

    constructor() ERC721("DogNFT","DOG"){
        s_tokenCounter = 0;
    }

    function mintNft(string memory tokenUri) public {
        _tokenIdToUri[s_tokenCounter] = tokenUri;
        _safeMint(msg.sender,s_tokenCounter);
        s_tokenCounter++;
    }

    function tokenURI(uint256 tokenId) public view override returns(string memory){
        return _tokenIdToUri[tokenId];
    }
} 