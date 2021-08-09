FROM ubuntu:focal
RUN apt-get update && apt-get install -y openssh-server && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir /var/run/sshd && \
    echo 'root:123456' | chpasswd && \
    sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config && \
    sed -ri 's/^#?LogLevel INFO/LogLevel VERBOSE/g' /etc/ssh/sshd_config && \
    sed -ri "s/^#?PasswordAuthentication yes/PasswordAuthentication yes/g" /etc/ssh/sshd_config && \
    sed -ri "s/^#?PermitEmptyPasswords no/PermitEmptyPasswords yes/g" /etc/ssh/sshd_config
CMD ["/usr/sbin/sshd", "-D", "-p", "2222"]