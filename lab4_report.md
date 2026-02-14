# Лабораторная работа №4

## "Эмуляция распределённой корпоративной сети связи, настройка iBGP, организация L3VPN, VPLS"

Университет: Университет ИТМО
Факультет: Инфокоммуникационных технологий
Курс: Введение в маршрутизацию

---

## Цель работы

Изучить протоколы BGP, MPLS и правила организации L3VPN и VPLS.

---

## Описание

Компания "RogalKopita Games" выпустила игру "Allmoney Impact". Нагрузка на серверы возросла, и нужно организовать собственную AS (автономную систему). Коллеги из отдела DEVOPS попросили:
1. Часть 1: Сделать L3VPN между 3 офисами для служебных нужд
2. Часть 2: Переделать L3VPN в VPLS для служебных нужд

---

## Схема сети

```
  PC2 ─── R01.NY ─── R01.LND ──── R01.HKI ─── R01.SPB ─── PC1
(DEVOPS)                 |    \      /   |              (DEVOPS)
                         |    R01.LBN    |
                         |        |      
                         |    R01.SVL    
                         |        |      
                         |      PC3     
                         |    (DEVOPS)   
```

Роли роутеров:
- PE (Provider Edge): R01.NY, R01.SPB, R01.SVL — подключены клиентские ПК
- P (Provider): R01.LBN — только транзит
- RR (Route Reflector): R01.LND, R01.HKI — отражают BGP-маршруты

AS: 65530

---

## Таблица IP-адресации

Loopback-адреса

| Роутер | Loopback | Роль |
|--------|----------|------|
| R01.NY | 10.10.10.1/32 | PE |
| R01.LND | 10.10.10.2/32 | RR №1 |
| R01.LBN | 10.10.10.3/32 | P |
| R01.HKI | 10.10.10.4/32 | RR №2 |
| R01.SPB | 10.10.10.5/32 | PE |
| R01.SVL | 10.10.10.6/32 | PE |

Магистральные каналы

| Канал | Подсеть | Сторона A | Сторона B |
|-------|---------|-----------|-----------|
| NY — LND | 10.10.1.0/30 | R01.NY ether1: .1 | R01.LND ether1: .2 |
| LND — HKI | 10.10.2.0/30 | R01.LND ether2: .1 | R01.HKI ether1: .2 |
| HKI — SPB | 10.10.3.0/30 | R01.HKI ether2: .1 | R01.SPB ether1: .2 |
| LND — LBN | 10.10.4.0/30 | R01.LND ether3: .1 | R01.LBN ether1: .2 |
| HKI — LBN | 10.10.5.0/30 | R01.HKI ether3: .1 | R01.LBN ether2: .2 |
| LBN — SVL | 10.10.6.0/30 | R01.LBN ether3: .1 | R01.SVL ether1: .2 |

Часть 1: L3VPN (VRF_DEVOPS) — разные подсети

| PE-роутер | VRF-интерфейс | Подсеть | Шлюз | ПК |
|-----------|---------------|---------|------|----|
| R01.NY | ether2 | 192.168.10.0/24 | 192.168.10.1 | PC2: 192.168.10.2 |
| R01.SPB | ether2 | 192.168.20.0/24 | 192.168.20.1 | PC1: 192.168.20.2 |
| R01.SVL | ether2 | 192.168.30.0/24 | 192.168.30.1 | PC3: 192.168.30.2 |

VRF параметры:
- RD: 65530:100
- RT Import: 65530:100
- RT Export: 65530:100

Часть 2: VPLS — одна подсеть

| ПК | IP-адрес |
|----|----------|
| PC1 | 192.168.100.1/24 |
| PC2 | 192.168.100.2/24 |
| PC3 | 192.168.100.3/24 |

---

## Технологии, используемые в работе

iBGP (internal BGP)

iBGP — BGP-сессии внутри одной автономной системы. Используется для распространения VPN-маршрутов (vpnv4) между PE-роутерами.

Проблема iBGP: каждый роутер должен иметь сессию с каждым другим, что образует полносвязную mesh-топологию. Для 6 роутеров это 15 сессий!

Решение: Route Reflector. Клиенты отправляют маршруты только рефлектору, а он "отражает" их всем остальным.

Route Reflector Cluster

В нашей сети два Route Reflector: R01.LND и R01.HKI. Они образуют кластер для отказоустойчивости.

BGP-пиринги (все через loopback-адреса):
```
R01.NY ──────→ R01.LND (RR) ←──── R01.LBN ────→ R01.HKI (RR)
                    ↕ (RR ↔ RR)                       ↕
R01.SVL ─────→ R01.LND (RR)                   R01.SPB
R01.SVL ─────→ R01.HKI (RR)
```
Каждый PE/P-роутер пирится хотя бы с одним RR. R01.LBN и R01.SVL пирятся с обоими RR для отказоустойчивости.

L3VPN (Layer 3 VPN)

L3VPN создаёт изолированную виртуальную сеть поверх общей инфраструктуры.

Компоненты:
1. VRF — отдельная таблица маршрутизации на PE-роутере
2. RD (Route Distinguisher) — делает маршруты уникальными в BGP (формат: ASN:число)
3. RT (Route Target) — определяет, какие VRF обмениваются маршрутами
4. MPLS — транспорт для VPN-трафика между PE-роутерами

Как работает:
1. PC2 отправляет пакет на 192.168.20.2 (PC1)
2. R01.NY смотрит в VRF_DEVOPS, находит маршрут через BGP до R01.SPB
3. Пакет инкапсулируется в MPLS-метки и отправляется через P-роутеры
4. R01.SPB снимает метки и доставляет пакет в VRF_DEVOPS, далее к PC1

VPLS (Virtual Private LAN Service)

VPLS — это виртуальный L2-коммутатор через MPLS-сеть. Все ПК оказываются в одном broadcast-домене (одной подсети).

Отличие от L3VPN:
- L3VPN: каждый офис в своей подсети, маршрутизация через VRF
- VPLS: все офисы в одной подсети, коммутация на уровне L2

Реализация: VPLS-интерфейсы + bridge на каждом PE-роутере.

---

## Развёртывание

```bash
cd lab4
sudo containerlab deploy --topo lab4.yaml
```

---

## Часть 1: Результаты проверки L3VPN

1. Проверка OSPF-соседства

R01.LND:

```
[admin@R01.LND] > /routing ospf neighbor print
 # ROUTER-ID       ADDRESS         INTERFACE   STATE     STATE-CHANGES
 0 10.10.10.1      10.10.1.1       ether1      Full            6
 1 10.10.10.4      10.10.2.2       ether2      Full            6
 2 10.10.10.3      10.10.4.2       ether3      Full            5
```

R01.HKI:

```
[admin@R01.HKI] > /routing ospf neighbor print
 # ROUTER-ID       ADDRESS         INTERFACE   STATE     STATE-CHANGES
 0 10.10.10.2      10.10.2.1       ether1      Full            6
 1 10.10.10.5      10.10.3.2       ether2      Full            5
 2 10.10.10.3      10.10.5.2       ether3      Full            5
```

2. Проверка BGP-сессий

R01.NY:

```
[admin@R01.NY] > /routing bgp peer print status
 # NAME       REMOTE-ADDRESS  REMOTE-AS  STATE         UPTIME      PREFIX-COUNT
 0 R01.LND    10.10.10.2      65530      established   00:28:14    2
```

R01.LND (Route Reflector):

```
[admin@R01.LND] > /routing bgp peer print status
 # NAME       REMOTE-ADDRESS  REMOTE-AS  STATE         UPTIME      PREFIX-COUNT
 0 R01.HKI    10.10.10.4      65530      established   00:29:03    2
 1 R01.NY     10.10.10.1      65530      established   00:28:14    1
 2 R01.LBN    10.10.10.3      65530      established   00:27:45    0
 3 R01.SVL    10.10.10.6      65530      established   00:26:31    1
```

R01.SPB:

```
[admin@R01.SPB] > /routing bgp peer print status
 # NAME       REMOTE-ADDRESS  REMOTE-AS  STATE         UPTIME      PREFIX-COUNT
 0 R01.HKI    10.10.10.4      65530      established   00:27:52    2
```

Все BGP-сессии в состоянии established — пиринг работает.

3. Проверка VRF-маршрутов

R01.NY:

```
[admin@R01.NY] > /ip route print where routing-mark=VRF_DEVOPS
Flags: X - disabled, A - active, D - dynamic,
C - connect, S - static, r - rip, b - bgp, o - ospf, m - mme,
B - blackhole, U - unreachable, P - prohibit
 #      DST-ADDRESS        PREF-SRC        GATEWAY            DISTANCE
 0 ADC  192.168.10.0/24    192.168.10.1    ether2                    0
 1 ADb  192.168.20.0/24                    10.10.10.5              200
 2 ADb  192.168.30.0/24                    10.10.10.6              200
```

R01.SPB:

```
[admin@R01.SPB] > /ip route print where routing-mark=VRF_DEVOPS
Flags: X - disabled, A - active, D - dynamic,
C - connect, S - static, r - rip, b - bgp, o - ospf, m - mme,
B - blackhole, U - unreachable, P - prohibit
 #      DST-ADDRESS        PREF-SRC        GATEWAY            DISTANCE
 0 ADb  192.168.10.0/24                    10.10.10.1              200
 1 ADC  192.168.20.0/24    192.168.20.1    ether2                    0
 2 ADb  192.168.30.0/24                    10.10.10.6              200
```

R01.SVL:

```
[admin@R01.SVL] > /ip route print where routing-mark=VRF_DEVOPS
Flags: X - disabled, A - active, D - dynamic,
C - connect, S - static, r - rip, b - bgp, o - ospf, m - mme,
B - blackhole, U - unreachable, P - prohibit
 #      DST-ADDRESS        PREF-SRC        GATEWAY            DISTANCE
 0 ADb  192.168.10.0/24                    10.10.10.1              200
 1 ADb  192.168.20.0/24                    10.10.10.5              200
 2 ADC  192.168.30.0/24    192.168.30.1    ether2                    0
```

ADb — BGP dynamic (маршрут, полученный через BGP, distance 200)

4. Пинг между VRF (L3VPN)

PC2 (Нью-Йорк) → PC1 (Санкт-Петербург):

```
root@PC2:/# ping 192.168.20.2 -c 4
PING 192.168.20.2 (192.168.20.2): 56 data bytes
64 bytes from 192.168.20.2: seq=0 ttl=61 time=22.847 ms
64 bytes from 192.168.20.2: seq=1 ttl=61 time=5.631 ms
64 bytes from 192.168.20.2: seq=2 ttl=61 time=5.204 ms
64 bytes from 192.168.20.2: seq=3 ttl=61 time=4.918 ms

--- 192.168.20.2 ping statistics ---
4 packets transmitted, 4 packets received, 0% packet loss
round-trip min/avg/max = 4.918/9.650/22.847 ms
```

PC2 (Нью-Йорк) → PC3 (Сан-Вали):

```
root@PC2:/# ping 192.168.30.2 -c 4
PING 192.168.30.2 (192.168.30.2): 56 data bytes
64 bytes from 192.168.30.2: seq=0 ttl=61 time=20.134 ms
64 bytes from 192.168.30.2: seq=1 ttl=61 time=6.217 ms
64 bytes from 192.168.30.2: seq=2 ttl=61 time=5.483 ms
64 bytes from 192.168.30.2: seq=3 ttl=61 time=5.102 ms

--- 192.168.30.2 ping statistics ---
4 packets transmitted, 4 packets received, 0% packet loss
round-trip min/avg/max = 5.102/9.234/20.134 ms
```

PC1 (Санкт-Петербург) → PC3 (Сан-Вали):

```
root@PC1:/# ping 192.168.30.2 -c 4
PING 192.168.30.2 (192.168.30.2): 56 data bytes
64 bytes from 192.168.30.2: seq=0 ttl=61 time=19.526 ms
64 bytes from 192.168.30.2: seq=1 ttl=61 time=5.891 ms
64 bytes from 192.168.30.2: seq=2 ttl=61 time=5.347 ms
64 bytes from 192.168.30.2: seq=3 ttl=61 time=4.762 ms

--- 192.168.30.2 ping statistics ---
4 packets transmitted, 4 packets received, 0% packet loss
round-trip min/avg/max = 4.762/8.881/19.526 ms
```

L3VPN работает: все три ПК DEVOPS видят друг друга через VRF, 0% потерь.

5. Таблица маршрутизации R01.LND (Route Reflector)

```
[admin@R01.LND] > /ip route print
Flags: X - disabled, A - active, D - dynamic,
C - connect, S - static, r - rip, b - bgp, o - ospf, m - mme,
B - blackhole, U - unreachable, P - prohibit
 #      DST-ADDRESS        PREF-SRC        GATEWAY            DISTANCE
 0 ADC  10.10.1.0/30       10.10.1.2       ether1                    0
 1 ADC  10.10.2.0/30       10.10.2.1       ether2                    0
 2 ADo  10.10.3.0/30                       10.10.2.2               110
 3 ADC  10.10.4.0/30       10.10.4.1       ether3                    0
 4 ADo  10.10.5.0/30                       10.10.4.2               110
 5 ADo  10.10.6.0/30                       10.10.4.2               110
 6 ADo  10.10.10.1/32                      10.10.1.1               110
 7 ADC  10.10.10.2/32      10.10.10.2      loopback                  0
 8 ADo  10.10.10.3/32                      10.10.4.2               110
 9 ADo  10.10.10.4/32                      10.10.2.2               110
10 ADo  10.10.10.5/32                      10.10.2.2               110
11 ADo  10.10.10.6/32                      10.10.4.2               110
```

---

## Часть 2: Переход на VPLS

Шаг 1: Разборка VRF на каждом PE-роутере

На R01.NY, R01.SPB и R01.SVL выполнить:

```
/ip route vrf remove [find routing-mark=VRF_DEVOPS]
/ip address remove [find interface=ether2]
```

Шаг 2: Настройка VPLS

На R01.NY:
```
/interface vpls
add name=VPLS_to_SPB remote-peer=10.10.10.5 vpls-id=65530:100 disabled=no
add name=VPLS_to_SVL remote-peer=10.10.10.6 vpls-id=65530:100 disabled=no

/interface bridge add name=VPLS_bridge

/interface bridge port
add bridge=VPLS_bridge interface=ether2
add bridge=VPLS_bridge interface=VPLS_to_SPB
add bridge=VPLS_bridge interface=VPLS_to_SVL
```

На R01.SPB:
```
/interface vpls
add name=VPLS_to_NY remote-peer=10.10.10.1 vpls-id=65530:100 disabled=no
add name=VPLS_to_SVL remote-peer=10.10.10.6 vpls-id=65530:100 disabled=no

/interface bridge add name=VPLS_bridge

/interface bridge port
add bridge=VPLS_bridge interface=ether2
add bridge=VPLS_bridge interface=VPLS_to_NY
add bridge=VPLS_bridge interface=VPLS_to_SVL
```

На R01.SVL:
```
/interface vpls
add name=VPLS_to_NY remote-peer=10.10.10.1 vpls-id=65530:100 disabled=no
add name=VPLS_to_SPB remote-peer=10.10.10.5 vpls-id=65530:100 disabled=no

/interface bridge add name=VPLS_bridge

/interface bridge port
add bridge=VPLS_bridge interface=ether2
add bridge=VPLS_bridge interface=VPLS_to_NY
add bridge=VPLS_bridge interface=VPLS_to_SPB
```

Шаг 3: Перенастройка IP на ПК

```bash
# PC1:
ip addr flush dev eth1
ip addr add 192.168.100.1/24 dev eth1

# PC2:
ip addr flush dev eth1
ip addr add 192.168.100.2/24 dev eth1

# PC3:
ip addr flush dev eth1
ip addr add 192.168.100.3/24 dev eth1
```

Шаг 4: Результаты проверки VPLS

PC1 → PC2:

```
root@PC1:/# ping 192.168.100.2 -c 4
PING 192.168.100.2 (192.168.100.2): 56 data bytes
64 bytes from 192.168.100.2: seq=0 ttl=64 time=17.632 ms
64 bytes from 192.168.100.2: seq=1 ttl=64 time=4.518 ms
64 bytes from 192.168.100.2: seq=2 ttl=64 time=4.205 ms
64 bytes from 192.168.100.2: seq=3 ttl=64 time=3.891 ms

--- 192.168.100.2 ping statistics ---
4 packets transmitted, 4 packets received, 0% packet loss
round-trip min/avg/max = 3.891/7.561/17.632 ms
```

PC1 → PC3:

```
root@PC1:/# ping 192.168.100.3 -c 4
PING 192.168.100.3 (192.168.100.3): 56 data bytes
64 bytes from 192.168.100.3: seq=0 ttl=64 time=15.917 ms
64 bytes from 192.168.100.3: seq=1 ttl=64 time=5.204 ms
64 bytes from 192.168.100.3: seq=2 ttl=64 time=4.637 ms
64 bytes from 192.168.100.3: seq=3 ttl=64 time=4.329 ms

--- 192.168.100.3 ping statistics ---
4 packets transmitted, 4 packets received, 0% packet loss
round-trip min/avg/max = 4.329/7.521/15.917 ms
```

PC2 → PC3:

```
root@PC2:/# ping 192.168.100.3 -c 4
PING 192.168.100.3 (192.168.100.3): 56 data bytes
64 bytes from 192.168.100.3: seq=0 ttl=64 time=16.283 ms
64 bytes from 192.168.100.3: seq=1 ttl=64 time=4.891 ms
64 bytes from 192.168.100.3: seq=2 ttl=64 time=4.472 ms
64 bytes from 192.168.100.3: seq=3 ttl=64 time=4.106 ms

--- 192.168.100.3 ping statistics ---
4 packets transmitted, 4 packets received, 0% packet loss
round-trip min/avg/max = 4.106/7.438/16.283 ms
```

TTL=64 — пакеты идут на уровне L2 (коммутация через VPLS-мост), а не L3 (маршрутизация). VPLS работает корректно.

---

## Вывод

В ходе лабораторной работы была построена IP/MPLS сеть с внедрённым BGPv4 для компании "RogalKopita Games". Выполнены две части:

Часть 1 — L3VPN:
- Настроен OSPF и MPLS LDP на всех роутерах (все OSPF-соседства Full)
- Создан iBGP Route Reflector кластер (R01.LND + R01.HKI, все сессии established)
- На PE-роутерах (R01.NY, R01.SPB, R01.SVL) настроен VRF_DEVOPS с одинаковыми RD и RT
- Проверена связность между ПК отдела DEVOPS — 0% потерь, TTL=61

Часть 2 — VPLS:
- VRF разобран на PE-роутерах
- Настроен VPLS — виртуальный L2-коммутатор через MPLS
- Все ПК DEVOPS помещены в одну подсеть 192.168.100.0/24
- Проверена L2-связность — 0% потерь, TTL=64
