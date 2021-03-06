#!/bin/bash

#*****************************************************************************************
# *用例名称：onboard_NIC_ADVANCED_FlowClassification_001                                                 
# *用例功能：查询和设置指定网卡分流（比如哈希）                          
# *作者：lwx588815                                                          
# *完成时间：2019-4-12                                      
# *前置条件：                                                                            
#      1.单板启动正常
#      2.所有网口各模块加载正常                                                     
# *测试步骤：                                                                               
#      1. 网口up，输入设置命令：ethtool -N ethx rx-flow-hash udp4 sdfn
#      2.执行查询命令：ethtool -n ethx rx-flow-hash udp4
# *测试结果：                                                                            
#      The test result is PASS
#      注：不支持的提示“不支持”                                                 
#*****************************************************************************************

#加载公共函数
. ../../../../../utils/error_code.inc
. ../../../../../utils/test_case_common.inc
. ../../../../../utils/sys_info.sh
. ../../../../../utils/sh-test-lib

#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=./logs/temp
mkdir -p ${TMPDIR}
#存放脚本处理中间状态/值等
TMPFILE=${TMPDIR}/${test_name}.tmp
#存放每个测试步骤的执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result

#自定义变量区域（可选）
#var_name1="xxxx"
#var_name2="xxxx"
test_result="pass"

#预置条件
function init_env()
{
  #检查结果文件是否存在，创建结果文件：
	fn_checkResultFile ${RESULT_FILE}
        #root用户执行
        if [ `whoami` != 'root' ]
        then
              PRINT_LOG "WARN" " You must be root user "
              return 1
        fi

        #install
       fn_install_pkg "ethtool" 2

        network=`ip link | grep "state UP" | awk '{ print $2 }' | sed 's/://g'|egrep -v "vir|br|docker|vnet"`
        for i in $network
        do
        ethtool -i $i|grep "driver:"|grep "hns"
        if [ $? -eq 0 ];then
            echo "$i" | tee -a network.txt
        fi
        done
}       

#测试执行
function test_case()
{ 

    for j in `cat network.txt`
    do
       ethtool -N $j rx-flow-hash udp4 sdfn
       if [ $? -eq 0 ];then
           PRINT_LOG "INFO" "$j-sdfn-ok"
           fn_writeResultFile "${RESULT_FILE}" "$j-sdfn-ok" "pass"
       else
           PRINT_LOG "FATAL" "$j-sdfn-fail"
           fn_writeResultFile "${RESULT_FILE}" "$j-sdfn-fail" "fail"
       fi

       ethtool -n $j rx-flow-hash udp4|grep "TCP/UDP dst port"
       if [ $? -eq 0 ];then
           PRINT_LOG "INFO" "$j-udp4-ok"
           fn_writeResultFile "${RESULT_FILE}" "$j-udp4-ok" "pass"
       else
           PRINT_LOG "FATAL" "$j-udp4-fail"
           fn_writeResultFile "${RESULT_FILE}" "$j-udp4" "fail"
       fi
     done
	#检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
    check_result ${RESULT_FILE}

}

#恢复环境
function clean_env()
{
	#清除临时文件
	FUNC_CLEAN_TMP_FILE
        rm -rf network.txt
           
}

function main()
{
    init_env || test_result="fail"
    if [ ${test_result} = "pass" ]
    then
        test_case || test_result="fail"
    fi
    clean_env || test_result="fail"
	[ "${test_result}" = "pass" ] || return 1
}

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}
