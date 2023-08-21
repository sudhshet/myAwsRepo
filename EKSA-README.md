# EKS-A HW BIOS settings, Plugins Installation and Configurations needed for NEC CU/DU onboarding

This page describes all the pre-requisites - BIOS & Kernel settings on the EKSA HPE DL110 workers and other plugin packages needed for NEC CU onboarding.

## 1. BIOS settings (At each Worker)

The BIOS settings for the HPE DL110 Worker nodes must be configured as per the below reference table -

![BIOS-Settings-Reference-main](images/BIOS-Settings-Reference-main.png){:height="550px" width=550px"}

### 1.1. Processor Options

* Change Workload Profile to `Custom`

![Workload-Profile](images/Workload-Profile.png){:height="600px" width="600px"}

### 1.2. Ensure Intel Hyper Threading is enabled under - RBSU -> Processor Options

![hyper-threading](images/hyper-threading.png){:height="600px" width="600px"}

### 1.3. Go to RBSU -> Power and Performance Options and change the following -

* Change Power Regulator to Static High Perfomance Mode
* Change Idle Power Core C-State to No C-states
* Change Idle Power Power Package C-State to No Package State
* Change Intel Turbo Boost to Disabled
* Change Energy/Performance Bias to Maximum Performance

![Turbo-Boost-Performance](images/Turbo-Boost-Performance.png){:height="600px" width="600px"}

### 1.4. Navigate to RBSU -> Power and Performance Options -> Processor Prefetch Options

* Make sure LLC Prefetch is Enabled

![LLC-Prefetch](images/LLC-Prefetch.png){:height="600px" width="600px"}

### 1.5. Navigate to RBSU -> Virtualization Options

* Make sure Intel-VT is Enabled
* Make sure SR-IOV is Enabled

![Virtualization-Technology-SRIOV](images/Virtualization-Technology-SRIOV.png){:height="600px" width="600px"}

### 1.6. Navigate to RBSU -> Server Security

* Make sure Secure Boot is Disabled

![Secure-Boot](images/Secure-Boot.png){:height="600px" width="600px"}

### 1.7. Navigate to RBSU -> Power and performance options -> Advanced Performance tuning options

Validate AVX settings (TBC)

![AVX](images/AVX.png){:height="600px" width="600px"}

## 2. GRUB config & Enable /etc/rc.local (on each worker node)

### 2.1. GRUB changes - For RAN applications - CPU isolation and affinity and huge page allocations (On each Worker)

Connect to the worker node via ssh from the Admin Server and then edit the grub config using following command -

```sh
sudo su
cd /etc/default/
vi grub

```
Edit the following lines. Comment the xisting GRUB_CMDLINE_LINUX_DEFAULT variable and add a new line as shown below -

```
#GRUB_CMDLINE_LINUX_DEFAULT="autoinstall ds=nocloud-net;s=http://10.0.2.2:8057/22.04/"
GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on iommu=pt vfio_pci.enable_sriov=1 vfio_pci.disable_idle_d3=1 usbcore.autosuspend=-1 selinux=0 enforcing=0 nmi_watchdog=0 crashkernel=auto softlockup_panic=0 audit=0 mce=off hugepagesz=1G hugepages=30 hugepagesz=2M hugepages=0 default_hugepagesz=1G kthread_cpus=0-28,35-63 irqaffinity=0-28,35-63 skew_tick=1 isolcpus=managed_irq,domain,29-34 intel_pstate=disable nosoftlockup tsc=nowatchdog nohz=on nohz_full=29-34 rcu_nocbs=29-34 rcu_nocb_poll"
```

Save the file and exit - :wq!

Run the following command to apply the new grub config and then perform a reboot of the worker node.

```sh
update-grub
sudo reboot
```
After the node reboots - login into the worker node and validate if the settings have taken effect with the command - `cat /proc/cmdline`

```
root@eksa-wk01:~# cat /proc/cmdline
BOOT_IMAGE=/boot/vmlinuz-5.15.0-78-generic root=UUID=4cf853e5-3a6b-4914-a4b8-54b89690b31c ro intel_iommu=on iommu=pt vfio_pci.enable_sriov=1 vfio_pci.disable_idle_d3=1 usbcore.autosuspend=-1 selinux=0 enforcing=0 nmi_watchdog=0 crashkernel=auto softlockup_panic=0 audit=0 mce=off hugepagesz=1G hugepages=30 hugepagesz=2M hugepages=0 default_hugepagesz=1G kthread_cpus=0-28,35-63 irqaffinity=0-28,35-63 skew_tick=1 isolcpus=managed_irq,domain,29-34 intel_pstate=disable nosoftlockup tsc=nowatchdog nohz=on nohz_full=29-34 rcu_nocbs=29-34 rcu_nocb_poll
```

### 2.2 Enable /etc/rc.local

Certain Multus and SRIOV configurations are not persistent across worker node reboot - thus they have to be added to run control scripts. Thus we need to be enable rc-local on the Ubuntu worker nodes. 

Execute the following vi command to create a service file -

```sh
cat > /etc/systemd/system/rc-local.service << EOF 
[Unit]
 Description=/etc/rc.local Compatibility
 ConditionPathExists=/etc/rc.local
[Service]
 Type=forking
 ExecStart=/etc/rc.local start
 TimeoutSec=0
 StandardOutput=tty
 RemainAfterExit=yes
 SysVStartPriority=99
[Install]
 WantedBy=multi-user.target
EOF
```


Execute the following commands to create a new /etc/rc.local file, provide execute permissions and then enable/restart rc-local service -

```sh
cat > /etc/rc.local << EOF
#!/bin/bash
echo "Script to run startup command on reboot"
EOF
sudo chmod +x /etc/rc.local
sudo systemctl enable rc-local
sudo systemctl restart rc-local
sudo systemctl status rc-local
```

## 3. Plugins - Multus, IPvlan, MACvlan, SRIOV/DPDK

### 3.1. Configure VF for SRIOV DPDK interface

![tamagawa-eksa-wk-port](images/tamagawa-eksa-wk-port.png)

* Retrieve current NIC info.

```sh
lspci | grep Ethernet
6c:00.0 Ethernet controller: Intel Corporation Ethernet Controller E810-C for SFP (rev 02)
6c:00.1 Ethernet controller: Intel Corporation Ethernet Controller E810-C for SFP (rev 02)
6c:00.2 Ethernet controller: Intel Corporation Ethernet Controller E810-C for SFP (rev 02)
6c:00.3 Ethernet controller: Intel Corporation Ethernet Controller E810-C for SFP (rev 02)
99:00.0 Ethernet controller: Intel Corporation Ethernet Controller E810-C for SFP (rev 02)
99:00.1 Ethernet controller: Intel Corporation Ethernet Controller E810-C for SFP (rev 02)
99:00.2 Ethernet controller: Intel Corporation Ethernet Controller E810-C for SFP (rev 02)
99:00.3 Ethernet controller: Intel Corporation Ethernet Controller E810-C for SFP (rev 02)
```

* Create 4 VFs over ens14f3 port.

```sh
echo 4 > /sys/class/net/ens14f3/device/sriov_numvfs
```

* Check configuration.

```sh
lspci | grep "Virtual Function"
6c:19.0 Ethernet controller: Intel Corporation Ethernet Adaptive Virtual Function (rev 02)
6c:19.1 Ethernet controller: Intel Corporation Ethernet Adaptive Virtual Function (rev 02)
6c:19.2 Ethernet controller: Intel Corporation Ethernet Adaptive Virtual Function (rev 02)
6c:19.3 Ethernet controller: Intel Corporation Ethernet Adaptive Virtual Function (rev 02)
````

### 3.2. DPDK21.11 Installation (At each Worker)

* Prerequisite

```sh
sudo su
apt-get update
apt-get install git libnuma-dev libhugetlbfs-dev build-essential cmake meson pkgconf python3-pyelftools
```

* Install DPDK21.11

```sh
# with root-permission
cd /opt/
wget http://static.dpdk.org/rel/dpdk-21.11.tar.xz
tar xf /opt/dpdk-21.11.tar.xz

cd dpdk-21.11
meson build
ninja -C build
ninja -C build install

# check DPDK
cd usertools/
./dpdk-devbind.py -s
```

* Binding VFs to DPDK vfio-pci drivers.

```sh
./dpdk-devbind.py -b vfio-pci 6c:19.0 6c:19.1 6c:19.2 6c:19.3
```

### 3.3 Multus CNI plugin Installation (at Admin)

* Install Multus plugin from the Multus Github link (this step to be done at Admin machine where you run kubectl)

```sh
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml
kubectl get daemonsets.apps -n kube-system
```

#### 3.3.1 Multus Macvlan & IPvlan Tests

* Create MACvlan and IPvlan NetworkAttachmentDefinitions using the following commands. Please note the interface name should be changed to the relevant Interface used for Multus - 

```sh
cat > nad.yaml <<EOF
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: macvlan-conf
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "macvlan",
      "master": "ens14f2",
      "mode": "bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "192.168.20.0/24",
        "rangeStart": "192.168.20.10",
        "rangeEnd": "192.168.20.50",
        "routes": [
          { "dst": "0.0.0.0/0" }
        ],
        "gateway": "192.168.20.1"
      }
    }'
---
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: ipvlan-conf
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "ipvlan",
      "master": "ens14f2",
      "mode": "l2",
      "ipam": {
        "type": "host-local",
        "subnet": "192.168.20.0/24",
        "rangeStart": "192.168.20.10",
        "rangeEnd": "192.168.20.50",
        "routes": [
          { "dst": "0.0.0.0/0" }
        ],
        "gateway": "192.168.20.1"
      }
    }'
EOF

kubectl apply -f nad.yaml
```

* Test macvlan multus by deploying sample pods that uses the Macvlan multus NAD.

```sh
cat > multus-macvlan-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multus-macvlan-deployment
spec:  # specification of the pod's contents
  replicas: 4
  selector:
    matchLabels:
      app: multus-macvlan
  template:
    metadata:
      labels:
        app: multus-macvlan
      annotations:
        k8s.v1.cni.cncf.io/networks: macvlan-conf
    spec:
      containers:
      - name: multus-test-pod
        image: praqma/network-multitool:extra
EOF

kubectl apply -f multus-macvlan-deployment.yaml
```

Check pod status and then login into the pods & verify to other pod Multus interface IP

```sh
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/multus# kubectl get pods -o wide
NAME                                         READY   STATUS    RESTARTS   AGE     IP              NODE        NOMINATED NODE   READINESS GATES
multus-macvlan-deployment-6d77847899-54s97   1/1     Running   0          2m30s   192.169.2.15    eksa-wk02   <none>           <none>
multus-macvlan-deployment-6d77847899-cdrbm   1/1     Running   0          2m30s   192.169.1.135   eksa-wk01   <none>           <none>
multus-macvlan-deployment-6d77847899-gq9hn   1/1     Running   0          2m30s   192.169.1.54    eksa-wk01   <none>           <none>
multus-macvlan-deployment-6d77847899-lw8nl   1/1     Running   0          2m30s   192.169.2.243   eksa-wk02   <none>           <none>
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/multus# kubectl exec -ti multus-macvlan-deployment-6d77847899-cdrbm -- bash
bash-5.1# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: net1@if4: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN group default
    link/ether 96:4e:e3:83:89:62 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.168.20.10/24 brd 192.168.20.255 scope global net1
       valid_lft forever preferred_lft forever
93: eth0@if94: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 62:86:b3:3a:55:13 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.169.1.135/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::6086:b3ff:fe3a:5513/64 scope link
       valid_lft forever preferred_lft forever
bash-5.1#
exit
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/multus# kubectl exec -ti multus-macvlan-deployment-6d77847899-gq9hn -- bash
bash-5.1# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: net1@if4: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN group default
    link/ether fa:cb:8d:86:2b:e3 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.168.20.11/24 brd 192.168.20.255 scope global net1
       valid_lft forever preferred_lft forever
95: eth0@if96: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 76:94:3a:8d:ed:7b brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.169.1.54/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::7494:3aff:fe8d:ed7b/64 scope link
       valid_lft forever preferred_lft forever
bash-5.1# ping 192.168.20.10
PING 192.168.20.10 (192.168.20.10) 56(84) bytes of data.
64 bytes from 192.168.20.10: icmp_seq=1 ttl=64 time=0.051 ms
64 bytes from 192.168.20.10: icmp_seq=2 ttl=64 time=0.030 ms
^C
--- 192.168.20.10 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1009ms
rtt min/avg/max/mdev = 0.030/0.040/0.051/0.010 ms
bash-5.1#
```

Delete the deployment to perform IPvlan multus test

```sh
kubectl delete -f multus-macvlan-deployment.yaml
```

* Test IPvlan multus by deploying sample pods that use the IPvlan multus NAD.

```sh
cat > multus-ipvlan-deployment.yaml  << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multus-ipvlan-deployment
spec:  # specification of the pod's contents
  replicas: 4
  selector:
    matchLabels:
      app: multus-ipvlan
  template:
    metadata:
      labels:
        app: multus-ipvlan
      annotations:
        k8s.v1.cni.cncf.io/networks: ipvlan-conf
    spec:
      containers:
      - name: multus-test-pod
        image: praqma/network-multitool:extra
EOF

kubectl apply -f multus-ipvlan-deployment.yaml
```

Check pod status and then login into the pods & verify to other pod Multus interface IP

```sh
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/multus# kubectl get pods -o wide
NAME                                        READY   STATUS    RESTARTS   AGE   IP              NODE        NOMINATED NODE   READINESS GATES
multus-ipvlan-deployment-778cdf4fff-8hnzc   1/1     Running   0          63s   192.169.1.250   eksa-wk01   <none>           <none>
multus-ipvlan-deployment-778cdf4fff-8k6vs   1/1     Running   0          62s   192.169.2.80    eksa-wk02   <none>           <none>
multus-ipvlan-deployment-778cdf4fff-vrwcw   1/1     Running   0          63s   192.169.2.4     eksa-wk02   <none>           <none>
multus-ipvlan-deployment-778cdf4fff-zlwqg   1/1     Running   0          63s   192.169.1.33    eksa-wk01   <none>           <none>
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/multus# kubectl exec -ti multus-ipvlan-deployment-778cdf4fff-8hnzc -- ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: net1@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default
    link/ether 40:a6:b7:9c:58:2a brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.168.20.10/24 brd 192.168.20.255 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::40a6:b700:19c:582a/64 scope link
       valid_lft forever preferred_lft forever
99: eth0@if100: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 5e:9f:bc:d0:c2:4b brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.169.1.250/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::5c9f:bcff:fed0:c24b/64 scope link
       valid_lft forever preferred_lft forever
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/multus# kubectl exec -ti multus-ipvlan-deployment-778cdf4fff-vrwcw -- bash
bash-5.1# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: net1@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default
    link/ether 40:a6:b7:9c:5a:6a brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.168.20.11/24 brd 192.168.20.255 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::40a6:b700:19c:5a6a/64 scope link
       valid_lft forever preferred_lft forever
97: eth0@if98: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether e2:ce:4a:d0:1f:d4 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.169.2.4/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::e0ce:4aff:fed0:1fd4/64 scope link
       valid_lft forever preferred_lft forever
bash-5.1# ping 192.168.20.11
PING 192.168.20.11 (192.168.20.11) 56(84) bytes of data.
64 bytes from 192.168.20.11: icmp_seq=1 ttl=64 time=0.020 ms
64 bytes from 192.168.20.11: icmp_seq=2 ttl=64 time=0.028 ms
^C
--- 192.168.20.11 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1011ms
rtt min/avg/max/mdev = 0.020/0.024/0.028/0.004 ms
```

### 3.4 SRIOV Device Plugin (SRIOV-DP) (at Admin)

* Download packages (e.g. at /home/nucuser1/eksa-mgmt1/plugins)

```sy
git clone https://github.com/intel/sriov-network-device-plugin
```

* Create SRIOV-DP ConfigMap along with VF information in the previou steps.

```sh
cat <<EOF > sriovdp-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sriovdp-config
  namespace: kube-system
data:
  config.json: |
    {
        "resourceList": [{
            "resourceName": "intelnics01",
            "resourcePrefix": "eks-a.io",
            "selectors": {
                "vendors": ["8086"],
                "devices": ["154c", "10ed", "1889"],
                "drivers": ["vfio-pci"],
                "pfNames": ["ens14f3"]
            }
          }
        ]
    }
 EOF
```

* Apply configMap and Daemonset.

```sh
kubectl apply -f sriovdp-configmap.yaml
kubectl apply -f sriov-network-device-plugin/deployments/sriovdp-daemonset.yaml
```

* Verify SRIOV-DP's SRIOV VF discovery.

```sh
kubectl get node eksa-wk01 -o json | jq '.status.allocatable'
{
  "cpu": "64",
  "eks-a.io/intelnics01": "4",  
  "ephemeral-storage": "424730208372",
  "hugepages-1Gi": "30Gi",
  "hugepages-2Mi": "0",
  "memory": "100099604Ki",
  "pods": "110"
}
```

### 3.5. ipvlan, macvlan, host-device plugins

* These plugins are pre-installed from the OS in /opt/cni/bin, so no need to have extra-installation.

### 3.6. SRIOV-CNI Plugin installation (at each Worker)

* Install go-1.16 to build SRIOV-CNI, and then install (this to be done at each worker host to place sriov-cni to each worker's /opt/cni/bin directory)

```sh
cd
wget https://go.dev/dl/go1.16.linux-amd64.tar.gz
tar -xvf go1.16.linux-amd64.tar.gz -C /usr/local/
export PATH=$PATH:/usr/local/go/bin
# check by go env
go env

git clone https://github.com/k8snetworkplumbingwg/sriov-cni.git
cd sriov-cni
git checkout v2.2
mkdir bin
# download and install golint
go get -u -v golang.org/x/lint/golint
cp ~/go/bin/golint bin/
go env -w GO111MODULE=off
make
cd build
cp sriov /opt/cni/bin
```

### NetworkAttachmentDefinition for Multus SRIOV (at Admin)

* Create and apply SRIOV-CNI NetworkAttachmentDefinition (NAD) (at Admin server)

```sh
cat <<EOF > onboardings/sriov-dpdk-nad.yaml
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: sriov-network-cu-u01-01-if00
  annotations:
    k8s.v1.cni.cncf.io/resourceName: eks-a.io/intelnics01
spec:
  config: '{
  "type": "sriov",
  "cniVersion": "0.3.1",
  "name": "sriov-dpdk"
}'
EOF

kubectl create -f onboardings/sriov-dpdk-nad.yaml
```

### 3.7 Adding config to /etc/rc.local (On each worker nodes)

* Take a ssh connection to the worker node and Execute the following commands to make the multus/sriov config persistent across reboots.

```sh
ls /sys/class/net/ |grep ens | while read line; do echo "ip link set dev "$line" up" >> /etc/rc.local; done
echo "echo 4 > /sys/class/net/ens14f3/device/sriov_numvfs" >> /etc/rc.local
echo "/opt/dpdk-21.11/usertools/dpdk-devbind.py -b vfio-pci 6c:19.0 6c:19.1 6c:19.2 6c:19.3" >> /etc/rc.local
```

* Perform a worker node reboot `sudo reboot` and then after it comes up - validate if the configuration is intact -

* Execute `ip -a` and check if all the multus interfaces are UP on the worker node.

* Execute the following command to check if there are 4 VF's displayed against the DPDK Driver -

```sh
/opt/dpdk-21.11/usertools/dpdk-devbind.py -s
```

```sh
root@eksa-wk01:/home/ec2-user# /opt/dpdk-21.11/usertools/dpdk-devbind.py -s

Network devices using DPDK-compatible driver
============================================
0000:6c:19.0 'Ethernet Adaptive Virtual Function 1889' drv=vfio-pci unused=iavf
0000:6c:19.1 'Ethernet Adaptive Virtual Function 1889' drv=vfio-pci unused=iavf
0000:6c:19.2 'Ethernet Adaptive Virtual Function 1889' drv=vfio-pci unused=iavf
0000:6c:19.3 'Ethernet Adaptive Virtual Function 1889' drv=vfio-pci unused=iavf

Network devices using kernel driver
===================================
0000:6c:00.0 'Ethernet Controller E810-C for SFP 1593' if=ens14f0 drv=ice unused=vfio-pci
0000:6c:00.1 'Ethernet Controller E810-C for SFP 1593' if=ens14f1 drv=ice unused=vfio-pci *Active*
0000:6c:00.2 'Ethernet Controller E810-C for SFP 1593' if=ens14f2 drv=ice unused=vfio-pci
0000:6c:00.3 'Ethernet Controller E810-C for SFP 1593' if=ens14f3 drv=ice unused=vfio-pci
0000:99:00.0 'Ethernet Controller E810-C for SFP 1593' if=ens3f0 drv=ice unused=vfio-pci
0000:99:00.1 'Ethernet Controller E810-C for SFP 1593' if=ens3f1 drv=ice unused=vfio-pci
0000:99:00.2 'Ethernet Controller E810-C for SFP 1593' if=ens3f2 drv=ice unused=vfio-pci
0000:99:00.3 'Ethernet Controller E810-C for SFP 1593' if=ens3f3 drv=ice unused=vfio-pci

No 'Baseband' devices detected
==============================

No 'Crypto' devices detected
.....
.....
.....
.....
```

* Execute the following command on the Admin server to check if the DPDK VF's are reflected on the node. "eks-a.io/intelnics01" parameter must be set to 4. 

```sh
kubectl get node <eksa-wk01> -o json | jq '.status.allocatable'
```

```sh
root@nec-nuc1:/home/nucuser1# kubectl get node eksa-wk01 -o json | jq '.status.allocatable'
{
  "cpu": "64",
  "eks-a.io/intelnics01": "4",
  "ephemeral-storage": "424730208372",
  "hugepages-1Gi": "30Gi",
  "hugepages-2Mi": "0",
  "memory": "100099604Ki",
  "pods": "110"
}
```

## 4. Rook Ceph Installation

* Clone the rook git repo to the Local machine and create the CRD's & custom operators

```sh
git clone --single-branch --branch master https://github.com/rook/root.git
cd rook/deploy/examples
kubectl create -f crds.yaml -f common.yaml -f operator.yaml
```

* Edit the cluster.yaml file to allow multiple mon pods per node. A minimum of 3 pods are needed - however since the lab currently has only 2 worker nodes - this parameter must be changed to True.

  Add the `deviceFilter: ^nv.` value parameter under the `storage:` section - this field defines the type of disk used for Rook Ceph storage. Rook identifies a free disk with this name that has no filesystem and build rook ceph on it.

```sh
storage: # cluster level storage configuration and selection
    useAllNodes: true
    useAllDevices: false
    deviceFilter: ^nv.
```

Also edit the following parameter in the cluster.yaml file as there are only 2 Worker nodes - Rook Ceph requires atleast 3 mon pods and thus `allowMultiplePerNode` must be changed to `true`.

```sh
  mon:
    # Set the number of mons to be started. Generally recommended to be 3.
    # For highest availability, an odd number of mons should be specified.
    count: 3
    # The mons should be on unique nodes. For production, at least 3 nodes are recommended for this reason.
    # Mons should only be allowed on the same node for test environments where data loss is acceptable.
    allowMultiplePerNode: true
```

* After changing the cluster.yaml file - create the root-ceph cluster using the following command -

```sh
kubectl create -f cluster.yaml
```

### 4.1. ReadWriteMany Storage on Rook Ceph

* Create a Ceph filesystem for ReadWriteMany storage using the following command -

```sh
kubectl apply -f filesystem.yaml
```

This creates two pods as shown below -

```sh
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/rook-ceph/rook/deploy/examples# kubectl get pods -n rook-ceph -o wide |grep myfs
rook-ceph-mds-myfs-a-ff88585c6-df44x                  2/2     Running     0          80s     192.169.1.32    eksa-wk01   <none>           <none>
rook-ceph-mds-myfs-b-644db95d7-xr56l                  2/2     Running     0          79s     192.169.2.254   eksa-wk02   <none>           <none>
```

* Create a K8S Storage Class for RWX storage using the following commands -

```sh
cat > storageClass-ceph.yaml << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-cephfs
# Change "rook-ceph" provisioner prefix to match the operator namespace if needed
provisioner: rook-ceph.cephfs.csi.ceph.com # driver:namespace:operator
parameters:
  # clusterID is the namespace where the rook cluster is running
  # If you change this namespace, also change the namespace below where the secret namespaces are defined
  clusterID: rook-ceph # namespace:cluster
  # CephFS filesystem name into which the volume shall be created
  fsName: myfs
  # Ceph pool into which the volume shall be created
  # Required for provisionVolume: "true"
  pool: myfs-replicated

  # The secrets contain Ceph admin credentials. These are generated automatically by the operator
  # in the same namespace as the cluster.
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph # namespace:cluster
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph # namespace:cluster
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-cephfs-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph # namespace:cluster
  # (optional) The driver can use either ceph-fuse (fuse) or ceph kernel client (kernel)
  # If omitted, default volume mounter will be used - this is determined by probing for ceph-fuse
  # or by setting the default mounter explicitly via --volumemounter command-line argument.
  # mounter: kernel
reclaimPolicy: Delete
allowVolumeExpansion: true
mountOptions:
  # uncomment the following line for debugging
  #- debug

EOF

kubectl apply -f storageClass-ceph.yaml
```

* Create PVC to test Rook RWX storage -

```sh
cat > pvc-rwx.yaml << EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: rwx-pvc1
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: rook-cephfs
  resources:
    requests:
      storage: 10Gi
EOF

kubectl apply -f pvc-rwx.yaml
```

Check PVC status the following command - `kubectl get pvc`

```sh
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/rook-ceph/rook/deploy/examples# kubectl get pvc
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
rwx-pvc1   Bound    pvc-c5c2846b-723d-47d3-b769-6b9bf7849b20   10Gi       RWX            rook-cephfs       1m
```

* Create Test pods to validate RWX access (parallel read/write) -

```sh
cat > pods-rwx.yaml  << EOF
apiVersion: v1
kind: Pod
metadata:
  name: testpod1-rwx
spec:
  containers:
  - name: app
    image: centos
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo $(hostname) - $(date -u) >> /data/out.txt; sleep 5; done"]
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: rwx-pvc1
      readOnly: false
---
apiVersion: v1
kind: Pod
metadata:
  name: testpod2-rwx
spec:
  containers:
  - name: app
    image: centos
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo $(hostname) - $(date -u) >> /data/out.txt; sleep 5; done"]
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: rwx-pvc1
      readOnly: false
EOF

kubectl apply -f pods-rwx.yaml
```

After the pods are running state - login into one of the pods and validate the parallel write is done to the /data/out.txt file as shown below -

```sh
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/rook-ceph/rook/deploy/examples# kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
testpod1-rwx   1/1     Running   0          29m
testpod2-rwx   1/1     Running   0          27m
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/rook-ceph/rook/deploy/examples# kubectl exec -ti testpod1-rwx -- bash
[root@testpod1-rwx /]# tail -f /data/out.txt
testpod1-rwx - Fri Aug 11 16:52:07 UTC 2023
testpod2-rwx - Fri Aug 11 16:52:11 UTC 2023
testpod1-rwx - Fri Aug 11 16:52:13 UTC 2023
testpod2-rwx - Fri Aug 11 16:52:16 UTC 2023
testpod1-rwx - Fri Aug 11 16:52:18 UTC 2023
testpod2-rwx - Fri Aug 11 16:52:21 UTC 2023
testpod1-rwx - Fri Aug 11 16:52:23 UTC 2023
testpod2-rwx - Fri Aug 11 16:52:26 UTC 2023
testpod1-rwx - Fri Aug 11 16:52:28 UTC 2023
testpod2-rwx - Fri Aug 11 16:52:31 UTC 2023
testpod1-rwx - Fri Aug 11 16:52:33 UTC 2023
testpod2-rwx - Fri Aug 11 16:52:36 UTC 2023
```

### 4.2. ReadWriteOnce Storage on Rook Ceph

* Create Rook Ceph Block storage pool and storage class using the following command -

```sh
cat > ceph-rbd-sc.yaml << EOF
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: replicapool
  namespace: rook-ceph # namespace:cluster
spec:
  failureDomain: osd
  replicated:
    size: 1
    # Disallow setting pool with replica 1, this could lead to data loss without recovery.
    # Make sure you're *ABSOLUTELY CERTAIN* that is what you want
    requireSafeReplicaSize: false
    # gives a hint (%) to Ceph in terms of expected consumption of the total cluster capacity of a given pool
    # for more info: https://docs.ceph.com/docs/master/rados/operations/placement-groups/#specifying-expected-pool-size
    #targetSizeRatio: .5
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-ceph-block
# Change "rook-ceph" provisioner prefix to match the operator namespace if needed
provisioner: rook-ceph.rbd.csi.ceph.com # driver:namespace:operator
parameters:
  # clusterID is the namespace where the rook cluster is running
  # If you change this namespace, also change the namespace below where the secret namespaces are defined
  clusterID: rook-ceph # namespace:cluster

  # If you want to use erasure coded pool with RBD, you need to create
  # two pools. one erasure coded and one replicated.
  # You need to specify the replicated pool here in the `pool` parameter, it is
  # used for the metadata of the images.
  # The erasure coded pool must be set as the `dataPool` parameter below.
  #dataPool: ec-data-pool
  pool: replicapool

  # RBD image format. Defaults to "2".
  imageFormat: "2"

  # RBD image features. Available for imageFormat: "2". CSI RBD currently supports only `layering` feature.
  imageFeatures: layering

  # The secrets contain Ceph admin credentials. These are generated automatically by the operator
  # in the same namespace as the cluster.
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph # namespace:cluster
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph # namespace:cluster
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph # namespace:cluster
  # Specify the filesystem type of the volume. If not specified, csi-provisioner
  # will set default as `ext4`.
  csi.storage.k8s.io/fstype: ext4
# uncomment the following to use rbd-nbd as mounter on supported nodes
#mounter: rbd-nbd
allowVolumeExpansion: true
reclaimPolicy: Delete
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/rook-ceph/rook/deploy/examples# cat pvc-rwo.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: rwo-pvc1
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: rook-ceph-block
  resources:
    requests:
      storage: 10Gi
EOF

kubectl apply -f ceph-rbd-sc.yaml
```

Check PVC status the following command - `kubectl get pvc`

```sh
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/rook-ceph/rook/deploy/examples# kubectl get pvc
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
rwo-pvc1   Bound    pvc-de82f935-d1ff-47fb-8f3c-a93fe0576467   10Gi       RWO            rook-ceph-block   13m
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/rook-ceph/rook/deploy/examples# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM              STORAGECLASS      REASON   AGE
pvc-de82f935-d1ff-47fb-8f3c-a93fe0576467   10Gi       RWO            Delete           Bound    default/rwo-pvc1   rook-ceph-block            13m
```

* Create a Test pod to validate RWO storage volume access -

```sh
cat > pod-rwo.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: testpod-rwo
spec:
  containers:
  - name: app
    image: centos
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo $(hostname) $(date -u) >> /data/out.txt; sleep 5; done"]
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: rwo-pvc1
      readOnly: false
EOF

kubectl apply -f pod-rwo.yaml
```

* Connect to the pod and validate the write are done to the rwo disk volume -

```sh
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/rook-ceph/rook/deploy/examples# kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
testpod-rwo    1/1     Running   0          7m23s
root@nec-nuc1:/home/nucuser1/eksa-mgmt1_20230808/plugins/rook-ceph/rook/deploy/examples# kubectl exec -ti testpod-rwo -- bash
[root@testpod-rwo /]# tail -f /data/out.txt
testpod-rwo Fri Aug 11 16:53:06 UTC 2023
testpod-rwo Fri Aug 11 16:53:11 UTC 2023
testpod-rwo Fri Aug 11 16:53:16 UTC 2023
testpod-rwo Fri Aug 11 16:53:21 UTC 2023
testpod-rwo Fri Aug 11 16:53:26 UTC 2023
testpod-rwo Fri Aug 11 16:53:31 UTC 2023
testpod-rwo Fri Aug 11 16:53:36 UTC 2023
testpod-rwo Fri Aug 11 16:53:41 UTC 2023
testpod-rwo Fri Aug 11 16:53:46 UTC 2023
testpod-rwo Fri Aug 11 16:53:51 UTC 2023
testpod-rwo Fri Aug 11 16:53:56 UTC 2023
^C
[root@testpod-rwo /]#
[root@testpod-rwo /]# exit
```

## 4.3. Rook Ceph Toolbox

* Install rook toolbox to basic checks using the following command -

```sh
kubectl create -f toolbox.yaml
```

* Login into the toolbox pod and execute command to validate the rook ceph status. Please note the output below shows HEALTH_WARN because there are only 2 OSD disk volume as there are only 2 Worker nodes in the NEC lab as of now. Rook CEPH requires a minimum of 3 OSDs.

```sh
kubectl -n rook-ceph exec -ti $(kubectl -n rook-ceph get pods -l "app=rook-ceph-tools" -o jsonpath='{.items[*].metadata.name}') -- bash
bash-4.4$ ceph status
  cluster:
    id:     a67866b8-fb10-411f-ba6c-dbe5dd565c16
    health: HEALTH_WARN
            Degraded data redundancy: 27/107 objects degraded (25.234%), 16 pgs degraded, 64 pgs undersized
            1 pool(s) have no replicas configured
            OSD count 2 < osd_pool_default_size 3

  services:
    mon: 3 daemons, quorum a,b,c (age 16h)
    mgr: a(active, since 16h), standbys: b
    mds: 1/1 daemons up, 1 hot standby
    osd: 2 osds: 2 up (since 16h), 2 in (since 16h)

  data:
    volumes: 1/1 healthy
    pools:   3 pools, 96 pgs
    objects: 53 objects, 21 MiB
    usage:   44 MiB used, 894 GiB / 894 GiB avail
    pgs:     27/107 objects degraded (25.234%)
             48 active+undersized
             32 active+clean
             16 active+undersized+degraded

  io:
    client:   767 B/s rd, 1.3 KiB/s wr, 1 op/s rd, 0 op/s wr

  progress:
    Global Recovery Event (0s)
      [............................]

bash-4.4$ ceph df
--- RAW STORAGE ---
CLASS     SIZE    AVAIL    USED  RAW USED  %RAW USED
nvme   894 GiB  894 GiB  44 MiB    44 MiB          0
TOTAL  894 GiB  894 GiB  44 MiB    44 MiB          0

--- POOLS ---
POOL             ID  PGS   STORED  OBJECTS     USED  %USED  MAX AVAIL
replicapool       1   32  5.4 MiB       26  5.4 MiB      0    850 GiB
myfs-metadata     2   32  954 KiB       25  1.9 MiB      0    425 GiB
myfs-replicated   3   32   44 KiB        2   96 KiB      0    425 GiB
```

## 5. NEC CU/DU On-boarding related configuration

Following sections descirbe the additional changes that were needed on the EKS-A cluster for the NEC CU/DU onboarding

### 5.1 CU on-boarding

#### 5.1.1 Pre-requisites for onboarding (Namespaces, storage class, IPvlan/SRIOV NAD)

* Create Namespaces for CU-CP and CU-UP onboarding

```sh
cat > createNamespaces.sh << EOF
#!/bin/bash
kubectl create ns gnb00000011--cu-c
kubectl create ns gnb00000011--cu-u000000001
EOF

chmod 755 createNamespaces.sh
./createNamespaces.sh
```

* Create Storage classes for RWO volume for CU-OAM components 

```sh
cat > oam-sc.yaml << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: oam-sc-filesystem-01
# Change "rook-ceph" provisioner prefix to match the operator namespace if needed
provisioner: rook-ceph.rbd.csi.ceph.com # driver:namespace:operator
parameters:
  # clusterID is the namespace where the rook cluster is running
  # If you change this namespace, also change the namespace below where the secret namespaces are defined
  clusterID: rook-ceph # namespace:cluster

  # If you want to use erasure coded pool with RBD, you need to create
  # two pools. one erasure coded and one replicated.
  # You need to specify the replicated pool here in the `pool` parameter, it is
  # used for the metadata of the images.
  # The erasure coded pool must be set as the `dataPool` parameter below.
  #dataPool: ec-data-pool
  pool: replicapool

  # RBD image format. Defaults to "2".
  imageFormat: "2"

  # RBD image features. Available for imageFormat: "2". CSI RBD currently supports only `layering` feature.
  imageFeatures: layering

  # The secrets contain Ceph admin credentials. These are generated automatically by the operator
  # in the same namespace as the cluster.
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph # namespace:cluster
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph # namespace:cluster
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph # namespace:cluster
  # Specify the filesystem type of the volume. If not specified, csi-provisioner
  # will set default as `ext4`.
  csi.storage.k8s.io/fstype: ext4
# uncomment the following to use rbd-nbd as mounter on supported nodes
#mounter: rbd-nbd
allowVolumeExpansion: true
reclaimPolicy: Delete
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: oam-sc-filesystem-02
# Change "rook-ceph" provisioner prefix to match the operator namespace if needed
provisioner: rook-ceph.rbd.csi.ceph.com # driver:namespace:operator
parameters:
  # clusterID is the namespace where the rook cluster is running
  # If you change this namespace, also change the namespace below where the secret namespaces are defined
  clusterID: rook-ceph # namespace:cluster

  # If you want to use erasure coded pool with RBD, you need to create
  # two pools. one erasure coded and one replicated.
  # You need to specify the replicated pool here in the `pool` parameter, it is
  # used for the metadata of the images.
  # The erasure coded pool must be set as the `dataPool` parameter below.
  #dataPool: ec-data-pool
  pool: replicapool

  # RBD image format. Defaults to "2".
  imageFormat: "2"

  # RBD image features. Available for imageFormat: "2". CSI RBD currently supports only `layering` feature.
  imageFeatures: layering

  # The secrets contain Ceph admin credentials. These are generated automatically by the operator
  # in the same namespace as the cluster.
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph # namespace:cluster
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph # namespace:cluster
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph # namespace:cluster
  # Specify the filesystem type of the volume. If not specified, csi-provisioner
  # will set default as `ext4`.
  csi.storage.k8s.io/fstype: ext4
# uncomment the following to use rbd-nbd as mounter on supported nodes
#mounter: rbd-nbd
allowVolumeExpansion: true
reclaimPolicy: Delete
EOF

kubectl apply -f oam-sc.yaml
```

* Create IPvlan and SRIOV NetworkAttachmentDefinitions for CU-CP and CU-UP components

```sh
cat > ipvlan-nad.yaml << EOF
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: ipvlan-network-cu-c-01-if01
  namespace: gnb00000011--cu-c
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "ipvlan",
      "master": "ens14f2",
      "mode": "l2",
      "ipam": {
        "type": "static",
        "routes": [
          { "dst": "0.0.0.0/0" }
        ],
        "gateway": "172.18.30.1"
      }
    }'
---
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: ipvlan-network-cu-u01-01-if01
  namespace: gnb00000011--cu-u000000001
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "ipvlan",
      "master": "ens14f2",
      "mode": "l2",
      "ipam": {
        "type": "static",
        "routes": [
          { "dst": "0.0.0.0/0" }
        ],
        "gateway": "172.18.30.1"
      }
    }'
EOF

kubectl apply -f ipvlan-nad.yaml
```

```sh
cat > sriov-dpdk-nad.yaml << EOF
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: sriov-network-cu-u01-01-if00
  namespace: gnb00000011--cu-u000000001
  annotations:
    k8s.v1.cni.cncf.io/resourceName: eks-a.io/intelnics01
spec:
  config: '{
  "type": "sriov",
  "cniVersion": "0.3.1",
  "name": "sriov-dpdk"
}'
EOF

kubectl apply -f sriov-dpdk-nad.yaml
```


#### 5.1.2 Kubelet config

NEC CU pods requires setting "security context" on the pods and configuration of fs.mqueue.msg_max and fs.mqueue.msgsize_max sysctl parameters. Thus these parameters had to be allowed in the _kubelet_ config file. To enable these the following lines needs to be added to `/var/lib/kubelet/config.yaml` as shown belown.

```yaml
allowedUnsafeSysctls:
- fs.mqueue.msg_max
- fs.mqueue.msgsize_max
```

```sh
root@eksa-wk01:~# cat /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
cgroupDriver: systemd
clusterDNS:
- 10.96.0.10
clusterDomain: cluster.local
cpuManagerReconcilePeriod: 0s
evictionPressureTransitionPeriod: 0s
fileCheckFrequency: 0s
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 0s
imageMinimumGCAge: 0s
kind: KubeletConfiguration
logging:
  flushFrequency: 0
  options:
    json:
      infoBufferSize: "0"
  verbosity: 0
memorySwap: {}
nodeStatusReportFrequency: 0s
nodeStatusUpdateFrequency: 0s
resolvConf: /run/systemd/resolve/resolv.conf
rotateCertificates: true
runtimeRequestTimeout: 0s
shutdownGracePeriod: 0s
shutdownGracePeriodCriticalPods: 0s
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 0s
syncFrequency: 0s
volumeStatsAggPeriod: 0s
allowedUnsafeSysctls:
- fs.mqueue.msg_max
- fs.mqueue.msgsize_max
```

After this yaml file is changed, execute the following command for the changes to take effect -

```sh
systemctl daemon-reload
systemctl restart kubelet
```

Confirm if the configuration has taken effect using the following command -

```sh
ps -ef | grep kubernetes/kubelet  | grep -v grep | sed -e 's/ /\n/g'
```

### 5.1.3 Containerd config

CU pods require Msg queue set to a large value - thus the following config is needed on the containerd service override yaml. This override yaml configures the systctl limits.

```sh
root@eksa-wk01:/etc# cat /etc/systemd/system/containerd.service.d/override.conf
[Service]
LimitMSGQUEUE=700028840000
```

After this yaml file is changed, execute the following command for the changes to take effect -

```sh
systemctl daemon-reload
systemctl restart containerd
```

Confirm if the configuration has taken effect using the following command -

```sh
cat /proc/$(ps -ef | grep /usr/local/bin/containerd | grep -v containerd-shim-runc-v2 | grep -v grep | awk '{print $2}')/limits
```

## 6. ECR Integration with EKS-A

### 6.0 Reference

* https://anywhere.eks.amazonaws.com/docs/packages/credential-provider-package/iam_roles_anywhere/
* https://docs.aws.amazon.com/rolesanywhere/latest/userguide/getting-started.html

### 6.1 Extract CA certificate from EKS-A cluster (Admin server)

Extract CA certificate from EKS-A cluster.

```sh
CLUSTER_NAME=eksa-mgmt1
export KUBECONFIG=${HOME}/${CLUSTER_NAME}/${CLUSTER_NAME}-eks-a-cluster.kubeconfig
kubectl get secret -n eksa-system ${CLUSTER_NAME}-ca -o yaml | yq '.data."tls.crt"' | base64 -d
```

```output
-----BEGIN CERTIFICATE-----
MIIC6jCCAdKgAwIBAgIBADANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwprdWJl
cm5ldGVzMB4XDTIzMDgxMDAzNDQ0OFoXDTMzMDgwNzAzNDk0OFowFTETMBEGA1UE
AxMKa3ViZXJuZXRlczCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANL3
sqlCTes9ydUD9meeLKLBlm6br0zONbZwd6tf8aHIY0stUyQyBkwWe2XwogXxUge/
jaa2rXQojQN6/lk8y9zLCz2NlWWeNdIgGaLoBy9W63IQoq8i0MJ6LFKPScNYzfjg
daAZIqM+OtSYgPPS6D5Pq5WU469mXJnFRTaNeGQXLgTwfzZAavt+lgaoDgRodp/m
wh3+0DzDijrux/1Tx6tbeERNZyZ7O+ysw7vwEDr9Gi0Shrj5haKYUib8cLTyP+hG
Ras/5Y1ds8Yw2xunvtmVt42QU7SQsHr/gbre8uTcTe4p3VR9ZQrW+HImn3S46SFG
GwtTGLCcUd05z2Rw4G0CAwEAAaNFMEMwDgYDVR0PAQH/BAQDAgKkMBIGA1UdEwEB
/wQIMAYBAf8CAQAwHQYDVR0OBBYEFH0/HZAspzKEZQAJaxJGuBl5nN89MA0GCSqG
SIb3DQEBCwUAA4IBAQAq0s8Hmn/pk3boxSVTsw/oQsKDMAlW5HMEhQe8YMqSd1De
FbQCD9ToKnvmpfOpgpnDSg3WHmhzGfnL5BuCFBGnQL34jm1ySUNTuH9/DJrhZxvk
4aLaQhHntPP1dN4DV5vV2lzAhbkB1p9mNCXWA8Ky3wJWAv3m3j/fK4AljfiQ+Iip
fnBkFMhrtyK5+yF1aRFgafxESwevsEUp79IRGaXMiwhtZBwAE3CrRUQZxLjMiz4U
+C8WPO7NhgGNgdXA0M8RYMg7o16UA31imykIQfMeeaPUHheYDde/vTTwD5fnsDs9
14EsaA/JsUeAPziSLZECEDZ5ru5K2qOpmEKd3tV9
-----END CERTIFICATE-----
```

### 6.2 Set up IAM Roles Anywhere (AWS Management Console)

#### 6.2.1 Create IAM policy

1. Open IAM Console
2. Create IAM Policy with following policy
3. Keep 783794618700 as is
4. Edit second account id `020448454134` to match your account
5. policy name: eksa-mgmt1-ecr-policy

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ECRRead",
            "Effect": "Allow",
            "Action": [
                "ecr:DescribeImageScanFindings",
                "ecr:GetDownloadUrlForLayer",
                "ecr:DescribeRegistry",
                "ecr:DescribePullThroughCacheRules",
                "ecr:DescribeImageReplicationStatus",
                "ecr:ListTagsForResource",
                "ecr:ListImages",
                "ecr:BatchGetImage",
                "ecr:DescribeImages",
                "ecr:DescribeRepositories",
                "ecr:BatchCheckLayerAvailability"
            ],
            "Resource": [
                "arn:aws:ecr:*:783794618700:repository/*",
                "arn:aws:ecr:*:020448454134:repository/*"
            ]
        },
        {
            "Sid": "ECRLogin",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
        }
    ]
}
```

#### 6.2.2 Create a trust anchor

1. Open IAM Console > Role > Roles Anywhere > **Manage**

![IAM Roles Anywhere](images/iam-roles-anywhere.png){:height="600px" width="600px"}

2. Click **Create a trust anchor**
3. Change region to tokyo
4. Enter cluster name as trust anchor name: eksa-mgmt1

![Create a trust anchor](images/create-trust-anchor.png){:height="600px" width="600px"}

5. Paste the CA certificate

![Paste the CA certificate](images/paste-ca-certificate.png){:height="600px" width="600px"}

6. Click **Create a trust anchor**
7. Check the trust anchor ARN

![Check the trust anchor ARN](images/check-trust-anchor-arn.png){:height="600px" width="600px"}

#### 6.2.3 Create a role

1. Create a role with custom trust policy
2. The aws:SourceArn of the condition is the ARN of the trust anchor.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "rolesanywhere.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession",
                "sts:SetSourceIdentity"
            ],
            "Condition": {
                "ArnEquals": {
                    "aws:SourceArn": "arn:aws:rolesanywhere:ap-northeast-1:020448454134:trust-anchor/5d9092ae-6aa1-4eb3-8d6a-5c251e8f7d75"
                }
            }
        }
    ]
}
```

3. Attach policy you just created: eksa-mgmt1-ecr-policy
4. role name: eksa-mgmt1-ecr-role
5. Check the IAM role ARN

#### 6.2.4 Create a profile

1. Open IAM Console > Role > Roles Anywhere > **Manage**
2. Make sure you are in Tokyo region
3. Click **Create a profile**
4. Enter profile name: eksa-mgmt1
5. Select role you just created

![Create a profile](images/create-profile.png){:height="600px" width="600px"}

6. Click **Create profile**
7. Check the profile ARN

![Check the profile ARN](images/check-profile-arn.png){:height="600px" width="600px"}

### 6.3 Set up credential-provider-package (Admin server)

Set variables from previous step and create a credfile.

```sh
CLUSTER_NAME=eksa-mgmt1
cd ${HOME}/${CLUSTER_NAME}

AWS_REGION=ap-northeast-1
PROFILE_ARN=arn:aws:rolesanywhere:ap-northeast-1:020448454134:profile/ff0384cd-ae04-4cc0-be90-0f2c5c1a62f0
ROLE_ARN=arn:aws:iam::020448454134:role/eksa-mgmt1-ecr-role
TRUST_ANCHOR_ARN=arn:aws:rolesanywhere:ap-northeast-1:020448454134:trust-anchor/5d9092ae-6aa1-4eb3-8d6a-5c251e8f7d75

cat << EOF >> credfile
[default]
region = $AWS_REGION
credential_process = aws_signing_helper credential-process --certificate /var/lib/kubelet/pki/kubelet-client-current.pem --private-key /var/lib/kubelet/pki/kubelet-client-current.pem --profile-arn $PROFILE_ARN --role-arn $ROLE_ARN --trust-anchor-arn $TRUST_ANCHOR_ARN
EOF
```

Create a secret.

```sh
export KUBECONFIG=${HOME}/${CLUSTER_NAME}/${CLUSTER_NAME}-eks-a-cluster.kubeconfig

# Create secret, for this example the secret name aws-config is used and the package will be installed in eksa-packages
kubectl create secret generic aws-config \
  --from-file=config=credfile \
  -n eksa-packages
```

Check the secret.

```sh
kubectl -n eksa-packages get secret
```

![Get secrets](images/get-secrets.png){:height="600px" width="600px"}

List current packages.

```sh
kubectl get package -A
```

![Get packages](images/get-packages.png){:height="800px" width="800px"}

Uninstall the current package.

```sh
eksctl anywhere delete packages ecr-credential-provider-package \
  --cluster ${CLUSTER_NAME} \
  --kubeconfig ${HOME}/${CLUSTER_NAME}/${CLUSTER_NAME}-eks-a-cluster.kubeconfig
```

Create `ecr-credential-provider-package.yaml` file. Second account id should match your account.

```yaml
apiVersion: packages.eks.amazonaws.com/v1alpha1
kind: Package
metadata:
  annotations:
    anywhere.eks.aws.com/internal: "true"
    helm.sh/resource-policy: keep
  name: ecr-credential-provider-package
  namespace: eksa-packages-eksa-mgmt1
spec:
  packageName: credential-provider-package
  targetNamespace: eksa-packages
  config: |-
    tolerations:
      - key: "node-role.kubernetes.io/master"
        operator: "Exists"
        effect: "NoSchedule"
      - key: "node-role.kubernetes.io/control-plane"
        operator: "Exists"
        effect: "NoSchedule"
    sourceRegistry: public.ecr.aws/eks-anywhere
    credential:
      - matchImages:
        - 783794618700.dkr.ecr.*.amazonaws.com
        - 020448454134.dkr.ecr.ap-northeast-1.amazonaws.com
        profile: "default"
        secretName: aws-config
        defaultCacheDuration: "5h"
```

Create a package.

```sh
eksctl anywhere create packages \
  -f ecr-credential-provider-package.yaml \
  --kubeconfig ${HOME}/${CLUSTER_NAME}/${CLUSTER_NAME}-eks-a-cluster.kubeconfig
```

Check ecr-credential-provider pods are running.

```sh
kubectl -n eksa-packages get pod
```

![Get credential provider pods](images/get-credential-provider-pods.png){:height="600px" width="600px"}

Check if you can run a pod from ECR repository.

```sh
kubectl run test --image=222866289084.dkr.ecr.ap-northeast-1.amazonaws.com/test
```

![Run a test pod](images/run-test-pod.png){:height="800px" width="800px"}
