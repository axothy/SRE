#!/bin/bash

#threshold values
TOTAL_CPU_USAGE_THRESHOLD=80
USER_CPU_USAGE_THRESHOLD=50
SYSTEM_CPU_USAGE_THRESHOLD=30
LOAD_AVG_THRESHOLD=1.0
CPU_TEMP_THRESHOLD=75

get_cpu_usage() {
    CPU=($(sed -n 's/^cpu\s//p' /proc/stat))
    IDLE_1=${CPU[3]}

    TOTAL_1=0
    for VALUE in "${CPU[@]:0:8}"; do
        TOTAL_1=$((TOTAL_1 + VALUE))
    done

    sleep 1

    CPU=($(sed -n 's/^cpu\s//p' /proc/stat))
    IDLE_2=${CPU[3]}

    TOTAL_2=0
    for VALUE in "${CPU[@]:0:8}"; do
        TOTAL_2=$((TOTAL_2 + VALUE))
    done

    IDLE_DELTA=$((IDLE_2 - IDLE_1))
    TOTAL_DELTA=$((TOTAL_2 - TOTAL_1))
    CPU_USAGE=$(( (1000 * (TOTAL_DELTA - IDLE_DELTA) / TOTAL_DELTA + 5) / 10 ))

    echo "$CPU_USAGE"
}

get_cpu_detail_usage() {
    #mpstat
    if command -v mpstat > /dev/null 2>&1; then
        mpstat 1 1 | awk '/Average/ && $12 ~ /[0-9.]+/ { printf "%.0f %.0f %.0f\n", 100 - $12, $4, $6 }'
    else
        #or top
        top -bn2 | grep "Cpu(s)" | tail -n 1 | awk '{ print $2 + $4, $2, $4 }' | tr -d '%usyrsni'
    fi
}

get_load_average() {
    read LOAD1 LOAD5 LOAD15 REST < /proc/loadavg
    echo "$LOAD1 $LOAD5 $LOAD15"
}

get_cpu_cores() {
    nproc
}

get_cpu_temperature() {
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo "$(echo "scale=1; $TEMP / 1000" | bc)"
    else
        echo "N/A"
    fi
}

TOTAL_CPU_USAGE=$(get_cpu_usage)
read TOTAL_CPU_USAGE USER_CPU_USAGE SYSTEM_CPU_USAGE <<< $(get_cpu_detail_usage)
read LOAD1 LOAD5 LOAD15 <<< $(get_load_average)
CPU_CORES=$(get_cpu_cores)
CPU_TEMP=$(get_cpu_temperature)
PROCESS_COUNT=$(ps -e --no-headers | wc -l)

echo "Общая загрузка CPU: $TOTAL_CPU_USAGE%"

if (( $(echo "$TOTAL_CPU_USAGE > $TOTAL_CPU_USAGE_THRESHOLD" | bc -l) )); then
    echo "WARN: общая загрузка CPU превшает пороговое значение ($TOTAL_CPU_USAGE_THRESHOLD%)"
fi

echo "Загрузка CPU пользовательскими процессами: $USER_CPU_USAGE%"

if (( $(echo "$USER_CPU_USAGE > $USER_CPU_USAGE_THRESHOLD" | bc -l) )); then
    echo "WARN: загрузка CPU пользовательскими процессами превшает пороговое значение ($USER_CPU_USAGE_THRESHOLD%)"
fi

echo "Загрузка CPU системными процессами: $SYSTEM_CPU_USAGE%"

if (( $(echo "$SYSTEM_CPU_USAGE > $SYSTEM_CPU_USAGE_THRESHOLD" | bc -l) )); then
    echo "WARN: загрузка CPU системными процессами превшает пороговое значение ($SYSTEM_CPU_USAGE_THRESHOLD%)"
fi

LOAD_PER_CORE=$(echo "scale=2; $LOAD1 / $CPU_CORES" | bc)
echo "Средняя нагрузка за 1 мин: $LOAD1 (на ядро: $LOAD_PER_CORE)"

if (( $(echo "$LOAD_PER_CORE > $LOAD_AVG_THRESHOLD" | bc -l) )); then
    echo "WARN: средняя нагрузка на ядро превшает пороговое значение ($LOAD_AVG_THRESHOLD)"
fi

echo "Температура CPU: $CPU_TEMP°C"
