#!/bin/bash

# Storage files
users_file="users.txt"
departments_file="departments.txt"
assignments_file="assignments.txt"
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

    read -p "Select an option: " user_option

    case $user_option in
        1)
            read -p "Enter the username: " new_username

            # Verify if the user exists in the system
            if id "$new_username" >/dev/null 2>&1; then
                echo "User $new_username already exists. Choose a different username."
            else
                # Create the user if the user no exists
                useradd -m -s /bin/bash "$new_username"
                passwd "$new_username"
                hashed_password=$(grep -E "$new_username:" /etc/shadow | cut -d: -f2)
                # Verify if the user exists in the DB
                if grep -q ";$new_username;" "$users_file"; then
                    # Enable user and update password
                    old_hashed_password=$(grep -E ";$new_username;" $users_file | cut -d ";" -f3)
                    sed -i "/;$new_username;/s/false/true/" "$users_file"
                    sed -i "/;$new_username;/s#$old_hashed_password#$hashed_password#" "$users_file"
                else
                    # Save user information to users.txt
                    echo "$(wc -l < $users_file);$new_username;$(grep -E "$new_username:" /etc/shadow | cut -d: -f2);true" >> $users_file  
                fi
                echo "User $new_username created"
            fi
            ;;
        2)
            read -p "Enter the username to disable: " disable_user

            # Verify if the user exists
            if id "$disable_user" >/dev/null 2>&1; then
                # Logic to disable a user
                sed -i "/;$disable_user;/s/true/false/" $users_file
                # Logic to delete a user
                sudo userdel -r $disable_user
                echo "User $disable_user was removed from the system and disabled in the DB"
            else 
                echo "User $disable_user does not exists. Choose a different username."
            fi
            
            ;;
        3)
            read -p "Enter the username to modify: " modify_user
            # Logic to modify a user
            # You can implement the logic according to your needs
            echo "Modification function not yet implemented"
            ;;
        0)
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# Function to manage departments
manage_departments() {
    clear
    echo "1. Create department"
    echo "2. Disable department"
    echo "3. Modify department"
    echo "0. Back to main menu"

    read -p "Select an option: " department_option

    case $department_option in
        1)
            read -p "Enter the department name: " new_department
            # Logic to create a department
            echo "$new_department" >> "$departments_file"
            echo "Department $new_department created"
            ;;
        2)
            read -p "Enter the department name to disable: " disable_department
            # Logic to disable a department
            sed -i "/$disable_department/d" "$departments_file"
            echo "Department $disable_department disabled"
            ;;
        3)
            read -p "Enter the department name to modify: " modify_department
            # Logic to modify a department
            # You can implement the logic according to your needs
            echo "Modification function not yet implemented"
            ;;
        0)
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# Function to manage user assignments to departments
manage_assignments() {
    clear
    echo "1. Assign user to department"
    echo "2. Unassign user from department"
    echo "0. Back to main menu"

    read -p "Select an option: " assignment_option

    case $assignment_option in
        1)
            read -p "Enter the username: " assign_user
            read -p "Enter the department name: " assign_department
            # Logic to assign a user to a department
            echo "$assign_user,$assign_department" >> "$assignments_file"
            echo "User $assign_user assigned to department $assign_department"
            ;;
        2)
            read -p "Enter the username to unassign: " unassign_user
            read -p "Enter the department name: " unassign_department
            # Logic to unassign a user from a department
            sed -i "/$unassign_user,$unassign_department/d" "$assignments_file"
            echo "User $unassign_user unassigned from department $unassign_department"
            ;;
        0)
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# Function to manage logs
manage_logs() {
    clear
    echo "1. Specific search in logs"
    echo "0. Back to main menu"

    read -p "Select an option: " logs_option

    case $logs_option in
        1)
            read -p "Enter the search term: " search_term
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

    read -p "Select an option: " activities_option

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

    read -p "Select an option: " system_option

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

createTable(){
  tableName=$1
  headers=$2
  if [ -e "$tableName" ]; then
  	echo "File exists"
  else
  	touch $tableName
  	chmod -wx $tableName
    #Add headers in the first line
    echo $headers >> $tableName
  fi
}

# Check if the user is root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with root privileges."
    exit 1
fi

createTable $users_file "#;Nombre de Usuario;Contraseña;Habilitado"
# The rest of the script here

echo "The script is running with root privileges."

# Main function
while true; do
    show_main_menu

    read -p "Select an option: " main_option

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

