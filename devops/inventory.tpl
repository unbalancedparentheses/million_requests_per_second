[server]
${server_ip}

[clients]
${client_ips}

[mrps:children]
server
clients

[monitor]
${monitor_ip}
