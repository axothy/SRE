#!/bin/bash

NETWORK_INTERFACE="eth0"           # Интерфейс для мониторинга
INCOMING_BANDWIDTH_THRESHOLD=80    # Входящая пропускная способность (% от максимальной)
OUTGOING_BANDWIDTH_THRESHOLD=80    # Исходящая пропускная способность (% от максимальной)
ERROR_RATE_THRESHOLD=1             # Процент ошибок пакетов (%)
DROPPED_RATE_THRESHOLD=1           # Процент сброшенных пакетов (%)
ESTABLISHED_CONNECTIONS_THRESHOLD=1000  # Количество установленных соединений
PING_LATENCY_THRESHOLD=100         # Задержка пинга (мс)
DNS_RESOLUTION_THRESHOLD=100       # Время разрешения DNS (мс)
COLLISIONS_THRESHOLD=10            # Количество коллизий на интерфейсе

INTERVAL=1

get_interface_speed() {
    ethtool $NETWORK_INTERFACE 2>/dev/null | grep "Speed:" | awk '{print $2}' | sed 's/Mb\/s//'
}

INTERFACE_SPEED=$(get_interface_speed)

if [ -z "$INTERFACE_SPEED" ]; then
    echo "Не удалось определить скорость интерфейса $NETWORK_INTERFACE"
    exit 1
fi

get_network_stats() {
    local interface=$1
    awk -v iface="$interface" '$0 ~ iface":" {print $2 " " $10 " " $3 " " $11}' /proc/net/dev
}

read RX_BYTES1 TX_BYTES1 RX_ERRORS1 TX_ERRORS1 <<< $(get_network_stats $NETWORK_INTERFACE)

sleep $INTERVAL

read RX_BYTES2 TX_BYTES2 RX_ERRORS2 TX_ERRORS2 <<< $(get_network_stats $NETWORK_INTERFACE)

RX_BYTES_PER_SEC=$(( ($RX_BYTES2 - $RX_BYTES1) / $INTERVAL ))
TX_BYTES_PER_SEC=$(( ($TX_BYTES2 - $TX_BYTES1) / $INTERVAL ))

read RX_PACKETS1 TX_PACKETS1 RX_DROPPED1 TX_DROPPED1 <<< $(awk -v iface="$NETWORK_INTERFACE" '$0 ~ iface":" {print $3 " " $11 " " $4 " " $12}' /proc/net/dev)
sleep $INTERVAL
read RX_PACKETS2 TX_PACKETS2 RX_DROPPED2 TX_DROPPED2 <<< $(awk -v iface="$NETWORK_INTERFACE" '$0 ~ iface":" {print $3 " " $11 " " $4 " " $12}' /proc/net/dev)

RX_ERROR_PACKETS=$(( $RX_ERRORS2 - $RX_ERRORS1 ))
TX_ERROR_PACKETS=$(( $TX_ERRORS2 - $TX_ERRORS1 ))
RX_DROPPED_PACKETS=$(( $RX_DROPPED2 - $RX_DROPPED1 ))
TX_DROPPED_PACKETS=$(( $TX_DROPPED2 - $TX_DROPPED1 ))

RX_TOTAL_PACKETS=$(( $RX_PACKETS2 - $RX_PACKETS1 ))
TX_TOTAL_PACKETS=$(( $TX_PACKETS2 - $TX_PACKETS1 ))

RX_ERROR_RATE=0
TX_ERROR_RATE=0
RX_DROPPED_RATE=0
TX_DROPPED_RATE=0

if [ $RX_TOTAL_PACKETS -gt 0 ]; then
    RX_ERROR_RATE=$(echo "scale=2; $RX_ERROR_PACKETS / $RX_TOTAL_PACKETS * 100" | bc)
    RX_DROPPED_RATE=$(echo "scale=2; $RX_DROPPED_PACKETS / $RX_TOTAL_PACKETS * 100" | bc)
fi

if [ $TX_TOTAL_PACKETS -gt 0 ]; then
    TX_ERROR_RATE=$(echo "scale=2; $TX_ERROR_PACKETS / $TX_TOTAL_PACKETS * 100" | bc)
    TX_DROPPED_RATE=$(echo "scale=2; $TX_DROPPED_PACKETS / $TX_TOTAL_PACKETS * 100" | bc)
fi

RX_MBPS=$(echo "scale=2; ($RX_BYTES_PER_SEC * 8) / (1024 * 1024)" | bc)
TX_MBPS=$(echo "scale=2; ($TX_BYTES_PER_SEC * 8) / (1024 * 1024)" | bc)

RX_BANDWIDTH_USAGE=$(echo "scale=2; ($RX_MBPS / $INTERFACE_SPEED) * 100" | bc)
TX_BANDWIDTH_USAGE=$(echo "scale=2; ($TX_MBPS / $INTERFACE_SPEED) * 100" | bc)

ESTABLISHED_CONNECTIONS=$(netstat -ant | grep ESTABLISHED | wc -l)

PING_HOST="8.8.8.8"
PING_LATENCY=$(ping -c 4 $PING_HOST | tail -1 | awk '{print $4}' | cut -d '/' -f 2)

DNS_SERVER="8.8.8.8"
DNS_TEST_DOMAIN="google.com"
DNS_RESOLUTION_TIME=$(dig @$DNS_SERVER $DNS_TEST_DOMAIN +noall +stats | grep 'Query time:' | awk '{print $4}')

declare -A CONNECTION_STATES

while read state count; do
    CONNECTION_STATES[$state]=$count
done < <(netstat -nat | awk '$4 ~ /:[0-9]+$/ {states[$6]++} END {for (s in states) print s, states[s]}')

INTERFACE_STATUS=$(ip link show $NETWORK_INTERFACE | grep 'state' | awk '{print $9}')

COLLISIONS=$(cat /sys/class/net/$NETWORK_INTERFACE/statistics/collisions)

PROMISCUOUS_MODE=$(ip link show $NETWORK_INTERFACE | grep -o 'PROMISC')

echo "----- Статистика сети для интерфейса $NETWORK_INTERFACE -----"
echo "Состояние интерфейса: $INTERFACE_STATUS"
if [ "$INTERFACE_STATUS" != "UP" ]; then
    echo "WARN: интерфейс $NETWORK_INTERFACE неактивен"
fi

echo "Входящая скорость: $RX_MBPS Мбит/с"
echo "Исходящая скорость: $TX_MBPS Мбит/с"
echo "Использование входящей пропускной способности: $RX_BANDWIDTH_USAGE%"
echo "Использование исходящей пропускной способности: $TX_BANDWIDTH_USAGE%"

if (( $(echo "$RX_BANDWIDTH_USAGE > $INCOMING_BANDWIDTH_THRESHOLD" | bc -l) )); then
    echo "WARN: входящая пропускная способность превышает пороговое значение (${INCOMING_BANDWIDTH_THRESHOLD}%)"
fi

if (( $(echo "$TX_BANDWIDTH_USAGE > $OUTGOING_BANDWIDTH_THRESHOLD" | bc -l) )); then
    echo "WARN: исходящая пропускная способность превышает пороговое значение (${OUTGOING_BANDWIDTH_THRESHOLD}%)"
fi

echo "Процент ошибок входящих пакетов: $RX_ERROR_RATE%"
if (( $(echo "$RX_ERROR_RATE > $ERROR_RATE_THRESHOLD" | bc -l) )); then
    echo "WARN: процент ошибок входящих пакетов превышает пороговое значение (${ERROR_RATE_THRESHOLD}%)"
fi

echo "Процент ошибок исходящих пакетов: $TX_ERROR_RATE%"
if (( $(echo "$TX_ERROR_RATE > $ERROR_RATE_THRESHOLD" | bc -l) )); then
    echo "WARN: процент ошибок исходящих пакетов превышает пороговое значение (${ERROR_RATE_THRESHOLD}%)"
fi

echo "Процент сброшенных входящих пакетов: $RX_DROPPED_RATE%"
if (( $(echo "$RX_DROPPED_RATE > $DROPPED_RATE_THRESHOLD" | bc -l) )); then
    echo "WARN: процент сброшенных входящих пакетов превышает пороговое значение (${DROPPED_RATE_THRESHOLD}%)"
fi

echo "Процент сброшенных исходящих пакетов: $TX_DROPPED_RATE%"
if (( $(echo "$TX_DROPPED_RATE > $DROPPED_RATE_THRESHOLD" | bc -l) )); then
    echo "WARN: процент сброшенных исходящих пакетов превышает пороговое значение (${DROPPED_RATE_THRESHOLD}%)"
fi

echo "Количество установленных соединений: $ESTABLISHED_CONNECTIONS"
if [ $ESTABLISHED_CONNECTIONS -gt $ESTABLISHED_CONNECTIONS_THRESHOLD ]; then
    echo "WARN: количество установлкеных соединений превышает пороговое значение ($ESTABLISHED_CONNECTIONS_THRESHOLD)"
fi

echo "Средняя задержка пинга до $PING_HOST: $PING_LATENCY мс"
if (( $(echo "$PING_LATENCY > $PING_LATENCY_THRESHOLD" | bc -l) )); then
    echo "WARN: задержка пинга превышает пороговое значение (${PING_LATENCY_THRESHOLD} мс)"
fi

echo "Время разрешения DNS для $DNS_TEST_DOMAIN: $DNS_RESOLUTION_TIME мс"
if [ -n "$DNS_RESOLUTION_TIME" ] && (( $DNS_RESOLUTION_TIME > $DNS_RESOLUTION_THRESHOLD )); then
    echo "WARN: время разрешения DNS превышает пороговое значение (${DNS_RESOLUTION_THRESHOLD} мс)"
fi

echo "Количество коллизий на интерфейсе: $COLLISIONS"
if [ $COLLISIONS -gt $COLLISIONS_THRESHOLD ]; then
    echo "WARN: количество коллизий превышает пороговое значение ($COLLISIONS_THRESHOLD)"
fi

echo "----- Состояние соединений -----"
for state in "${!CONNECTION_STATES[@]}"; do
    echo "$state: ${CONNECTION_STATES[$state]}"
done


