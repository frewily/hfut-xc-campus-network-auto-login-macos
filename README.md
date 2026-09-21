# HFUT Xuancheng Campus Network Auto Login for macOS

适用于合肥工业大学宣城校区校园网认证门户 `http://172.18.3.3/0.htm` 的 macOS 自动登录脚本。

它通过 `sleepwatcher` 监听 macOS 唤醒事件：Mac 唤醒后，系统先自动加入已保存的 `hfut_wlan`，监听器最多等待 20 秒让 Wi-Fi 恢复，然后立即认证。认证通过 HTTP 请求完成，不会主动打开浏览器窗口。

## 安全设计

- 不包含、记录或上传任何账号和密码。
- 凭据由 macOS 钥匙串保存；脚本仅在本机运行时读取。
- `.gitignore` 排除了日志、临时文件和本机安装目录。
- 请不要将自己的钥匙串导出、终端历史或认证请求抓包上传到仓库。

## 前提

- macOS（系统自带 Bash、`curl`、`security`、`launchctl` 与 `md5`）。
- [Homebrew](https://brew.sh/)；用它安装 `sleepwatcher`。
- 已连接校园网 Wi-Fi 或网线。
- 在“系统设置 → Wi-Fi → hfut_wlan”中开启“自动加入此网络”。
- 仅使用你本人有权使用的校园网账号，并遵守学校网络规定。

## 安装

克隆仓库后，进入仓库目录并保存凭据。以下两条命令会交互式要求输入内容；终端不会回显输入。

```bash
security add-generic-password -U -a "$USER" -s 'HFUT-XC-Campus-Network-Username' -w
security add-generic-password -U -a "$USER" -s 'HFUT-XC-Campus-Network-Password' -w
```

第一条输入学号，第二条输入校园网密码。

安装唤醒监听器，然后在仓库根目录执行：

```bash
brew install sleepwatcher
sleepwatcherPath="$(command -v sleepwatcher)"
installDir="$HOME/Documents/hfut-campus-login"
mkdir -p "$installDir"
cp hfut-campus-login.sh "$installDir/hfut-campus-login.sh"
cp hfut-campus-on-wake.sh "$installDir/hfut-campus-on-wake.sh"
chmod 700 "$installDir/hfut-campus-login.sh"
chmod 700 "$installDir/hfut-campus-on-wake.sh"
sed -e "s|SLEEPWATCHER-PATH-TOKEN|$sleepwatcherPath|" -e "s|WAKE-SCRIPT-PATH-TOKEN|$installDir/hfut-campus-on-wake.sh|" cn.hfut.xc.campus-login.plist > "$HOME/Library/LaunchAgents/cn.hfut.xc.campus-login.plist"
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/cn.hfut.xc.campus-login.plist" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/cn.hfut.xc.campus-login.plist"
launchctl kickstart -k "gui/$(id -u)/cn.hfut.xc.campus-login"
```

监听器会在登录时启动，并只在 Mac 唤醒时认证；它不会每两分钟轮询。`sleepwatcher` 进程平时阻塞等待系统事件，几乎不使用 CPU；已联网时不会提交登录请求或写入日志。

## 测试与排障

手动执行一次（模拟 Wi-Fi 已恢复后的认证）：

```bash
bash "$HOME/Documents/hfut-campus-login/hfut-campus-login.sh"
```

只有脚本实际提交认证时，才会写入 `~/Library/Logs/hfut-campus-login.log`。查看任务状态：

```bash
launchctl print "gui/$(id -u)/cn.hfut.xc.campus-login"
```

若门户更换了地址、表单字段或加密规则，脚本会记录“门户参数格式发生变化”，而不会提交猜测的请求。

## 卸载

```bash
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/cn.hfut.xc.campus-login.plist"
rm "$HOME/Library/LaunchAgents/cn.hfut.xc.campus-login.plist"
rm -f "$HOME/Documents/hfut-campus-login/hfut-campus-on-wake.sh"
```

如不再使用，也请在“钥匙串访问”中删除两个以 `HFUT-XC-Campus-Network` 开头的条目。

## License

[MIT](LICENSE)
