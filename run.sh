#!/bin/bash

export LD_LIBRARY_PATH=./
MINER_CONF="./miner.conf"

parse_conf() {
    local file=$1
    local key=$2

    awk -v key="$key" '
    BEGIN {
        FS="="
    }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
        if ($1 == key) {
            print $2
        }
    }
    ' "$file"
}

algo=$(parse_conf "$MINER_CONF" "algo")
account=$(parse_conf "$MINER_CONF" "account")
worker=$(parse_conf "$MINER_CONF" "worker")
pool=$(parse_conf "$MINER_CONF" "pool")
solo=$(parse_conf "$MINER_CONF" "solo")
gpu=$(parse_conf "$MINER_CONF" "gpu")
parallel=$(parse_conf "$MINER_CONF" "parallel")
thread=$(parse_conf "$MINER_CONF" "thread")
cpu_off=$(parse_conf "$MINER_CONF" "cpu-off")
gpu_off=$(parse_conf "$MINER_CONF" "gpu-off")
mode=$(parse_conf "$MINER_CONF" "mode")
log=$(parse_conf "$MINER_CONF" "log")
rest=$(parse_conf "$MINER_CONF" "rest")
port=$(parse_conf "$MINER_CONF" "port")
third_miner=$(parse_conf "$MINER_CONF" "third_miner"|sed 's/.*"\(.*\)".*/\1/')
third_cmd=$(parse_conf "$MINER_CONF" "third_cmd"|sed 's/.*"\(.*\)".*/\1/')
pool_quai=$(parse_conf "$MINER_CONF" "pool-quai")
xmr_thread=$(parse_conf "$MINER_CONF" "xmr-thread"|sed 's/.*"\(.*\)".*/\1/')
xmr_gpu_off=$(parse_conf "$MINER_CONF" "xmr-gpu-off")
xmr_cpu_off=$(parse_conf "$MINER_CONF" "xmr-cpu-off")

params=()

[ -n "$algo" ] && params+=(--algo "$algo")
[ -n "$account" ] && params+=(--account "$account")
[ -n "$worker" ] && params+=(--worker "$worker")

if [ -n "$gpu" ]; then
    gpu_args=()
    IFS=',' read -ra gpu_ids <<< "$gpu"
    for id in "${gpu_ids[@]}"; do
        gpu_args+=("-g" "$id")
    done
    params+=("${gpu_args[@]}")
fi

[ -n "$parallel" ] && params+=(-p "$parallel")
[ -n "$thread" ] && params+=(-t "$thread")
[ -n "$log" ] && params+=(--log "$log")
[ -n "$port" ] && params+=(--port "$port")
[ -n "$mode" ] && params+=(--mode "$mode")
[ -n "$pool_quai" ] && params+=(--pool-slave "$pool_quai")
[ -n "$xmr_thread" ] && params+=(--thread-slave "$xmr_thread")
[ "$cpu_off" == "true" ] && params+=(--cpu-off)
[ "$gpu_off" == "true" ] && params+=(--gpu-off)
[ "$xmr_gpu_off" == "true" ] && params+=(--gpu-off-slave)
[ "$xmr_cpu_off" == "true" ] && params+=(--cpu-off-slave)

if [ -n "$pool" ]; then
    params+=(--pool "$pool")
elif [ -n "$solo" ]; then
    params+=(--solo "$solo")
fi

if [ -z "$third_cmd" ]; then
    nohup proxychains ./apoolminer "${params[@]}" > $algo.log 2>&1 &
    exit 0
fi

if [ -n "$(lsof -p $$ | grep run.log)" ]; then
    while true; do
        now_time=$(date +%s)
        url="http://qubic1.hk.apool.io:8001/api/qubic/mode"
        url_code=$(proxychains curl -s -o /dev/null -w '%{http_code}' "$url")
        if [ -e "$third_miner" ]; then
            if [ "$url_code" -eq 200 ]; then
                res_url=$(proxychains curl -s "$url")
                mining_seed=$(echo "$res_url" | sed -n 's/.*"mode":\([0-9]*\).*/\1/p')
                if [ -z "$mining_seed" ]; then
                    echo -e "$(date +"%Y-%m-%d %H:%M:%S")     \033[31mERROR\033[0m Failed to check mining seed, will retry after 30 seconds"
                    sleep 30
                    continue
                elif [ "$mining_seed" = 1 ]; then
                    if pgrep -f 'apoolminer' > /dev/null; then
                        echo -e "$(date +"%Y-%m-%d %H:%M:%S")     \033[32mINFO\033[0m Template is available, apoolminer is already running"
                    else
                        if pgrep -f "$third_miner" > /dev/null; then
                            echo -e "$(date +"%Y-%m-%d %H:%M:%S")     \033[32mINFO\033[0m Template is available, kill third_cmd and run apoolminer"
                            pkill -f "$third_miner"
                            nohup proxychains ./apoolminer "${params[@]}" > $algo.log 2>&1 &
                        else
                            echo -e "$(date +"%Y-%m-%d %H:%M:%S")     \033[32mINFO\033[0m Template is available, run apoolminer"
                            nohup ./apoolminer "${params[@]}" > $algo.log 2>&1 &
                        fi
                    fi
                else
                    if pgrep -f 'apoolminer' > /dev/null; then
                        echo -e "$(date +"%Y-%m-%d %H:%M:%S")     \033[32mINFO\033[0m No template available, kill apoolminer and run third_cmd"
                        pkill -f 'apoolminer'
                        nohup $third_cmd > $third_miner.log 2>&1 &
                    else
                        if pgrep -f "$third_miner" > /dev/null; then
                            echo -e "$(date +"%Y-%m-%d %H:%M:%S")     \033[32mINFO\033[0m No template available, third_cmd is already running"
                        else
                            echo -e "$(date +"%Y-%m-%d %H:%M:%S")     \033[32mINFO\033[0m No template available, run third_cmd"
                            nohup $third_cmd > $third_miner.log 2>&1 &
                        fi
                    fi
                fi
                sleep_time=10
                echo -e "$(date +"%Y-%m-%d %H:%M:%S")     \033[32mINFO\033[0m Wait for $sleep_time seconds to check the template"
                sleep $sleep_time
            else
                echo -e "$(date +"%Y-%m-%d %H:%M:%S")     \033[31mERROR\033[0m Failed to connect to the url, will retry after 30 seconds"
                sleep 30
                continue
            fi
        else
            echo -e "$(date +"%Y-%m-%d %H:%M:%S")     \033[31mERROR\033[0m $third_miner does not exist"
            sleep 5
        fi
    done
else
    echo -e "Please use nohup to run.\nUsage:\033[0;32m nohup bash run.sh > run.log 2>&1 &\033[0m"
    exit 1
fi
