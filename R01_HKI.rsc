# ============================================================
# Конфигурация роутера R01.HKI (Хельсинки) — Route Reflector №2
# Лабораторная работа №4 — iBGP, L3VPN, VPLS
# ============================================================
# Второй Route Reflector. Работает в паре с R01.LND.
# Два RR обеспечивают отказоустойчивость: если один упадёт,
# BGP-маршруты всё равно будут распространяться через второй.
#
# Интерфейсы:
#   ether1 — канал до R01.LND (первый RR)
#   ether2 — канал до R01.SPB
#   ether3 — канал до R01.LBN
# ============================================================

# --- Имя и пароль ---
/system identity set name=R01.HKI
/user set [find name=admin] password=admin

# --- Loopback ---
/interface bridge add name=loopback
/ip address add address=10.10.10.4/32 interface=loopback

# --- IP-адреса ---
/ip address
add address=10.10.2.2/30 interface=ether1 comment="Канал до R01.LND"
add address=10.10.3.1/30 interface=ether2 comment="Канал до R01.SPB"
add address=10.10.5.1/30 interface=ether3 comment="Канал до R01.LBN"

# === OSPF ===
/routing ospf instance
set default router-id=10.10.10.4

/routing ospf network
add area=backbone network=10.10.2.0/30
add area=backbone network=10.10.3.0/30
add area=backbone network=10.10.5.0/30
add area=backbone network=10.10.10.4/32

# === MPLS LDP ===
/mpls ldp
set enabled=yes transport-address=10.10.10.4 lsr-id=10.10.10.4

/mpls ldp interface
add interface=ether1
add interface=ether2
add interface=ether3

# === iBGP — Route Reflector №2 ===
/routing bgp instance
set default as=65530 router-id=10.10.10.4 \
    client-to-client-reflection=yes

# --- Пир с R01.LND (первый Route Reflector) ---
/routing bgp peer
add name=R01.LND \
    remote-address=10.10.10.2 \
    remote-as=65530 \
    address-families=vpnv4 \
    update-source=loopback \
    route-reflect=yes

# --- Пиры с клиентами ---
add name=R01.SPB \
    remote-address=10.10.10.5 \
    remote-as=65530 \
    address-families=vpnv4 \
    update-source=loopback \
    route-reflect=yes

add name=R01.LBN \
    remote-address=10.10.10.3 \
    remote-as=65530 \
    address-families=vpnv4 \
    update-source=loopback \
    route-reflect=yes

add name=R01.SVL \
    remote-address=10.10.10.6 \
    remote-as=65530 \
    address-families=vpnv4 \
    update-source=loopback \
    route-reflect=yes
