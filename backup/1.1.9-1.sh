#!/bin/bash
# версия 1.1.9

# Проверка установки команды bc
check_bc_installed() {
    if ! command -v bc &> /dev/null; then
        echo "Команда bc не установлена, пытаемся установить..."
        if [ -f /etc/debian_version ]; then
            sudo apt update && sudo apt install -y bc
        else
            echo "Операционная система не поддерживается, установите bc вручную и повторите."
            exit 1
        fi
        if ! command -v bc &> /dev/null; then
            echo "Установка bc не удалась, проверьте сеть или настройки пакетного менеджера."
            exit 1
        fi
        echo "bc успешно установлен."
    else
        echo "bc уже установлен, продолжаем выполнение скрипта."
    fi
}

# Проверка, существует ли в /etc/profile данный блок кода (игнорируя пробелы и пустые строки)
check_code_exists() {
    local normalized_file
    normalized_file=$(grep -v '^\s*$' /etc/profile | tr -d '[:space:]')
    local normalized_code
    normalized_code=$(echo "$1" | tr -d '[:space:]')
    if [[ "$normalized_file" == *"$normalized_code"* ]]; then
        return 0
    else
        return 1
    fi
}

# Удаление MOTD
remove_motd() {
    echo "Выполняется удаление..."

    # Удаляем определённые блоки из /etc/profile
    sudo sed -i '/^if \[ -n "\$SSH_CONNECTION" \] && \[ -z "\$MOTD_SHOWN" \]; then/,/^fi$/d' /etc/profile
    sudo sed -i '/^if \[ -n "\$SSH_CONNECTION" \]; then/,/^fi$/d' /etc/profile

    # Удаляем файлы из /etc/update-motd.d
    for file in "00-debian-heads" "20-debian-sysinfo" "20-armbian-sysinfo2"; do
        [ -f "/etc/update-motd.d/$file" ] && sudo rm -f "/etc/update-motd.d/$file" 2>/dev/null
    done

    echo "Удаление завершено"
}

# Загрузка скриптов MOTD
download_motd_script() {
    read -r -p "Выберите тип операционной системы (debian/armbian/Enter для выхода): " os_type
    os_type=${os_type,,}  # преобразование в нижний регистр

    if [ "$os_type" == "debian" ]; then
        for file_name in "00-debian-heads" "20-debian-sysinfo"; do
            file_dest="/etc/update-motd.d/$file_name"
            if [ -f "$file_dest" ]; then
                if [ "$file_name" == "00-debian-heads" ]; then
                    echo "Файл 1 уже существует, удаляем старый..."
                else
                    echo "Файл 2 уже существует, удаляем старый..."
                fi
                sudo rm -f "$file_dest"
            fi
        done

        file_url_1="https://ghproxy.cc/https://raw.githubusercontent.com/qljsyph/bash-script/refs/heads/main/sysinfo/00-debian-heads"
        file_url_2="https://ghproxy.cc/https://raw.githubusercontent.com/qljsyph/bash-script/refs/heads/main/sysinfo/20-debian-sysinfo"

        echo "Скачиваем файл 1..."
        curl -s -o "/etc/update-motd.d/00-debian-heads" "$file_url_1"
        download_status_1=$?

        echo "Скачиваем файл 2..."
        curl -s -o "/etc/update-motd.d/20-debian-sysinfo" "$file_url_2"
        download_status_2=$?

        if [ $download_status_1 -eq 0 ] && [ $download_status_2 -eq 0 ]; then
            chmod 755 /etc/update-motd.d/{00-debian-heads,20-debian-sysinfo}
            echo "Файлы для Debian успешно загружены и права установлены на 755."
        else
            echo "Ошибка загрузки файлов! Код ошибки: $download_status_2"
            exit 1
        fi

    elif [ "$os_type" == "armbian" ]; then
        file_url="https://ghproxy.cc/https://raw.githubusercontent.com/qljsyph/bash-script/refs/heads/main/sysinfo/20-armbian-sysinfo2"
        file_name="20-armbian-sysinfo2"
        file_dest="/etc/update-motd.d/$file_name"

        if [ -f "$file_dest" ]; then
            echo "Файл уже существует, удаляем старый..."
            sudo rm -f "$file_dest"
        fi

        echo "Скачиваем файл с GitHub..."
        curl -s -o "$file_dest" "$file_url"
        download_status=$?

        if [ $download_status -eq 0 ]; then
            chmod 755 "$file_dest"
            echo "Файл для Armbian успешно загружен и права установлены на 755."
        else
            echo "Ошибка загрузки файла! Код ошибки: $download_status"
            exit 1
        fi

    else
        echo "Неверный тип ОС, скрипт завершает работу."
        exit 1
    fi

    # Проверяем, используется ли bc в скачанном скрипте
    if grep -q "bc" "$file_dest"; then
        echo "Обнаружено использование bc в скрипте, проверяем установку..."
        check_bc_installed
    fi
}

# Обработка изменений в /etc/profile
handle_profile_modification() {
    local tool_choice=$1
    local check_code=""

    if [ "$tool_choice" == "1" ]; then
        check_code="if [ -n \"\$SSH_CONNECTION\" ] && [ -z \"\$MOTD_SHOWN\" ]; then
    export MOTD_SHOWN=1
    run-parts /etc/update-motd.d
fi"
        echo "Очищаем файл /etc/motd..."
        sudo truncate -s 0 /etc/motd
        echo "Файл /etc/motd очищен."
    else
        check_code="if [ -n \"\$SSH_CONNECTION\" ]; then
    run-parts /etc/update-motd.d
fi"
    fi

    if ! check_code_exists "$check_code"; then
        echo "Полный блок кода не найден, добавляем..."

        existing_count=$(grep -c "run-parts /etc/update-motd.d" /etc/profile)
        if [ "$existing_count" -gt 0 ]; then
            echo "Внимание: похожий блок кода уже существует ($existing_count раз)"
            echo "Пожалуйста, вручную проверьте /etc/profile и удалите старый блок, затем запустите скрипт снова."
            exit 1
        fi

        sudo sed -i -e '$a\\' /etc/profile
        echo "$check_code" | sudo tee -a /etc/profile > /dev/null
        echo "Блок кода успешно добавлен."
    else
        echo "Полный блок кода уже существует, пропускаем добавление."
    fi
}

# Главная функция
main() {
    echo "Выберите операцию:"
    echo "1. Установка"
    echo "2. Удаление"
    read -r -p "Введите вариант (1 или 2): " operation_choice

    case $operation_choice in
        1)
            echo "Начинаем установку..."
            check_bc_installed
            download_motd_script
            echo "Выберите используемый инструмент (обязательно ознакомьтесь с wiki):"
            echo "1. FinalShell/MobaXterm"
            echo "2. Другие инструменты (ServerBox и др.)"
            read -r -p "Введите вариант (1 или 2): " tool_choice
            if [[ ! "$tool_choice" =~ ^[12]$ ]]; then
                echo "Неверный вариант, введите 1 или 2."
                exit 1
            fi
            handle_profile_modification "$tool_choice"
            ;;
        2)
            remove_motd
            ;;
        *)
            echo "Неверный вариант, введите 1 или 2."
            exit 1
            ;;
    esac
}

main
