# run_stratus_redteam.sh

Automated execution script for Stratus Red Team attack techniques across multiple cloud platforms.

## Requirements
1. stratus - https://github.com/DataDog/stratus-red-team
2. awscli - https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
3. kubectl - https://kubernetes.io/docs/tasks/tools/
4. gcloud - https://docs.cloud.google.com/sdk/gcloud

## Synopsis

```bash
./run_stratus_redteam.sh [PLATFORM] [CLEANUP]
```

## Parameters

| Parameter | Description | Default | Valid Values |
|-----------|-------------|---------|--------------|
| `PLATFORM` | Target cloud platform | `aws` | `aws`, `azure`, `gcp`, `kubernetes`, `eks` |
| `CLEANUP` | Clean up resources after execution | `true` | `true`, `false` |

## Examples

```bash
# Run all AWS techniques with cleanup
./run_stratus_redteam.sh

# Run all Kubernetes techniques
./run_stratus_redteam.sh kubernetes

# Run EKS techniques without cleanup
./run_stratus_redteam.sh eks false

# Run Azure techniques with cleanup
./run_stratus_redteam.sh azure true
```

## What It Does

The script automates the following workflow for each technique:

1. **Fetch Techniques** - Retrieves all available techniques for the specified platform
2. **Warmup** - Deploys prerequisite infrastructure (EC2 instances, IAM roles, etc.)
3. **Detonate** - Executes the attack technique
4. **Cleanup** - Removes all deployed resources (optional)
5. **Log** - Saves all output to timestamped log files
6. **Report** - Displays execution summary with success/failure counts

## Output

### Log Directory

Each execution creates a timestamped directory:
```
./stratus-logs-YYYYMMDD-HHMMSS/
```

### Log Files

One log file per technique containing warmup, detonation, and cleanup output:
```
./stratus-logs-20260304-140913/
├── aws.credential-access.ec2-get-password-data.log
├── aws.defense-evasion.cloudtrail-stop.log
├── k8s.credential-access.dump-secrets.log
└── eks.persistence.backdoor-aws-auth-configmap.log
```

### Console Output

Real-time colored output showing:
- Progress counter (e.g., [5/43])
- Current technique being executed
- Status indicators (✓ success, ✗ failure, ⚠ warning)
- Execution summary with counts
- Final technique status report

## Platform Details

### AWS (43 techniques)

**Prefix**: `aws.`

**Example Techniques**:
- `aws.credential-access.ec2-steal-instance-credentials`
- `aws.defense-evasion.cloudtrail-stop`
- `aws.persistence.iam-create-backdoor-role`

**Requirements**: AWS CLI configured with valid credentials

### Azure (9 techniques)

**Prefix**: `azure.`

**Example Techniques**:
- `azure.execution.vm-custom-script-extension`
- `azure.persistence.service-principal-create`

**Requirements**: Azure CLI configured (`az login`)

### GCP

**Prefix**: `gcp.`

**Example Techniques**:
- `gcp.defense-evasion.impair-logging`
- `gcp.persistence.create-admin-service-account`

**Requirements**: gcloud CLI configured (`gcloud auth login`)

### Kubernetes (8 techniques)

**Prefix**: `k8s.`

**Example Techniques**:
- `k8s.credential-access.dump-secrets`
- `k8s.credential-access.steal-serviceaccount-token`
- `k8s.persistence.create-admin-clusterrole`
- `k8s.privilege-escalation.privileged-pod`

**Requirements**: kubectl configured with cluster access

### EKS (2 techniques)

**Prefix**: `eks.`

**Example Techniques**:
- `eks.lateral-movement.create-access-entry`
- `eks.persistence.backdoor-aws-auth-configmap`

**Requirements**: AWS CLI and kubectl configured with EKS cluster access

## Script Behavior

### Error Handling

- **set -e**: Script exits on errors (except where explicitly handled)
- **Warmup failures**: Script continues and attempts detonation anyway
- **Detonation failures**: Marked as failure, script continues to next technique
- **Cleanup failures**: Logged as warning, script continues

### Counters

The script tracks:
- `SUCCESS_COUNT`: Techniques that detonated successfully
- `FAILURE_COUNT`: Techniques that failed to detonate
- `SKIPPED_COUNT`: Reserved for future use

### When Cleanup is Disabled

If you run with `CLEANUP=false`:
- Resources remain deployed in your cloud environment
- Useful for manual investigation or testing detection systems
- Remember to clean up manually: `stratus cleanup --all`
- Can incur ongoing costs until cleaned up

## Execution Summary

At the end of execution, the script displays:

```
================================================
  Execution Summary
================================================
Total Techniques: 43
Successful: 38
Failed: 5
Skipped: 0

Logs saved to: ./stratus-logs-20260304-140913
================================================

[*] Current technique status:
[displays output of: stratus status --platform <platform>]
```

## Manual Technique Execution

To run a single technique manually:

```bash
# List all techniques
stratus list --platform aws

# Run a specific technique
stratus warmup aws.defense-evasion.cloudtrail-stop
stratus detonate aws.defense-evasion.cloudtrail-stop
stratus cleanup aws.defense-evasion.cloudtrail-stop

# Check status
stratus status --platform aws

# Clean up all
stratus cleanup --all
```

## Troubleshooting

### No techniques found

**Error**: "No techniques found for platform: X"

**Solution**:
```bash
# Verify stratus is installed
which stratus
stratus version

# Check available techniques manually
stratus list --platform aws

# Ensure platform name is correct (lowercase)
./run_stratus_redteam.sh kubernetes  # not Kubernetes
```

### Permission denied

**Error**: "./run_stratus_redteam.sh: Permission denied"

**Solution**:
```bash
chmod +x run_stratus_redteam.sh
./run_stratus_redteam.sh
```

### Technique failures

**Cause**: Missing credentials, insufficient permissions, or quota limits

**Solution**:
1. Check the technique-specific log file in the logs directory
2. Verify credentials: `aws sts get-caller-identity` or `kubectl cluster-info`
3. Review IAM/RBAC permissions
4. Check cloud provider quotas and limits

### Already warmed up

**Warning**: "Warmup failed or already warmed up"

**Explanation**: Resources from a previous run still exist

**Solution**:
- The script will attempt detonation anyway
- Or clean up first: `stratus cleanup --all`

## Security Warning

**CRITICAL**: This script executes real attack techniques that:
- Modify cloud resources and configurations
- May trigger security alerts and incident response
- Can disable logging and monitoring
- May violate security policies

**Only use in authorized test environments with proper approval.**

## Best Practices

1. **Test in Isolated Environments**: Use dedicated test/sandbox accounts
2. **Enable Cleanup**: Always use cleanup unless specifically investigating
3. **Review Logs**: Check logs for errors and understand what was executed
4. **Monitor Costs**: Some techniques deploy resources that incur costs
5. **Validate Detection**: After execution, verify your security tools detected the attacks
6. **Document Authorization**: Maintain records of approval for security testing

## Integration Examples

### CI/CD Pipeline

```yaml
# Example GitHub Actions workflow
name: Security Testing
on:
  schedule:
    - cron: '0 0 * * 1'  # Weekly

jobs:
  stratus-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Stratus
        run: |
          brew install stratus-red-team
      - name: Configure AWS
        run: aws configure set region us-east-1
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      - name: Run Stratus
        run: ./run_stratus_redteam.sh aws
      - name: Upload logs
        uses: actions/upload-artifact@v2
        with:
          name: stratus-logs
          path: stratus-logs-*
```

### Cron Job

```bash
# Run weekly AWS security testing
0 2 * * 1 /path/to/run_stratus_redteam.sh aws true >> /var/log/stratus-weekly.log 2>&1
```

## Related Files

- `STRATUS_REDTEAM_GUIDE.md` - Comprehensive guide with additional context and use cases

## Resources

- Stratus Red Team: https://stratus-red-team.cloud/
- Technique List: https://stratus-red-team.cloud/attack-techniques/list/
- GitHub: https://github.com/datadog/stratus-red-team

## Version History

- **v1.1** - Added support for Kubernetes and EKS platforms, fixed technique parsing bug
- **v1.0** - Initial version with AWS, Azure, GCP support
