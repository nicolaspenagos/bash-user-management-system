#!/bin/bash

# Storage files
users_file="users.txt"
departments_file="departments.txt"
logs_file="logs.txt"

# Path to the current project
directory="./"

# Function to display the main menu
show_main_menu() {
    echo "1. User Management"
    echo "2. Department Management"
    echo "3. Users by Department"
    echo "4. Log Management"
    echo "5. Activity Management"
    echo "6. System Management"
    echo "0. Exit"
}

# Function to manage users
manage_users() {
    clear
    echo "1. Create user"
    echo "2. Disable user"
    echo "3. Modify user"
    echo "0. Back to main menu"

    read -rp "Select an option: " user_option

    case $user_option in
    1)
        create_user
        ;;
    2)
        disable_user
        ;;
    3)
        modify_user
        ;;
    0) ;;
    *)
        echo "Invalid option"
        ;;
    esac
}

create_user() {
    local new_username
    read -rp "Enter the username: " new_username

    # Check if the username contains the characters '/' or '\'
    if [[ "$new_username" =~ [\/\\] ]]; then
        printf "The username cannot contain the characters '/' or '%c'.\n" "\\"
        write_log "create_user:InvalidUsername"
    else
        # Verify if the user exists in the system
        if id "$new_username" >/dev/null 2>&1; then
            echo "User $new_username already exists. Choose a different username."
            write_log "create_user:UserAlreadyExists"
        else
            # Check if a group with the same name exists before creating a new user.
            if grep -q "^$new_username:" "/etc/group"; then
                useradd -m -s /bin/bash "$new_username" -g "$new_username"
            else
                useradd -m -s /bin/bash "$new_username"
            fi
            write_log "create_user:UserCreatedInOS"
            passwd "$new_username"
            # Verify if the user exists in the DB
            if grep -q ";$new_username;" "$users_file"; then
                # Enable user and update password
                sed -i "/;$new_username;/s/No/Yes/" "$users_file"
                update_password_in_DB "$new_username"
                #Update departments of the user
                update_deparments_of_disabled_user "$new_username"
                write_log "create_user:UserCreatedAndEnabled"
            else
                # Save user information to users.txt
                echo "$(wc -l <$users_file);$new_username;$(grep -E "$new_username:" /etc/shadow | cut -d: -f2);Yes;None" >>$users_file
                write_log "create_user:UserCreated"
            fi
            echo "User $new_username created"
        fi
    fi
}

#Re-associates all departments the user had when enabled
update_deparments_of_disabled_user() {
    local username=$1
    local initial_departments
    initial_departments=$(grep -E ";$username;" $users_file | cut -d ";" -f5)
    local final_departments=""
    if [[ "$initial_departments" != "None" ]]; then
        write_log "update_deparments_of_disabled_user:DepartmentsExist"
        for department in $(echo "$initial_departments" | tr ":" "\n"); do
            # Check if the department exists in the operating system
            if department_exists_in_OS "$department_name"; then
                usermod -aG "$department" "$username"
                if [[ "$final_departments" == "" ]]; then
                    final_departments="$department"
                else
                    final_departments="$final_departments:$department"
                fi
                add_disabled_user_to_department_in_DB "$username" "$department"
            fi
        done
        sed -i "/;$username;/s/$initial_departments/$final_departments/" "$users_file"
        write_log "update_deparments_of_disabled_user:DepartmentsUpdated"
    fi
}

#Adds a user that was disabled to a department in the DB
add_disabled_user_to_department_in_DB() {
    local new_username=$1
    local department_name=$2
    # Users in the department
    local users
    local new_users
    users=$(grep -E ";$department_name;" $departments_file | cut -d ";" -f4)
    # Replace : with space
    users="${users//:/ }"
    if ! echo "$users" | grep -qw "$new_username"; then
        if [[ "$users" == "None" ]]; then
            new_users="$new_username"
        else
            new_users="$users:$new_username"
        fi
        sed -i "/;$department_name;/s/$users/$new_users/" "$departments_file"
        write_log "add_disabled_user_to_department_in_DB: User '$new_username' added to department '$department_name'"
    fi
}

disable_user() {
    local disable_user
    read -rp "Enter the username to disable: " disable_user

    # Verify if the user exists
    if id "$disable_user" >"/dev/null" 2>&1; then
        # Logic to delete a user
        sudo userdel -r "$disable_user"
        # Logic to disable a user
        sed -i "/;$disable_user;/s/Yes/No/" $users_file
        remove_user_from_departments "$disable_user"

        # Logging: User successfully disabled
        write_log "disable_user:UserDisabled '$disable_user'"

        echo "User $disable_user was removed from the system and disabled in the DB"
    else
        # Logging: User does not exist
        write_log "disable_user:UserNotFound '$disable_user'"
        echo "User $disable_user does not exists. Choose a different username."
    fi
}

remove_user_from_departments() {
    local username=$1
    local departments
    departments=$(grep -E ";$username;" $users_file | cut -d ";" -f5)
    if [[ "$departments" != "None" ]]; then
        for department in $(echo "$departments" | tr ":" "\n"); do
            remove_user_from_department_in_db "$username" "$department"

            # Logging: User successfully removed from department
            write_log "remove_user_from_departments:UserSuccessfullyRemovedFromDepartment '$username' from '$department'"
        done
    fi
}

modify_user() {
    echo "1. Change user name"
    echo "2. Change password"
    echo "3. Change username and password"
    echo "0. Back to main menu"

    local user_option
    read -rp "Select an option: " user_option
    local username
    local new_username

    case $user_option in
    1)
        read -rp "Enter the old username: " username
        # Logging: Attempt to update username
        write_log "update_username:AttemptToUpdateUsername '$username'"

        # Verify if the user exists
        if id "$username" >"/dev/null" 2>&1; then
            read -rp "Enter the new username: " new_username
            # Logging: Attempt to change username to a new one
            write_log "update_username:AttemptToChangeUsername '$username' to '$new_username'"

            # Check if the username contains the characters '/' or '\'
            if [[ "$new_username" =~ [\/\\] ]]; then
                # Logging: Invalid characters in the new username
                write_log "update_username:InvalidCharactersInNewUsername '$new_username'"
                printf "The username cannot contain the characters '/' or '%c'.\n" "\\"
            else
                # Verify that the user does not exist
                if id "$new_username" >"/dev/null" 2>&1; then
                    # Logging: New username already exists
                    write_log "update_username:NewUsernameAlreadyExists '$new_username'"
                    echo "User $new_username already exists. Choose a different username."
                else
                    #Update user in the system
                    usermod -l "$new_username" -m -d "/home/$new_username" "$username"
                    #Update user in the DB
                    change_username_in_dbs "$username" "$new_username"
                    # Logging: New username already exists
                    write_log "update_username:NewUsernameAlreadyExists '$new_username'"
                    echo "The user was successfully updated"
                fi
            fi
        else
            # Logging: User not found
            write_log "update_username:UserNotFound '$username'"
            echo "User $username does not exists. Choose a different username."
        fi
        ;;
    2)
        read -rp "Enter the username: " username
        write_log "update_password:AttemptToUpdatePassword '$username'"
        # Verify if the user exists
        if id "$username" >"/dev/null" 2>&1; then
            #Update password in the system
            passwd "$username"
            #Update password in the DB
            update_password_in_DB "$username"
            # Logging: Password successfully updated
            write_log "update_password:PasswordSuccessfullyUpdated '$username'"
            echo "The user was successfully updated"
        else
            write_log "update_password:UserNotFound '$username'"
            echo "User $username does not exists. Choose a different username."
        fi
        ;;
    3)
        read -rp "Enter the old username: " username
        # Logging: Attempt to update username and password
        write_log "update_username_and_password:AttemptToUpdateUsernameAndPassword '$username'"

        # Verify if the user exists
        if id "$username" >"/dev/null" 2>&1; then
            read -rp "Enter the new username: " new_username
            # Logging: Attempt to change username to a new one
            write_log "update_username_and_password:AttemptToChangeUsername '$username' to '$new_username'"

            # Check if the username contains the characters '/' or '\'
            if [[ "$new_username" =~ [\/\\] ]]; then
                # Logging: Invalid characters in the new username
                write_log "update_username_and_password:InvalidCharactersInNewUsername '$new_username'"
                printf "The username cannot contain the characters '/' or '%c'.\n" "\\"
            else
                # Verify that the user does not exist
                if id "$new_username" >"/dev/null" 2>&1; then
                    # Logging: New username already exists
                    write_log "update_username_and_password:NewUsernameAlreadyExists '$new_username'"
                    echo "User $new_username already exists. Choose a different username."
                else
                    #Update user in the system
                    usermod -l "$new_username" -m -d "/home/$new_username" "$username"
                    passwd "$new_username"
                    #Update system in the DB
                    change_username_in_dbs "$username" "$new_username"
                    update_password_in_DB "$new_username"
                    # Logging: User successfully updated
                    write_log "update_username_and_password:UserSuccessfullyUpdated '$username' to '$new_username'"
                    echo "The user was successfully updated"
                fi
            fi
        else
            # Logging: User not found
            write_log "update_username_and_password:UserNotFound '$username'"
            echo "User $username does not exists. Choose a different username."
        fi
        ;;
    0) ;;
    *)
        echo "Invalid option"
        ;;
    esac
}

change_username_in_dbs() {
    local old_username=$1
    local new_username=$2
    local departments
    departments=$(grep -E ";$old_username;" $users_file | cut -d ";" -f5)
    change_username_in_users_DB "$old_username" "$new_username"
    for department in $(echo "$departments" | tr ":" "\n"); do
        change_username_in_departments_DB "$old_username" "$new_username" "$department"
    done
}

change_username_in_users_DB() {
    local old_username=$1
    local new_username=$2
    sed -i "/;$old_username;/s/$old_username/$new_username/" $users_file
}

change_username_in_departments_DB() {
    local old_username=$1
    local new_username=$2
    local department=$3
    sed -i "/;$department;/s/;$old_username:/;$new_username:/" "$departments_file"
    sed -i "/;$department;/s/:$old_username/:$new_username/" "$departments_file"
    sed -i "/;$department;/s/;$old_username/;$new_username/" "$departments_file"
}

update_password_in_DB() {
    local username=$1
    local old_hashed_password
    local hashed_password
    old_hashed_password=$(grep -E ";$username;" $users_file | cut -d ";" -f3)
    hashed_password=$(grep -E "$username:" /etc/shadow | cut -d: -f2)
    sed -i "/;$username;/s#$old_hashed_password#$hashed_password#" "$users_file"
}

create_department() {
    read -rp "Enter the department name: " new_department

    # Logging: Attempt to create a department
    write_log "create_department:AttemptToCreateDepartment '$new_department'"

    # Check if the department already exists in the operating system
    if department_exists "$new_department"; then
        # The department already exists in the system
        # Logging: Department already exists in the system
        write_log "create_department:DepartmentAlreadyExists '$new_department'"
        echo "Department $new_department already exists."
    else
        # Check if the department is disabled in the db
        if department_disabled_in_db "$new_department"; then
            # Logging: Attempt to re-enable a department
            write_log "create_department:AttemptToReEnableDepartment '$new_department'"

            # Add the department to the system
            sudo addgroup "$new_department"
            # Enable department in db
            sed -i "/$new_department/s/No/Yes/" "$departments_file"
            # Check if there were users associated with the department
            department_users=$(grep "$new_department" "$departments_file" | cut -d';' -f4)
            if [ "$department_users" != "None" ]; then
                # Add users back to the department
                IFS=':' read -ra users <<<"$department_users"
                for user in "${users[@]}"; do
                    # Check if the user exists before adding to the department
                    if user_exists "$user"; then
                        sudo adduser "$user" "$new_department"
                        add_department_to_user_in_DB "$user" "$new_department"
                    else
                        # Logging: User doesn't exist, not re-added to the department
                        write_log "create_department:UserNotFound '$user', NotReAddedToDepartment '$new_department'"
                        echo "User $user doesn't exist, so it won't be re-added to department $new_department."
                    fi
                done
            fi
            # Logging: Department re-enabled successfully
            write_log "create_department:DepartmentReEnabledSuccessfully '$new_department'"
            echo "Department $new_department re-enabled."
        else
            # The department does not exist in the operating system or the db, add it to the system and the db
            sudo addgroup "$new_department"
            # Logging: Attempt to create a new department
            write_log "create_department:AttemptToCreateNewDepartment '$new_department'"
            echo "$(wc -l <$departments_file);$new_department;Yes;None" >>"$departments_file"
            # Logging: Department created successfully
            write_log "create_department:DepartmentCreatedSuccessfully '$new_department'"
            echo "Department $new_department created."
        fi
    fi
}

# Function to disable/delete a department and adjust user membership
disable_department() {
    read -rp "Enter the department name to disable: " department_name
    # Logging: Attempt to disable a department
    write_log "disable_department:AttemptToDisableDepartment '$department_name'"
    if department_exists "$department_name"; then
        # Get the list of users in the department
        users_in_department=$(getent group "$department_name" | cut -d: -f4)

        # Logging: Users in the department
        write_log "disable_department:UsersInDepartment '$department_name': '$users_in_department'"

        # Show users in department
        echo "Users in the department $department_name: $users_in_department"

        # Ask if the user wants to continue
        read -rp "Do you want to delete the group $department_name and adjust the users' membership? (s/n): " response

        if [[ "$response" =~ [Ss] ]]; then
            # Logging: Attempt to adjust user membership
            write_log "disable_department:AttemptToAdjustUserMembershipInDepartment '$department_name'"

            # Adjust user membership
            for user in $(echo "$users_in_department" | tr "," "\n"); do
                sudo deluser "$user" "$department_name"
            done

            # Logging: Attempt to delete the department
            write_log "disable_department:AttemptToDeleteDepartment '$department_name'"

            # Delete department
            sudo delgroup "$department_name"
            sed -i "/$department_name/s/Yes/No/" "$departments_file"
            remove_department_from_users_in_db "$department_name"

            # Logging: Department successfully disabled
            write_log "disable_department:DepartmentSuccessfullyDisabled '$department_name'"
            echo "Department $department_name disabled."
        else
            echo "Operation cancelled."
            # Logging: Operation cancelled
            write_log "disable_department:OperationCancelled"

        fi
    else
        # Logging: Department not found
        write_log "disable_department:DepartmentNotFound '$department_name'"
        echo "Department $department_name doesn't exist."
    fi
}

modify_department() {
    read -rp "Enter the department name to modify: " department_name
    # Logging: Attempt to modify a department
    write_log "modify_department:AttemptToModifyDepartment '$department_name'"

    # Check if the department exists in the operating system
    if department_exists_in_OS "$department_name"; then
        # Logging: Department found, attempt to modify
        write_log "modify_department:DepartmentFound '$department_name', AttemptToModify"

        # Request new name for the department
        read -rp "Ingrese el nuevo nombre para el departamento $department_name: " new_department_name

        # Logging: Attempt to change department name
        write_log "modify_department:AttemptToChangeDepartmentName '$department_name' to '$new_department_name'"

        # Modify the department name
        sudo groupmod -n "$new_department_name" "$department_name"
        change_department_name_in_dbs "$department_name" "$new_department_name"

        # Logging: Department successfully modified
        write_log "modify_department:DepartmentSuccessfullyModified '$department_name' to '$new_department_name'"

        echo "Department $department_name modified to $new_department_name."
    else
        # Logging: Department not found
        write_log "modify_department:DepartmentNotFound '$department_name'"
        echo "Department $department_name doesn't exist."
    fi
}

change_department_name_in_dbs() {
    local old_department_name=$1
    local new_department_name=$2
    local users
    users=$(grep -E ";$old_department_name;" $departments_file | cut -d ";" -f4)
    change_department_name_in_users_DB "$old_department_name" "$new_department_name"
    for user in $(echo "$users" | tr ":" "\n"); do
        change_department_name_in_departments_DB "$old_department_name" "$new_department_name" "$user"
    done
}

change_department_name_in_users_DB() {
    local old_department_name=$1
    local new_department_name=$2
    sed -i "/;$old_department_name;/s/$old_department_name/$new_department_name/" $departments_file
}

change_department_name_in_departments_DB() {
    local old_department_name=$1
    local new_department_name=$2
    local user=$3
    sed -i "/;$user;/s/;$old_department_name:/;$new_department_name:/" "$users_file"
    sed -i "/;$user;/s/:$old_department_name/:$new_department_name/" "$users_file"
    sed -i "/;$user;/s/;$old_department_name/;$new_department_name/" "$users_file"
}

# Function to check if the department exists
department_exists_in_OS() {
    grep -q "^$1:" /etc/group
}

# Feature to check if a department already exists and is disabled in db
department_disabled_in_db() {
    grep -q "$1;No" "$departments_file"
}

# Function to manage departments
manage_departments() {
    clear
    echo "1. Create department"
    echo "2. Disable department"
    echo "3. Modify department"
    echo "0. Back to main menu"

    read -rp "Select an option: " department_option

    case $department_option in
    1)
        create_department
        ;;
    2)
        disable_department
        ;;
    3)
        modify_department
        ;;
    0) ;;
    *)
        echo "Invalid option"
        ;;
    esac
}

unassign_user_from_department() {
    read -rp "Enter the username to unassign: " unassign_user
    read -rp "Enter the department name: " unassign_department

    # Logging: Attempt to unassign user from department
    write_log "unassign_user_from_department:AttemptToUnassignUser '$unassign_user' from Department '$unassign_department'"

    # Verify that the user and department exist
    if user_exists "$unassign_user" && department_exists "$unassign_department"; then
        # Logging: User and department exist, attempt to unassign
        write_log "unassign_user_from_department:UserAndDepartmentExist, AttemptToUnassign"

        # Check if the user is assigned to the department
        if user_assigned_to_department "$unassign_user" "$unassign_department" && department_has_user "$unassign_department" "$unassign_user"; then

            # Logging: User assigned to department, attempt to remove
            write_log "unassign_user_from_department:UserAssignedToDepartment, AttemptToRemove"
            # Remove the user from the department in the file
            remove_user_from_department_in_db "$unassign_user" "$unassign_department"
            remove_department_from_user_in_db "$unassign_user" "$unassign_department"
            # Remove user from department in OS
            sudo deluser "$unassign_user" "$unassign_department" &>/dev/null
            # Logging: User successfully unassigned from department
            write_log "unassign_user_from_department:UserSuccessfullyUnassigned '$unassign_user' from Department '$unassign_department'"
            echo "Usuario $unassign_user removido del departamento $unassign_department."
        else
            # Logging: User not assigned to department
            write_log "unassign_user_from_department:UserNotAssignedToDepartment '$unassign_user' to Department '$unassign_department'"

            echo "El usuario $unassign_user no está asignado al departamento $unassign_department."
        fi
    else
        # Logging: User or department not found
        write_log "unassign_user_from_department:UserOrDepartmentNotFound '$unassign_user' or '$unassign_department'"
        echo "El usuario o el departamento no existen."
    fi
}

remove_department_from_users_in_db() {
    department=$1
    sed -i "s/;$department:/;/" "$users_file"
    sed -i "s/:$department//" "$users_file"
    sed -i "s/;$department/;None/" "$users_file"
}

# Function to department from a user
remove_department_from_user_in_db() {
    user=$1
    department=$2
    # Modificar users.txt
    sed -i "/;$user;/s/;$department:/;/" "$users_file"
    sed -i "/;$user;/s/:$department//" "$users_file"
    sed -i "/;$user;/s/;$department/;None/" "$users_file"
}

# Function to remove a user from a department
remove_user_from_department_in_db() {
    local user=$1
    local department=$2
    # Modificar departments.txt
    sed -i "/;$department;/s/;$user:/;/" "$departments_file"
    sed -i "/;$department;/s/:$user//" "$departments_file"
    sed -i "/;$department;/s/;$user/;None/" "$departments_file"
}

# Function to check if a user exists
user_exists() {
    id "$1" &>/dev/null 2>&1
}

# Function to check if a department exists
department_exists() {
    getent group "$1" &>/dev/null
}

# Function to check if a user is assigned to a department
user_assigned_to_department() {
    id -nG "$1" | grep -q "$2"
}

# Function to manage user assignments to departments
department_has_user() {
    getent group "$1" | cut -d: -f4 | tr ',' '\n' | grep -q "$2"
}

# Function to manage user assignments to departments
manage_assignments() {
    clear
    echo "1. Assign user to department"
    echo "2. Unassign user from department"
    echo "0. Back to main menu"

    read -rp "Select an option: " assignment_option

    case $assignment_option in
    1)
        assign_user_to_department
        ;;
    2)
        unassign_user_from_department
        ;;
    0) ;;
    *)
        echo "Invalid option"
        ;;
    esac
}

assign_user_to_department() {
    local username_to_assign
    read -rp "Enter the username: " username_to_assign
    # Logging: Attempt to assign user to department
    write_log "assign_user_to_department:AttemptToAssignUser '$username_to_assign' to Department"

    # Verify if the user exists
    if id "$username_to_assign" >"/dev/null" 2>&1; then
        local department_name
        read -rp "Enter the department name to assign to $username_to_assign: " department_name
        # Check if the department exists in the operating system
        if department_exists_in_OS "$department_name"; then
            # Check if the user is already a member of the department
            if id -nG "$username_to_assign" | grep -qw "$department_name"; then
                # Logging: User is already a member
                write_log "assign_user_to_department:UserAlreadyMemberOfDepartment '$username_to_assign' in '$department_name'"
                echo "User $username_to_assign is already a member of the department $department_name."
            else

                #Assign the user to the department in the system
                usermod -aG "$department_name" "$username_to_assign"
                # Logging: Attempt to assign user to the department in the DB

                #Assign the user to the department in the DB
                add_user_to_department_in_DB "$username_to_assign" "$department_name"
                # Logging: Attempt to assign department to the user in the DB
                write_log "assign_user_to_department:AttemptToAssignDepartmentToUserInDB '$username_to_assign' to '$department_name'"
                #Assign the department to the user in the DB
                add_department_to_user_in_DB "$username_to_assign" "$department_name"
                # Logging: User successfully assigned to the department
                write_log "assign_user_to_department:UserSuccessfullyAssigned '$username_to_assign' to '$department_name'"
                echo "The user was successfully assigned to the department"
            fi
        else
            # Logging: Department does not exist
            write_log "assign_user_to_department:DepartmentDoesNotExist '$department_name'"
            echo "Department $department_name doesn't exist."
        fi
    else
        # Logging: User not found
        write_log "assign_user_to_department:UserNotFound '$username_to_assign'"
        echo "User $username_to_assign does not exists. Choose a different username."
    fi
}

add_user_to_department_in_DB() {
    local username=$1
    local department_name=$2
    local old_users_in_department
    local new_users_in_department
    old_users_in_department=$(grep -E ";$department_name;" $departments_file | cut -d ";" -f4)
    if [[ "$old_users_in_department" == "None" ]]; then
        new_users_in_department="$username"
    else
        new_users_in_department="$old_users_in_department:$username"
    fi
    sed -i "/;$department_name;/s/$old_users_in_department/$new_users_in_department/" "$departments_file"
}

add_department_to_user_in_DB() {
    local username=$1
    local department_name=$2
    local old_departments_of_user
    local new_departments_of_user
    old_departments_of_user=$(grep -E ";$username;" $users_file | cut -d ";" -f5)
    if [[ "$old_departments_of_user" == "None" ]]; then
        new_departments_of_user="$department_name"
    else
        new_departments_of_user="$old_departments_of_user:$department_name"
    fi
    sed -i "/;$username;/s/$old_departments_of_user/$new_departments_of_user/" "$users_file"
}

# LOGS_START

# Function to manage logs
manage_logs() {
    clear
    echo "1. Filter logs by date"
    echo "2. Filter logs by author username"
    echo "3. Filter logs by action"
    echo "4. Find the day with most activity (more logs)"
    echo "5. Find the most active user (more logs)"
    echo "6. Find the most repeated action"
    echo "0. Back to main menu"

    read -rp "Select an option: " logs_option

    case $logs_option in
    1)
        filter_logs_by_date
        ;;
    2)
        filter_logs_by_username
        ;;
    3)
        search_logs_by_action
        ;;
    4)
        find_day_with_most_logs
        ;;
    5)
        find_most_active_user
        ;;
    6)
        find_most_repeated_action
        ;;

    0) ;;
    *)
        echo "Invalid option"
        ;;
    esac
}

# Function to write logs to $logs_file table
write_log() {
    author=$(who am i | cut -d' ' -f1)
    date=$(date +"%Y-%m-%d %H:%M:%S")
    action=$1

    # Count the number of lines in the log file to determine the index
    index=$(wc -l <"$logs_file")

    # Append the log entry to the $logs_file table with the index
    echo -e "${index};${author};${date};${action}" >>"$logs_file"
}

# Function to load and filter logs by date without hours
filter_logs_by_date() {
    read -rp "Enter the date (YYYY-MM-DD): " filter_date

    # Validate the date format
    if [[ ! $filter_date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "Invalid date format. Please use the format YYYY-MM-DD."
        return
    fi

    # Load logs from $logs_file
    if [ -e "$logs_file" ]; then
        # Filter logs by date without hours
        filtered_logs=$(awk -v date="$filter_date" -F ";" '$3 ~ date { print }' "$logs_file")

        # Display filtered logs
        if [ -n "$filtered_logs" ]; then
            echo -e "Filtered logs for date $filter_date:\n$filtered_logs"
        else
            echo "No logs found for the specified date."
        fi
    else
        echo "Log file not found."
    fi
}

# Function to load and filter logs by username
filter_logs_by_username() {
    read -rp "Enter the username to filter: " filter_username

    # Load logs from $logs_file
    if [ -e "$logs_file" ]; then
        # Filter logs by username
        filtered_logs=$(awk -v username="$filter_username" -F ";" '$2 ~ username { print }' "$logs_file")

        # Display filtered logs
        if [ -n "$filtered_logs" ]; then
            echo -e "Filtered logs for username $filter_username:\n$filtered_logs"
        else
            echo "No logs found for the specified username."
        fi
    else
        echo "Log file not found."
    fi
}

# Function to search logs by action or partial action
search_logs_by_action() {
    read -rp "Enter the action or partial action to search: " search_action

    # Load logs from $logs_file
    if [ -e "$logs_file" ]; then
        # Search logs by action or partial action
        matched_logs=$(grep -i "$search_action" "$logs_file")

        # Display matched logs
        if [ -n "$matched_logs" ]; then
            echo -e "Logs matching '$search_action':\n$matched_logs"
        else
            echo "No logs found for the specified action or partial action."
        fi
    else
        echo "Log file not found."
    fi
}

# Function to find the day with the most logs
find_day_with_most_logs() {
    # Load logs from $logs_file
    if [ -e "$logs_file" ]; then
        # Extract the day from each log entry using awk
        days=$(awk -F ';' '{split($3, date, " "); print date[1]}' "$logs_file")

        # Count occurrences of each day and find the day with the most logs
        most_logs_day=$(echo "$days" | sort | uniq -c | sort -nr | head -n 1)

        # Display the day with the most logs and the number of logs
        if [ -n "$most_logs_day" ]; then
            echo -e "Day with the most logs: $most_logs_day"
        else
            echo "No logs found."
        fi
    else
        echo "Log file not found."
    fi
}

# Function to find the most repeated action
find_most_repeated_action() {
    # Load logs from $logs_file
    if [ -e "$logs_file" ]; then
        # Extract the action from each log entry using awk
        actions=$(awk -F ':' '{print $NF}' "$logs_file")

        # Count occurrences of each action and find the most repeated action
        most_repeated_action=$(echo "$actions" | sort | uniq -c | sort -nr | head -n 1)

        # Display the most repeated action and the number of occurrences
        if [ -n "$most_repeated_action" ]; then
            echo -e "Most repeated action: $most_repeated_action"
        else
            echo "No logs found."
        fi
    else
        echo "Log file not found."
    fi
}

# Function to find the most active user
find_most_active_user() {
    # Load logs from $logs_file
    if [ -e "$logs_file" ]; then
        # Extract the username from each log entry using awk
        usernames=$(awk -F ';' '{print $2}' "$logs_file")

        # Count occurrences of each username and find the most active user
        most_active_user=$(echo "$usernames" | sort | uniq -c | sort -nr | head -n 1)

        # Display the most active user and the number of occurrences
        if [ -n "$most_active_user" ]; then
            echo -e "Most active user: $most_active_user"
        else
            echo "No logs found."
        fi
    else
        echo "Log file not found."
    fi
}

#LOGS_END

# Function to manage system activities
manage_activities() {
    clear
    echo "1. Track user activities in memory"
    echo "2. Track user activities in processes"
    echo "3. Track user activities in files"
    echo "0. Back to main menu"

    read -rp "Select an option: " activities_option

    case $activities_option in
    1)
        # Logic to track activities in memory
        track_memory_activities
        ;;
    2)
        # Logic to track activities in processes
        track_process_activities
        ;;
    3)
        # Logic to track activities in files
        track_file_activities
        ;;
    0)
        show_main_menu
        ;;
    *)
        echo "Invalid option"
        ;;
    esac
}

track_memory_activities() {
    # Retrieve information about running processes
    ps aux >memory_activities.log
    echo "Memory activities tracked and saved to memory_activities.log"
    write_log "track_memory_activities:MemoryActivitiesTracked"
}

track_process_activities() {
    # Retrieve real-time information about running processes
    top -b -n 1 >process_activities.log
    echo "Process activities tracked and saved to process_activities.log"
    write_log "track_process_activities:ProcessActivitiesTracked"
}

track_file_activities() {
    clear
    echo "Select a file to check activity:"
    echo "1. GROUP"
    echo "2. PASSWD"
    echo "3. SHADOW"
    echo "4. USERS.TXT"
    echo "5. DEPARTMENTS.TXT"
    echo "0. Back to main menu"

    read -rp "Select an option: " file_option

    case $file_option in
    1)
        get_group_directory_details
        ;;
    2)
        get_passwd_directory_details
        ;;
    3)
        get_shadow_directory_details
        ;;
    4)
        get_users_directory_details
        ;;
    5)
        get_departments_directory_details

        ;;
    0)
      show_main_menu
      ;;
    *)
        echo "Invalid option"
        ;;
    esac
}

get_group_directory_details() {
    file_path="/etc/group"

        if [ -e "$file_path" ]; then
            stat "$file_path"
        else
            echo "File not found: $file_path"
        fi
}

get_passwd_directory_details() {
    file_path="/etc/passwd"

            if [ -e "$file_path" ]; then
                stat "$file_path"
            else
                echo "File not found: $file_path"
            fi
}

get_shadow_directory_details() {
    file_path="/etc/shadow"

            if [ -e "$file_path" ]; then
                stat "$file_path"
            else
                echo "File not found: $file_path"
            fi
}

get_users_directory_details() {

            if [ -e "$users_file" ]; then
                stat "$users_file"
            else
                echo "File not found: $users_file"
            fi
}

get_departments_directory_details() {

        if [ -e "$departments_file" ]; then
            stat "$departments_file"
        else
            echo "File not found: $departments_file"
        fi
}


# Function to manage the system
manage_system() {
    clear
    echo "1. Check CPU threshold"
    echo "2. Show secondary storage threshold"
    echo "3. Check I/O threshold"
    echo "4. Check swapping threshold"
    echo "5. Check running time and average load threshold"
    echo "6. Check RAM memory threshold"
    echo "0. Back to main menu"

    read -rp "Select an option: " system_option

    case $system_option in
    1)
        check_cpu_threshold
        ;;
    2)
        check_secondary_storage_threshold
        ;;
    3)
        check_ps_threshold
        ;;
    4)
        check_swapping_threshold
        ;;
    5)
        check_uptime_threshold
        ;;
    6)
        check_memory_threshold
        ;;
    0) ;;
    *)
        echo "Invalid option"
        ;;
    esac
}

check_cpu_threshold() {
    THRESHOLD=90
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}' | cut -d. -f1)
    echo "CPU Usage: $CPU_USAGE%"
    if [ "$CPU_USAGE" -gt $THRESHOLD ]; then
        echo "Alert: CPU usage higher than $THRESHOLD%!"
    else
        echo "Everything is okay!"
    fi
}

check_uptime_threshold() {
    # Get the 1-minute load average
    saved_uptime=$(uptime)
    load_average=$(echo "$saved_uptime" | awk -F'[a-z]:' '{print int($2)}')

    # Set the threshold for a high load average
    threshold=1

    echo "Current uptime and load average: $saved_uptime"

    # Compare load average with the threshold
    if [ "$load_average" -gt "$threshold" ]; then
        echo "Load average is high! Alert!"
    else
        echo "Everythig is okay!"
    fi
}

check_memory_threshold() {
    # Get the free memory information
    free_memory=$(free -h | grep Mem)

    # Extract the percentage of used memory
    used_percent=$(echo "$free_memory" | awk '{print int($3)}' | tr -d '%')

    # Set the threshold for high memory usage
    memory_threshold=70

    echo "Current memory usage:"
    echo "$free_memory"

    # Compare memory usage with the threshold
    if [ "$used_percent" -gt "$memory_threshold" ]; then
        echo "Memory usage is high! Alert!"
        # You can add additional actions here, such as sending an email or a system notification.
    else
        echo "Everythig is okay!"
    fi
}

check_secondary_storage_threshold() {
    clear
    df_output=$(df -h)
    echo "$df_output"
    if echo "$df_output" | awk 'NR>1 && $5 > 80' | grep -q .; then
        echo "File system usage is high!"
    else
        echo "File system usage is correct."
    fi
}

check_ps_threshold() {
    ps_output=$(ps aux --sort=-%cpu)
    echo "$ps_output"

    # Verifica si alguna línea tiene un uso de CPU superior al umbral (80% en este caso)
    if echo "$ps_output" | awk '$3 > 80' | grep -q .; then
        echo "Alert: High I/O usage detected!"
    else
        echo "Info: I/O usage is within normal range."
    fi
}

check_swapping_threshold() {
    THRESHOLD=10
    # Run the vmstat command and extract the value from the "swap in" column (si)
    SWAP_IN=$(vmstat 1 2 | tail -1 | awk '{print $7}')

    # Round the value to an integer
    SWAP_IN=$(printf "%.0f" "$SWAP_IN")

    echo "Swapping: $SWAP_IN KB"

    if [ "$SWAP_IN" -gt "$THRESHOLD" ]; then
        echo "Alert: Swap activity (swap in) exceeds the threshold of $THRESHOLD!"
    else
        echo "Swap activity (swap in) within normal range."
    fi
}

create_tables() {
    if [ ! -e "$users_file" ]; then
        echo -e "#;Username;Password;Enabled;Departments" >"$users_file"
        chmod 777 "$users_file"
    fi

    if [ ! -e "$departments_file" ]; then
        echo -e "#;Department_name;Enabled;Users" >"$departments_file"
        chmod 777 "$departments_file"
    fi

    # Check if the log file exists, if not, create it with the header
    if [ ! -e "$logs_file" ]; then
        echo -e "#;Username;Date;Action" >"$logs_file"
        chmod 777 "$logs_file"
    fi
}

# Check if the user is root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with root privileges."
    exit 1
fi

echo "The script is running with root privileges."

create_tables

# Main function
while true; do
    show_main_menu

    read -rp "Select an option: " main_option

    case $main_option in
    1)
        manage_users
        ;;
    2)
        manage_departments
        ;;
    3)
        manage_assignments
        ;;
    4)
        manage_logs
        ;;
    5)
        manage_activities
        ;;
    6)
        manage_system
        ;;
    0)
        echo "Exiting the script. Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid option"
        ;;
    esac
done
