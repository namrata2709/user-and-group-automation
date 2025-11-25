#!/usr/bin/env bash

# =================================================================
# Test Suite for User Lock/Unlock Functionality
# =================================================================

# --- Test Setup ---
# Create test users
sudo useradd test_lock_user1
sudo useradd test_lock_user2
sudo useradd test_lock_user3

# Create test files
cat > lock_users.txt << EOF
test_lock_user1:Security reason
test_lock_user2
EOF

cat > lock_users.json << EOF
{
  "users": [
    { "username": "test_lock_user1", "reason": "JSON lock reason" },
    { "username": "test_lock_user2" }
  ]
}
EOF

cat > unlock_users.txt << EOF
test_lock_user1
test_lock_user2
EOF

cat > unlock_users.json << EOF
{
  "users": [
    { "username": "test_lock_user1" },
    { "username": "test_lock_user2" }
  ]
}
EOF

cat > invalid.json << EOF
{
  "invalid": []
}
EOF


# --- Test Cases ---

echo "--- Running User Lock/Unlock Tests ---"

# 1. Single User Lock
echo "1. Testing single user lock..."
sudo ../scripts/user.sh --lock --name test_lock_user1 --reason "Initial lock"
passwd -S test_lock_user1 | grep " L "

# 2. Attempt to lock already locked user
echo "2. Testing locking an already locked user..."
sudo ../scripts/user.sh --lock --name test_lock_user1

# 3. Single User Unlock
echo "3. Testing single user unlock..."
sudo ../scripts/user.sh --unlock --name test_lock_user1
passwd -S test_lock_user1 | grep " P "

# 4. Attempt to unlock already unlocked user
echo "4. Testing unlocking an already unlocked user..."
sudo ../scripts/user.sh --unlock --name test_lock_user1

# 5. Lock non-existent user
echo "5. Testing locking a non-existent user..."
sudo ../scripts/user.sh --lock --name non_existent_user

# 6. Lock from text file
echo "6. Testing lock from text file..."
sudo ../scripts/user.sh --lock --names lock_users.txt
passwd -S test_lock_user1 | grep " L "
passwd -S test_lock_user2 | grep " L "

# 7. Unlock from text file
echo "7. Testing unlock from text file..."
sudo ../scripts/user.sh --unlock --names unlock_users.txt
passwd -S test_lock_user1 | grep " P "
passwd -S test_lock_user2 | grep " P "

# 8. Lock from JSON file
echo "8. Testing lock from JSON file..."
sudo ../scripts/user.sh --lock --input lock_users.json --format json
passwd -S test_lock_user1 | grep " L "
passwd -S test_lock_user2 | grep " L "

# 9. Unlock from JSON file
echo "9. Testing unlock from JSON file..."
sudo ../scripts/user.sh --unlock --input unlock_users.json --format json
passwd -S test_lock_user1 | grep " P "
passwd -S test_lock_user2 | grep " P "

# 10. Test with non-existent file
echo "10. Testing with a non-existent file..."
sudo ../scripts/user.sh --lock --names no_such_file.txt

# 11. Test with invalid JSON
echo "11. Testing with invalid JSON..."
sudo ../scripts/user.sh --lock --input invalid.json --format json


# --- Test Teardown ---
echo "--- Cleaning up ---"
sudo userdel test_lock_user1
sudo userdel test_lock_user2
sudo userdel test_lock_user3
rm lock_users.txt lock_users.json unlock_users.txt unlock_users.json invalid.json

echo "--- Tests complete ---"