#!/bin/bash

echo "Информация о CPU"

num_sockets=$(lscpu | grep '^Socket(s):' | awk '{print $2}')

cores_per_socket=$(lscpu | grep '^Core(s) per socket:' | awk '{print $4}')

total_cores=$((num_sockets * cores_per_socket))

threads_per_core=$(lscpu | grep '^Thread(s) per core:' | awk '{print $4}')

total_threads=$((total_cores * threads_per_core))

current_load=$(top -bn1 | grep "Cpu(s)" |
             sed "s/.*, *([0-9.]*)%* id.*/1/" |
             awk '{print 100 - $1"%"}')

# Получение среднего значения нагрузки за 1, 5 и 15 минут
load_avg=$(uptime | awk -F'load average:' '{ print $2 }' |
           cut -d, -f1-3 | tr -d ' ')

# Вывод результатов
echo "количество cpu: $num_sockets"
echo "количество ядер: $total_cores"
echo "количество потоков: $total_threads"
echo "рабочая нагрузка: $current_load"
echo "средняя нагрузка (1, 5, 15 минут): $load_avg"

L1dCache=$(lscpu | awk '/^L1d cache:/ {print $3}')
L1iCache=$(lscpu | awk '/^L1i cache:/ {print $3}')
L2Cache=$(lscpu | awk '/^L2 cache:/ {print $3}')
L3Cache=$(lscpu | awk '/^L3 cache:/ {print $3}')

echo "Размеры кэшей:"
echo "  L1d cache: $L1dCache"
echo "  L1i cache: $L1iCache"
echo "  L2 cache: $L2Cache"
echo "  L3 cache: $L3Cache"

echo "Информация о физической памяти:"

# Парсинг информации о модулях памяти
sudo dmidecode -t memory | awk -v RS='nn' '
BEGIN {count=0}
/Memory Device/ {
  if ($0 ~ /Size: No Module Installed/) next
  else {
    count++
    slot = ""; size = ""; type = ""; speed = ""; manufacturer=""; part_number=""
    n = split($0, lines, "n")
    for (i=1; i<=n; i++) {
      line = lines[i]
      if (line ~ /Locator:/) {
        split(line, arr, ":")
        slot = arr[2]; gsub(/^[ t]+/, "", slot)
      }
      if (line ~ /Size:/) {
        split(line, arr, ":")
        size = arr[2]; gsub(/^[ t]+/, "", size)
      }
      if (line ~ /Type:/ && line !~ /Type Detail:/) {
        split(line, arr, ":")
        type = arr[2]; gsub(/^[ t]+/, "", type)
      }
      if (line ~ /Speed:/ && line !~ /Configured Memory Speed/) {
        split(line, arr, ":")
        speed = arr[2]; gsub(/^[ t]+/, "", speed)
      }
      if (line ~ /Part Number:/) {
        split(line, arr, ":")
        part_number = arr[2]; gsub(/^[ t]+/, "", part_number)
      }
    }
    print "Слот: " slot ", Размер: " size ", Тип: " type ", Скорость: " speed ", Номер детали: " part_number
  }
}
END {print "nОбщее количество модулей памяти: " count}
'
