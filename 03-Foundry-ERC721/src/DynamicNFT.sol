// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract DynamicNft is ERC721 {
    uint256 public s_tokenCounter;
    string private s_happySvgImageURI;
    string private s_sadSvgImageURI;

    enum Mood {
        HAPPY,
        SAD
    }

    mapping (uint256 => Mood) private s_tokenIdToMood;

    constructor (string memory happySvg, string memory sadSvg) ERC721("MoodNFT","MN"){
        s_tokenCounter = 0;
        s_happySvgImageURI = happySvg;
        s_sadSvgImageURI = sadSvg;
    }

    function mintNft() public {
        _safeMint(msg.sender,s_tokenCounter);
        s_tokenIdToMood[s_tokenCounter] = Mood.HAPPY;
        s_tokenCounter++;
    }

    function flipMood(uint256 tokenId) public{
        require(_ownerOf(tokenId) == msg.sender,"Not the owner");
        
        if(s_tokenIdToMood[tokenId] == Mood.HAPPY){
            s_tokenIdToMood[tokenId] = Mood.SAD;
        }else if(s_tokenIdToMood[tokenId] == Mood.SAD){
            s_tokenIdToMood[tokenId] = Mood.HAPPY;
        }
    }

    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    function tokenURI(uint256 tokenId) public view override returns(string memory){
        string memory imageURI;

        if(s_tokenIdToMood[tokenId] == Mood.HAPPY){
            imageURI = s_happySvgImageURI;
        }else {
            imageURI = s_sadSvgImageURI;
        }

        return string(
            abi.encodePacked(
                _baseURI(),
                Base64.encode(
                    bytes( // bytes casting actually unnecessary as 'abi.encodePacked()' returns a bytes
                        abi.encodePacked(
                            '{"name":"',
                            name(), // You can add whatever name here
                            '", "description":"An NFT that reflects the mood of the owner, 100% on Chain!", ',
                            '"attributes": [{"trait_type": "moodiness", "value": 100}], "image":"',
                            imageURI,
                            '"}'
                        )
                    )
                )
            )
        );
    }


    //Getter function
    function getTokenIdToMood(uint256 tokenId) external view returns(Mood){
        return s_tokenIdToMood[tokenId];
    }
}