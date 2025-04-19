#!/bin/sh

# Test script for minecraft-server-manager.sh
# This script tests all functionality of the Minecraft server manager
# without actually making system-level changes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test environment setup
TEST_DIR="/tmp/minecraft-test"
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")/minecraft-server-manager.sh"
MOCK_DIR="$TEST_DIR/mock"
MOCK_LOG_DIR="$MOCK_DIR/log"
MOCK_LOG_FILE="$MOCK_LOG_DIR/test.log"

# Initialize test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_test_env() {
    echo "${YELLOW}Setting up test environment...${NC}"
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    mkdir -p "$MOCK_DIR/minecraft"
    mkdir -p "$MOCK_DIR/minecraft.old"
    mkdir -p "$MOCK_LOG_DIR"
    touch "$MOCK_LOG_FILE"
    
    # Create a mock version of the script with overridden functions
    create_mock_script
    
    echo "${GREEN}Test environment set up at $TEST_DIR${NC}"
}

# Create a modified version of the script for testing
create_mock_script() {
    MOCK_SCRIPT="$TEST_DIR/minecraft-server-manager-mock.sh"
    
    # Copy the original script
    cp "$SCRIPT_PATH" "$MOCK_SCRIPT"
    
    # Modify the script to override system-changing functions
    cat << EOF > "$TEST_DIR/mock_functions.sh"
#!/bin/sh

# Mock functions that override actual system-changing functions

# Override directories
BASE_DIR="$MOCK_DIR"
MINECRAFT_DIR="\$BASE_DIR/minecraft"
OLD_MINECRAFT_DIR="\$BASE_DIR/minecraft.old"
LOG_DIR="$MOCK_LOG_DIR"
LOG_FILE="$MOCK_LOG_FILE"
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
    if echo "\$@" | grep -q "$MINECRAFT_URL_API"; then
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

EOF

    # Add the mock functions to the beginning of the script
    sed -i '2r '"$TEST_DIR/mock_functions.sh" "$MOCK_SCRIPT"
    chmod +x "$MOCK_SCRIPT"
}

# Run a test and report result
run_test() {
    TEST_NAME="$1"
    TEST_CMD="$2"
    EXPECTED_RESULT="$3"
    
    echo "${YELLOW}Running test: $TEST_NAME${NC}"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Run the test command
    TEST_OUTPUT=$(eval "$TEST_CMD" 2>&1)
    TEST_RESULT=$?
    
    # Check if the result matches expected
    if [ "$TEST_RESULT" -eq "$EXPECTED_RESULT" ]; then
        echo "${GREEN}✓ PASSED: $TEST_NAME${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "${RED}✗ FAILED: $TEST_NAME${NC}"
        echo "${RED}  Expected result: $EXPECTED_RESULT, Got: $TEST_RESULT${NC}"
        echo "${RED}  Output: $TEST_OUTPUT${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Check if a file exists
check_file_exists() {
    FILE_PATH="$1"
    FILE_DESC="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ -f "$FILE_PATH" ]; then
        echo "${GREEN}✓ PASSED: $FILE_DESC exists${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "${RED}✗ FAILED: $FILE_DESC does not exist${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Check if a directory exists
check_dir_exists() {
    DIR_PATH="$1"
    DIR_DESC="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ -d "$DIR_PATH" ]; then
        echo "${GREEN}✓ PASSED: $DIR_DESC exists${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "${RED}✗ FAILED: $DIR_DESC does not exist${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Check if a file contains specific text
check_file_contains() {
    FILE_PATH="$1"
    SEARCH_TEXT="$2"
    FILE_DESC="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ -f "$FILE_PATH" ] && grep -q "$SEARCH_TEXT" "$FILE_PATH"; then
        echo "${GREEN}✓ PASSED: $FILE_DESC contains '$SEARCH_TEXT'${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "${RED}✗ FAILED: $FILE_DESC does not contain '$SEARCH_TEXT'${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test the log function
test_log_function() {
    echo "${YELLOW}Testing log function...${NC}"
    
    # Clear the log file
    > "$MOCK_LOG_FILE"
    
    # Execute the log function through the mock script
    TEST_MESSAGE="This is a test log message"
    "$TEST_DIR/minecraft-server-manager-mock.sh" log "$TEST_MESSAGE"
    
    # Check if the message was logged
    check_file_contains "$MOCK_LOG_FILE" "$TEST_MESSAGE" "Log file"
}

# Test get_latest_server_id function
test_get_latest_server_id() {
    echo "${YELLOW}Testing get_latest_server_id function...${NC}"
    
    # Execute the function through the mock script
    "$TEST_DIR/minecraft-server-manager-mock.sh" get_latest_server_id
    
    # Check if the function logged the expected output
    check_file_contains "$MOCK_LOG_FILE" "Latest server version ID: 12345" "Log file"
}

# Test check_for_new_version function
test_check_for_new_version() {
    echo "${YELLOW}Testing check_for_new_version function...${NC}"
    
    # Test when no version file exists (should indicate update needed)
    rm -f "$MOCK_DIR/minecraft/minecraft_version.txt"
    run_test "check_for_new_version (no version file)" \
        "\"$TEST_DIR/minecraft-server-manager-mock.sh\" check_for_new_version" 0
    
    # Test when version file exists with different version (should indicate update needed)
    mkdir -p "$MOCK_DIR/minecraft"
    echo "11111" > "$MOCK_DIR/minecraft/minecraft_version.txt"
    run_test "check_for_new_version (different version)" \
        "\"$TEST_DIR/minecraft-server-manager-mock.sh\" check_for_new_version" 0
    
    # Test when version file exists with same version (should indicate no update needed)
    echo "12345" > "$MOCK_DIR/minecraft/minecraft_version.txt"
    run_test "check_for_new_version (same version)" \
        "\"$TEST_DIR/minecraft-server-manager-mock.sh\" check_for_new_version" 1
}

# Test download_latest_server function
test_download_latest_server() {
    echo "${YELLOW}Testing download_latest_server function...${NC}"
    
    # Execute the function through the mock script
    "$TEST_DIR/minecraft-server-manager-mock.sh" download_latest_server
    
    # Check if the installer file was created
    check_file_exists "$MOCK_DIR/minecraft/$INSTALLER_NAME" "Server installer file"
    
    # Check if the version file was updated
    check_file_exists "$MOCK_DIR/minecraft/minecraft_version.txt" "Version file"
    check_file_contains "$MOCK_DIR/minecraft/minecraft_version.txt" "12345" "Version file"
}

# Test create_start_script function
test_create_start_script() {
    echo "${YELLOW}Testing create_start_script function...${NC}"
    
    # Execute the function through the mock script
    "$TEST_DIR/minecraft-server-manager-mock.sh" create_start_script
    
    # Check if the start script was created
    check_file_exists "$MOCK_DIR/minecraft/$START_SCRIPT" "Start script"
    check_file_contains "$MOCK_DIR/minecraft/$START_SCRIPT" "screen -S minecraft" "Start script"
}

# Test create_service function
test_create_service() {
    echo "${YELLOW}Testing create_service function...${NC}"
    
    # Execute the function through the mock script
    "$TEST_DIR/minecraft-server-manager-mock.sh" create_service
    
    # Check if the service file was created
    check_file_exists "$MOCK_DIR/minecraft/etc/init.d/minecraft" "Service file"
}

# Test create_motd function
test_create_motd() {
    echo "${YELLOW}Testing create_motd function...${NC}"
    
    # Execute the function through the mock script
    "$TEST_DIR/minecraft-server-manager-mock.sh" create_motd
    
    # Check if the MOTD file was created
    check_file_exists "$MOCK_DIR/minecraft/etc/motd" "MOTD file"
}

# Test add_shell_commands function
test_add_shell_commands() {
    echo "${YELLOW}Testing add_shell_commands function...${NC}"
    
    # Execute the function through the mock script
    "$TEST_DIR/minecraft-server-manager-mock.sh" add_shell_commands
    
    # Check if the profile was modified
    check_file_exists "$MOCK_DIR/minecraft/mock_profile" "Shell profile"
}

# Test install_minecraft function
test_install_minecraft() {
    echo "${YELLOW}Testing install_minecraft function...${NC}"
    
    # Clear the test directory
    rm -rf "$MOCK_DIR/minecraft"
    mkdir -p "$MOCK_DIR/minecraft"
    
    # Execute the function through the mock script
    "$TEST_DIR/minecraft-server-manager-mock.sh" install_minecraft
    
    # Check if all expected files and directories were created
    check_file_exists "$MOCK_DIR/minecraft/$INSTALLER_NAME" "Server installer file"
    check_file_exists "$MOCK_DIR/minecraft/minecraft_version.txt" "Version file"
    check_file_exists "$MOCK_DIR/minecraft/$START_SCRIPT" "Start script"
    check_file_exists "$MOCK_DIR/minecraft/etc/init.d/minecraft" "Service file"
    check_file_exists "$MOCK_DIR/minecraft/etc/motd" "MOTD file"
}

# Test update_minecraft function
test_update_minecraft() {
    echo "${YELLOW}Testing update_minecraft function...${NC}"
    
    # Set up a scenario where an update is needed
    rm -rf "$MOCK_DIR/minecraft"
    rm -rf "$MOCK_DIR/minecraft.old"
    mkdir -p "$MOCK_DIR/minecraft"
    mkdir -p "$MOCK_DIR/minecraft/$WORLD_DIR"
    echo "11111" > "$MOCK_DIR/minecraft/minecraft_version.txt"
    
    # Execute the function through the mock script
    "$TEST_DIR/minecraft-server-manager-mock.sh" update_minecraft
    
    # Check if the backup was created
    check_dir_exists "$MOCK_DIR/minecraft.old" "Backup directory"
    
    # Check if the new server was installed
    check_file_exists "$MOCK_DIR/minecraft/$INSTALLER_NAME" "Server installer file"
    check_file_exists "$MOCK_DIR/minecraft/minecraft_version.txt" "Version file"
    check_file_contains "$MOCK_DIR/minecraft/minecraft_version.txt" "12345" "Version file"
    
    # Check if the world was restored
    check_dir_exists "$MOCK_DIR/minecraft/$WORLD_DIR" "World directory"
}

# Test the main script execution
test_main_execution() {
    echo "${YELLOW}Testing main script execution...${NC}"
    
    # Test install command
    run_test "Main execution (install)" \
        "\"$TEST_DIR/minecraft-server-manager-mock.sh\" install" 0
    
    # Test update command
    run_test "Main execution (update)" \
        "\"$TEST_DIR/minecraft-server-manager-mock.sh\" update" 0
    
    # Test invalid command
    run_test "Main execution (invalid command)" \
        "\"$TEST_DIR/minecraft-server-manager-mock.sh\" invalid_command" 1
}

# Run all tests
run_all_tests() {
    echo "${YELLOW}Running all tests...${NC}"
    
    setup_test_env
    
    # Test individual functions
    test_log_function
    test_get_latest_server_id
    test_check_for_new_version
    test_download_latest_server
    test_create_start_script
    test_create_service
    test_create_motd
    test_add_shell_commands
    
    # Test main functions
    test_install_minecraft
    test_update_minecraft
    
    # Test main script execution
    test_main_execution
    
    # Print test summary
    echo "${YELLOW}===================================${NC}"
    echo "${YELLOW}Test Summary:${NC}"
    echo "${YELLOW}===================================${NC}"
    echo "${YELLOW}Total tests:${NC} $TESTS_TOTAL"
    echo "${GREEN}Tests passed:${NC} $TESTS_PASSED"
    echo "${RED}Tests failed:${NC} $TESTS_FAILED"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Clean up test environment
cleanup() {
    echo "${YELLOW}Cleaning up test environment...${NC}"
    rm -rf "$TEST_DIR"
    echo "${GREEN}Test environment cleaned up.${NC}"
}

# Main execution
main() {
    # Run all tests
    run_all_tests
    TEST_RESULT=$?
    
    # Clean up
    cleanup
    
    # Return the test result
    return $TEST_RESULT
}

# Run the main function
main
exit $?
