#!/bin/bash

# Script to troubleshoot ArgoCD sync timeout issues

set -euo pipefail

echo "ArgoCD Sync Troubleshooting Script"
echo "=================================="

# Function to check application status
check_application_status() {
    local app_name="$1"
    local namespace="$2"
    
    echo "Checking application: $app_name in namespace: $namespace"
    
    # Get application status
    local sync_status
    local health_status
    local message
    
    sync_status=$(oc get applications.argoproj.io "$app_name" -n "$namespace" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    health_status=$(oc get applications.argoproj.io "$app_name" -n "$namespace" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    message=$(oc get applications.argoproj.io "$app_name" -n "$namespace" -o jsonpath='{.status.operation.message}' 2>/dev/null || echo "No message")
    
    echo "  Sync Status: $sync_status"
    echo "  Health Status: $health_status"
    echo "  Message: $message"
    
    if [[ "$sync_status" == "OutOfSync" ]]; then
        echo "  ⚠️  Application is OutOfSync"
        return 1
    elif [[ "$sync_status" == "Synced" ]]; then
        echo "  ✅ Application is Synced"
        return 0
    else
        echo "  ❌ Application has issues"
        return 1
    fi
}

# Function to check for failed resources
check_failed_resources() {
    local app_name="$1"
    local namespace="$2"
    
    echo "Checking for failed resources in $app_name..."
    
    # Get failed resources
    oc get applications.argoproj.io "$app_name" -n "$namespace" -o jsonpath='{.status.operation.syncResult.resources[*]}' | jq -r 'select(.status == "SyncFailed") | "\(.kind)/\(.name) in \(.namespace): \(.message)"' 2>/dev/null || echo "No failed resources found"
}

# Function to check ArgoCD controller logs
check_controller_logs() {
    echo "Checking ArgoCD controller logs for sync issues..."
    
    # Get ArgoCD controller pods
    local controller_pods
    controller_pods=$(oc get pods -n openshift-gitops -l app.kubernetes.io/name=argocd-application-controller -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$controller_pods" ]]; then
        echo "Found ArgoCD controller pods: $controller_pods"
        echo "Recent controller logs (last 20 lines):"
        oc logs -n openshift-gitops $(echo "$controller_pods" | awk '{print $1}') --tail=20 | grep -i "sync\|timeout\|error" || echo "No sync-related errors found in logs"
    else
        echo "No ArgoCD controller pods found"
    fi
}

# Function to check resource quotas and limits
check_resource_limits() {
    echo "Checking resource quotas and limits..."
    
    # Check for resource quotas
    oc get resourcequota -A | grep -E "(openshift|policies)" || echo "No resource quotas found"
    
    # Check for limit ranges
    oc get limitrange -A | grep -E "(openshift|policies)" || echo "No limit ranges found"
    
    # Check node resources
    echo "Node resource usage:"
    oc top nodes || echo "Could not get node resource usage"
}

# Function to check policy resources
check_policy_resources() {
    echo "Checking policy-related resources..."
    
    # Check for policies
    echo "Policies in policies namespace:"
    oc get policies -n policies || echo "No policies found"
    
    # Check for placement rules
    echo "PlacementRules in policies namespace:"
    oc get placementrules -n policies || echo "No placement rules found"
    
    # Check for placement bindings
    echo "PlacementBindings in policies namespace:"
    oc get placementbindings -n policies || echo "No placement bindings found"
}

# Function to provide recommendations
provide_recommendations() {
    echo ""
    echo "Recommendations:"
    echo "==============="
    echo ""
    echo "1. If sync timeout persists:"
    echo "   - Increase syncTimeout in variants/odf/values-odf.yaml (currently 3600s)"
    echo "   - Consider breaking complex policies into smaller ones"
    echo "   - Check for resource constraints"
    echo ""
    echo "2. If PlacementRule issues:"
    echo "   - Verify ACM is properly installed"
    echo "   - Check API version compatibility"
    echo "   - Consider using simpler placement logic"
    echo ""
    echo "3. If policy complexity issues:"
    echo "   - Use the simplified policy (policy-cluster-proxy-ca-simple.yaml)"
    echo "   - Remove complex inline scripts"
    echo "   - Use separate jobs for complex operations"
    echo ""
    echo "4. Manual sync trigger:"
    echo "   oc patch applications.argoproj.io opp-policy -n ramendr-starter-kit-hub --type=merge --patch='{\"spec\":{\"syncPolicy\":{\"syncOptions\":[\"syncTimeout=7200s\"]}}}'"
    echo ""
    echo "5. Force sync:"
    echo "   oc patch applications.argoproj.io opp-policy -n ramendr-starter-kit-hub --type=merge --patch='{\"operation\":{\"sync\":{\"syncStrategy\":{\"hook\":{}}}}}'"
}

# Main execution
main() {
    echo "Starting ArgoCD sync troubleshooting..."
    echo ""
    
    # Check application status
    echo "1. Checking application status..."
    check_application_status "opp-policy" "ramendr-starter-kit-hub"
    echo ""
    
    # Check for failed resources
    echo "2. Checking for failed resources..."
    check_failed_resources "opp-policy" "ramendr-starter-kit-hub"
    echo ""
    
    # Check controller logs
    echo "3. Checking ArgoCD controller logs..."
    check_controller_logs
    echo ""
    
    # Check resource limits
    echo "4. Checking resource limits..."
    check_resource_limits
    echo ""
    
    # Check policy resources
    echo "5. Checking policy resources..."
    check_policy_resources
    echo ""
    
    # Provide recommendations
    provide_recommendations
}

# Show usage if help requested
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [options]"
    echo ""
    echo "This script helps troubleshoot ArgoCD sync timeout issues by:"
    echo "1. Checking application status"
    echo "2. Identifying failed resources"
    echo "3. Checking controller logs"
    echo "4. Verifying resource limits"
    echo "5. Providing recommendations"
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    exit 0
fi

# Run main function
main
