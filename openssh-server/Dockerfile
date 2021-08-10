FROM ubuntu:focal
RUN apt-get update && apt-get install -y openssh-server && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir /var/run/sshd && \
    echo 'root:123456' | chpasswd && \
    sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config && \
    sed -ri 's/^#?LogLevel INFO/LogLevel VERBOSE/g' /etc/ssh/sshd_config && \
    sed -ri "s/^#?PasswordAuthentication yes/PasswordAuthentication yes/g" /etc/ssh/sshd_config && \
    sed -ri "s/^#?RSAAuthentication yes/RSAAuthentication yes/g" /etc/ssh/sshd_config && \
    sed -ri "s/^#?PubkeyAuthentication yes/PubkeyAuthentication yes/g" /etc/ssh/sshd_config && \
    sed -ri "s/^#?GatewayPorts no/GatewayPorts clientspecified/g" /etc/ssh/sshd_config && \
    mkdir -p /root/.ssh && touch /root/.ssh/authorized_keys
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/usr/sbin/sshd", "-dD", "-p", "2222"]