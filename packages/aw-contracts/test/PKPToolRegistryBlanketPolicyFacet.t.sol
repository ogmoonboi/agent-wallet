// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/DeployPKPToolRegistry.s.sol";
import "../src/PKPToolRegistry.sol";
import "../src/facets/PKPToolRegistryBlanketPolicyFacet.sol";
import "../src/facets/PKPToolRegistryToolFacet.sol";
import "../src/libraries/PKPToolRegistryErrors.sol";
import "../src/libraries/PKPToolRegistryPolicyEvents.sol";
import "./mocks/MockPKPNFT.sol";

contract PKPToolRegistryBlanketPolicyFacetTest is Test {
    // Test addresses
    MockPKPNFT mockPkpNft;
    address deployer;
    address nonOwner;
    
    // Contract instances
    PKPToolRegistry diamond;
    DeployPKPToolRegistry deployScript;
    
    // Test data
    uint256 constant TEST_PKP_TOKEN_ID = 1;
    uint256 constant TEST_PKP_TOKEN_ID_2 = 2;
    string constant TEST_TOOL_CID = "test-tool-cid";
    string constant TEST_TOOL_CID_2 = "test-tool-cid-2";
    string constant TEST_POLICY_CID = "test-policy-cid";
    string constant TEST_POLICY_CID_2 = "test-policy-cid-2";
    address constant TEST_DELEGATEE = address(0x1234);

    // Events to test
    event SetBlanketToolPolicies(uint256 indexed pkpTokenId, string[] toolIpfsCids, string[] policyIpfsCids);
    event BlanketPoliciesRemoved(uint256 indexed pkpTokenId, string[] toolIpfsCids);
    event BlanketPoliciesSet(
        uint256 indexed pkpTokenId,
        string[] toolIpfsCids,
        string[] policyIpfsCids,
        bool enablePolicies
    );
    event BlanketPoliciesEnabled(
        uint256 indexed pkpTokenId,
        string[] toolIpfsCids
    );
    event BlanketPoliciesDisabled(
        uint256 indexed pkpTokenId,
        string[] toolIpfsCids
    );

    function setUp() public {
        // Setup deployer account using default test account
        deployer = vm.addr(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        nonOwner = makeAddr("non-owner");

        // Deploy mock PKP NFT contract
        mockPkpNft = new MockPKPNFT();

        // Set environment variables for deployment
        vm.setEnv("PKP_TOOL_REGISTRY_DEPLOYER_PRIVATE_KEY", "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
        
        // Deploy using the script
        deployScript = new DeployPKPToolRegistry();
        address diamondAddress = deployScript.deployToNetwork("test", address(mockPkpNft));
        diamond = PKPToolRegistry(payable(diamondAddress));

        // Set up mock PKP NFT for tests
        mockPkpNft.setOwner(TEST_PKP_TOKEN_ID, deployer);
        mockPkpNft.setOwner(TEST_PKP_TOKEN_ID_2, deployer);

        // Register both tools for testing
        vm.startPrank(deployer);
        string[] memory toolIpfsCids = new string[](2);
        toolIpfsCids[0] = TEST_TOOL_CID;
        toolIpfsCids[1] = TEST_TOOL_CID_2;
        PKPToolRegistryToolFacet(address(diamond)).registerTools(TEST_PKP_TOKEN_ID, toolIpfsCids, true);
        vm.stopPrank();
    }

    /// @notice Test setting a single blanket policy
    function test_setSingleBlanketPolicy() public {
        vm.startPrank(deployer);

        string[] memory toolIpfsCids = new string[](1);
        toolIpfsCids[0] = TEST_TOOL_CID;
        string[] memory policyIpfsCids = new string[](1);
        policyIpfsCids[0] = TEST_POLICY_CID;

        // Expect the BlanketPoliciesSet event
        vm.expectEmit(true, false, false, true);
        emit BlanketPoliciesSet(TEST_PKP_TOKEN_ID, toolIpfsCids, policyIpfsCids, true);

        // Set the policy
        PKPToolRegistryBlanketPolicyFacet(address(diamond)).setBlanketToolPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids,
            policyIpfsCids,
            true
        );

        // Verify policy was set
        string memory storedPolicy = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID
        );
        assertEq(storedPolicy, TEST_POLICY_CID, "Wrong policy CID");

        vm.stopPrank();
    }

    /// @notice Test setting multiple blanket policies
    function test_setMultipleBlanketPolicies() public {
        vm.startPrank(deployer);

        string[] memory toolIpfsCids = new string[](2);
        toolIpfsCids[0] = TEST_TOOL_CID;
        toolIpfsCids[1] = TEST_TOOL_CID_2;
        string[] memory policyIpfsCids = new string[](2);
        policyIpfsCids[0] = TEST_POLICY_CID;
        policyIpfsCids[1] = TEST_POLICY_CID_2;

        // Expect the BlanketPoliciesSet event
        vm.expectEmit(true, false, false, true);
        emit BlanketPoliciesSet(TEST_PKP_TOKEN_ID, toolIpfsCids, policyIpfsCids, true);

        // Set the policies
        PKPToolRegistryBlanketPolicyFacet(address(diamond)).setBlanketToolPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids,
            policyIpfsCids,
            true
        );

        // Verify policies were set
        string memory storedPolicy1 = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID
        );
        string memory storedPolicy2 = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID_2
        );
        assertEq(storedPolicy1, TEST_POLICY_CID, "Wrong policy CID for tool 1");
        assertEq(storedPolicy2, TEST_POLICY_CID_2, "Wrong policy CID for tool 2");

        vm.stopPrank();
    }

    /// @notice Test removing blanket policies
    function test_removeBlanketPolicies() public {
        vm.startPrank(deployer);

        // First set some policies
        string[] memory toolIpfsCids = new string[](2);
        toolIpfsCids[0] = TEST_TOOL_CID;
        toolIpfsCids[1] = TEST_TOOL_CID_2;
        string[] memory policyIpfsCids = new string[](2);
        policyIpfsCids[0] = TEST_POLICY_CID;
        policyIpfsCids[1] = TEST_POLICY_CID_2;

        PKPToolRegistryBlanketPolicyFacet(address(diamond)).setBlanketToolPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids,
            policyIpfsCids,
            true
        );

        // Remove one policy
        string[] memory toolsToRemove = new string[](1);
        toolsToRemove[0] = TEST_TOOL_CID;

        // Expect the BlanketPoliciesRemoved event
        vm.expectEmit(true, false, false, true);
        emit BlanketPoliciesRemoved(TEST_PKP_TOKEN_ID, toolsToRemove);

        // Remove the policy
        PKPToolRegistryBlanketPolicyFacet(address(diamond)).removeBlanketToolPolicies(
            TEST_PKP_TOKEN_ID,
            toolsToRemove
        );

        // Verify policy was removed
        string memory storedPolicy1 = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID
        );
        string memory storedPolicy2 = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID_2
        );
        assertEq(storedPolicy1, "", "Policy 1 should be removed");
        assertEq(storedPolicy2, TEST_POLICY_CID_2, "Policy 2 should still exist");

        vm.stopPrank();
    }

    /// @notice Test removing multiple blanket policies
    function test_removeMultipleBlanketPolicies() public {
        vm.startPrank(deployer);

        // First register multiple tools
        string[] memory toolIpfsCids = new string[](2);
        toolIpfsCids[0] = TEST_TOOL_CID;
        toolIpfsCids[1] = TEST_TOOL_CID_2;
        PKPToolRegistryToolFacet(address(diamond)).registerTools(TEST_PKP_TOKEN_ID, toolIpfsCids, true);

        // Set blanket policies for both tools
        string[] memory policyIpfsCids = new string[](2);
        policyIpfsCids[0] = TEST_POLICY_CID;
        policyIpfsCids[1] = TEST_POLICY_CID_2;
        PKPToolRegistryBlanketPolicyFacet(address(diamond)).setBlanketToolPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids,
            policyIpfsCids,
            true
        );

        // Verify policies are set
        (string memory policy1, bool isDelegateeSpecific1) = PKPToolRegistryPolicyFacet(address(diamond)).getEffectiveToolPolicyForDelegatee(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids[0],
            TEST_DELEGATEE
        );
        assertEq(policy1, TEST_POLICY_CID, "First blanket policy not set correctly");
        assertFalse(isDelegateeSpecific1, "First policy should be blanket policy");

        (string memory policy2, bool isDelegateeSpecific2) = PKPToolRegistryPolicyFacet(address(diamond)).getEffectiveToolPolicyForDelegatee(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids[1],
            TEST_DELEGATEE
        );
        assertEq(policy2, TEST_POLICY_CID_2, "Second blanket policy not set correctly");
        assertFalse(isDelegateeSpecific2, "Second policy should be blanket policy");

        // Expect the BlanketPoliciesRemoved event
        vm.expectEmit(true, false, false, true);
        emit BlanketPoliciesRemoved(TEST_PKP_TOKEN_ID, toolIpfsCids);

        // Remove blanket policies for both tools
        PKPToolRegistryBlanketPolicyFacet(address(diamond)).removeBlanketToolPolicies(TEST_PKP_TOKEN_ID, toolIpfsCids);

        // Verify policies are removed
        (string memory removedPolicy1, bool isDelegateeSpecific1After) = PKPToolRegistryPolicyFacet(address(diamond)).getEffectiveToolPolicyForDelegatee(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids[0],
            TEST_DELEGATEE
        );
        assertEq(removedPolicy1, "", "First blanket policy should be removed");
        assertFalse(isDelegateeSpecific1After, "First policy should still not be delegatee specific");

        (string memory removedPolicy2, bool isDelegateeSpecific2After) = PKPToolRegistryPolicyFacet(address(diamond)).getEffectiveToolPolicyForDelegatee(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids[1],
            TEST_DELEGATEE
        );
        assertEq(removedPolicy2, "", "Second blanket policy should be removed");
        assertFalse(isDelegateeSpecific2After, "Second policy should still not be delegatee specific");

        vm.stopPrank();
    }

    /// @notice Test enabling a single blanket policy
    function test_enableBlanketPolicy() public {
        vm.startPrank(deployer);

        // First set a policy (disabled)
        string[] memory toolIpfsCids = new string[](1);
        toolIpfsCids[0] = TEST_TOOL_CID;
        string[] memory policyIpfsCids = new string[](1);
        policyIpfsCids[0] = TEST_POLICY_CID;

        PKPToolRegistryBlanketPolicyFacet(address(diamond)).setBlanketToolPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids,
            policyIpfsCids,
            false
        );

        // Verify policy is disabled
        string memory storedPolicy = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID
        );
        assertEq(storedPolicy, "", "Policy should be disabled");

        // Enable the policy
        vm.expectEmit(true, false, false, true);
        emit BlanketPoliciesEnabled(TEST_PKP_TOKEN_ID, toolIpfsCids);

        PKPToolRegistryBlanketPolicyFacet(address(diamond)).enableBlanketPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids
        );

        // Verify policy is enabled
        storedPolicy = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID
        );
        assertEq(storedPolicy, TEST_POLICY_CID, "Policy should be enabled");

        vm.stopPrank();
    }

    /// @notice Test enabling multiple blanket policies
    function test_enableMultipleBlanketPolicies() public {
        vm.startPrank(deployer);

        // First set multiple policies (disabled)
        string[] memory toolIpfsCids = new string[](2);
        toolIpfsCids[0] = TEST_TOOL_CID;
        toolIpfsCids[1] = TEST_TOOL_CID_2;
        string[] memory policyIpfsCids = new string[](2);
        policyIpfsCids[0] = TEST_POLICY_CID;
        policyIpfsCids[1] = TEST_POLICY_CID_2;

        PKPToolRegistryBlanketPolicyFacet(address(diamond)).setBlanketToolPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids,
            policyIpfsCids,
            false
        );

        // Verify policies are disabled
        string memory storedPolicy1 = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID
        );
        string memory storedPolicy2 = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID_2
        );
        assertEq(storedPolicy1, "", "First policy should be disabled");
        assertEq(storedPolicy2, "", "Second policy should be disabled");

        // Enable the policies
        vm.expectEmit(true, false, false, true);
        emit BlanketPoliciesEnabled(TEST_PKP_TOKEN_ID, toolIpfsCids);

        PKPToolRegistryBlanketPolicyFacet(address(diamond)).enableBlanketPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids
        );

        // Verify policies are enabled
        storedPolicy1 = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID
        );
        storedPolicy2 = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID_2
        );
        assertEq(storedPolicy1, TEST_POLICY_CID, "First policy should be enabled");
        assertEq(storedPolicy2, TEST_POLICY_CID_2, "Second policy should be enabled");

        vm.stopPrank();
    }

    /// @notice Test disabling a single blanket policy
    function test_disableBlanketPolicy() public {
        vm.startPrank(deployer);

        // First set a policy (enabled)
        string[] memory toolIpfsCids = new string[](1);
        toolIpfsCids[0] = TEST_TOOL_CID;
        string[] memory policyIpfsCids = new string[](1);
        policyIpfsCids[0] = TEST_POLICY_CID;

        PKPToolRegistryBlanketPolicyFacet(address(diamond)).setBlanketToolPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids,
            policyIpfsCids,
            true
        );

        // Verify policy is enabled
        string memory storedPolicy = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID
        );
        assertEq(storedPolicy, TEST_POLICY_CID, "Policy should be enabled");

        // Disable the policy
        vm.expectEmit(true, false, false, true);
        emit BlanketPoliciesDisabled(TEST_PKP_TOKEN_ID, toolIpfsCids);

        PKPToolRegistryBlanketPolicyFacet(address(diamond)).disableBlanketPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids
        );

        // Verify policy is disabled
        storedPolicy = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID
        );
        assertEq(storedPolicy, "", "Policy should be disabled");

        vm.stopPrank();
    }

    /// @notice Test disabling multiple blanket policies
    function test_disableMultipleBlanketPolicies() public {
        vm.startPrank(deployer);

        // First set multiple policies (enabled)
        string[] memory toolIpfsCids = new string[](2);
        toolIpfsCids[0] = TEST_TOOL_CID;
        toolIpfsCids[1] = TEST_TOOL_CID_2;
        string[] memory policyIpfsCids = new string[](2);
        policyIpfsCids[0] = TEST_POLICY_CID;
        policyIpfsCids[1] = TEST_POLICY_CID_2;

        PKPToolRegistryBlanketPolicyFacet(address(diamond)).setBlanketToolPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids,
            policyIpfsCids,
            true
        );

        // Verify policies are enabled
        string memory storedPolicy1 = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID
        );
        string memory storedPolicy2 = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID_2
        );
        assertEq(storedPolicy1, TEST_POLICY_CID, "First policy should be enabled");
        assertEq(storedPolicy2, TEST_POLICY_CID_2, "Second policy should be enabled");

        // Disable the policies
        vm.expectEmit(true, false, false, true);
        emit BlanketPoliciesDisabled(TEST_PKP_TOKEN_ID, toolIpfsCids);

        PKPToolRegistryBlanketPolicyFacet(address(diamond)).disableBlanketPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids
        );

        // Verify policies are disabled
        storedPolicy1 = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID
        );
        storedPolicy2 = PKPToolRegistryBlanketPolicyFacet(address(diamond)).getBlanketToolPolicy(
            TEST_PKP_TOKEN_ID,
            TEST_TOOL_CID_2
        );
        assertEq(storedPolicy1, "", "First policy should be disabled");
        assertEq(storedPolicy2, "", "Second policy should be disabled");

        vm.stopPrank();
    }

    /// @notice Test error cases
    function test_errorCases() public {
        vm.startPrank(deployer);

        string[] memory toolIpfsCids = new string[](1);
        toolIpfsCids[0] = TEST_TOOL_CID;
        string[] memory policyIpfsCids = new string[](1);
        policyIpfsCids[0] = TEST_POLICY_CID;

        // Test non-owner cannot set policies
        vm.stopPrank();
        vm.startPrank(nonOwner);
        vm.expectRevert(PKPToolRegistryErrors.NotPKPOwner.selector);
        PKPToolRegistryBlanketPolicyFacet(address(diamond)).setBlanketToolPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids,
            policyIpfsCids,
            true
        );
        vm.stopPrank();
        vm.startPrank(deployer);

        // Test array length mismatch
        string[] memory mismatchedPolicies = new string[](2);
        mismatchedPolicies[0] = TEST_POLICY_CID;
        mismatchedPolicies[1] = TEST_POLICY_CID_2;
        vm.expectRevert(PKPToolRegistryErrors.ArrayLengthMismatch.selector);
        PKPToolRegistryBlanketPolicyFacet(address(diamond)).setBlanketToolPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids,
            mismatchedPolicies,
            true
        );

        // Test cannot set policy for non-existent tool
        string[] memory nonExistentTools = new string[](1);
        nonExistentTools[0] = "QmNONEXISTENT";
        vm.expectRevert(abi.encodeWithSelector(PKPToolRegistryErrors.ToolNotFound.selector, "QmNONEXISTENT"));
        PKPToolRegistryBlanketPolicyFacet(address(diamond)).setBlanketToolPolicies(
            TEST_PKP_TOKEN_ID,
            nonExistentTools,
            policyIpfsCids,
            true
        );

        // Test cannot enable non-existent policy
        vm.expectRevert(PKPToolRegistryErrors.NoPolicySet.selector);
        PKPToolRegistryBlanketPolicyFacet(address(diamond)).enableBlanketPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids
        );

        // Test cannot disable non-existent policy
        vm.expectRevert(PKPToolRegistryErrors.NoPolicySet.selector);
        PKPToolRegistryBlanketPolicyFacet(address(diamond)).disableBlanketPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids
        );

        // Test cannot remove non-existent policy
        vm.expectRevert(PKPToolRegistryErrors.NoPolicySet.selector);
        PKPToolRegistryBlanketPolicyFacet(address(diamond)).removeBlanketToolPolicies(
            TEST_PKP_TOKEN_ID,
            toolIpfsCids
        );

        vm.stopPrank();
    }
}