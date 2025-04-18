# PowerShell Test Script for minecraft-server-manager.sh
# This script tests the functionality of the Minecraft server manager on Windows

# Colors for output
$RED = [System.Console]::ForegroundColor = "Red"
$GREEN = [System.Console]::ForegroundColor = "Green"
$YELLOW = [System.Console]::ForegroundColor = "Yellow"
$NC = [System.Console]::ResetColor()

function Write-ColorOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $true)]
        [string]$Color
    )
    
    $originalColor = [System.Console]::ForegroundColor
    [System.Console]::ForegroundColor = $Color
    Write-Output $Message
    [System.Console]::ForegroundColor = $originalColor
}

# Test environment setup
$TEST_DIR = "$env:TEMP\minecraft-test"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPT_PATH = "$SCRIPT_DIR\minecraft-server-manager.sh"
$MOCK_DIR = "$TEST_DIR\mock"
$MOCK_LOG_DIR = "$MOCK_DIR\log"
$MOCK_LOG_FILE = "$MOCK_LOG_DIR\test.log"

# Initialize test counters
$TESTS_TOTAL = 0
$TESTS_PASSED = 0
$TESTS_FAILED = 0

# Setup test environment
function Setup-TestEnvironment {
    Write-ColorOutput "Setting up test environment..." "Yellow"
    
    # Clean up previous test directory if it exists
    if (Test-Path $TEST_DIR) {
        Remove-Item -Path $TEST_DIR -Recurse -Force
    }
    
    # Create test directories
    New-Item -Path $TEST_DIR -ItemType Directory -Force | Out-Null
    New-Item -Path "$MOCK_DIR\minecraft" -ItemType Directory -Force | Out-Null
    New-Item -Path "$MOCK_DIR\minecraft.old" -ItemType Directory -Force | Out-Null
    New-Item -Path $MOCK_LOG_DIR -ItemType Directory -Force | Out-Null
    New-Item -Path $MOCK_LOG_FILE -ItemType File -Force | Out-Null
    
    # Create a mock version of the script for testing
    Create-MockScript
    
    Write-ColorOutput "Test environment set up at $TEST_DIR" "Green"
}

# Create a modified version of the script for testing
function Create-MockScript {
    $MOCK_SCRIPT = "$TEST_DIR\minecraft-server-manager-mock.sh"
    
    # Copy the original script
    Copy-Item -Path $SCRIPT_PATH -Destination $MOCK_SCRIPT -Force
    
    # Create mock functions file
    $mockFunctionsContent = @"
#!/bin/sh

# Mock functions that override actual system-changing functions

# Override directories
BASE_DIR="$($MOCK_DIR -replace '\\', '/')"
MINECRAFT_DIR="\$BASE_DIR/minecraft"
OLD_MINECRAFT_DIR="\$BASE_DIR/minecraft.old"
LOG_DIR="$($MOCK_LOG_DIR -replace '\\', '/')"
LOG_FILE="$($MOCK_LOG_FILE -replace '\\', '/')"
VERSION_FILE="\$MINECRAFT_DIR/minecraft_version.txt"
SCRIPT_PATH="\$MINECRAFT_DIR/minecraft-server-manager.sh"

# Mock apk commands
apk() {
    log "MOCK: apk \$@"
    return 0
}

# Mock wget
wget() {
    log "MOCK: wget \$@"
    # Create a dummy file to simulate download
    if [ "\$1" = "-O" ]; then
        touch "\$2"
    fi
    return 0
}

# Mock curl
curl() {
    log "MOCK: curl \$@"
    # Return mock JSON for API calls
    if echo "\$@" | grep -q "\$MINECRAFT_URL_API"; then
        echo '{"versions":[{"id":"12345"}]}'
    else
        echo '{}'
    fi
    return 0
}

# Mock rc-service
rc-service() {
    log "MOCK: rc-service \$@"
    return 0
}

# Mock rc-update
rc-update() {
    log "MOCK: rc-update \$@"
    return 0
}

# Mock crontab
crontab() {
    log "MOCK: crontab \$@"
    return 0
}

# Mock screen
screen() {
    log "MOCK: screen \$@"
    return 0
}

# Override functions that write to system files
create_service() {
    log "MOCK: Creating OpenRC service for Minecraft server..."
    mkdir -p "\$MINECRAFT_DIR/etc/init.d"
    echo "#!/sbin/openrc-run" > "\$MINECRAFT_DIR/etc/init.d/minecraft"
    chmod +x "\$MINECRAFT_DIR/etc/init.d/minecraft"
}

create_motd() {
    log "MOCK: Creating Message of the Day (MOTD)..."
    mkdir -p "\$MINECRAFT_DIR/etc"
    echo "MINECRAFT SERVER MOTD" > "\$MINECRAFT_DIR/etc/motd"
}

add_shell_commands() {
    log "MOCK: Adding helpful commands to shell profiles..."
    echo "# Minecraft commands" > "\$MINECRAFT_DIR/mock_profile"
}

"@
    
    # Write the mock functions to a file
    $mockFunctionsContent | Out-File -FilePath "$TEST_DIR\mock_functions.sh" -Encoding utf8 -NoNewline
    
    # Add a line to the mock script to source the mock functions
    $scriptContent = Get-Content -Path $MOCK_SCRIPT -Raw
    $scriptContent = $scriptContent -replace "#!/bin/sh", "#!/bin/sh`n`n# Source mock functions`n. `"$($TEST_DIR -replace '\\', '/')/mock_functions.sh`"`n"
    $scriptContent | Out-File -FilePath $MOCK_SCRIPT -Encoding utf8 -NoNewline
}

# Run a test and report result
function Test-Function {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [int]$ExpectedResult = 0
    )
    
    Write-ColorOutput "Running test: $TestName" "Yellow"
    $TESTS_TOTAL++
    
    try {
        # Run the test
        & $TestScript
        $testResult = $LASTEXITCODE
        
        # Check if the result matches expected
        if ($testResult -eq $ExpectedResult) {
            Write-ColorOutput "✓ PASSED: $TestName" "Green"
            $TESTS_PASSED++
        } else {
            Write-ColorOutput "✗ FAILED: $TestName" "Red"
            Write-ColorOutput "  Expected result: $ExpectedResult, Got: $testResult" "Red"
            $TESTS_FAILED++
        }
    } catch {
        Write-ColorOutput "✗ FAILED: $TestName (Exception)" "Red"
        Write-ColorOutput "  Error: $_" "Red"
        $TESTS_FAILED++
    }
}

# Check if a file exists
function Test-FileExists {
    param(
        [string]$FilePath,
        [string]$FileDescription
    )
    
    $TESTS_TOTAL++
    
    if (Test-Path -Path $FilePath -PathType Leaf) {
        Write-ColorOutput "✓ PASSED: $FileDescription exists" "Green"
        $TESTS_PASSED++
        return $true
    } else {
        Write-ColorOutput "✗ FAILED: $FileDescription does not exist" "Red"
        $TESTS_FAILED++
        return $false
    }
}

# Check if a directory exists
function Test-DirExists {
    param(
        [string]$DirPath,
        [string]$DirDescription
    )
    
    $TESTS_TOTAL++
    
    if (Test-Path -Path $DirPath -PathType Container) {
        Write-ColorOutput "✓ PASSED: $DirDescription exists" "Green"
        $TESTS_PASSED++
        return $true
    } else {
        Write-ColorOutput "✗ FAILED: $DirDescription does not exist" "Red"
        $TESTS_FAILED++
        return $false
    }
}

# Check if a file contains specific text
function Test-FileContains {
    param(
        [string]$FilePath,
        [string]$SearchText,
        [string]$FileDescription
    )
    
    $TESTS_TOTAL++
    
    if ((Test-Path -Path $FilePath -PathType Leaf) -and (Get-Content -Path $FilePath -Raw | Select-String -Pattern $SearchText -Quiet)) {
        Write-ColorOutput "✓ PASSED: $FileDescription contains '$SearchText'" "Green"
        $TESTS_PASSED++
        return $true
    } else {
        Write-ColorOutput "✗ FAILED: $FileDescription does not contain '$SearchText'" "Red"
        $TESTS_FAILED++
        return $false
    }
}

# Simulate running a function in the shell script
function Invoke-ShellFunction {
    param(
        [string]$Function,
        [string[]]$Arguments
    )
    
    # We need to use WSL or Git Bash to run the shell script
    # First, check if WSL is available
    $useWSL = $false
    try {
        $wslCheck = wsl.exe --list
        if ($LASTEXITCODE -eq 0) {
            $useWSL = $true
        }
    } catch {
        $useWSL = $false
    }
    
    # If WSL is available, use it
    if ($useWSL) {
        $mockScriptPath = $MOCK_SCRIPT -replace '\\', '/'
        $mockScriptPath = "/mnt/" + $mockScriptPath -replace ':', ''
        $command = "wsl.exe bash -c '$mockScriptPath $Function $Arguments'"
        Invoke-Expression $command
    } else {
        # Otherwise, check for Git Bash
        $gitBashPath = "C:\Program Files\Git\bin\bash.exe"
        if (Test-Path $gitBashPath) {
            $mockScriptPath = $MOCK_SCRIPT -replace '\\', '/'
            $command = "& '$gitBashPath' -c '$mockScriptPath $Function $Arguments'"
            Invoke-Expression $command
        } else {
            Write-ColorOutput "Error: Neither WSL nor Git Bash is available. Cannot run shell script tests." "Red"
            exit 1
        }
    }
}

# Test the log function
function Test-LogFunction {
    Write-ColorOutput "Testing log function..." "Yellow"
    
    # Clear the log file
    Set-Content -Path $MOCK_LOG_FILE -Value "" -Force
    
    # Execute the log function
    $testMessage = "This is a test log message"
    Invoke-ShellFunction "log" $testMessage
    
    # Check if the message was logged
    Test-FileContains -FilePath $MOCK_LOG_FILE -SearchText $testMessage -FileDescription "Log file"
}

# Test get_latest_server_id function
function Test-GetLatestServerId {
    Write-ColorOutput "Testing get_latest_server_id function..." "Yellow"
    
    # Execute the function
    Invoke-ShellFunction "get_latest_server_id"
    
    # Check if the function logged the expected output
    Test-FileContains -FilePath $MOCK_LOG_FILE -SearchText "Latest server version ID: 12345" -FileDescription "Log file"
}

# Test check_for_new_version function
function Test-CheckForNewVersion {
    Write-ColorOutput "Testing check_for_new_version function..." "Yellow"
    
    # Test when no version file exists (should indicate update needed)
    if (Test-Path "$MOCK_DIR\minecraft\minecraft_version.txt") {
        Remove-Item -Path "$MOCK_DIR\minecraft\minecraft_version.txt" -Force
    }
    
    Test-Function -TestName "check_for_new_version (no version file)" -TestScript {
        Invoke-ShellFunction "check_for_new_version"
    } -ExpectedResult 0
    
    # Test when version file exists with different version (should indicate update needed)
    New-Item -Path "$MOCK_DIR\minecraft" -ItemType Directory -Force | Out-Null
    Set-Content -Path "$MOCK_DIR\minecraft\minecraft_version.txt" -Value "11111" -Force
    
    Test-Function -TestName "check_for_new_version (different version)" -TestScript {
        Invoke-ShellFunction "check_for_new_version"
    } -ExpectedResult 0
    
    # Test when version file exists with same version (should indicate no update needed)
    Set-Content -Path "$MOCK_DIR\minecraft\minecraft_version.txt" -Value "12345" -Force
    
    Test-Function -TestName "check_for_new_version (same version)" -TestScript {
        Invoke-ShellFunction "check_for_new_version"
    } -ExpectedResult 1
}

# Test download_latest_server function
function Test-DownloadLatestServer {
    Write-ColorOutput "Testing download_latest_server function..." "Yellow"
    
    # Execute the function
    Invoke-ShellFunction "download_latest_server"
    
    # Check if the installer file was created
    Test-FileExists -FilePath "$MOCK_DIR\minecraft\serverinstaller_latest" -FileDescription "Server installer file"
    
    # Check if the version file was updated
    Test-FileExists -FilePath "$MOCK_DIR\minecraft\minecraft_version.txt" -FileDescription "Version file"
    Test-FileContains -FilePath "$MOCK_DIR\minecraft\minecraft_version.txt" -SearchText "12345" -FileDescription "Version file"
}

# Test create_start_script function
function Test-CreateStartScript {
    Write-ColorOutput "Testing create_start_script function..." "Yellow"
    
    # Execute the function
    Invoke-ShellFunction "create_start_script"
    
    # Check if the start script was created
    Test-FileExists -FilePath "$MOCK_DIR\minecraft\start-minecraft.sh" -FileDescription "Start script"
    Test-FileContains -FilePath "$MOCK_DIR\minecraft\start-minecraft.sh" -SearchText "screen -S minecraft" -FileDescription "Start script"
}

# Test create_service function
function Test-CreateService {
    Write-ColorOutput "Testing create_service function..." "Yellow"
    
    # Execute the function
    Invoke-ShellFunction "create_service"
    
    # Check if the service file was created
    Test-FileExists -FilePath "$MOCK_DIR\minecraft\etc\init.d\minecraft" -FileDescription "Service file"
}

# Test create_motd function
function Test-CreateMotd {
    Write-ColorOutput "Testing create_motd function..." "Yellow"
    
    # Execute the function
    Invoke-ShellFunction "create_motd"
    
    # Check if the MOTD file was created
    Test-FileExists -FilePath "$MOCK_DIR\minecraft\etc\motd" -FileDescription "MOTD file"
}

# Test add_shell_commands function
function Test-AddShellCommands {
    Write-ColorOutput "Testing add_shell_commands function..." "Yellow"
    
    # Execute the function
    Invoke-ShellFunction "add_shell_commands"
    
    # Check if the profile was modified
    Test-FileExists -FilePath "$MOCK_DIR\minecraft\mock_profile" -FileDescription "Shell profile"
}

# Run all tests
function Test-All {
    Write-ColorOutput "Running all tests..." "Yellow"
    
    Setup-TestEnvironment
    
    # Test individual functions
    Test-LogFunction
    Test-GetLatestServerId
    Test-CheckForNewVersion
    Test-DownloadLatestServer
    Test-CreateStartScript
    Test-CreateService
    Test-CreateMotd
    Test-AddShellCommands
    
    # Print test summary
    Write-ColorOutput "===================================" "Yellow"
    Write-ColorOutput "Test Summary:" "Yellow"
    Write-ColorOutput "===================================" "Yellow"
    Write-ColorOutput "Total tests: $TESTS_TOTAL" "White"
    Write-ColorOutput "Tests passed: $TESTS_PASSED" "Green"
    Write-ColorOutput "Tests failed: $TESTS_FAILED" "Red"
    
    if ($TESTS_FAILED -eq 0) {
        Write-ColorOutput "All tests passed!" "Green"
        return 0
    } else {
        Write-ColorOutput "Some tests failed!" "Red"
        return 1
    }
}

# Clean up test environment
function Cleanup-TestEnvironment {
    Write-ColorOutput "Cleaning up test environment..." "Yellow"
    if (Test-Path $TEST_DIR) {
        Remove-Item -Path $TEST_DIR -Recurse -Force
    }
    Write-ColorOutput "Test environment cleaned up." "Green"
}

# Main execution
function Main {
    # Run all tests
    Test-All
    $testResult = $LASTEXITCODE
    
    # Clean up
    Cleanup-TestEnvironment
    
    # Return the test result
    return $testResult
}

# Run the main function
Main
