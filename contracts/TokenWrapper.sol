// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./libraries/ERC20.sol";
import "./interfaces/IERC20.sol";

contract TokenWrapper is
    ERC20,
    PausableUpgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant PROXY_ADMIN_ROLE = keccak256("PROXY_ADMIN");

    IERC20 public toWrap;
    address public feeReceiver;
    address public proxyAdmin;

    event Wrapped(address indexed account, uint amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     *
     * @notice Initializes the contract
     * @param _admin Default admin who can grant and revoke roles
     * @param _pauser Wallet address that can pause and unpause mints and transfers
     * @param _operator General operator
     * @param _toWrap Asset that will be wrapped
     * @param _proxyAdmin Responsible for upgrading this contract, ideally a proxyAdmin contract
     */
    function initialize(
        address _admin,
        address _pauser,
        address _operator,
        IERC20 _toWrap,
        address _proxyAdmin
    ) public initializer {
        toWrap = _toWrap;
        string memory symbol = toWrap.symbol();
        string memory name = string(abi.encodePacked("x", symbol)); //placeholder names
        string memory _symbol = string(abi.encodePacked("Wrapped", symbol));
        __ERC20_init(name, _symbol);
        __AccessControlEnumerable_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _pauser);
        _grantRole(OPERATOR_ROLE, _operator);
        _grantRole(PROXY_ADMIN_ROLE, _proxyAdmin);
        proxyAdmin = _proxyAdmin;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setFeeReceiver(address _feeReceiver) external onlyRole(OPERATOR_ROLE) {
        feeReceiver = _feeReceiver;
    }

    /**
     * 
     * @notice Take wrapped token out of this contract
     */
    function withdrawWrapped(uint amount, address to) external onlyRole(OPERATOR_ROLE) {
        toWrap.transfer(to, amount);
    }

    /**
     *
     * @notice deposit `toWrap` and receive a wrapped version in a 1:1 ratio
     * @dev since ratio is 1:1, wrapper totalSupply == total wrapped.
     * @param amount How many tokens to wrap
     */
    function deposit(uint amount) public whenNotPaused {
        toWrap.transferFrom(msg.sender, address(this), amount);
        emit Wrapped(msg.sender, amount);
        _mint(msg.sender, amount);
    }

    /**
     * 
     * @notice override internal _transfer to charge fees
     */
    function _transfer(address from, address to, uint amount) internal override {
        // 1% fee charged before transfer
        uint fee;
        unchecked {
            fee = (amount * 1e18) / 10e18;
        }
        _burn(from, fee);
        _mint(feeReceiver, fee >> 1);
        super._transfer(from, to, amount - fee);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(PROXY_ADMIN_ROLE) {}

    /// @dev grantRole already checks role, so no more additional checks are necessary
    function changeAdmin(address newAdmin) external {
        grantRole(PROXY_ADMIN_ROLE, newAdmin);
        renounceRole(PROXY_ADMIN_ROLE, proxyAdmin);
        proxyAdmin = newAdmin;
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }
}
