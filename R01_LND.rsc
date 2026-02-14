# ============================================================
# Конфигурация роутера R01.LND (Лондон) — Route Reflector №1
# Лабораторная работа №4 — iBGP, L3VPN, VPLS
# ============================================================
# Route Reflector (RR) — роутер, который "отражает" BGP-маршруты
# от одних клиентов к другим. Без RR в iBGP пришлось бы делать
# полносвязную mesh-топологию (каждый с каждым), а это неудобно.
#
# R01.LND — один из двух RR (второй — R01.HKI).
# Он не является PE, то есть к нему не подключены ПК DEVOPS.
#
# Интерфейсы:
#   ether1 — канал до R01.NY
#   ether2 — канал до R01.HKI (второй RR)
#   ether3 — канал до R01.LBN
# ============================================================

# --- Имя и пароль ---
/system identity set name=R01.LND
/user set [find name=admin] password=admin

# --- Loopback ---
/interface bridge add name=loopback
/ip address add address=10.10.10.2/32 interface=loopback

# --- IP-адреса ---
/ip address
add address=10.10.1.2/30 interface=ether1 comment="Канал до R01.NY"
add address=10.10.2.1/30 interface=ether2 comment="Канал до R01.HKI"
add address=10.10.4.1/30 interface=ether3 comment="Канал до R01.LBN"

# === OSPF ===
/routing ospf instance
set default router-id=10.10.10.2

/routing ospf network
add area=backbone network=10.10.1.0/30
add area=backbone network=10.10.2.0/30
add area=backbone network=10.10.4.0/30
add area=backbone network=10.10.10.2/32

# === MPLS LDP ===
/mpls ldp
set enabled=yes transport-address=10.10.10.2 lsr-id=10.10.10.2

/mpls ldp interface
add interface=ether1
add interface=ether2
add interface=ether3

# === iBGP — Route Reflector ===
# Это Route Reflector: он принимает VPN-маршруты от PE-клиентов
# и "отражает" (перенаправляет) их другим клиентам.
# route-reflect=yes — включает отражение для данного пира.
/routing bgp instance
set default as=65530 router-id=10.10.10.2 \
    client-to-client-reflection=yes

# --- Пир с R01.HKI (второй Route Reflector) ---
# Между двумя RR тоже нужна BGP-сессия для обмена маршрутами
/routing bgp peer
add name=R01.HKI \
    remote-address=10.10.10.4 \
    remote-as=65530 \
    address-families=vpnv4 \
    update-source=loopback \
    route-reflect=yes

# --- Пиры с клиентами (PE-роутерами) ---
# route-reflect=yes — мы будем отражать им маршруты от других клиентов
add name=R01.NY \
    remote-address=10.10.10.1 \
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
