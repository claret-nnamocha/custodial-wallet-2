// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract Wallet {
    address payable public owner;

    uint256 MAX_AMOUNT =
        57896044618658100000000000000000000000000000000000000000000000000000000000000;

    receive() external payable {}

    fallback() external payable {}

    constructor() {
        owner = payable(msg.sender);
    }

    modifier isOwner() {
        require(msg.sender == owner, "You are not permitted");
        _;
    }

    function drainETH() public isOwner returns (bool) {
        return owner.send(address(this).balance);
    }

    function approve(
        address tracker,
        address spender
    ) public isOwner returns (bool) {
        return IERC20(tracker).approve(spender, MAX_AMOUNT);
    }
}

contract WalletFactory {
    mapping(bytes => address) private deployedWallets;

    mapping(address => bool) private permitted;

    receive() external payable {}

    constructor() {
        permitted[msg.sender] = true;
    }

    modifier senderIsPermitted() {
        require(permitted[msg.sender], "You are not permitted");
        _;
    }

    modifier walletIsCreated(bytes memory salt) {
        require(isCreated(salt), "Wallet is not yet created");
        _;
    }

    function isContract(address account) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(account)
        }
        return (size > 0);
    }

    function approve(
        bytes memory salt,
        address erc20,
        address spender
    ) private senderIsPermitted {
        address payable account = payable(deployedWallets[salt]);
        Wallet(account).approve(erc20, spender);
    }

    function isPermitted(address account) public view returns (bool) {
        return permitted[account];
    }

    function isCreated(bytes memory salt) public view returns (bool) {
        return
            deployedWallets[salt] != 0x0000000000000000000000000000000000000000;
    }

    function getAddress(bytes memory salt) public view returns (address) {
        bytes memory bytecode = type(Wallet).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode());

        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                uint256(bytes32(salt)),
                keccak256(bytecode)
            )
        );
        return address(uint160(uint256(hash)));
    }

    function getERC20Balance(
        bytes memory salt,
        address erc20
    ) public view returns (uint256) {
        return IERC20(erc20).balanceOf(deployedWallets[salt]);
    }

    function getETHBalance(bytes memory salt) public view returns (uint256) {
        return address(deployedWallets[salt]).balance;
    }

    function grantPermission(address account) public senderIsPermitted {
        require(!isContract(account), "Account is a smart contract");
        require(!permitted[account], "Account is already permitted");
        permitted[account] = true;
    }

    function revokePermission(address account) public senderIsPermitted {
        require(permitted[account], "Account is not permitted");
        permitted[account] = false;
    }

    function createWallet(bytes memory salt) public senderIsPermitted {
        if (!isCreated(salt)) {
            bytes memory bytecode = type(Wallet).creationCode;
            bytecode = abi.encodePacked(bytecode, abi.encode());
            uint256 index = uint256(bytes32(salt));

            address walletAddress;

            assembly {
                walletAddress := create2(
                    callvalue(),
                    add(bytecode, 0x20),
                    mload(bytecode),
                    index
                )

                if iszero(extcodesize(walletAddress)) {
                    revert(0, 0)
                }
            }

            deployedWallets[salt] = walletAddress;
        }
    }

    function drainETH(
        bytes memory salt
    ) public senderIsPermitted walletIsCreated(salt) {
        address payable walletAccount = payable(deployedWallets[salt]);
        Wallet(walletAccount).drainETH();
    }

    function drainERC20(
        bytes memory salt,
        address erc20
    ) public senderIsPermitted walletIsCreated(salt) {
        address account = deployedWallets[salt];
        IERC20 token = IERC20(erc20);

        uint256 allowance = token.allowance(account, address(this));
        uint256 balance = token.balanceOf(account);

        if (allowance < balance) {
            approve(salt, erc20, address(this));
        }

        token.transferFrom(account, address(this), balance);
    }

    function transferERC20(
        address tracker,
        uint256 amount,
        address to
    ) public senderIsPermitted returns (bool) {
        return IERC20(tracker).transfer(to, amount);
    }

    function transferETH(
        uint256 amount,
        address payable to
    ) public senderIsPermitted returns (bool) {
        return to.send(amount);
    }
}
