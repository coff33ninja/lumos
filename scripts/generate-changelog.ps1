param(
    [Parameter(Mandatory = $true)]
    [string]$FromTag,
    [string]$ToRef = "HEAD",
    [string]$OutputFile = "",
    [switch]$MarkdownFormat,
    [switch]$GroupByType
)

$ErrorActionPreference = "Stop"

function Get-CommitsBetween {
    param(
        [string]$From,
        [string]$To
    )
    
    $format = "%H|%h|%an|%ae|%ad|%s"
    $commits = git log "$From..$To" --pretty=format:$format --date=short
    
    $result = @()
    foreach ($line in $commits) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        
        $parts = $line -split '\|', 6
        if ($parts.Count -lt 6) { continue }
        
        $result += [PSCustomObject]@{
            FullHash = $parts[0]
            ShortHash = $parts[1]
            Author = $parts[2]
            Email = $parts[3]
            Date = $parts[4]
            Subject = $parts[5]
            Type = Get-CommitType -Subject $parts[5]
        }
    }
    
    return $result
}

function Get-CommitType {
    param([string]$Subject)
    
    # Conventional commit patterns
    if ($Subject -match '^feat(\(.+?\))?:') { return "Features" }
    if ($Subject -match '^fix(\(.+?\))?:') { return "Bug Fixes" }
    if ($Subject -match '^docs(\(.+?\))?:') { return "Documentation" }
    if ($Subject -match '^style(\(.+?\))?:') { return "Style" }
    if ($Subject -match '^refactor(\(.+?\))?:') { return "Refactoring" }
    if ($Subject -match '^perf(\(.+?\))?:') { return "Performance" }
    if ($Subject -match '^test(\(.+?\))?:') { return "Tests" }
    if ($Subject -match '^build(\(.+?\))?:') { return "Build" }
    if ($Subject -match '^ci(\(.+?\))?:') { return "CI/CD" }
    if ($Subject -match '^chore(\(.+?\))?:') { return "Chores" }
    if ($Subject -match '^security(\(.+?\))?:') { return "Security" }
    
    # Keyword-based detection
    if ($Subject -match '\b(security|vulnerability|CVE-)\b') { return "Security" }
    if ($Subject -match '\b(fix|fixed|fixes|bug)\b') { return "Bug Fixes" }
    if ($Subject -match '\b(add|added|new|feature)\b') { return "Features" }
    if ($Subject -match '\b(update|updated|upgrade)\b') { return "Updates" }
    if ($Subject -match '\b(remove|removed|delete)\b') { return "Removals" }
    if ($Subject -match '\b(deprecate|deprecated)\b') { return "Deprecations" }
    
    return "Other Changes"
}

function Format-ChangelogMarkdown {
    param(
        [array]$Commits,
        [string]$From,
        [string]$To,
        [bool]$GroupByType
    )
    
    $output = @()
    $output += "## Changes from $From to $To"
    $output += ""
    $output += "Total commits: $($Commits.Count)"
    $output += ""
    
    if ($GroupByType) {
        $grouped = $Commits | Group-Object -Property Type | Sort-Object Name
        
        foreach ($group in $grouped) {
            $output += "### $($group.Name)"
            $output += ""
            foreach ($commit in $group.Group) {
                $output += "- ``$($commit.ShortHash)`` $($commit.Subject) (*$($commit.Author)*, $($commit.Date))"
            }
            $output += ""
        }
    } else {
        foreach ($commit in $Commits) {
            $output += "- ``$($commit.Date)`` ``$($commit.ShortHash)`` $($commit.Subject)"
        }
        $output += ""
    }
    
    return $output -join "`r`n"
}

function Format-ChangelogPlain {
    param(
        [array]$Commits,
        [string]$From,
        [string]$To
    )
    
    $output = @()
    $output += "Changes from $From to $To"
    $output += "=" * 80
    $output += ""
    
    foreach ($commit in $Commits) {
        $output += "$($commit.Date) $($commit.ShortHash) $($commit.Subject)"
    }
    
    return $output -join "`r`n"
}

# Main execution
try {
    $commits = Get-CommitsBetween -From $FromTag -To $ToRef
    
    if ($commits.Count -eq 0) {
        Write-Warning "No commits found between $FromTag and $ToRef"
        exit 0
    }
    
    if ($MarkdownFormat) {
        $changelog = Format-ChangelogMarkdown -Commits $commits -From $FromTag -To $ToRef -GroupByType $GroupByType
    } else {
        $changelog = Format-ChangelogPlain -Commits $commits -From $FromTag -To $ToRef
    }
    
    if ([string]::IsNullOrWhiteSpace($OutputFile)) {
        Write-Output $changelog
    } else {
        Set-Content -Path $OutputFile -Value $changelog -Encoding utf8
        Write-Host "Changelog written to: $OutputFile" -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to generate changelog: $($_.Exception.Message)"
    exit 1
}
