#!/bin/bash
# v 1.2.5

check_bc_installed() {
    if ! command -v bc &> /dev/null; then
        echo "Команда bc не установлена, пытаемся установить..."
        if [ -f /etc/debian_version ]; then
            sudo apt update && sudo apt install -y bc
        else
            echo "Операционная система не поддерживается, пожалуйста, установите bc вручную и повторите."
            exit 1
        fi
        if ! command -v bc &> /dev/null; then
            echo "Не удалось установить bc, проверьте соединение с сетью или конфигурацию пакетного менеджера."
            exit 1
        fi
        echo "bc успешно установлена."
    else
        echo "bc уже установлена, продолжаем выполнение скрипта."
    fi
}

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

remove_motd() {
    echo "Выполняется удаление..."
    sudo sed -i '/^if \[ -n "\$SSH_CONNECTION" \]; then/,/^fi$/ { /^if \[ -z "\$MOTD_SHOWN" \]; then/,/^fi$/d; /^fi$/d; }' /etc/profile
    sudo sed -i '/^if \[ -n "\$SSH_CONNECTION" \] && \[ -z "\$MOTD_SHOWN" \]; then/,/^fi$/d' /etc/profile
    sudo sed -i '/^if \[ -n "\$SSH_CONNECTION" \]; then/,/^fi$/d' /etc/profile
    for file in "00-debian-heads" "20-debian-sysinfo" "20-debian-sysinfo2" "20-debian-sysinfo3" "20-armbian-sysinfo2" "20-armbian-sysinfo3"; do
        [ -f "/etc/update-motd.d/$file" ] && sudo rm -f "/etc/update-motd.d/$file" 2>/dev/null
    done
    echo "Удаление завершено"
}

handle_installation() {
    local os_type=$1
    local system_version=$2
    local tool_choice=$3

    if [ "$os_type" == "debian" ]; then
        case $system_version in
            1)
                file_url_1="https://ghfast.top/https://raw.githubusercontent.com/qljsyph/DPInfo-script/refs/heads/main/sysinfo/00-debian-heads"
                file_url_2="https://ghfast.top/https://raw.githubusercontent.com/qljsyph/DPInfo-script/refs/heads/main/sysinfo/20-debian-sysinfo"
                ;;
            2)
                file_url_1="https://ghfast.top/https://raw.githubusercontent.com/qljsyph/DPInfo-script/refs/heads/main/sysinfo/00-debian-heads"
                file_url_2="https://ghfast.top/https://raw.githubusercontent.com/qljsyph/DPInfo-script/refs/heads/main/sysinfo/20-debian-sysinfo2"
                ;;
            3)
                file_url_1="https://ghfast.top/https://raw.githubusercontent.com/qljsyph/DPInfo-script/refs/heads/main/sysinfo/00-debian-heads"
                file_url_2="https://ghfast.top/https://raw.githubusercontent.com/qljsyph/DPInfo-script/refs/heads/main/sysinfo/20-debian-sysinfo3"
                ;;
            *)
                echo "Неверный выбор версии, пожалуйста, введите 1, 2 или 3"
                exit 1
                ;;
        esac

        local file_name_1="00-debian-heads"
        case $system_version in
            1) local file_name_2="20-debian-sysinfo" ;;
            2) local file_name_2="20-debian-sysinfo2" ;;
            3) local file_name_2="20-debian-sysinfo3" ;;
        esac

        for file_name in "$file_name_1" "$file_name_2"; do
            file_dest="/etc/update-motd.d/$file_name"
            if [ -f "$file_dest" ]; then
                if [ "$file_name" == "$file_name_1" ]; then
                    echo "Файл 1 уже существует, удаляем старый файл..."
                else
                    echo "Файл 2 уже существует, удаляем старый файл..."
                fi
                sudo rm -f "$file_dest"
            fi
        done

        echo "Скачиваем файл 1..."
        sudo curl -s -o "/etc/update-motd.d/$file_name_1" "$file_url_1"
        download_status_1=$?
        echo "Скачиваем файл 2..."
        sudo curl -s -o "/etc/update-motd.d/$file_name_2" "$file_url_2"
        download_status_2=$?

        if [ $download_status_1 -eq 0 ] && [ $download_status_2 -eq 0 ]; then
            sudo chmod 755 "/etc/update-motd.d/$file_name_1" "/etc/update-motd.d/$file_name_2"
            echo "Файлы Debian успешно загружены и даны права 755."
        else
            echo "Не удалось скачать файлы! Код ошибки: $download_status_2"
            exit 1
        fi
    elif [ "$os_type" == "armbian" ]; then
        echo "Выберите версию:"
        echo "1. mihomo"
        echo "2. sing box"
        read -r -p "Введите выбор (1 или 2): " armbian_choice
        if [[ ! "$armbian_choice" =~ ^[12]$ ]]; then
            echo "Неверный выбор, введите 1 или 2"
            exit 1
        fi
        if [ "$armbian_choice" == "1" ]; then
            file_url="https://ghfast.top/https://raw.githubusercontent.com/qljsyph/DPInfo-script/refs/heads/main/sysinfo/20-armbian-sysinfo3"
            file_name="20-armbian-sysinfo3"
        else
            file_url="https://ghfast.top/https://raw.githubusercontent.com/qljsyph/DPInfo-script/refs/heads/main/sysinfo/20-armbian-sysinfo2"
            file_name="20-armbian-sysinfo2"
        fi
        file_dest="/etc/update-motd.d/$file_name"
        if [ -f "$file_dest" ]; then
            echo "Файл уже существует, удаляем старый..."
            sudo rm -f "$file_dest"
        fi
        echo "Скачиваем файл с GitHub..."
        sudo curl -s -o "$file_dest" "$file_url"
        download_status=$?
        if [ $download_status -eq 0 ]; then
            sudo chmod 755 "$file_dest"
            echo "Файл Armbian успешно загружен и даны права 755."
        else
            echo "Скачивание не удалось! Код ошибки: $download_status"
            exit 1
        fi
    fi

    # Проверка bc
    local check_file
    if [ "$os_type" == "debian" ]; then
        check_file="/etc/update-motd.d/$file_name_2"
    else
        check_file="$file_dest"
    fi
    if grep -q "bc" "$check_file"; then
        echo "Обнаружено использование bc в скрипте, проверяем его наличие..."
        check_bc_installed
    fi

    # Обработка /etc/profile
    local check_code=""
    if [ "$os_type" == "debian" ] && [ "$system_version" == "1" ]; then
        if [ "$tool_choice" == "1" ]; then
            check_code="if [ -n \"\$SSH_CONNECTION\" ] && [ -z \"\$MOTD_SHOWN\" ]; then
    export MOTD_SHOWN=1
    run-parts /etc/update-motd.d
fi"
            echo "Очищаем MOTD..."
            sudo truncate -s 0 /etc/motd
            echo "MOTD очищен."
        else
            check_code="if [ -n \"\$SSH_CONNECTION\" ]; then
    run-parts /etc/update-motd.d
fi"
        fi
    else
        if [ "$tool_choice" == "1" ]; then
            check_code="if [ -n \"\$SSH_CONNECTION\" ]; then
    if [ -z \"\$MOTD_SHOWN\" ]; then
        export MOTD_SHOWN=1
        run-parts /etc/update-motd.d
    fi
fi"
            echo "Очищаем MOTD..."
            sudo truncate -s 0 /etc/motd
            echo "MOTD очищен."
        else
            check_code="if [ -n \"\$SSH_CONNECTION\" ]; then
    run-parts /etc/update-motd.d
fi"
        fi
    fi

    if ! check_code_exists "$check_code"; then
        echo "Код не найден в /etc/profile, добавляем..."
        existing_count=$(grep -c "run-parts /etc/update-motd.d" /etc/profile)
        if [ "$existing_count" -gt 0 ]; then
            echo "ВНИМАНИЕ: уже существует похожий код ($existing_count мест)"
            echo "Пожалуйста, проверьте /etc/profile вручную и удалите конфликтующие блоки перед повторным запуском."
            exit 1
        fi
        sudo sed -i -e '$a\\' /etc/profile
        echo "$check_code" | sudo tee -a /etc/profile > /dev/null
        echo "Код успешно добавлен."
    else
        echo "Код уже присутствует, пропускаем добавление."
    fi
}

main() {
    echo "Выберите операцию:"
    echo "1. Установить"
    echo "2. Удалить"
    read -r -p "Введите ваш выбор (1 или 2): " operation_choice
    case $operation_choice in
        1)
            echo "Начинаем установку..."
            check_bc_installed

            read -r -p "Выберите тип ОС (введите debian/armbian или Enter для выхода): " os_type
            os_type=${os_type,,}
            if [[ ! "$os_type" =~ ^(debian|armbian)$ ]]; then
                echo "Недопустимый тип ОС, выходим."
                exit 1
            fi

            local system_version="2"
            if [ "$os_type" == "debian" ]; then
                read -r -p "Выберите тип информации (1: sing-box, 2: базовая, 3: mihomo): " system_version
                if [[ ! "$system_version" =~ ^[123]$ ]]; then
                    echo "Недопустимый выбор, введите 1, 2 или 3"
                    exit 1
                fi
            fi

            echo "Выберите тип используемого клиента (подробнее в wiki):"
            echo "1. FinalShell/MobaXterm"
            echo "2. Другие (например, ServerBox)"
            read -r -p "Введите ваш выбор (1 или 2): " tool_choice
            if [[ ! "$tool_choice" =~ ^[12]$ ]]; then
                echo "Неверный выбор, введите 1 или 2"
                exit 1
            fi

            handle_installation "$os_type" "$system_version" "$tool_choice"
            ;;
        2)
            remove_motd
            ;;
        *)
            echo "Недопустимый выбор, введите 1 или 2"
            exit 1
            ;;
    esac
}

main
