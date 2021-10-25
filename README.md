# 学校云计算中心虚拟机配置笔记

## 网络配置

初始状态：
* 计算中心有两个网关：
  * 内网网关`172.22.31.254`，只能上校园网
  * 公网关`172.22.5.255`，只能上公网
* 虚拟机默认网关为内网网关`172.22.31.254`

目标状态：
* 既能上公网又能上校园网

宿舍DHCP得到的IP地址为`10.208.XXX.XXX`，实验室DHCP得到的IP地址为`10.201.XXX.XXX`，`201=11001001`、`208=11010000`。于是推测校园网IP范围至少是`10.192.0.0/11`，至多是`10.192.0.0/8`。

于是，添加路由：
```sh
route del -net 0.0.0.0/0 gw 172.22.31.254 metric 20100
route add -net 10.0.0.0/8 gw 172.22.31.254
route add default gw 172.22.5.255
systemd-resolve --set-dns=114.114.114.114 --interface=ens3
```

测试内网和外网均可ping通，表明路由正确。

需要将上述路由添加为永久配置。网上查到的资料都是要改`/etc/network/interfaces`里的配置，这种配置方法还要指定网卡。我只想要添加两个路由而已，用指令配置明明就不需要指定网卡，不喜。暂时没找到合适的配置文件，所以我把上面那两条指令直接加了个脚本在`/etc/ppp/ip-up.d/`。

## 内网穿透

采用最基础的FRP方案：

```mermaid
graph LR
虚拟机--Frpc-->Frps
```

```sh
FRP_URL=https://github.com/fatedier/frp/releases/download/v0.34.3/frp_0.34.3_linux_amd64.tar.gz
PROXY=http://办公用电脑地址
wget $FRP_URL -e HTTP_PROXY=$PROXY -e HTTPS_PROXY=$PROXY -O ~/frp.tar.gz &&
    mkdir -p /etc/frp && tar -zxvf ~/frp.tar.gz -C /etc/frp --strip-components=1 &&
    rm -f ~/frp.tar.gz
cat > /etc/frp/frpc.ini <<EOF
[common]
server_addr = 办公用电脑地址
server_port = 7000
protocol=websocket
log_level = debug

[SEU-VM]
type = tcp
local_ip = localhost
local_port = 22
remote_port = 23
EOF
cat > /etc/systemd/system/frpc.service <<EOF
[Unit]
Description=Frp Client Service
After=network.target

[Service]
Type=simple
User=nobody
Restart=on-failure
RestartSec=5s
ExecStart=/etc/frp/frpc -c /etc/frp/frpc.ini
ExecReload=/etc/frp/frpc reload -c /etc/frp/frpc.ini

[Install]
WantedBy=multi-user.target
EOF
systemctl enable frpc.service && systemctl start frpc.service && systemctl status frpc.service
```
