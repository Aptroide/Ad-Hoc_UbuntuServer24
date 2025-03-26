# Configuración de Tarjeta de Red Externa y Modo Ad-Hoc en Ubuntu Server 24

## 1. Configurar la Tarjeta de Red Externa

Editar el archivo de configuración de Netplan:

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

Añadir la siguiente configuración para redes abiertas:
```yaml
network:
  version: 2
  ethernets:
    eth0:
      optional: true
      dhcp4: true
  wifis:
    <interfaz-name>:
      dhcp4: true
      access-points:
        "SSI Name": {}
```

o para redes cerradas:
```yaml
network:
  version: 2
  ethernets:
    eth0:
      optional: true
      dhcp4: true
  wifis:
    <interfaz-name>:
        dhcp4: true
        access-points:
        SSID_SinEspacios:
            password: "CONTRASEÑA"
```


Aplicar la configuración:

```bash
sudo netplan apply
```

## 2. Instalar Dependencias de Red

Actualizar paquetes e instalar herramientas necesarias:

```bash
sudo apt update
sudo apt install iw wpasupplicant iwd
```

## 3. Crear un Servicio systemd para Ejecutar el Script en el Arranque

Crear un nuevo servicio systemd:

```bash
sudo nano /etc/systemd/system/wifi-adhoc.service
```

Agregar el siguiente contenido:

```ini
[Unit]
Description=Configurar WiFi en modo Ad-Hoc
After=network-pre.target
Before=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wifi-adhoc.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```
## 4. Crear el Script Bash para Configurar Modo Ad-Hoc

Crear el script:
```bash
sudo nano /usr/local/bin/wifi-adhoc.sh
```

Añadir el siguiente código modificando la IP y la interfaz de red (wlan0) que se necesita:

```bash
#!/bin/bash
ip link set wlan0 down
sleep 2

iw dev wlan0 set type ibss
sleep 2

ip link set wlan0 up
sleep 2

iw dev wlan0 ibss join MiRedAdHoc 2437
sleep 2

ip addr flush dev wlan0
ip addr add 192.168.1.20/24 dev wlan0
sleep 2
```

## 5. Desactivar DHCP
Editar la configuración de la interfaz `wlan0` (cambiar si es necesario):

```bash
sudo nano /etc/systemd/network/10-wifi-adhoc.network
```
Añadir la configuración:

```ini
[Match]
Name=wlan0

[Network]
Address=192.168.1.20/24
Gateway=192.168.1.1
DNS=8.8.8.8
DHCP=no
```

## 6. Configurar IP Fija en la Red Ad-Hoc

Crear un nuevo archivo de configuración:
```bash
sudo nano /etc/systemd/network/10-wifi-adhoc.network
```
Añadir la configuración:
```ini
[Match]
Name=wlan0

[Network]
Address=192.168.1.20/24
Gateway=192.168.1.1
DNS=8.8.8.8
DHCP=no
LinkLocalAddressing=no
IPv6AcceptRA=no
MulticastDNS=yes
```

## 7. Deshabilitar Configuración en `/usr/lib/systemd/network/`

Renombrar el archivo existente para deshabilitarlo:
```bash
sudo mv /usr/lib/systemd/network/80-wifi-adhoc.network /usr/lib/systemd/network/80-wifi-adhoc.network.bak
```

## 8. Aplicar Cambios y Habilitar el Servicio
Hacer el script ejecutable:
```bash
sudo chmod +x /usr/local/bin/wifi-adhoc.sh
```
Reiniciar el servicio de red:
```bash
sudo systemctl restart systemd-networkd
sudo systemctl daemon-reload
sudo systemctl enable wifi-adhoc.service
sudo systemctl start wifi-adhoc.service
sudo reboot
```

## 9. Verificar Funcionamiento del Modo Ad-Hoc

Ejecutar los siguientes comandos para verificar la configuración:
```bash
iw dev wlan0 info
ip addr show wlan0
networkctl status wlan0
```
