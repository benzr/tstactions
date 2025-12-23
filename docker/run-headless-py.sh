#!/bin/bash
echo "Starting eval for $1.py"
cd /opt/CoppeliaSim_Edu_V4_10_0_rev0_Ubuntu24_04
./coppeliaSim.sh  -h -s 60000 -q /scenes/dartv2_final_v0_simple.ttt &
cd /eval/py    
python3 $1.py > $1_log.txt 2> $1_errlog.txt
wait
echo "All background processes completed"
