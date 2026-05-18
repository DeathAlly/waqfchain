// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUSDC {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract ComplianceRegistry {
    address public owner;

    struct InvestorRecord {
        bool kycVerified;
        bool sanctionsCleared;
        bool accredited;
        uint256 verifiedAt;
        string jurisdiction;
    }

    struct AssetRecord {
        bool shariaCompliant;
        bool awqafRegistered;
        bytes32 awqafHash;
        bytes32 shariaFatwaHash;
        uint256 lastAudit;
        uint256 complianceScore;
    }

    mapping(address => InvestorRecord) public investors;
    mapping(address => AssetRecord) public assets;
    mapping(address => bool) public trustedOracles;

    event InvestorVerified(address indexed investor, string jurisdiction);
    event AssetCompliant(address indexed tokenContract, bytes32 awqafHash);

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier onlyOracle() { require(trustedOracles[msg.sender], "Not oracle"); _; }

    constructor() { owner = msg.sender; }

    function setOracle(address oracle, bool trusted) external onlyOwner {
        trustedOracles[oracle] = trusted;
    }

    function verifyInvestor(address investor, bool accredited, string calldata jurisdiction) external onlyOracle {
        investors[investor] = InvestorRecord(true, true, accredited, block.timestamp, jurisdiction);
        emit InvestorVerified(investor, jurisdiction);
    }

    function registerAsset(address tokenContract, bytes32 awqafHash, bytes32 shariaFatwaHash, uint256 score) external onlyOracle {
        assets[tokenContract] = AssetRecord(true, true, awqafHash, shariaFatwaHash, block.timestamp, score);
        emit AssetCompliant(tokenContract, awqafHash);
    }

    function isEligible(address investor) external view returns (bool) {
        return investors[investor].kycVerified && investors[investor].sanctionsCleared;
    }

    function isAssetCompliant(address tokenContract) external view returns (bool) {
        return assets[tokenContract].shariaCompliant && assets[tokenContract].awqafRegistered;
    }
}

contract WaqfToken {
    address public owner;
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    string public assetName;
    string public assetLocation;
    string public waqfRegNumber;
    uint256 public totalValuation;
    uint256 public annualYieldBps;
    bool public paused;

    ComplianceRegistry public compliance;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    struct Beneficiary {
        address wallet;
        uint256 shareBps;
        string purpose;
    }
    Beneficiary[] public beneficiaries;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event TokensIssued(address indexed to, uint256 amount);

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier whenNotPaused() { require(!paused, "Paused"); _; }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _assetName,
        string memory _assetLocation,
        string memory _waqfRegNumber,
        uint256 _totalValuation,
        uint256 _annualYieldBps,
        uint256 _initialSupply,
        address _complianceRegistry
    ) {
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        assetName = _assetName;
        assetLocation = _assetLocation;
        waqfRegNumber = _waqfRegNumber;
        totalValuation = _totalValuation;
        annualYieldBps = _annualYieldBps;
        compliance = ComplianceRegistry(_complianceRegistry);
        totalSupply = _initialSupply * 10 ** decimals;
        balanceOf[msg.sender] = totalSupply;
        emit TokensIssued(msg.sender, totalSupply);
    }

    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        require(compliance.isEligible(msg.sender) && compliance.isEligible(to), "Not KYC verified");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function addBeneficiary(address wallet, uint256 shareBps, string calldata purpose) external onlyOwner {
        beneficiaries.push(Beneficiary(wallet, shareBps, purpose));
    }

    function getBeneficiaries() external view returns (Beneficiary[] memory) {
        return beneficiaries;
    }

    function pause() external onlyOwner { paused = true; }
    function unpause() external onlyOwner { paused = false; }
}

contract DistributionEngine {
    address public owner;
    IUSDC public usdc;
    ComplianceRegistry public compliance;
    address public zakatReserve;
    uint256 public constant ZAKAT_BPS = 250;

    struct Distribution {
        address tokenContract;
        uint256 totalAmount;
        uint256 timestamp;
        uint256 beneficiaryCount;
        bool executed;
    }

    Distribution[] public distributions;

    event DistributionQueued(uint256 indexed id, address tokenContract, uint256 amount);
    event DistributionExecuted(uint256 indexed id, uint256 count, uint256 zakatAmount);
    event BeneficiaryPaid(address indexed wallet, uint256 amount, string purpose);

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }

    constructor(address _usdc, address _complianceRegistry, address _zakatReserve) {
        owner = msg.sender;
        usdc = IUSDC(_usdc);
        compliance = ComplianceRegistry(_complianceRegistry);
        zakatReserve = _zakatReserve;
    }

    function queueDistribution(address tokenContract, uint256 totalAmount) external onlyOwner returns (uint256 id) {
        require(compliance.isAssetCompliant(tokenContract), "Asset not compliant");
        id = distributions.length;
        distributions.push(Distribution(tokenContract, totalAmount, block.timestamp, 0, false));
        emit DistributionQueued(id, tokenContract, totalAmount);
    }

    function executeDistribution(uint256 id) external onlyOwner {
        Distribution storage dist = distributions[id];
        require(!dist.executed, "Already executed");
        require(usdc.transferFrom(msg.sender, address(this), dist.totalAmount), "USDC transfer failed");

        uint256 zakatAmount = (dist.totalAmount * ZAKAT_BPS) / 10000;
        uint256 distributable = dist.totalAmount - zakatAmount;
        usdc.transfer(zakatReserve, zakatAmount);

        WaqfToken token = WaqfToken(dist.tokenContract);
        WaqfToken.Beneficiary[] memory bens = token.getBeneficiaries();
        uint256 count = 0;

        for (uint256 i = 0; i < bens.length; i++) {
            if (!compliance.isEligible(bens[i].wallet)) continue;
            uint256 amount = (distributable * bens[i].shareBps) / 10000;
            if (amount == 0) continue;
            usdc.transfer(bens[i].wallet, amount);
            emit BeneficiaryPaid(bens[i].wallet, amount, bens[i].purpose);
            count++;
        }

        dist.executed = true;
        dist.beneficiaryCount = count;
        emit DistributionExecuted(id, count, zakatAmount);
    }
}

contract WaqfGovernance {
    uint256 public constant REQUIRED_APPROVALS = 2;
    address[3] public trustees;

    mapping(bytes32 => uint256) public approvalCount;
    mapping(bytes32 => mapping(address => bool)) public hasApproved;

    event ProposalCreated(bytes32 indexed proposalId, address proposer, string action);
    event ProposalApproved(bytes32 indexed proposalId, address trustee, uint256 count);
    event ProposalExecuted(bytes32 indexed proposalId);

    modifier onlyTrustee() {
        bool found = false;
        for (uint i = 0; i < 3; i++) {
            if (trustees[i] == msg.sender) { found = true; break; }
        }
        require(found, "Not a trustee");
        _;
    }

    constructor(address t1, address t2, address t3) {
        trustees[0] = t1; trustees[1] = t2; trustees[2] = t3;
    }

    function propose(string calldata action, bytes calldata data) external onlyTrustee returns (bytes32 proposalId) {
        proposalId = keccak256(abi.encodePacked(action, data, block.timestamp));
        emit ProposalCreated(proposalId, msg.sender, action);
        _approve(proposalId);
    }

    function approve(bytes32 proposalId) external onlyTrustee { _approve(proposalId); }

    function _approve(bytes32 proposalId) internal {
        require(!hasApproved[proposalId][msg.sender], "Already approved");
        hasApproved[proposalId][msg.sender] = true;
        approvalCount[proposalId]++;
        emit ProposalApproved(proposalId, msg.sender, approvalCount[proposalId]);
        if (approvalCount[proposalId] >= REQUIRED_APPROVALS) {
            emit ProposalExecuted(proposalId);
        }
    }

    function isApproved(bytes32 proposalId) external view returns (bool) {
        return approvalCount[proposalId] >= REQUIRED_APPROVALS;
    }
}
