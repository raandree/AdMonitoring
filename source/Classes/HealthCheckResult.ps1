<#
.SYNOPSIS
    Represents the result of an Active Directory health check.

.DESCRIPTION
    This class encapsulates the results of a health check operation,
    including the status, message, and any associated data or remediation steps.
#>

class HealthCheckResult {
    # Category of the health check (e.g., 'Replication', 'Services', 'DNS')
    [string]$Category
    
    # Name of the specific check performed
    [string]$CheckName
    
    # Target of the check (e.g., DC name, forest name)
    [string]$Target
    
    # Health status: Healthy, Warning, Critical, Unknown
    [ValidateSet('Healthy', 'Warning', 'Critical', 'Unknown')]
    [string]$Status
    
    # Detailed message about the check result
    [string]$Message
    
    # Optional: Additional data about the check
    [object]$Data
    
    # Optional: Recommended remediation steps
    [string]$Remediation
    
    # Timestamp when the check was performed
    [datetime]$Timestamp
    
    # Constructor
    HealthCheckResult(
        [string]$Category,
        [string]$CheckName,
        [string]$Target,
        [string]$Status,
        [string]$Message
    ) {
        $this.Category = $Category
        $this.CheckName = $CheckName
        $this.Target = $Target
        $this.Status = $Status
        $this.Message = $Message
        $this.Timestamp = Get-Date
    }
    
    # Overload with data
    HealthCheckResult(
        [string]$Category,
        [string]$CheckName,
        [string]$Target,
        [string]$Status,
        [string]$Message,
        [object]$Data
    ) {
        $this.Category = $Category
        $this.CheckName = $CheckName
        $this.Target = $Target
        $this.Status = $Status
        $this.Message = $Message
        $this.Data = $Data
        $this.Timestamp = Get-Date
    }
    
    # Full overload
    HealthCheckResult(
        [string]$Category,
        [string]$CheckName,
        [string]$Target,
        [string]$Status,
        [string]$Message,
        [object]$Data,
        [string]$Remediation
    ) {
        $this.Category = $Category
        $this.CheckName = $CheckName
        $this.Target = $Target
        $this.Status = $Status
        $this.Message = $Message
        $this.Data = $Data
        $this.Remediation = $Remediation
        $this.Timestamp = Get-Date
    }
}
