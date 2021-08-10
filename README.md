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
route add -net 10.0.0.0/8 gw 172.22.31.254
route add default gw 172.22.5.255
```

测试内网和外网均可ping通，表明路由正确。

需要将上述路由添加为永久配置。网上查到的资料都是要改`/etc/network/interfaces`里的配置，这种配置方法还要指定网卡。我只想要添加两个路由而已，用指令配置明明就不需要指定网卡，不喜。暂时没找到合适的配置文件，所以我把上面那两条指令直接加了个脚本在`/etc/ppp/ip-up.d/`。

## 内网穿透

首先尝试最基础的FRP方案：

```mermaid
graph LR
虚拟机--SSH Tunnel-->SSHD--Frpc-->Frps
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
log_level = debug

[Local]
type = tcp
local_ip = localhost
local_port = 22
remote_port = 22

[Vino]
type = tcp
local_ip = localhost
local_port = 5900
remote_port = 5900
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

报错：`Accept new mux stream error: EOF`，怎么调都无法连接，遂放弃

改用SSH隧道方案：

```sh
ssh -NR 0.0.0.0:2222:localhost:22 yin@办公用电脑地址
```

在`sshd`主机上登录：
```sh
ssh root@localhost -p 2222
```

发现可以登录，但在同样网络环境下的另一台主机上登录：
```sh
ssh root@192.168.1.11 -p 2222
```

发现不能登录，`lsof`发现`sshd`主机只监听了`localhost`，把`0.0.0.0`换成`*`或者加上`-g`均无效。迫不得已，只能在`sshd`主机上再加一层FRP：

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
log_level = debug

[Local]
type = tcp
local_ip = localhost
local_port = 2222
remote_port = 2222
EOF
/etc/frp/frpc -c /etc/frp/frpc.ini
```

好了终于能连上ssh了，可喜可贺。接下来用同样的方法即可把远程桌面也加入转发。

## 用`docker-compose`一键配置

结构：

```mermaid
graph LR
虚拟机--SSH Tunnel-->SSHD--Frpc-->Frps
```

虚拟机通过SSH Tunnel将本地的端口转发到`sshd`上，`sshd`再经由`frpc`将端口映射至`frps`。其中，`sshd`、`frpc`、`frps`可以用一个Compose合在一起。见[`docker-compose.yml`](./docker-compose.yml)文件。


在办公机器上，先生成登录密钥，然后启动Compose：

```sh
mkdir -p ./data
ssh-keygen -t rsa -b 4096 -f ./data/id_rsa -N ''
```

测试是否能无密码登陆：

```sh
docker run --rm -it -v "$(pwd)/data/id_rsa:/root/.ssh/id_rsa" linuxserver/openssh-server sh -c "chmod 0600 /root/.ssh/id_rsa && ssh -v root@192.168.1.2 -p 2222 -o StrictHostKeyChecking=no"
```

在虚拟机上，需要将他们加入系统服务以开机启动：

```sh
cat > /root/.ssh/id_rsa <<EOF
把你的密钥data/id_rsa内容放在这里
EOF
chmod 0600 /root/.ssh/id_rsa
cat > /etc/systemd/system/ssh-tunnel.service <<EOF
[Unit]
Description=Frp Client Service
After=network.target

[Service]
Type=simple
User=nobody
Restart=on-failure
RestartSec=5s
ExecStart=/usr/bin/ssh -vNR 0.0.0.0:22:localhost:22 root@10.201.224.251 -p 2222 -o StrictHostKeyChecking=no

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/vnc-tunnel.service <<EOF
[Unit]
Description=Frp Client Service
After=network.target

[Service]
Type=simple
User=nobody
Restart=on-failure
RestartSec=5s
ExecStart=/usr/bin/ssh -vNR 0.0.0.0:5900:localhost:5900 root@10.201.224.251 -p 2222 -o StrictHostKeyChecking=no

[Install]
WantedBy=multi-user.target
EOF
systemctl enable ssh-tunnel.service && systemctl start ssh-tunnel.service && systemctl status ssh-tunnel.service
systemctl enable vnc-tunnel.service && systemctl start vnc-tunnel.service && systemctl status vnc-tunnel.service
```