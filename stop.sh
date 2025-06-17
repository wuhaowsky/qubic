#!/bin/bash
# 杀掉正在运行的 run.sh 脚本
pkill -f run.sh
# 杀掉 apoolminer 进程
killall -9 apoolminer 
killall -9 xmrig
