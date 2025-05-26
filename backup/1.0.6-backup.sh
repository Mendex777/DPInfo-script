#!/bin/bash

# Проверка установлен ли bc
check_bc_installed() {
    if ! command -v bc &> /dev/null; then
        echo "Команда bc не установлена, пытаемся установить..."

        # Проверяем ОС и выбираем команду установки
        if [ -f /etc/debian_version ]; then
            sudo apt update && sudo apt install -y bc
        else
            echo "Операционная система не поддерживается, установите bc вручную и попробуйте снова."
            exit 1
        fi

        # Снова проверяем, установился ли bc
        if ! command -v bc &> /dev/null; then
            echo "Установка bc не удалась, проверьте сеть или настройки менеджера пакетов."
            exit 1
        fi

        echo "bc успешно установлен."
    else
        echo "bc уже установлен, продолжаем выполнение скрипта."
    fi
}

# Точное проверка существования блока кода (игнорируя пробелы и переводы строк)
check_code_exists() {
    local normalized_file=$(grep -v '^\s*$' /etc/profile | tr -d '[:space:]')
    local normalized_code=$(echo "$1" | tr -d '[:space:]')

    if [[ "$normalized_file" == *"$normalized_code"* ]]; then
        return 0  # Полное совпадение найдено
    else
        return 1  # Совпадение не найдено
    fi
}

# Скачивание и установка скриптов MOTD
download_motd_script() {
    # Выбор типа ОС: Debian или Armbian
    read -p "Выберите тип операционной системы (введите debian/armbian/нажмите Enter для выхода): " os_type
    os_type=${os_type,,} # преобразуем в нижний регистр

    # Выбор файлов для загрузки в зависимости от ОС
    if [ "$os_type" == "debian" ]; then
        # Удаляем существующие файлы
        for file_name in "20-debian-sysinfo" "00-debian-heads"; do
            file_dest="/etc/update-motd.d/$file_name"
            if [ -f "$file_dest" ]; then
                echo "Файл $file_name уже существует, удаляем старый файл..."
                sudo rm -f "$file_dest"
            fi
        done
        
        # Скачиваем два файла
        file_url_1="https://ghgo.xyz/https://raw.githubusercontent.com/qljsyph/bash-script/refs/heads/main/sysinfo/20-debian-sysinfo"
        file_url_2="https://ghgo.xyz/https://raw.githubusercontent.com/qljsyph/bash-script/refs/heads/main/sysinfo/00-debian-heads"
        
        echo "Скачиваем файл 20-debian-sysinfo..."
        curl -s -o "/etc/update-motd.d/20-debian-sysinfo" "$file_url_1"
        
        echo "Скачиваем файл 00-debian-heads..."
        curl -s -o "/etc/update-motd.d/00-debian-heads" "$file_url_2"
        
        # Проверяем успешность скачивания
        if [ $? -eq 0 ]; then
            chmod 755 /etc/update-motd.d/{20-debian-sysinfo,00-debian-heads}
            echo "Файлы для Debian успешно скачаны и права установлены на 755."
        else
            echo "Ошибка при скачивании файлов! Код ошибки: $?"
            exit 1
        fi
    elif [ "$os_type" == "armbian" ]; then
        file_url="https://ghgo.xyz/https://raw.githubusercontent.com/qljsyph/bash-script/refs/heads/main/sysinfo/20-armbian-sysinfo2"
        file_name="20-armbian-sysinfo2"

        # Удаляем существующий файл и скачиваем новый
        file_dest="/etc/update-motd.d/$file_name"
        if [ -f "$file_dest" ]; then
            echo "Файл $file_name уже существует, удаляем старый файл..."
            sudo rm -f "$file_dest"
        fi
        
        echo "Скачиваем файл Armbian с GitHub..."
        curl -s -o "$file_dest" "$file_url"

        # Проверяем успешность скачивания
        if [ $? -eq 0 ]; then
            chmod 755 "$file_dest"
            echo "Файл Armbian успешно скачан и права установлены на 755."
        else
            echo "Ошибка при скачивании файла! Код ошибки: $?"
            exit 1
        fi
    else
        echo "Неверный тип операционной системы, выход из скрипта."
        exit 1
    fi

    # Проверяем, использует ли скачанный скрипт bc
    if grep -q "bc" "$file_dest"; then
        echo "Обнаружено использование bc в скрипте MOTD, проверяем, что он установлен..."
        check_bc_installed
    fi
}

# Проверка и добавление блока кода в /etc/profile
handle_profile_modification() {
    local tool_choice=$1
    local check_code=""
    
    if [ "$tool_choice" == "1" ]; then
        # Блок кода для FinalShell/MobaXterm
        check_code='if [ -n "$SSH_CONNECTION" ] && [ -z "$MOTD_SHOWN" ]; then
    export MOTD_SHOWN=1
    run-parts /etc/update-motd.d
fi'
        
        # Очистка файла /etc/motd
        echo "Очищаем файл /etc/motd..."
        sudo truncate -s 0 /etc/motd
        echo "Файл /etc/motd очищен."
    else
        # Оригинальный блок кода
        check_code='if [ -n "$SSH_CONNECTION" ]; then
 run-parts /etc/update-motd.d
fi'
    fi

    if ! check_code_exists "$check_code"; then
        echo "Полное совпадение блока кода не найдено, добавляем..."

        # Проверяем, есть ли похожие блоки
        existing_count=$(grep -c "run-parts /etc/update-motd.d" /etc/profile)

        if [ "$existing_count" -gt 0 ]; then
            echo "Внимание: найдено $existing_count похожих блока(ов)"
            echo "Пожалуйста, вручную проверьте блоки с update-motd.d в /etc/profile и при необходимости удалите их перед повторным запуском скрипта."
            exit 1
        fi

        # Добавляем перевод строки в конец файла
        sudo sed -i -e '$a\\' /etc/profile

        # Добавляем блок кода
        echo "$check_code" | sudo tee -a /etc/profile > /dev/null

        echo "Блок кода успешно добавлен."
    else
        echo "Полный блок кода уже существует, добавление пропущено."
    fi
}

# Основная логика скрипта
main() {
    # Проверяем установлен ли bc
    check_bc_installed

    # Выбираем тип инструмента
    echo "Выберите тип используемого инструмента:"
    echo "1. FinalShell/MobaXterm"
    echo "2. Другие инструменты (например, ServerBox)"
    read -p "Введите вариант (1 или 2): " tool_choice

    # Проверка ввода
    if [[ ! "$tool_choice" =~ ^[12]$ ]]; then
        echo "Неверный вариант, введите 1 или 2"
        exit 1
    fi

    # Обработка изменений в profile
    handle_profile_modification "$tool_choice"

    # Скачиваем скрипты MOTD
    download_motd_script
}

# Запуск основной функции
main

# Выход из скрипта
exit
