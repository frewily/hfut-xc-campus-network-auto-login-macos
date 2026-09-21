# HFUT Xuancheng Campus Network Auto Login for macOS

适用于合肥工业大学宣城校区校园网认证门户 `http://172.18.3.3/0.htm` 的 macOS 自动登录脚本。

它在登录、唤醒或网络恢复后定期检查网络；需要认证时，读取门户当前的 `pid` 与 `calg` 参数，按门户前端 `a41.js` 的规则提交登录请求。

## 安全设计

- 不包含、记录或上传任何账号和密码。
- 凭据由 macOS 钥匙串保存；脚本仅在本机运行时读取。
- `.gitignore` 排除了日志、临时文件和本机安装目录。
- 请不要将自己的钥匙串导出、终端历史或认证请求抓包上传到仓库。

## 前提

- macOS（系统自带 Bash、`curl`、`security`、`launchctl` 与 `md5`）。
- 已连接校园网 Wi-Fi 或网线。
- 仅使用你本人有权使用的校园网账号，并遵守学校网络规定。

## 安装

克隆仓库后，进入仓库目录并保存凭据。以下两条命令会交互式要求输入内容；终端不会回显输入。

```bash
security add-generic-password -U -a "$USER" -s 'HFUT-XC-Campus-Network-Username' -w
security add-generic-password -U -a "$USER" -s 'HFUT-XC-Campus-Network-Password' -w
```

第一条输入学号，第二条输入校园网密码。

然后，在仓库根目录执行：

```bash
installDir="$HOME/Documents/hfut-campus-login"
mkdir -p "$installDir"
cp hfut-campus-login.sh "$installDir/hfut-campus-login.sh"
chmod 700 "$installDir/hfut-campus-login.sh"
sed "s|SCRIPT-PATH-TOKEN|$installDir/hfut-campus-login.sh|" cn.hfut.xc.campus-login.plist > "$HOME/Library/LaunchAgents/cn.hfut.xc.campus-login.plist"
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/cn.hfut.xc.campus-login.plist" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/cn.hfut.xc.campus-login.plist"
launchctl kickstart -k "gui/$(id -u)/cn.hfut.xc.campus-login"
```

任务会在启动时运行，并每两分钟检查一次。已联网时不会发起登录请求或写入日志。

## 测试与排障

手动执行一次：

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
```

如不再使用，也请在“钥匙串访问”中删除两个以 `HFUT-XC-Campus-Network` 开头的条目。

## License

[MIT](LICENSE)
