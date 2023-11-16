#!/bin/bash

# Archivos de almacenamiento
usuarios_file="usuarios.txt"
departamentos_file="departamentos.txt"
asignaciones_file="asignaciones.txt"
logs_file="logs.txt"

# Función para mostrar el menú principal
mostrar_menu_principal() {
    echo "1. Gestión de usuarios"
    echo "2. Gestión de departamentos"
    echo "3. Usuarios x departamento"
    echo "4. Gestión de logs"
    echo "5. Gestión de actividades"
    echo "6. Gestión del sistema"
    echo "0. Salir"
}

# Función para gestionar usuarios
gestionar_usuarios() {
    clear
    echo "1. Crear usuario"
    echo "2. Deshabilitar usuario"
    echo "3. Modificar usuario"
    echo "0. Volver al menú principal"

    read -p "Seleccione una opción: " opcion_usuario

    case $opcion_usuario in
        1)
            read -p "Ingrese el nombre del usuario: " new_username
            useradd -m -s /bin/bash $new_username
            passwd $new_username
            echo "Usuario $nuevo_usuario creado"
            
            ;;
        2)
            read -p "Ingrese el nombre del usuario a deshabilitar: " usuario_deshabilitar
            # Lógica para deshabilitar un usuario
            sed -i "/$usuario_deshabilitar/d" "$usuarios_file"
            echo "Usuario $usuario_deshabilitar deshabilitado"
            ;;
        3)
            read -p "Ingrese el nombre del usuario a modificar: " usuario_modificar
            # Lógica para modificar un usuario
            # Puedes implementar la lógica según tus necesidades
            echo "Función de modificación aún no implementada"
            ;;
        0)
            ;;
        *)
            echo "Opción no válida"
            ;;
    esac
}

# Función para gestionar departamentos
gestionar_departamentos() {
    clear
    echo "1. Crear departamento"
    echo "2. Deshabilitar departamento"
    echo "3. Modificar departamento"
    echo "0. Volver al menú principal"

    read -p "Seleccione una opción: " opcion_departamento

    case $opcion_departamento in
        1)
            read -p "Ingrese el nombre del departamento: " nuevo_departamento
            # Lógica para crear un departamento
            echo "$nuevo_departamento" >> "$departamentos_file"
            echo "Departamento $nuevo_departamento creado"
            ;;
        2)
            read -p "Ingrese el nombre del departamento a deshabilitar: " departamento_deshabilitar
            # Lógica para deshabilitar un departamento
            sed -i "/$departamento_deshabilitar/d" "$departamentos_file"
            echo "Departamento $departamento_deshabilitar deshabilitado"
            ;;
        3)
            read -p "Ingrese el nombre del departamento a modificar: " departamento_modificar
            # Lógica para modificar un departamento
            # Puedes implementar la lógica según tus necesidades
            echo "Función de modificación aún no implementada"
            ;;
        0)
            ;;
        *)
            echo "Opción no válida"
            ;;
    esac
}

# Función para gestionar asignaciones de usuarios a departamentos
gestionar_asignaciones() {
    clear
    echo "1. Asignar usuario a departamento"
    echo "2. Desasignar usuario de departamento"
    echo "0. Volver al menú principal"

    read -p "Seleccione una opción: " opcion_asignacion

    case $opcion_asignacion in
        1)
            read -p "Ingrese el nombre del usuario: " usuario_asignar
            read -p "Ingrese el nombre del departamento: " departamento_asignar
            # Lógica para asignar un usuario a un departamento
            echo "$usuario_asignar,$departamento_asignar" >> "$asignaciones_file"
            echo "Usuario $usuario_asignar asignado al departamento $departamento_asignar"
            ;;
        2)
            read -p "Ingrese el nombre del usuario a desasignar: " usuario_desasignar
            read -p "Ingrese el nombre del departamento: " departamento_desasignar
            # Lógica para desasignar un usuario de un departamento
            sed -i "/$usuario_desasignar,$departamento_desasignar/d" "$asignaciones_file"
            echo "Usuario $usuario_desasignar desasignado del departamento $departamento_desasignar"
            ;;
        0)
            ;;
        *)
            echo "Opción no válida"
            ;;
    esac
}

# Función para gestionar logs
gestionar_logs() {
    clear
    echo "1. Búsqueda específica en logs"
    echo "0. Volver al menú principal"

    read -p "Seleccione una opción: " opcion_logs

    case $opcion_logs in
        1)
            read -p "Ingrese el término de búsqueda: " termino_busqueda
            # Lógica para buscar en los logs
            grep "$termino_busqueda" "$logs_file"
            ;;
        0)
            ;;
        *)
            echo "Opción no válida"
            ;;
    esac
}

# Función para gestionar actividades en el sistema
gestionar_actividades() {
    clear
    echo "1. Rastrear actividades de usuarios en memoria"
    echo "2. Rastrear actividades de usuarios en procesos"
    echo "3. Rastrear actividades de usuarios en archivos"
    echo "0. Volver al menú principal"

    read -p "Seleccione una opción: " opcion_actividades

    case $opcion_actividades in
        1)
            # Lógica para rastrear actividades en memoria
            echo "Función no implementada"
            ;;
        2)
            # Lógica para rastrear actividades en procesos
            echo "Función no implementada"
            ;;
        3)
            # Lógica para rastrear actividades en archivos
            echo "Función no implementada"
            ;;
        0)
            ;;
        *)
            echo "Opción no válida"
            ;;
    esac
}

# Función para gestionar el sistema
gestionar_sistema() {
    clear
    echo "1. Monitorizar estado del sistema"
    echo "2. Crear reporte de alerta"
    echo "0. Volver al menú principal"

    read -p "Seleccione una opción: " opcion_sistema

    case $opcion_sistema in
        1)
            # Lógica para monitorizar estado del sistema
            echo "Función no implementada"
            ;;
        2)
            # Lógica para crear reporte de alerta
            echo "Función no implementada"
            ;;
        0)
            ;;
        *)
            echo "Opción no válida"
            ;;
    esac
}
# Verificar si el usuario es root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse con privilegios de root."
    exit 1
fi

# El resto del script aquí

echo "El script se está ejecutando con privilegios de root."

# Función principal
while true; do
    mostrar_menu_principal

    read -p "Seleccione una opción: " opcion_principal

    case $opcion_principal in
        1)
            gestionar_usuarios
            ;;
        2)
            gestionar_departamentos
            ;;
        3)
            gestionar_asignaciones
            ;;
        4)
            gestionar_logs
            ;;
        5)
            gestionar_actividades
            ;;
        6)
            gestionar_sistema
            ;;
        0)
            echo "Saliendo del script. ¡Hasta luego!"
            exit 0
            ;;
        *)
            echo "Opción no válida"
            ;;
    esac
done
