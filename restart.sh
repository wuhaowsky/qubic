#!/bin/bash

# 杀掉正在运行的 run.sh 脚本
pkill -f run.sh

# 杀掉 apoolminer 进程
killall -9 apoolminer
killall -9 xmrig
# 启动 run.sh 并将输出重定向到 run.log
nohup bash run.sh > run.log 2>&1 &
