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
            sudo useradd -m -s /bin/bash $new_username
            passwd $new_username
            echo "User $new_username created"
            ;;
        2)
            read -p "Enter the username to disable: " disable_user
            # Logic to disable a user
            sed -i "/$disable_user/d" "$users_file"
            echo "User $disable_user disabled"
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

create_department() {
    read -p "Enter the department name: " new_department
    # Check if the department already exists in the operating system
    if department_exists_in_OS "$department_name"; then
        # The department already exists in the system
        echo "Department $new_department already exists."
    else
        # Check if the department is disabled in the db
        if department_disabled_in_db "$new_department"; then
            # Enable department in db
            sed -i "/$new_department/s/No/Yes/" "$departments_file"
            # Add the department to the system
            sudo addgroup "$new_department"
            echo "Department $new_department re-enabled."
        else
            # The department does not exist in the operating system or the db, add it to the system and the db
            sudo addgroup "$new_department"
            numero_registro=$(wc -l < "$departments_file")
            if [ "$numero_registro" -gt 0 ]; then
                ((numero_registro--))
            fi
            ((numero_registro++))
            echo -e "$numero_registro;$new_department;Yes;None" >> "$departments_file"
            echo "Department $new_department created."
        fi
    fi
}

# Function to disable/delete a department and adjust user membership
disable_department() {
  read -p "Enter the department name to disable: " department_name
  if department_exists_in_OS "$department_name"; then
    # Get the list of users in the department
    users=$(getent group "$department_name" | cut -d: -f4)

    # Show users in department
    echo "Users in the department $department_name: $users"

    # Ask if the user wants to continue
    read -p "Do you want to delete the group $department_name and adjust the users' membership? (s/n): " response

    if [ "$response" == "s" ]; then
      # Adjust user membership
      for user in $users; do
        sudo deluser "$user" "$department_name"
      done

      # Delete department
      sudo delgroup "$department_name"
      sed -i "/$department_name/s/Yes/No/" "$departments_file"
      echo "Department $department_name disabled."
    else
      echo "Operation cancelled."
    fi
  else
    echo "Department $department_name doesn't exist."
  fi
}

modify_department() {
    read -p "Enter the department name to modify: " department_name
    # Check if the department exists in the operating system
    if department_exists_in_OS "$department_name"; then
        # Request new name for the department
        read -p "Ingrese el nuevo nombre para el departamento $department_name: " new_department_name
        # Modify the department name
        sudo groupmod -n "$new_department_name" "$department_name"
        sed -i "s/$department_name/$new_department_name/" "$departments_file"
        echo "Department $department_name modified to $new_department_name."
    else
        echo "Department $department_name doesn't exist."
    fi
}

# Function to check if the group exists
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

    read -p "Select an option: " department_option

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

create_tables() {
  if [ ! -e "$users_file" ]; then
    echo -e "#;Username;Password;Enabled" > "$users_file"
    chmod 777 "$users_file"
  fi

  if [ ! -e "$departments_file" ]; then
    echo -e "#;Group_name;Enabled;Users" > "$departments_file"
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
