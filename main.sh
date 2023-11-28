#!/bin/bash

# Storage files
users_file="users.txt"
departments_file="departments.txt"
logs_file="logs.txt"

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
        0)
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

create_user() {
    read -rp "Enter the username: " new_username

    # Check if the username contains the characters '/' or '\'
    if [[ "$new_username" =~ [\/\\] ]]; then
        printf "The username cannot contain the characters '/' or '%c'.\n" "\\"
    else
        # Verify if the user exists in the system
        if id "$new_username" >/dev/null 2>&1; then
            echo "User $new_username already exists. Choose a different username."
        else
            # Check if a group with the same name exists before creating a new user.
            if grep -q "^$new_username:" "/etc/group"; then
                useradd -m -s /bin/bash "$new_username" -g "$new_username"
            else
                useradd -m -s /bin/bash "$new_username"
            fi
            passwd "$new_username"
            # Verify if the user exists in the DB
            if grep -q ";$new_username;" "$users_file"; then
                # Enable user and update password
                sed -i "/;$new_username;/s/No/Yes/" "$users_file"
                update_password_in_DB "$new_username"
                #Update departments of the user
                update_deparments_of_disabled_user "$new_username"
            else
                # Save user information to users.txt
                echo "$(wc -l < $users_file);$new_username;$(grep -E "$new_username:" /etc/shadow | cut -d: -f2);Yes;None" >> $users_file
            fi
            echo "User $new_username created"
        fi
    fi
}

#Re-associates all departments the user had when enabled
update_deparments_of_disabled_user() {
    username=$1
    initial_departments=$(grep -E ";$username;" $users_file | cut -d ";" -f5)
    final_departments=""
    if [[ "$initial_departments" != "None" ]]; then
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
    fi
}

#Adds a user that was disabled to a department in the DB
add_disabled_user_to_department_in_DB() {
    new_username=$1
    department_name=$2
    # Users in the department
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
    fi
}

disable_user() {
    read -rp "Enter the username to disable: " disable_user

    # Verify if the user exists
    if id "$disable_user" > "/dev/null" 2>&1; then
        # Logic to delete a user
        sudo userdel -r "$disable_user"
        # Logic to disable a user
        sed -i "/;$disable_user;/s/Yes/No/" $users_file
        echo "User $disable_user was removed from the system and disabled in the DB"
    else
        echo "User $disable_user does not exists. Choose a different username."
    fi
}

modify_user() {
    echo "1. Change user name"
    echo "2. Change password"
    echo "3. Change username and password"
    echo "0. Back to main menu"

    read -rp "Select an option: " user_option

    case $user_option in
        1)
            read -rp "Enter the old username: " username
            # Verify if the user exists
            if id "$username" > "/dev/null" 2>&1; then
                read -rp "Enter the new username: " new_username
                # Check if the username contains the characters '/' or '\'
                if [[ "$new_username" =~ [\/\\] ]]; then
                    printf "The username cannot contain the characters '/' or '%c'.\n" "\\"
                else
                    # Verify that the user does not exist
                    if id "$new_username" > "/dev/null" 2>&1; then
                        echo "User $new_username already exists. Choose a different username."
                    else
                        #Update user in the system
                        usermod -l "$new_username" -m -d "/home/$new_username" "$username"
                        #Update user in the DB
                        change_username_in_DB "$username" "$new_username"
                        echo "The user was successfully updated"
                    fi
                fi
            else
                echo "User $username does not exists. Choose a different username."
            fi
            ;;
        2)
            read -rp "Enter the username: " username
            # Verify if the user exists
            if id "$username" > "/dev/null" 2>&1; then
                #Update password in the system
                passwd "$username"
                #Update password in the DB
                update_password_in_DB "$username"
                echo "The user was successfully updated"
            else
                echo "User $username does not exists. Choose a different username."
            fi
            ;;
        3)
            read -rp "Enter the old username: " username
            # Verify if the user exists
            if id "$username" > "/dev/null" 2>&1; then
                read -rp "Enter the new username: " new_username
                # Check if the username contains the characters '/' or '\'
                if [[ "$new_username" =~ [\/\\] ]]; then
                    printf "The username cannot contain the characters '/' or '%c'.\n" "\\"
                else
                    # Verify that the user does not exist
                    if id "$new_username" > "/dev/null" 2>&1; then
                        echo "User $new_username already exists. Choose a different username."
                    else
                        #Update user in the system
                        usermod -l "$new_username" -m -d "/home/$new_username" "$username"
                        passwd "$new_username"
                        #Update system in the DB
                        change_username_in_DB "$username" "$new_username"
                        update_password_in_DB "$new_username"
                        echo "The user was successfully updated"
                    fi
                fi
            else
                echo "User $username does not exists. Choose a different username."
            fi
            ;;
        0)
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

change_username_in_DB() {
    old_username=$1
    new_username=$2
    sed -i "/;$old_username;/s/$old_username/$new_username/" $users_file
}

update_password_in_DB() {
    username=$1
    old_hashed_password=$(grep -E ";$new_username;" $users_file | cut -d ";" -f3)
    hashed_password=$(grep -E "$new_username:" /etc/shadow | cut -d: -f2)
    sed -i "/;$new_username;/s#$old_hashed_password#$hashed_password#" "$users_file"
}

create_department() {
    read -rp "Enter the department name: " new_department
    # Check if the department already exists in the operating system
    if department_exists "$new_department"; then
        # The department already exists in the system
        echo "Department $new_department already exists."
    else
        # Check if the department is disabled in the db
        if department_disabled_in_db "$new_department"; then
            # Add the department to the system
            sudo addgroup "$new_department"
            # Enable department in db
            sed -i "/$new_department/s/No/Yes/" "$departments_file"
            # Check if there were users associated with the department
            department_users=$(grep "$new_department" "$departments_file" | cut -d';' -f4)
            if [ "$department_users" != "None" ]; then
                # Add users back to the department
                IFS=':' read -ra users <<< "$department_users"
                for user in "${users[@]}"; do
                    # Check if the user exists before adding to the department
                    if user_exists "$user"; then
                        sudo adduser "$user" "$new_department"
                        add_department_to_user_in_DB "$user" "$new_department"
                    else
                        echo "User $user doesn't exist, so it won't be re-added to department $new_department."
                    fi
                done
            fi
            echo "Department $new_department re-enabled."
        else
            # The department does not exist in the operating system or the db, add it to the system and the db
            sudo addgroup "$new_department"
            echo -e "$(wc -l < $users_file);$new_department;Yes;None" >> "$departments_file"
            echo "Department $new_department created."
        fi
    fi
}

# Function to disable/delete a department and adjust user membership
disable_department() {
  read -rp "Enter the department name to disable: " department_name
  if department_exists "$department_name"; then
    # Get the list of users in the department
    users=$(getent group "$department_name" | cut -d: -f4)

    # Show users in department
    echo "Users in the department $department_name: $users"

    # Ask if the user wants to continue
    read -rp "Do you want to delete the group $department_name and adjust the users' membership? (s/n): " response

    if [[ "$response" =~ [Ss] ]]; then
      # Adjust user membership
      for user in $(echo "$users" | tr "," "\n"); do
        sudo deluser "$user" "$department_name"
      done

      # Delete department
      sudo delgroup "$department_name"
      sed -i "/$department_name/s/Yes/No/" "$departments_file"
      remove_department_from_users_in_db "$department_name"
      echo "Department $department_name disabled."
    else
      echo "Operation cancelled."
    fi
  else
    echo "Department $department_name doesn't exist."
  fi
}

modify_department() {
    read -rp "Enter the department name to modify: " department_name
    # Check if the department exists in the operating system
    if department_exists_in_OS "$department_name"; then
        # Request new name for the department
        read -rp "Ingrese el nuevo nombre para el departamento $department_name: " new_department_name
        # Modify the department name
        sudo groupmod -n "$new_department_name" "$department_name"
        sed -i "s/$department_name/$new_department_name/" "$departments_file"
        echo "Department $department_name modified to $new_department_name."
    else
        echo "Department $department_name doesn't exist."
    fi
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
        0)
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

unassign_user_from_department() {
    read -rp "Enter the username to unassign: " unassign_user
    read -rp "Enter the department name: " unassign_department
    # Verify that the user and department exist
    if user_exists "$unassign_user" && department_exists "$unassign_department"; then
        # Check if the user is assigned to the department
        if user_assigned_to_department "$unassign_user" "$unassign_department" && department_has_user "$unassign_department" "$unassign_user"; then
            # Remove the user from the department in the file
            remove_user_from_department_in_db "$unassign_user" "$unassign_department"
            remove_department_from_user_in_db "$unassign_user" "$unassign_department"
            # Remove user from department in OS
            sudo deluser "$unassign_user" "$unassign_department" &>/dev/null
            echo "Usuario $unassign_user removido del departamento $unassign_department."
        else
            echo "El usuario $unassign_user no está asignado al departamento $unassign_department."
        fi
    else
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
  user=$1
  department=$2
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
        0)
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

assign_user_to_department() {
    read -rp "Enter the username: " username
    # Verify if the user exists
    if id "$username" > "/dev/null" 2>&1; then
        read -rp "Enter the department name to assign to $username: " department_name
        # Check if the department exists in the operating system
        if department_exists_in_OS "$department_name"; then
            # Check if the user is already a member of the department
            if id -nG "$username" | grep -qw "$department_name"; then
                echo "User $username is already a member of the department $department_name."
            else
                #Assign the user to the department in the system
                usermod -aG "$department_name" "$username"
                #Assign the user to the department in the DB
                add_user_to_department_in_DB "$username" "$department_name"
                #Assign the department to the user in the DB
                add_department_to_user_in_DB "$username" "$department_name"
                echo "The user was successfully assigned to the department"
            fi
        else
            echo "Department $department_name doesn't exist."
        fi
    else
        echo "User $username does not exists. Choose a different username."
    fi
}

add_user_to_department_in_DB() {
    username=$1
    department_name=$2

    old_users_in_department=$(grep -E ";$department_name;" $departments_file | cut -d ";" -f4)
    if [[ "$old_users_in_department" == "None" ]]; then
        new_users_in_department="$username"
    else
        new_users_in_department="$old_users_in_department:$username"
    fi
    sed -i "/;$department_name;/s/$old_users_in_department/$new_users_in_department/" "$departments_file"
}

add_department_to_user_in_DB() {
    username=$1
    department_name=$2

    old_departments_of_user=$(grep -E ";$username;" $users_file | cut -d ";" -f5)
    if [[ "$old_departments_of_user" == "None" ]]; then
        new_departments_of_user="$department_name"
    else
        new_departments_of_user="$old_departments_of_user:$department_name"
    fi
    sed -i "/;$username;/s/$old_departments_of_user/$new_departments_of_user/" "$users_file"
}

# Function to manage logs
manage_logs() {
    clear
    echo "1. Specific search in logs"
    echo "0. Back to main menu"

    read -rp "Select an option: " logs_option

    case $logs_option in
        1)
            read -rp "Enter the search term: " search_term
            # Logic to search in logs
            grep "$search_term" "$logs_file"
            ;;
        0)
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

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
            echo "Function not implemented"
            ;;
        2)
            # Logic to track activities in processes
            echo "Function not implemented"
            ;;
        3)
            # Logic to track activities in files
            echo "Function not implemented"
            ;;
        0)
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# Function to manage the system
manage_system() {
    clear
    echo "1. Monitor system status"
    echo "2. Create alert report"
    echo "0. Back to main menu"

    read -rp "Select an option: " system_option

    case $system_option in
        1)
            # Logic to monitor system status
            echo "Function not implemented"
            ;;
        2)
            # Logic to create alert report
            echo "Function not implemented"
            ;;
        0)
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

create_tables() {
  if [ ! -e "$users_file" ]; then
    echo -e "#;Username;Password;Enabled;Departments" > "$users_file"
    chmod 777 "$users_file"
  fi

  if [ ! -e "$departments_file" ]; then
    echo -e "#;Department_name;Enabled;Users" > "$departments_file"
    chmod 777 "$departments_file"
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
