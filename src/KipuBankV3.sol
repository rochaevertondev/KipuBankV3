// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
}


contract KipuBank is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    IUniversalRouter public immutable universalRouter;
    
    IPermit2 public immutable permit2;
    
    IWETH public immutable weth;
    
    IERC20 public immutable USDC;

    uint256 public bankCapUsdc6;
    
    uint256 public totalUsdc;
    
    mapping(address => uint256) public balanceUsdc;
    
    uint256 public depositCount;
    uint256 public withdrawCount;
    
    address public immutable ownerBank;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    error NotOwnerBank(address caller);
    error NotAccountOwner(address caller);
    error InvalidValue(uint256 value);
    error InsufficientBalance(uint256 available);
    error BankCapExceeded(uint256 attempted, uint256 cap);
    error InsufficientSwapOutput(uint256 received, uint256 minimum);
    error TransferFailed();

    event SuccessfulDeposit(
        address indexed account,
        address indexed token,
        uint256 amount,
        uint256 newBalance,
        uint256 usdValue
    );
    event SuccessfulWithdrawal(
        address indexed account,
        address indexed token,
        uint256 amount,
        uint256 newBalance,
        uint256 usdValue
    );
    event SwappedToUSDC(address indexed user, address indexed tokenIn, uint256 amountIn, uint256 usdcOut);
    event AdminRecovery(address indexed account, address indexed token, uint256 oldBalance, uint256 newBalance);
    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);

    constructor(
        address _universalRouter,
        address _permit2,
        address _weth,
        address _usdc,
        uint256 _bankCapUsdc6
    ) {
        require(_universalRouter != address(0), "router=0");
        require(_permit2 != address(0), "permit2=0");
        require(_weth != address(0), "weth=0");
        require(_usdc != address(0), "usdc=0");
        
        universalRouter = IUniversalRouter(_universalRouter);
        permit2 = IPermit2(_permit2);
        weth = IWETH(_weth);
        USDC = IERC20(_usdc);
        
        ownerBank = msg.sender;
        bankCapUsdc6 = _bankCapUsdc6 > 0 ? _bankCapUsdc6 : 10000 * 10 ** 6; // 10k USDC default

        _grantRole(OWNER_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
    }

    // ========= Modifiers =========
    
    modifier onlyOwner() {
        if (!hasRole(OWNER_ROLE, msg.sender)) {
            revert NotOwnerBank(msg.sender);
        }
        _;
    }

    modifier onlyAccountOwnerOrAdmin(address account) {
        if (msg.sender != account && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert NotAccountOwner(msg.sender);
        }
        _;
    }

    // ========= Deposit Functions =========

    /// @notice Direct USDC deposit (no swap needed)
    function depositToken(address token, uint256 amount) external nonReentrant {
        require(token == address(USDC), "Only USDC direct deposits");
        if (amount == 0) revert InvalidValue(amount);
        if (totalUsdc + amount > bankCapUsdc6) revert BankCapExceeded(totalUsdc + amount, bankCapUsdc6);

        uint256 before = USDC.balanceOf(address(this));
        USDC.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = USDC.balanceOf(address(this)) - before;

        balanceUsdc[msg.sender] += received;
        totalUsdc += received;
        unchecked { depositCount++; }

        emit SuccessfulDeposit(
            msg.sender,
            address(USDC),
            received,
            balanceUsdc[msg.sender],
            received * 100
        );
    }

    /// @notice Deposit ETH and swap to USDC
    function depositETHAndSwap(
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 minUsdcOut,
        uint256 deadline
    ) external payable nonReentrant {
        if (msg.value == 0) revert InvalidValue(msg.value);
        if (totalUsdc + minUsdcOut > bankCapUsdc6) revert BankCapExceeded(totalUsdc + minUsdcOut, bankCapUsdc6);

        // Wrap ETH to WETH
        weth.deposit{value: msg.value}();

        // Approve Permit2
        if (IERC20(address(weth)).allowance(address(this), address(permit2)) < msg.value) {
            IERC20(address(weth)).approve(address(permit2), type(uint256).max);
        }
        
        // Grant router permission
        permit2.approve(address(weth), address(universalRouter), uint160(msg.value), type(uint48).max);

        uint256 beforeBal = USDC.balanceOf(address(this));
        universalRouter.execute(commands, inputs, deadline);
        uint256 afterBal = USDC.balanceOf(address(this));
        uint256 usdcOut = afterBal - beforeBal;

        if (usdcOut < minUsdcOut) revert InsufficientSwapOutput(usdcOut, minUsdcOut);

        balanceUsdc[msg.sender] += usdcOut;
        totalUsdc += usdcOut;
        unchecked { depositCount++; }

        emit SwappedToUSDC(msg.sender, ETH_ADDRESS, msg.value, usdcOut);
        emit SuccessfulDeposit(
            msg.sender,
            ETH_ADDRESS,
            msg.value,
            balanceUsdc[msg.sender],
            usdcOut * 100
        );
    }

    /// @notice Deposit any token and swap to USDC
    function depositTokenAndSwap(
        address token,
        uint256 amount,
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 minUsdcOut,
        uint256 deadline
    ) external nonReentrant {
        if (amount == 0) revert InvalidValue(amount);
        if (totalUsdc + minUsdcOut > bankCapUsdc6) revert BankCapExceeded(totalUsdc + minUsdcOut, bankCapUsdc6);

        // Transfer token from user
        uint256 before = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - before;

        // Approve Permit2
        if (IERC20(token).allowance(address(this), address(permit2)) < received) {
            IERC20(token).approve(address(permit2), type(uint256).max);
        }
        
        // Grant router permission
        permit2.approve(token, address(universalRouter), uint160(received), type(uint48).max);

        // Execute swap
        uint256 usdcBefore = USDC.balanceOf(address(this));
        universalRouter.execute(commands, inputs, deadline);
        uint256 usdcAfter = USDC.balanceOf(address(this));
        uint256 usdcOut = usdcAfter - usdcBefore;

        if (usdcOut < minUsdcOut) revert InsufficientSwapOutput(usdcOut, minUsdcOut);

        balanceUsdc[msg.sender] += usdcOut;
        totalUsdc += usdcOut;
        unchecked { depositCount++; }

        emit SwappedToUSDC(msg.sender, token, received, usdcOut);
        emit SuccessfulDeposit(
            msg.sender,
            token,
            received,
            balanceUsdc[msg.sender],
            usdcOut * 100
        );
    }

    // ========= Withdrawal Functions =========

    /// @notice Withdraw USDC directly
    function withdrawToken(address token, uint256 amount) external nonReentrant {
        require(token == address(USDC), "Only USDC withdrawals");
        if (amount == 0) revert InvalidValue(amount);
        if (amount > balanceUsdc[msg.sender]) revert InsufficientBalance(balanceUsdc[msg.sender]);

        balanceUsdc[msg.sender] -= amount;
        totalUsdc -= amount;
        unchecked { withdrawCount++; }

        USDC.safeTransfer(msg.sender, amount);

        emit SuccessfulWithdrawal(
            msg.sender,
            address(USDC),
            amount,
            balanceUsdc[msg.sender],
            amount * 100
        );
    }

    /// @notice Withdraw USDC and swap to target token
    function withdrawAndSwap(
        uint256 usdcAmount,
        address targetToken,
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 minTokenOut,
        uint256 deadline
    ) external nonReentrant {
        if (usdcAmount == 0) revert InvalidValue(usdcAmount);
        if (usdcAmount > balanceUsdc[msg.sender]) revert InsufficientBalance(balanceUsdc[msg.sender]);

        balanceUsdc[msg.sender] -= usdcAmount;
        totalUsdc -= usdcAmount;
        unchecked { withdrawCount++; }

        // Approve Permit2
        if (USDC.allowance(address(this), address(permit2)) < usdcAmount) {
            USDC.approve(address(permit2), type(uint256).max);
        }
        
        // Grant router permission
        permit2.approve(address(USDC), address(universalRouter), uint160(usdcAmount), type(uint48).max);

        // Execute swap
        uint256 tokenBefore = IERC20(targetToken).balanceOf(address(this));
        universalRouter.execute(commands, inputs, deadline);
        uint256 tokenAfter = IERC20(targetToken).balanceOf(address(this));
        uint256 tokenOut = tokenAfter - tokenBefore;

        if (tokenOut < minTokenOut) revert InsufficientSwapOutput(tokenOut, minTokenOut);

        // Transfer target tokens to user
        IERC20(targetToken).safeTransfer(msg.sender, tokenOut);

        emit SuccessfulWithdrawal(
            msg.sender,
            targetToken,
            tokenOut,
            balanceUsdc[msg.sender],
            usdcAmount * 100
        );
    }

    // ========= View Functions =========

    function getBalanceOf(address token, address account) 
        external 
        view 
        onlyAccountOwnerOrAdmin(account) 
        returns (uint256) 
    {
        require(token == address(USDC), "Only USDC balances tracked");
        return balanceUsdc[account];
    }

    function totalBankUsd() public view returns (uint256) {
        return totalUsdc * 100;
    }

    function currentBalance() external view onlyOwner returns (uint256) {
        return totalBankUsd();
    }

    function capRemaining() public view returns (uint256) {
        return bankCapUsdc6 > totalUsdc ? (bankCapUsdc6 - totalUsdc) : 0;
    }

    // ========= Admin Functions =========

    function setBankCapUsdc6(uint256 newCap) external onlyOwner {
        bankCapUsdc6 = newCap;
    }

    function addAdmin(address account) external onlyOwner {
        _grantRole(ADMIN_ROLE, account);
        emit AdminAdded(account);
    }

    function removeAdmin(address account) external onlyOwner {
        _revokeRole(ADMIN_ROLE, account);
        emit AdminRemoved(account);
    }

    function recoverUserBalance(
        address token,
        address account,
        uint256 newBalance
    ) external onlyRole(ADMIN_ROLE) {
        require(token == address(USDC), "Only USDC balances");
        uint256 old = balanceUsdc[account];
        
        if (newBalance > old) {
            uint256 delta = newBalance - old;
            balanceUsdc[account] = newBalance;
            totalUsdc += delta;
        } else if (newBalance < old) {
            uint256 delta = old - newBalance;
            balanceUsdc[account] = newBalance;
            totalUsdc -= delta;
        }

        emit AdminRecovery(account, token, old, newBalance);
    }

    receive() external payable {}
}
