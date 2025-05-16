// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
An fully compliant ERC 20 token must implement 6 function and 2 Events
Among these 6 functions, only first 3 functions tokens are enough for a basic token 
*/

/* 
Because public is actually a superset of external (it creates both an external ABI entry and an internal call function), 
you can implement an external interface function as public if you want internal-call flexibility
*/
interface ERC20Interface {
    //Always use external only
    function totalSupply() external view returns(uint);
    function balanceOf(address tokenOwner) external view returns(uint balance);
    function transfer(address to, uint tokens)external returns(bool success);

    function allowance(address tokenOwner,address spender) external view returns(uint remaning);
    function approve(address spender, uint tokens) external returns(bool success);
    function transferFrom(address from, address to, uint tokens) external returns(bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


contract ManualToken is ERC20Interface{
    string public name = "AbhiToken";
    string public symbol = "ABHI";
    uint8 public decimals = 18  ; //18 is the most used value
    uint public override totalSupply;

    address public founder;

    mapping (address => uint) public balances;
    mapping (address => mapping(address => uint)) allowed;

    constructor(){ 
        totalSupply = 1000 ether;
        founder = msg.sender;
        balances[founder] = totalSupply; //So basically at the start only the founder will own all the tokens
    }

    function balanceOf(address tokenOwner) public view override returns(uint balance){
        return balances[tokenOwner];
    }

    function transfer(address to, uint tokens)public override returns(bool success){
        //Check first the sender account has enough balance
        require(balances[msg.sender] > tokens);
        require(tokens > 0);

        balances[to] = balances[to] + tokens;
        balances[msg.sender] = balances[msg.sender] - tokens;   

        emit Transfer(msg.sender,to,tokens);
        return true;
    }

    function allowance(address tokenOwner,address spender) view public override returns(uint remaning){
        return allowed[tokenOwner][spender];
    }

    function approve(address spender, uint tokens)public override returns(bool success){
        require(balances[msg.sender] >= tokens);
        require(tokens > 0);

        allowed[msg.sender][spender] = tokens;

        emit Approval(msg.sender,spender,tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens)public override returns(bool success){
        require(allowed[from][msg.sender] >= tokens);
        require(balanceOf(from) >= tokens);

        balances[from] -= tokens;
        allowed[from][msg.sender] -= tokens;
        balances[to] += tokens;

        emit Transfer(from,to,tokens);
        return true;
    }
}               