#!/bin/bash

SERVER_IP=$1

apt install shadowsocks-libev -y
rm /etc/shadowsocks-libev/config.json
{
    echo "{"
    echo "\"server\":\"0.0.0.0\","
    echo "\"mode\":\"tcp_and_udp\","
    echo "\"server_port\":6789,"
    echo "\"local_port\":1080,"
    echo "\"password\":\"secret123\","
    echo "\"timeout\":60,"
    echo "\"method\":\"chacha20-ietf-poly1305\""
    echo "}"
} > /etc/shadowsocks-libev/config.json

sudo systemctl restart shadowsocks-libev

apt install openvpn easy-rsa -y
cp -r /usr/share/easy-rsa /etc/openvpn/
cd /etc/openvpn/easy-rsa/
cp openssl-easyrsa.cnf openssl.cnf

{
    echo "export EASYRSA_REQ_COUNTRY=\"US\""
    echo "export EASYRSA_REQ_PROVINCE=\"California\""
    echo "export EASYRSA_REQ_CITY=\"San Francisco\""
    echo "export EASYRSA_REQ_ORG=\"Copyleft Certificate Co\""
    echo "export EASYRSA_REQ_EMAIL=\"me@example.net\""
    echo "export EASYRSA_REQ_OU=\"My Organizational Unit\""
} > vars

source ./vars
./easyrsa clean-all
./easyrsa build-ca nopass
./easyrsa gen-dh
./easyrsa build-server-full server0 nopass
./easyrsa build-client-full client1 nopass
cd pki && cp ca.crt ../.. && cp dh.pem ../.. && cd issued && cp *.crt ../../..
cd ../private && cp *.key ../../.. && cd ../../..
openvpn --genkey secret tls-crypt.key
{
    echo "port 1194"
    echo "proto tcp"
    echo "dev tun"
    echo "ca ca.crt"
    echo "cert server0.crt"
    echo "key server0.key"
    echo "dh dh.pem"
    echo "server 10.8.0.0 255.255.255.0"
    echo "ifconfig-pool-persist ipp.txt"
    echo "push \"redirect-gateway def1 bypass-dhcp\""
    echo "push \"dhcp-option DNS 1.1.1.1\""
    echo "push \"dhcp-option DNS 1.0.0.1\""
    echo "keepalive 10 120"
    echo "cipher AES-256-GCM"
    echo "tls-crypt tls-crypt.key"
    echo "user nobody"
    echo "group nogroup"
    echo "persist-key"
    echo "persist-tun"
    echo "status openvpn-status.log"
    echo "verb 3"
} > server0.conf

sed -i '/net.ipv4.ip_forward=1/s/^#//g' /etc/sysctl.conf

iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to-source $SERVER_IP
apt install iptables-persistent -y

{
    echo "client"
    echo "dev tun"
    echo "proto tcp"
    echo "remote $SERVER_IP 1194"
    echo "resolv-retry infinite"
    echo "nobind"
    echo "persist-key"
    echo "persist-tun"
    echo "remote-cert-tls server"
    echo "auth SHA512"
    echo "cipher AES-256-CBC"
    echo "ignore-unknown-option block-outside-dns"
    echo "block-outside-dns"
    echo "verb 3"

    echo "socks-proxy 127.0.0.1 1080"
    echo "route $SERVER_IP 255.255.255.255 net_gateway"
    echo "route 192.168.0.0 255.255.0.0 net_gateway"

    echo "<ca>"
    cat ca.crt
    echo "</ca>"
    echo "<cert>"
    sed -ne '/BEGIN CERTIFICATE/,$ p' client1.crt
    echo "</cert>"
    echo "<key>"
    cat client1.key
    echo "</key>"
    echo "<tls-crypt>"
    sed -ne '/BEGIN OpenVPN Static key/,$ p' tls-crypt.key
    echo "</tls-crypt>"
} > client1.ovpn

echo "$SERVER_IP" > ip_addr.conf

systemctl restart openvpn@server0
ss -tulpn | grep 1194
ss -tulpn | grep 6789
