#!/usr/bin/env bash

## 本脚本搬运并模仿 liuqitoday
dir_config=/ql/data/config
dir_script=/ql/data/scripts
dir_repo=/ql/data/repo
config_sync_path=$dir_config/sync.sh
bot_json=$dir_config/bot.json

# 下载 sync.sh
dl_sync_shell() {
    curl -sfL https://raw.githubusercontent.com/Shalong22/Oreomeow-VIP/main/Scripts/sh/sync.sh -o $config_sync_path
    # 判断是否下载成功
    update_size=$(ls -l $config_sync_path | awk '{print $5}')
    if (( $(echo "${update_size} < 100" | bc -l) )); then
        echo "sync.sh 下载失败"
        exit 0
    fi
}

# 将 sync.sh 添加到定时任务
add_sync() {
    if [ "$(grep -c "sync.sh" $dir_config/crontab.list)" != 0 ]; then
        echo "您的任务列表中已存在 sync.sh"
    else
        echo "添加 sync.sh"
        # 获取token
        token=$(cat $dir_config/auth.json | jq --raw-output .token)
        curl -s -H 'Accept: application/json' -H "Authorization: Bearer $token" -H 'Content-Type: application/json;charset=UTF-8' -H 'Accept-Language: zh-CN,zh;q=0.9' --data-binary '{"name":"更新配置和任务","command":"task /ql/data/config/sync.sh","schedule":"16 6 * * *"}' --compressed 'http://127.0.0.1:5700/api/crons?t=1624782068473'
    fi
}
# 运行一次 Update
run_sync() {
    echo "请耐心等待..."
    task $dir_config/sync.sh
}

read -p "是否配置Bot机器人, n 跳过, y 配置, 回车默认 n:" bot
    bot=${bot:-'n'}

echo "开始拉取任务脚本,请确保本路由器网络已过墙."
dl_sync_shell && add_sync && run_sync

# 添加定时任务 ql bot
add_ql_bot() {
    if [ "$(grep -c "ql\ bot" $dir_config/crontab.list)" != 0 ]; then
        echo "您的任务列表中已存在 task:ql bot"
    else
        echo "开始添加 task:ql bot"
        # 获取token
        token=$(cat $dir_config/auth.json | jq --raw-output .token)
        curl -s -H 'Accept: application/json' -H "Authorization: Bearer $token" -H 'Content-Type: application/json;charset=UTF-8' -H 'Accept-Language: zh-CN,zh;q=0.9' --data-binary '{"name":"拉取机器人","command":"ql bot","schedule":"13 14 * * *"}' --compressed 'http://127.0.0.1:5700/api/crons?t=1626247933219'
    fi
}
# 运行一次并简单设置 bot.json
set_bot_json() {
    ql bot
    echo -e "\"//user_id\": \"↓↓↓  你的USERID，去除双引号  ↓↓↓\",\n\"user_id\": 123456789,\n\"//bot_token\": \"↓↓↓  你的机器人TOKEN  ↓↓↓\",\n\"bot_token\": \"123456789:ABCDEFGSHSFDASDFAD\",\n\"//api_id\": \"↓↓↓  https://my.telegram.org 在该网站申请到的id  ↓↓↓\",\n\"api_id\": \"456423156\",\n\"//api_hash\": \"↓↓↓  https://my.telegram.org 在该网站申请到的hash  ↓↓↓\",\n\"api_hash\": \"ASDFAWEFADSFAWEFDSFASFD\","
    echo -e "----- 以上为示例，以下为你的配置(不要引号) -----"
    read -p "\"user_id\": " user_id
    read -p "\"bot_token\": " bot_token
    read -p "\"api_id\": " api_id
    read -p "\"api_hash\": " api_hash
    sed -i "s/123456789,/${user_id},/" $bot_json
    sed -ri "s/123456789\:ABCDEFGSHSFDASDFAD/${bot_token}/" $bot_json
    sed -i "s/456423156/${api_id}/" $bot_json
    sed -i "s/ASDFAWEFADSFAWEFDSFASFD/${api_hash}/" $bot_json
}

if [ "${bot}" = 'y' ]; then
    add_ql_bot && set_bot_json && ql bot
else
    echo "已为您跳过操作 Bot机器人"
fi

# 提示配置结束
echo -e "\n配置到此结束, 管理地址: 后台ip:5700 "
