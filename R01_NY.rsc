# ============================================================
# Конфигурация роутера R01.NY (Нью-Йорк) — PE-роутер
# Лабораторная работа №4 — iBGP, L3VPN, VPLS
# ============================================================
# PE-роутер (Provider Edge) в Нью-Йорке.
# К ether2 подключён PC2 отдела DEVOPS.
#
# Интерфейсы:
#   ether1 — магистраль до R01.LND (Route Reflector)
#   ether2 — подключение PC2 (VRF_DEVOPS / VPLS)
# ============================================================

# --- Имя и пароль ---
/system identity set name=R01.NY
/user set [find name=admin] password=admin

# --- Loopback ---
/interface bridge add name=loopback
/ip address add address=10.10.10.1/32 interface=loopback

# --- IP-адреса на магистральных интерфейсах ---
/ip address
add address=10.10.1.1/30 interface=ether1 comment="Магистраль до R01.LND"

# === OSPF ===
# OSPF нужен для связности loopback-адресов между роутерами.
# Без OSPF iBGP и MPLS работать не будут, потому что
# BGP-сессии устанавливаются через loopback-адреса.
/routing ospf instance
set default router-id=10.10.10.1

/routing ospf network
add area=backbone network=10.10.1.0/30
add area=backbone network=10.10.10.1/32

# === MPLS LDP ===
# MPLS нужен для передачи VPN-трафика через метки.
# Без MPLS L3VPN и VPLS работать не будут.
/mpls ldp
set enabled=yes transport-address=10.10.10.1 lsr-id=10.10.10.1

/mpls ldp interface
add interface=ether1

# ===========================================================
# ЧАСТЬ 1: L3VPN (VRF_DEVOPS)
# ===========================================================
# L3VPN позволяет создать изолированную виртуальную сеть
# для отдела DEVOPS поверх общей MPLS-инфраструктуры.
# Каждый офис DEVOPS получает свою подсеть, но все они
# могут общаться друг с другом через VPN.

# --- VRF (Virtual Routing and Forwarding) ---
# VRF — это отдельная таблица маршрутизации.
# RD (Route Distinguisher) — делает маршруты уникальными в BGP.
# RT (Route Target) — определяет, какие маршруты импортировать/экспортировать.
# Одинаковые RT на всех PE = все видят маршруты друг друга.
/ip route vrf
add routing-mark=VRF_DEVOPS \
    route-distinguisher=65530:100 \
    import-route-targets=65530:100 \
    export-route-targets=65530:100 \
    interfaces=ether2

# --- IP-адрес в VRF (для PC2) ---
/ip address
add address=192.168.10.1/24 interface=ether2 comment="VRF_DEVOPS - PC2 Нью-Йорк"

# --- iBGP с Route Reflector ---
# BGP-сессия устанавливается с R01.LND (Route Reflector).
# address-families=vpnv4 — мы обмениваемся VPN-маршрутами.
# update-source=loopback — сессия идёт через стабильный loopback-адрес.
/routing bgp instance
set default as=65530 router-id=10.10.10.1

/routing bgp peer
add name=R01.LND \
    remote-address=10.10.10.2 \
    remote-as=65530 \
    address-families=vpnv4 \
    update-source=loopback

# --- Редистрибуция подключённых сетей VRF в BGP ---
# Это нужно, чтобы сеть 192.168.10.0/24 появилась в BGP
# и была доступна из других офисов DEVOPS.
/routing bgp instance vrf
add routing-mark=VRF_DEVOPS instance=default redistribute-connected=yes

# ===========================================================
# ЧАСТЬ 2: VPLS (раскомментировать после разборки VRF)
# ===========================================================
# VPLS — это виртуальный L2-коммутатор через MPLS-сеть.
# Все ПК DEVOPS окажутся в одном broadcast-домене (одной подсети).
#
# Чтобы перейти к VPLS:
# 1. Удалить VRF: /ip route vrf remove [find routing-mark=VRF_DEVOPS]
# 2. Удалить IP с ether2: /ip address remove [find interface=ether2]
# 3. Раскомментировать команды ниже
# 4. Перенастроить PC2: ip addr add 192.168.100.2/24 dev eth1
#
# /interface vpls
# add name=VPLS_to_SPB remote-peer=10.10.10.5 vpls-id=65530:100 disabled=no
# add name=VPLS_to_SVL remote-peer=10.10.10.6 vpls-id=65530:100 disabled=no
#
# /interface bridge add name=VPLS_bridge
#
# /interface bridge port
# add bridge=VPLS_bridge interface=ether2
# add bridge=VPLS_bridge interface=VPLS_to_SPB
# add bridge=VPLS_bridge interface=VPLS_to_SVL
