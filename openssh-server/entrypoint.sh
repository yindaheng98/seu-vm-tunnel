#!/bin/bash
chmod 644 /root/.ssh/authorized_keys
exec "$@"