# ============================================================
# Конфигурация роутера R01.LBN (Любляна) — P-роутер
# Лабораторная работа №4 — iBGP, L3VPN, VPLS
# ============================================================
# P-роутер (Provider) — транзитный роутер. К нему не подключены
# клиентские ПК, он только пропускает трафик между другими
# роутерами. Но ему всё равно нужен BGP для передачи
# VPN-маршрутов (через Route Reflectors).
#
# Интерфейсы:
#   ether1 — канал до R01.LND
#   ether2 — канал до R01.HKI
#   ether3 — канал до R01.SVL
# ============================================================

# --- Имя и пароль ---
/system identity set name=R01.LBN
/user set [find name=admin] password=admin

# --- Loopback ---
/interface bridge add name=loopback
/ip address add address=10.10.10.3/32 interface=loopback

# --- IP-адреса ---
/ip address
add address=10.10.4.2/30 interface=ether1 comment="Канал до R01.LND"
add address=10.10.5.2/30 interface=ether2 comment="Канал до R01.HKI"
add address=10.10.6.1/30 interface=ether3 comment="Канал до R01.SVL"

# === OSPF ===
/routing ospf instance
set default router-id=10.10.10.3

/routing ospf network
add area=backbone network=10.10.4.0/30
add area=backbone network=10.10.5.0/30
add area=backbone network=10.10.6.0/30
add area=backbone network=10.10.10.3/32

# === MPLS LDP ===
/mpls ldp
set enabled=yes transport-address=10.10.10.3 lsr-id=10.10.10.3

/mpls ldp interface
add interface=ether1
add interface=ether2
add interface=ether3

# === iBGP ===
# Даже транзитный роутер участвует в BGP — он пиринг
# устанавливает с обоими Route Reflectors, чтобы
# корректно обрабатывать VPN-метки.
/routing bgp instance
set default as=65530 router-id=10.10.10.3

/routing bgp peer
add name=R01.LND \
    remote-address=10.10.10.2 \
    remote-as=65530 \
    address-families=vpnv4 \
    update-source=loopback

add name=R01.HKI \
    remote-address=10.10.10.4 \
    remote-as=65530 \
    address-families=vpnv4 \
    update-source=loopback
