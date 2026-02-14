# ============================================================
# Конфигурация роутера R01.SVL (Сан-Вали) — PE-роутер
# Лабораторная работа №4 — iBGP, L3VPN, VPLS
# ============================================================
# PE-роутер, к нему подключён PC3 отдела DEVOPS.
# Связан с остальной сетью через R01.LBN.
#
# Интерфейсы:
#   ether1 — магистраль до R01.LBN
#   ether2 — подключение PC3 (VRF_DEVOPS / VPLS)
# ============================================================

# --- Имя и пароль ---
/system identity set name=R01.SVL
/user set [find name=admin] password=admin

# --- Loopback ---
/interface bridge add name=loopback
/ip address add address=10.10.10.6/32 interface=loopback

# --- IP-адреса на магистральных интерфейсах ---
/ip address
add address=10.10.6.2/30 interface=ether1 comment="Магистраль до R01.LBN"

# === OSPF ===
/routing ospf instance
set default router-id=10.10.10.6

/routing ospf network
add area=backbone network=10.10.6.0/30
add area=backbone network=10.10.10.6/32

# === MPLS LDP ===
/mpls ldp
set enabled=yes transport-address=10.10.10.6 lsr-id=10.10.10.6

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
add address=192.168.30.1/24 interface=ether2 comment="VRF_DEVOPS - PC3 Сан-Вали"

# --- iBGP с Route Reflectors ---
# R01.SVL пирится с обоими Route Reflectors (R01.LND и R01.HKI),
# чтобы получать VPN-маршруты от других PE-роутеров.
# Два пира — для отказоустойчивости: если один RR упадёт,
# маршруты всё равно придут через второй.
/routing bgp instance
set default as=65530 router-id=10.10.10.6

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
# 4. Перенастроить PC3: ip addr add 192.168.100.3/24 dev eth1
#
# /interface vpls
# add name=VPLS_to_NY remote-peer=10.10.10.1 vpls-id=65530:100 disabled=no
# add name=VPLS_to_SPB remote-peer=10.10.10.5 vpls-id=65530:100 disabled=no
#
# /interface bridge add name=VPLS_bridge
#
# /interface bridge port
# add bridge=VPLS_bridge interface=ether2
# add bridge=VPLS_bridge interface=VPLS_to_NY
# add bridge=VPLS_bridge interface=VPLS_to_SPB
