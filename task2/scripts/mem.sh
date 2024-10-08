#!/bin/bash

TOTAL_MEM_USAGE_THRESHOLD=80
SWAP_USAGE_THRESHOLD=20
FREE_MEM_THRESHOLD=1024
CACHE_BUFF_USAGE_THRESHOLD=50
PAGE_FAULTS_THRESHOLD=1000
SLAB_USAGE_THRESHOLD=1024
HUGEPAGES_FREE_THRESHOLD=10

INTERVAL=1

# free
get_memory_usage() {
    free -m | awk '/^Mem:/ { print $2" "$3" "$4" "$6" "$7 }'
}

# swap
get_swap_usage() {
    free -m | awk '/^Swap:/ { print $2" "$3" "$4 }'
}

# page faults
get_page_faults() {
    vmstat $INTERVAL 2 | tail -1 | awk '{ print $7" "$8 }'
}

# Slab
get_slab_usage() {
    awk '/^Slab:/ { print $2/1024 }' /proc/meminfo
}

#  HugePages
get_hugepages_info() {
    awk '/^HugePages_Total:/ { total=$2 }
         /^HugePages_Free:/  { free=$2 }
         END { print total" "free }' /proc/meminfo
}


read TOTAL_MEM USED_MEM FREE_MEM BUFF_CACHE AVAILABLE_MEM <<< $(get_memory_usage)
MEM_USAGE_PERCENT=$(echo "scale=2; $USED_MEM/$TOTAL_MEM*100" | bc)

read TOTAL_SWAP USED_SWAP FREE_SWAP <<< $(get_swap_usage)
if [ "$TOTAL_SWAP" -ne 0 ]; then
    SWAP_USAGE_PERCENT=$(echo "scale=2; $USED_SWAP/$TOTAL_SWAP*100" | bc)
else
    SWAP_USAGE_PERCENT=0
fi

CACHE_BUFF_USAGE_PERCENT=$(echo "scale=2; ($TOTAL_MEM - $FREE_MEM - $USED_MEM)/$TOTAL_MEM*100" | bc)

read MAJFLT MINFLT <<< $(get_page_faults)

SLAB_USAGE=$(get_slab_usage)

read HUGE_TOTAL HUGE_FREE <<< $(get_hugepages_info)

echo "Общая память: $TOTAL_MEM МБ"
echo "Используемая память: $USED_MEM МБ ($MEM_USAGE_PERCENT%)"

if (( $(echo "$MEM_USAGE_PERCENT > $TOTAL_MEM_USAGE_THRESHOLD" | bc -l) )); then
    echo "WARN: использование памяти превышает пороговое значение ($TOTAL_MEM_USAGE_THRESHOLD%)"
fi

echo "Свободная память: $FREE_MEM МБ"

if (( $(echo "$FREE_MEM < $FREE_MEM_THRESHOLD" | bc -l) )); then
    echo "WARN: свободная память ниже порогового значения ($FREE_MEM_THRESHOLD МБ)"
fi

echo "Память, используемая кэшем и буферами: $CACHE_BUFF_USAGE_PERCENT%"

if (( $(echo "$CACHE_BUFF_USAGE_PERCENT > $CACHE_BUFF_USAGE_THRESHOLD" | bc -l) )); then
    echo "WARN: использование памяти кэшем и буферами превышает пороговое значение ($CACHE_BUFF_USAGE_THRESHOLD%)"
fi

echo "Всего swap: $TOTAL_SWAP МБ"
echo "Используемый swap: $USED_SWAP МБ ($SWAP_USAGE_PERCENT%)"

if (( $(echo "$SWAP_USAGE_PERCENT > $SWAP_USAGE_THRESHOLD" | bc -l) )); then
    echo "WARN: использование swap превшает пороговое значение ($SWAP_USAGE_THRESHOLD%)"
fi

echo "Мажорные page faults: $MAJFLT"
echo "Минорные page faults: $MINFLT"

if (( $(echo "$MAJFLT + $MINFLT > $PAGE_FAULTS_THRESHOLD" | bc -l) )); then
    echo "WARN: колтество page faults за интервал превышает пороговое значение ($PAGE_FAULTS_THRESHOLD)"
fi

echo "Использование Slab Cache: ${SLAB_USAGE} МБ"

if (( $(echo "$SLAB_USAGE > $SLAB_USAGE_THRESHOLD" | bc -l) )); then
    echo "WARN: использование Slab Cache превышает пороговое значение ($SLAB_USAGE_THRESHOLD МБ)"
fi

echo "Всего HugePages: $HUGE_TOTAL"
echo "Свободных HugePages: $HUGE_FREE"

if (( $(echo "$HUGE_FREE < $HUGEPAGES_FREE_THRESHOLD" | bc -l) )); then
    echo "WARN: количество свободных HugePages ниже порогового значения ($HUGEPAGES_FREE_THRESHOLD)"
fi