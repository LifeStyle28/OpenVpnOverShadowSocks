#!/bin/bash

rm ~/$1.ovpn
rm /etc/openvpn/easy-rsa/pki/reqs/$1.req
rm /etc/openvpn/easy-rsa/pki/issued/$1.crt
rm /etc/openvpn/easy-rsa/pki/private/$1.key

cd /etc/openvpn/easy-rsa && ./easyrsa build-client-full $1 nopass && cd ..

cp easy-rsa/pki/issued/$1.crt .
cp easy-rsa/pki/private/$1.key .

SERVER_IP=$(cat ip_addr.conf)

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
    sed -ne '/BEGIN CERTIFICATE/,$ p' $1.crt
    echo "</cert>"
    echo "<key>"
    cat $1.key
    echo "</key>"
    echo "<tls-crypt>"
    sed -ne '/BEGIN OpenVPN Static key/,$ p' tls-crypt.key
    echo "</tls-crypt>"
} > ~/$1.ovpn
