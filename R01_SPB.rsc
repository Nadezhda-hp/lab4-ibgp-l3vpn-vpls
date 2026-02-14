# ============================================================
# Конфигурация роутера R01.SPB (Санкт-Петербург) — PE-роутер
# Лабораторная работа №4 — iBGP, L3VPN, VPLS
# ============================================================
# PE-роутер в Санкт-Петербурге. К ether2 подключён PC1
# отдела DEVOPS.
#
# Интерфейсы:
#   ether1 — магистраль до R01.HKI (Route Reflector)
#   ether2 — подключение PC1 (VRF_DEVOPS / VPLS)
# ============================================================

# --- Имя и пароль ---
/system identity set name=R01.SPB
/user set [find name=admin] password=admin

# --- Loopback ---
/interface bridge add name=loopback
/ip address add address=10.10.10.5/32 interface=loopback

# --- IP-адреса на магистральных интерфейсах ---
/ip address
add address=10.10.3.2/30 interface=ether1 comment="Магистраль до R01.HKI"

# === OSPF ===
/routing ospf instance
set default router-id=10.10.10.5

/routing ospf network
add area=backbone network=10.10.3.0/30
add area=backbone network=10.10.10.5/32

# === MPLS LDP ===
/mpls ldp
set enabled=yes transport-address=10.10.10.5 lsr-id=10.10.10.5

/mpls ldp interface
add interface=ether1

# ===========================================================
# ЧАСТЬ 1: L3VPN (VRF_DEVOPS)
# ===========================================================

# --- VRF ---
/ip route vrf
add routing-mark=VRF_DEVOPS \
    route-distinguisher=65530:100 \
    import-route-targets=65530:100 \
    export-route-targets=65530:100 \
    interfaces=ether2

# --- IP-адрес в VRF ---
/ip address
add address=192.168.20.1/24 interface=ether2 comment="VRF_DEVOPS - PC1 Санкт-Петербург"

# --- iBGP с Route Reflector (R01.HKI) ---
/routing bgp instance
set default as=65530 router-id=10.10.10.5

/routing bgp peer
add name=R01.HKI \
    remote-address=10.10.10.4 \
    remote-as=65530 \
    address-families=vpnv4 \
    update-source=loopback

# --- Редистрибуция VRF в BGP ---
/routing bgp instance vrf
add routing-mark=VRF_DEVOPS instance=default redistribute-connected=yes

# ===========================================================
# ЧАСТЬ 2: VPLS (раскомментировать после разборки VRF)
# ===========================================================
# Чтобы перейти к VPLS:
# 1. Удалить VRF: /ip route vrf remove [find routing-mark=VRF_DEVOPS]
# 2. Удалить IP с ether2: /ip address remove [find interface=ether2]
# 3. Раскомментировать команды ниже
# 4. Перенастроить PC1: ip addr add 192.168.100.1/24 dev eth1
#
# /interface vpls
# add name=VPLS_to_NY remote-peer=10.10.10.1 vpls-id=65530:100 disabled=no
# add name=VPLS_to_SVL remote-peer=10.10.10.6 vpls-id=65530:100 disabled=no
#
# /interface bridge add name=VPLS_bridge
#
# /interface bridge port
# add bridge=VPLS_bridge interface=ether2
# add bridge=VPLS_bridge interface=VPLS_to_NY
# add bridge=VPLS_bridge interface=VPLS_to_SVL
