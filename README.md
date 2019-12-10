# Kafka Cluster and Monitoring setup

* [Section 1 : Kafka Cluster Setup](#section-1--kafka-cluster-setup)
    * [1.1 Zookeeper Theory Part](#11-zookeeper-theory-part)
    * [1.2 Zookeeper Single instance setup](#12-zookeeper-single-instance-setup)
    * [1.3 Zookeeper Cluster setup](#13-zookeeper-cluster-setup)
    * [1.4 Kafka Theory Part](#14-kafka-theory-part)
    * [1.5 Kafka Single Instance setup](#15-kafka-single-instance-setup)
    * [1.6 Kafka Cluster setup](#16-kafka-cluster-setup)
    * [1.7 Kafka Configuration Detail](#17-kafka-performance-and-configuration-detail)

* [Section 2 : Admin Tools setup for Zookeeper and Kafka](#section-2--admin-tools-setup-for-zookeeper-and-kafka)
    * [2.1 Zoo navigator setup](#21-zoo-navigator-setup)
    * [2.2 Kafka Manager](#22-kafka-manager)

* [Section 3 : Monitoring Tools setup for Zookeeper and Kafka](#section-3--monitoring-tools-setup-for-zookeeper-and-kafka)
    * [3.1 Kafka Monitor UI](#31-kafka-monitor-ui)
    * [3.2 Prometheus setup for Zookeeper and Kafka](#32-prometheus-setup-for-zookeeper-and-kafka)
    * [3.3 Install Grafana and setup Dashboard](#33-install-grafana-and-setup-dashboard)

# Section 1 : Kafka Cluster setup
In this section we are going perform below steps to setup a stable Kafka cluster:
* Zookeeper Cluster
* Kafka Cluster
* Proper replication factor
* Proper configurations
* Administration tools
* HA setting for the cluster

For this course I am using three VMs, each has ubuntu 18.04 and Open JDK 8 install on it. We will setup zookeeper and 
kafka on each of these three nodes. This is not recommended practice to setup Kafka and zookeeper co-located or I can say
on one server for production. 

We have done static IP setup has for each of virtual machine, this is necessary to have static IP or DNS which can 
resolve to our HOST. For current setup we have below IP and node name respectively.
* Node 1 - 192.168.109.131
* Node 2 - 192.168.109.132
* Node 3 - 192.168.109.133

If you don't setup your IP static then it will create a problem in cluster every time you restart machine, due to change 
in IP assigned dynamically to machine. To setup the static ip we edit '/etc/netplan/*.yml' file in Ubuntu 18.04 and
changed file like below:
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
     dhcp4: no
     addresses: [192.168.109.132/24]
     gateway4: 192.168.109.2
     nameservers:
       addresses: [192.168.109.2,8.8.8.8,8.8.4.4]
```
In above case 192.168.109.132 is static IP for that machine, Please make sure it will be assigned to unique machine in
your cluster.

## 1.1 Zookeeper Theory Part
Let's first understand what a zookeeper is and what it does for us. 
* Zookeeper operates on Quorum Architecture. Minimum number of servers required to run the Zookeeper is called 
[Quorum](https://stackoverflow.com/questions/25174622/difference-between-ensemble-and-quorum-in-zookeeper).
* Zookeeper provides multiple features for distributed applications:
    * Keep key value store in distributed manner
    * Self election/ consensus building
    * Co-ordination and locks for applications
    * Distributed configuration management
* The zookeeper you can consider is like file system tree, Where we have tree from one node to other child nodes which
are denoting the child directory.
* So Zookeeper internal data structure is like a tree.
    * Each node is called a zNode and each zNode has a path
    * zNode can be 
        * persistent : alive all the time
        * ephemeral : goes after application got disconnect
    * Each zNode can store data.
    * Each zNode can be watched for changes.
    
### Role of zookeeper in Kafka
* Zookeeper do broker registrations and keep the current active brokers node list. This is done through heartbeat
mechanism, where each broker sends the heartbeat to zookeeper, if after a particular timeout zookeeper don't receive
heartbeat from a broker, it will declared as inactive or dead and remove from active brokers list.
* Zookeeper maintain the list of topics, their configuration like partitions, replication factor, clean policy and 
additional configuration.
* Zookeeper also maintains the ISR (in sync replicas) for partitions, Also in case any broker got disconnect then it will
perform the leader election for partition. The election is as fast the cluster can recover as fast in case of 
the broker failure.
* Zookeeper stores the Kafka cluster id which is randomly generated at 1st startup of cluster.
* Zookeeper also keeps data about ACL(Access control list) in case of security enabled, then it keeps information for 
ACL of Topics, Consumer Groups and Users.

### Zookeeper Cluster/Quorum sizing
* Zookeeper need to have a strict majority of servers up to form the strict majority when votes happen
* There Zookeeper quorums have 1,3,5,7.... (2N+1) servers
* Using this configuration our cluster can survive till N node go down, So in case of 3 it will be active till 2 server
means 1 server can go down in case of 5 upto 2 server can go down and so on.
* Now let's talk about which sizing is better for your different environment and their pros and cons
<table>
<tr><th></th><th>Size 1</th><th>Size 3</th><th>Size 5</th><th>Size 7</th></tr>
<tr>
<th>Pros</th>
<td>

* Fast to put in place
* Fast to make decisions
</td>
<td>

* Distributed
* Preferred for small Kafka deployments
</td>
<td>

* Used for big Kafka deployments
* Two servers can go down
</td>
<td></td>
</tr>
<tr>
<th>Cons</th>
<td>

* Not resilient
* Not distributed
</td>
<td>

* Only one server can go down
</td>
<td>

* Need performant machines as each server talking to other servers which use a lot of network
and network latency.
</td><td>Network overhead and lag may affect zookeeper performance</td></tr>
<tr>
<th>Environment</th>
<td>Best suited for development environment</td>
<td>Can use in Stage and in Production where kafka cluster is small</td>
<td>Mostly used in production environment setup</td>
<td>Rarely used and needed setup and needs expert tuning</td></tr>
</table>
 
### Zookeeper configuration
Let's understand some of zookeeper configuration we will put in zookeeper.properties. Below field contains the comments for 
each field which explain meaning of fields
```properties
# the location to store the in-memory database snapshots and, unless specified otherwise, the transaction log of updates to the database.
dataDir=/data/zookeeper
# the port at which the clients will connect
clientPort=2181
# disable the per-ip limit on the number of connections since this is a non-production config
maxClientCnxns=0
# the basic time unit in milliseconds used by ZooKeeper. It is used to do heartbeats and the minimum session timeout will be twice the tickTime.
tickTime=2000
# The number of ticks that the initial synchronization phase can take
initLimit=10
# The number of ticks that can pass between
# sending a request and getting an acknowledgement
syncLimit=5
# zoo servers
# these hostnames such as `zookeeper-1` come from the /etc/hosts file also the 2888,3888 are internal ports of zookeeper
server.1=zookeeper1:2888:3888
server.2=zookeeper2:2888:3888
server.3=zookeeper3:2888:3888
```
As we can see the tickTime, initLimit and syncLimit play important role for synchronization and initialization of zookeeper,
that's why we need a performant network and machine for this.

## 1.2 Zookeeper Single instance setup
For now we just start setting up our single instance of zookeeper. I have just Linux machine which has Ubuntu 18.04. 
To start with setting up zookeeper we are going to perform below steps:
* Install Open JDK 8 or Open JDK 11 or on your machine
* Disable RAM Swap (As RAM swap is bad for Kafka and Zookeeper, due to RAM swap latency will be increased and it is not
good for our cluster)
* Download & Configure Zookeeper on the machine
* Launch Zookeeper on the machine to test
* Setup Zookeeper as a service on the machine

So Let's start with each step in detail.

### Install Open JDK 8 or Open JDK 11 or Java on your machine
To install the JDK on your machine use below command on your machine:
```shell script
ngupta@node1:~$ sudo apt-get install openjdk-8-jdk
```
This will install the JDK on your machine, to test the JDK is installed or not your machine use below command:
```shell script
ngupta@node1:~$ java -version
openjdk version "1.8.0_222"
OpenJDK Runtime Environment (build 1.8.0_222-8u222-b10-1ubuntu1~18.04.1-b10)
OpenJDK 64-Bit Server VM (build 25.222-b10, mixed mode)
ngupta@node1:~$
```
So above output is showing that We have installed the JDK 8 version 1.8.0_222. The installation command will be differ 
for the different Linux flavour if you are not using Ubuntu; Google how to install the JDK for your Linux flavor and do it.
Now let's move to our next step.

### Disable RAM Swap
To understand more why we need to disable the RAM swap, please visit below link:

https://stackoverflow.com/questions/33463803/why-swapping-is-not-a-good-idea-in-zookeeper-and-kafka/33473351

Kafka and Zookeeper uses system page cache extensively for producing and consuming the messages or data. The Linux kernel 
parameter, vm.swappiness, is a value from 0-100 that controls the swapping of application data (as anonymous pages) 
from physical memory to virtual memory on disk. The higher the value, the more aggressively inactive processes are 
swapped out from physical memory. The lower the value, the less they are swapped, forcing filesystem buffers to be 
emptied. It is an important kernel parameter for Kafka because the more memory allocated to the swap space, the less 
memory can be allocated to the page cache.So it is recommended to set vm.swappiness value to 1 which will reduce latency.

Now let's first see what is current value in our machine
```shell script
ngupta@node1:~$ sudo sysctl vm.swappiness
[sudo] password for ngupta:
vm.swappiness = 60
ngupta@node1:~$
```
So it's current value is 60, But our desired value is 0 or 1, since most of the operating support the value 1 not 0; we 
will set this up to 1. To setup the value for current session we can use the below command:
```shell script
ngupta@node1:~$ sudo sysctl vm.swappiness=1
vm.swappiness = 1
ngupta@node1:~$ sudo sysctl vm.swappiness
vm.swappiness = 1
``` 
In above command we set the value and checked it, but it is for the current session; if our machine get restarted then it 
will set to it's default value again. To setup vm.swappiness value 1 to for machine all the time; we need to add 
entry "vm.swappiness = 1" in "/etc/sysctl.conf" file. To do this you can use vi editor or to append in last we can use
below command:
```shell script
ngupta@node1:~$ echo 'vm.swappiness=1' | sudo tee --append /etc/sysctl.conf
ngupta@node1:~$ cat /etc/sysctl.conf |grep 'swappiness'
vm.swappiness=1
```
As we can see RAM swap is disabled now and we set the vm.swappiness value to 1. Now let's move to next step.

### Download & Configure Zookeeper on the machine
Zookeeper come as bundle with Kafka setup, so for Kafka setup we recommend to use the zookeeper which comes with the Kafka.
To download the bundle visit below link:

https://kafka.apache.org/downloads

Then download the stable version and see the JDK support for it, After 2.1.0 JDK 11 is supported by Kafka. Download the
binary and put it in a location where you can extract it. I have downloaded in my user directory for the instance, it is
not best practice for production, in upcoming section we will discuss directory structure for production setup as well. 
For now we keep it on the home directory of the user.
```shell script
ngupta@node1:~/kafka$ pwd
/home/ngupta/kafka
ngupta@node1:~/kafka$ tar -xzf kafka_2.12-2.3.0.tgz
ngupta@node1:~/kafka$ ls -lrt
total 55880
drwxr-xr-x 6 ngupta ngupta     4096 Jun 19 20:44 kafka_2.12-2.3.0
-rw-rw-r-- 1 ngupta ngupta 57215197 Jun 25 00:38 kafka_2.12-2.3.0.tgz
ngupta@node1:~/kafka$
```

I have extracted it, and the directory kafka_2.12-2.3.0 will be created. Let's see the content inside the directory:
```shell script
ngupta@node1:~/kafka/kafka_2.12-2.3.0$ ls
bin  config  libs  LICENSE  NOTICE  site-docs
ngupta@node1:~/kafka/kafka_2.12-2.3.0$ ls config/
connect-console-sink.properties    connect-file-sink.properties    connect-standalone.properties  producer.properties     trogdor.conf
connect-console-source.properties  connect-file-source.properties  consumer.properties            server.properties       zookeeper.properties
connect-distributed.properties     connect-log4j.properties        log4j.properties               tools-log4j.properties
ngupta@node1:~/kafka/kafka_2.12-2.3.0$ ls bin/
connect-distributed.sh        kafka-consumer-groups.sh     kafka-preferred-replica-election.sh  kafka-streams-application-reset.sh  zookeeper-server-start.sh
connect-standalone.sh         kafka-consumer-perf-test.sh  kafka-producer-perf-test.sh          kafka-topics.sh                     zookeeper-server-stop.sh
kafka-acls.sh                 kafka-delegation-tokens.sh   kafka-reassign-partitions.sh         kafka-verifiable-consumer.sh        zookeeper-shell.sh
kafka-broker-api-versions.sh  kafka-delete-records.sh      kafka-replica-verification.sh        kafka-verifiable-producer.sh
kafka-configs.sh              kafka-dump-log.sh            kafka-run-class.sh                   trogdor.sh
kafka-console-consumer.sh     kafka-log-dirs.sh            kafka-server-start.sh                windows
kafka-console-producer.sh     kafka-mirror-maker.sh        kafka-server-stop.sh                 zookeeper-security-migration.sh
ngupta@node1:~/kafka/kafka_2.12-2.3.0$
```
So in the directory for shell script and configuration. Let's see the default configuration of zookeeper comes with bundle.
```shell script
ngupta@node1:~/kafka/kafka_2.12-2.3.0$ cat config/zookeeper.properties
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# the directory where the snapshot is stored.
dataDir=/tmp/zookeeper
# the port at which the clients will connect
clientPort=2181
# disable the per-ip limit on the number of connections since this is a non-production config
maxClientCnxns=0
```
For now we we are not changing any configuration in above file and start our zookeeper. These settings are not best suited for
the production environment in later section We will explain what are setting you need to take care while setting the Zookeeper
in production. Let's move to next step and start zookeeper.

### Launch Zookeeper on the machine to test
Now to launch the Zookeeper we need to execute below command:
```shell script
ngupta@node1:~/kafka/kafka_2.12-2.3.0$ bin/zookeeper-server-start.sh config/zookeeper.properties
[2019-11-07 04:07:16,056] INFO Reading configuration from: config/zookeeper.properties (org.apache.zookeeper.server.quorum.QuorumPeerConfig)
.
.
.
[2019-11-07 04:07:16,156] INFO Using org.apache.zookeeper.server.NIOServerCnxnFactory as server connection factory (org.apache.zookeeper.server.ServerCnxnFactory)
[2019-11-07 04:07:16,177] INFO binding to port 0.0.0.0/0.0.0.0:2181 (org.apache.zookeeper.server.NIOServerCnxnFactory)
```
As we can see zookeeper is started but it is in hand mode of the zookeeper, you can't give any further command from same window.
Also when the window will be closed then zookeeper will go down, so Now we will start zookeeper in the background mode
using below command
```shell script
ngupta@node1:~/kafka/kafka_2.12-2.3.0$ bin/zookeeper-server-start.sh -daemon config/zookeeper.properties
ngupta@node1:~/kafka/kafka_2.12-2.3.0$
```

Zookeeper will be run in the background. Let's test it by using some command on the zookeeper:
```shell script
ngupta@node1:~/kafka/kafka_2.12-2.3.0$ bin/zookeeper-shell.sh localhost:2181
Connecting to localhost:2181
Welcome to ZooKeeper!
JLine support is disabled

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
ls \
Command failed: java.lang.IllegalArgumentException: Path must start with / character
ls /
[zookeeper]
^Cngupta@node1:~/kafka/kafka_2.12-2.3.0$
```
If you are getting the output of "ls /" command as "[zookeeper]" then the zookeeper is good. We have one more method to 
test the zookeeper which comes from [Four letter words zookeeper command](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_zkCommands)
to test zookeeper.
```shell script
ngupta@node1:~/kafka/kafka_2.12-2.3.0$ echo "ruok" | nc localhost 2181 ; echo
imok
```
In above command we are sending the ruok("Are you OK?") command to zookeeper and in response zookeeper returning response
imok("I am OK").

Now let's setup the zookeeper as service. 

### Setup Zookeeper as a service on the machine
To register the zookeeper as service we need some script which can start,stop,restart our zookeeper server. I have kept
one script with file name [zookeeper.sh](scripts/zookeeper.sh) in scripts folder to perform this. We will copy this script
to our servers in the directory. You just need to update the KAFKA_ROOT_PATH in file with your path to kafka and then 
copy this file to /etc/init.d. Since this is script we need to give the executable permission on this using chmod. 
I have copied this file and edited with my kafka path in home directory, now we will copy to init.d directory.
```shell script
ngupta@node1:~$ pwd
/home/ngupta
ngupta@node1:~$ ls
kafka  zookeeper.sh
ngupta@node1:~$ sudo cp zookeeper.sh /etc/init.d/
[sudo] password for ngupta:
ngupta@node1:~$ ls /etc/init.d/
acpid     console-setup.sh  dbus         irqbalance         lvm2           lxd             open-vm-tools  rsync           udev                 x11-common
apparmor  cron              ebtables     iscsid             lvm2-lvmetad   mdadm           plymouth       rsyslog         ufw                  zookeeper.sh
apport    cryptdisks        grub-common  keyboard-setup.sh  lvm2-lvmpolld  mdadm-waitidle  plymouth-log   screen-cleanup  unattended-upgrades
atd       cryptdisks-early  hwclock.sh   kmod               lxcfs          open-iscsi      procps         ssh             uuidd
ngupta@node1:~$ sudo chmod +x /etc/init.d/zookeeper.sh
```
So now we will change owner of this file to root.
```shell script
ngupta@node1:~$ sudo chown root:root /etc/init.d/zookeeper.sh
ngupta@node1:~$ sudo update-rc.d zookeeper.sh defaults
```
And that's it, now we can start, stop, status and test it is working fine.
```shell script
ngupta@node1:~$ sudo service zookeeper start
ngupta@node1:~$ nc -vz localhost 2181
Connection to localhost 2181 port [tcp/*] succeeded!
ngupta@node1:~$ echo "ruok" | nc localhost 2181 ; echo
imok
ngupta@node1:~$ sudo service zookeeper stop
ngupta@node1:~$ nc -vz localhost 2181
nc: connect to localhost port 2181 (tcp) failed: Connection refused
ngupta@node1:~$ echo "ruok" | nc localhost 2181 ; echo

ngupta@node1:~$ sudo service zookeeper status
● zookeeper.service - SYSV: Standard script to start and stop zookeeper
   Loaded: loaded (/etc/init.d/zookeeper.sh; generated)
   Active: inactive (dead)
     Docs: man:systemd-sysv-generator(8)

Nov 07 05:32:02 node1 systemd[1]: Started SYSV: Standard script to start and stop zookeeper.
Nov 07 05:32:13 node1 systemd[1]: Stopping SYSV: Standard script to start and stop zookeeper...
Nov 07 05:32:13 node1 zookeeper.sh[4871]: Shutting down zookeeper
Nov 07 05:32:13 node1 systemd[1]: Stopped SYSV: Standard script to start and stop zookeeper.
Nov 07 05:37:03 node1 systemd[1]: Starting SYSV: Standard script to start and stop zookeeper...
Nov 07 05:37:03 node1 zookeeper.sh[4926]: Starting zookeeper
Nov 07 05:37:04 node1 systemd[1]: Started SYSV: Standard script to start and stop zookeeper.
Nov 07 05:37:29 node1 systemd[1]: Stopping SYSV: Standard script to start and stop zookeeper...
Nov 07 05:37:29 node1 zookeeper.sh[5276]: Shutting down zookeeper
Nov 07 05:37:29 node1 systemd[1]: Stopped SYSV: Standard script to start and stop zookeeper.
```
We setup the zookeeper as a service and we have tested our service by starting,stopping and using four letter word 
command followed by service status. And It is working. To check the logs just go to kafka directory and perform 
the less command on the the logs/zookeeper.out.

Now our zookeeper has been setup, let's get some hands-on on the zookeeper cli. This is not required for Kafka Cluster
but it is good to have.

### Hands-on over Zookeeper CLI
Let's understand and some of the commands we can use in Zookeeper with CLI, As written in above section this is not required
but good to have. We will look below operations using the Zookeeper CLI:
* Creating node/sub-nodes
* Get/Set data for a node
* Watch a node
* Delete a node 
Let's first enter in Zookeeper CLI.

#### Create a node/sub-node
```shell script
ngupta@node1:~/kafka/kafka_2.12-2.3.0$ bin/zookeeper-shell.sh localhost:2181
Connecting to localhost:2181
Welcome to ZooKeeper!
JLine support is disabled

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
ls
ls /
[zookeeper]
create my-node "This is data"
Command failed: java.lang.IllegalArgumentException: Path must start with / character
create /my-node "This is my-node node data"
Created /my-node
ls /
[zookeeper, my-node]
``` 
As we can see in above script, we entered in CLI then we had done ls to list all the nodes. Initially we did ls only
and we got no results as we were not querying the root. Then we created the node we need to provide the / character
at start otherwise we get the error as you can see in above output. When we provide proper syntax like 
'create /my-node "This is my-node node data"' then a node is created with data. And when we query using "ls /" 
we can see our newly created node. Now let's create a sub node.
```shell script
create /my-node/sub-node1 "sub-node1 data"
Created /my-node/sub-node1
create /my-node/sub-node2 "sub-node2 data"
Created /my-node/sub-node2
ls /my-node
[sub-node1, sub-node2]
ls /
[zookeeper, my-node]
get /my-node/sub-node1
sub-node1 data
cZxid = 0x4
ctime = Tue Nov 12 02:08:16 UTC 2019
mZxid = 0x4
mtime = Tue Nov 12 02:08:16 UTC 2019
pZxid = 0x4
cversion = 0
dataVersion = 0
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 14
numChildren = 0
```
As you can see we have created twos sub nodes and we can see it's data.

#### Get/Set data for a node
To get your data from Zookeeper you need to use the command get and path to node.
```shell script
get /my-node
This is my-node node data
cZxid = 0x2
ctime = Tue Nov 12 01:53:39 UTC 2019
mZxid = 0x2
mtime = Tue Nov 12 01:53:39 UTC 2019
pZxid = 0x2
cversion = 0
dataVersion = 0
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 25
numChildren = 0
```
It will provide the data and some more information about the data,as you can see the data version. Let's update the data
of my-node and see the data again, dataVersion should be updated according the data update. To update the data of a node
we need to use set command like below:
```shell script
set /my-node "This is my-node changed data"
cZxid = 0x2
ctime = Tue Nov 12 01:53:39 UTC 2019
mZxid = 0x3
mtime = Tue Nov 12 02:01:25 UTC 2019
pZxid = 0x2
cversion = 0
dataVersion = 1
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 28
numChildren = 0
get /my-npde
Node does not exist: /my-npde
get /my-node
This is my-node changed data
cZxid = 0x2
ctime = Tue Nov 12 01:53:39 UTC 2019
mZxid = 0x3
mtime = Tue Nov 12 02:01:25 UTC 2019
pZxid = 0x2
cversion = 0
dataVersion = 1
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 28
numChildren = 0
```

#### Watch a node
Let's watch the nodes. Watching a node means whenever the data is updated on the node, we will get an notification. 
To set the watch we need to pass one more argument with get which is true to watch the node as did below:

```shell script
get /my-node true
This is my-node changed data
cZxid = 0x2
ctime = Tue Nov 12 01:53:39 UTC 2019
mZxid = 0x3
mtime = Tue Nov 12 02:01:25 UTC 2019
pZxid = 0x5
cversion = 2
dataVersion = 1
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 28
numChildren = 2
set /my-node "Changed to Version 3"

WATCHER::

WatchedEvent state:SyncConnected type:NodeDataChanged path:/my-node
cZxid = 0x2
ctime = Tue Nov 12 01:53:39 UTC 2019
mZxid = 0x6
mtime = Tue Nov 12 02:12:25 UTC 2019
pZxid = 0x5
cversion = 2
dataVersion = 2
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 20
numChildren = 2
set /my-node/sub-node1 "Changed subnode"
cZxid = 0x4
ctime = Tue Nov 12 02:08:16 UTC 2019
mZxid = 0x7
mtime = Tue Nov 12 02:12:51 UTC 2019
pZxid = 0x4
cversion = 0
dataVersion = 1
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 15
numChildren = 0
```
So when we start watching the node, using get /my-node true, and changed the data we get Watcher Event.

#### Delete a node 
To delete data recursively we need to use rmr command like below:
```shell script
ls /
[zookeeper, my-node]
rmr /my-node
ls /
[zookeeper]
```
rmr will remove the node from the node.

## 1.3 Zookeeper Cluster setup
Before setting up the kafka I am clearing my node-1 setup, and perform below steps on my each node.
* Check JDK is install on each node, if missing on any node we are going to install.

Node1
```shell script
ngupta@node1:~$ java -version
openjdk version "1.8.0_222"
OpenJDK Runtime Environment (build 1.8.0_222-8u222-b10-1ubuntu1~18.04.1-b10)
OpenJDK 64-Bit Server VM (build 25.222-b10, mixed mode)
```
Node2
```shell script
ngupta@node2:~$ java -version
openjdk version "1.8.0_222"
OpenJDK Runtime Environment (build 1.8.0_222-8u222-b10-1ubuntu1~18.04.1-b10)
OpenJDK 64-Bit Server VM (build 25.222-b10, mixed mode)
```
Node3
```shell script
ngupta@node3:~$ java -version
openjdk version "1.8.0_222"
OpenJDK Runtime Environment (build 1.8.0_222-8u222-b10-1ubuntu1~18.04.1-b10)
OpenJDK 64-Bit Server VM (build 25.222-b10, mixed mode)
```
We have java installed on each of our server.

* Disable RAM Swap.

Node1
```shell script
ngupta@node1:~$ sudo sysctl vm.swappiness
vm.swappiness = 1
ngupta@node1:~$
```
Node2
```shell script
ngupta@node2:~$ sudo sysctl vm.swappiness
vm.swappiness = 60
ngupta@node2:~$ sudo sysctl vm.swappiness=1
vm.swappiness = 1
ngupta@node2:~$ sudo sysctl vm.swappiness
vm.swappiness = 1
ngupta@node2:~$
```
Node3
```shell script
ngupta@node3:~$ sudo sysctl vm.swappiness
vm.swappiness = 60
ngupta@node3:~$ sudo sysctl vm.swappiness=1
vm.swappiness = 1
ngupta@node3:~$ sudo sysctl vm.swappiness
vm.swappiness = 1
```
As you can see the Node1 has already disabled the RAM swap, we had during the single node setup. But Node 2 and Node 3 
are our new node so we had setup for them. Also as you remember from the RAM swap section we need to put an entry in
/etc/systemctl.conf to setup this RAM swap disable even after restart. If you didn't done for your rest of nodes please
do it and theen move ahead.

* Get Kafka on all of the servers.

Node1
```shell script
ngupta@node1:~$ wget http://apachemirror.wuchna.com/kafka/2.3.1/kafka_2.12-2.                                                                                  3.1.tgz
--2019-11-12 02:32:32--  http://apachemirror.wuchna.com/kafka/2.3.1/kafka_2.1                                                                                  2-2.3.1.tgz
Resolving apachemirror.wuchna.com (apachemirror.wuchna.com)... 104.26.3.179,                                                                                   104.26.2.179, 2606:4700:20::681a:2b3, ...
Connecting to apachemirror.wuchna.com (apachemirror.wuchna.com)|104.26.3.179|                                                                                  :80... connected.
HTTP request sent, awaiting response... 200 OK
Length: 62366158 (59M) [application/x-gzip]
Saving to: ‘kafka_2.12-2.3.1.tgz’

kafka_2.12-2.3.1.tgz                    100%[==============================================================================>]  59.48M   997KB/s    in 90s     s

2019-11-12 02:34:02 (674 KB/s) - ‘kafka_2.12-2.3.1.tgz’ saved [62366158/62366158]
ngupta@node1:~$ clear
ngupta@node1:~$ ls -lrt
total 60912
-rw-rw-r-- 1 ngupta ngupta 62366158 Oct 24 21:25 kafka_2.12-2.3.1.tgz
ngupta@node1:~$ scp kafka_2.12-2.3.1.tgz ngupta@192.168.109.132:/home/ngupta
The authenticity of host '192.168.109.132 (192.168.109.132)' can't be established.
ECDSA key fingerprint is SHA256:mZJYuyD5dnGKzTFKvAg6jz0wagcgvVTF6eApSUBf2nM.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.109.132' (ECDSA) to the list of known hosts.
ngupta@192.168.109.132's password:
kafka_2.12-2.3.1.tgz                                                                                                         100%   59MB 110.6MB/s   00:00
ngupta@node1:~$ scp kafka_2.12-2.3.1.tgz ngupta@192.168.109.133:/home/ngupta
The authenticity of host '192.168.109.133 (192.168.109.133)' can't be established.
ECDSA key fingerprint is SHA256:mZJYuyD5dnGKzTFKvAg6jz0wagcgvVTF6eApSUBf2nM.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.109.133' (ECDSA) to the list of known hosts.
ngupta@192.168.109.133's password:
kafka_2.12-2.3.1.tgz                                                                                                         
```
At Node 1 we have downloaded Kafka and copied on to other servers path /home/ngupta. Let's check server 2 and 
server 3.

Node2
```shell script
ngupta@node2:~$ pwd
/home/ngupta
ngupta@node2:~$ ls -lr
total 60908
-rw-rw-r-- 1 ngupta ngupta 62366158 Nov 12 02:35 kafka_2.12-2.3.1.tgz
```
Node3
```shell script
ngupta@node3:~$ pwd
/home/ngupta
ngupta@node3:~$ ls -lrt
total 60908
-rw-rw-r-- 1 ngupta ngupta 62366158 Nov 12 02:36 kafka_2.12-2.3.1.tgz
```

* Extract the kafka on all server.

Node1
```shell script
ngupta@node1:~$ ls -lrt
total 60912
-rw-rw-r-- 1 ngupta ngupta 62366158 Oct 24 21:25 kafka_2.12-2.3.1.tgz
ngupta@node1:~$ tar -xzf kafka_2.12-2.3.1.tgz
ngupta@node1:~$ ls -lrt
total 60916
drwxr-xr-x 6 ngupta ngupta     4096 Oct 18 00:12 kafka_2.12-2.3.1
-rw-rw-r-- 1 ngupta ngupta 62366158 Oct 24 21:25 kafka_2.12-2.3.1.tgz
ngupta@node1:~$ ls -lrt kafka_2.12-2.3.1
total 52
-rw-r--r-- 1 ngupta ngupta   337 Oct 18 00:10 NOTICE
-rw-r--r-- 1 ngupta ngupta 32216 Oct 18 00:10 LICENSE
drwxr-xr-x 2 ngupta ngupta  4096 Oct 18 00:12 config
drwxr-xr-x 3 ngupta ngupta  4096 Oct 18 00:12 bin
drwxr-xr-x 2 ngupta ngupta  4096 Oct 18 00:12 site-docs
drwxr-xr-x 2 ngupta ngupta  4096 Nov 12 02:39 libs
ngupta@node1:~$ mv kafka_2.12-2.3.1 kafka
ngupta@node1:~$ ls -lrt
total 60916
drwxr-xr-x 6 ngupta ngupta     4096 Oct 18 00:12 kafka
-rw-rw-r-- 1 ngupta ngupta 62366158 Oct 24 21:25 kafka_2.12-2.3.1.tgz
-rw-rw-r-- 1 ngupta ngupta     1253 Nov  7 05:24 zookeeper.sh
ngupta@node1:~$ rm kafka_2.12-2.3.1.tgz
ngupta@node1:~$
```
Node2
```shell script
ngupta@node2:~$ ls -lrt
total 60908
-rw-rw-r-- 1 ngupta ngupta 62366158 Nov 12 02:35 kafka_2.12-2.3.1.tgz
ngupta@node2:~$ tar -xzf kafka_2.12-2.3.1.tgz
ngupta@node2:~$ ls -lrt
total 60912
drwxr-xr-x 6 ngupta ngupta     4096 Oct 18 00:12 kafka_2.12-2.3.1
-rw-rw-r-- 1 ngupta ngupta 62366158 Nov 12 02:35 kafka_2.12-2.3.1.tgz
ngupta@node2:~$ ls -lrt kafka_2.12-2.3.1
total 52
-rw-r--r-- 1 ngupta ngupta   337 Oct 18 00:10 NOTICE
-rw-r--r-- 1 ngupta ngupta 32216 Oct 18 00:10 LICENSE
drwxr-xr-x 2 ngupta ngupta  4096 Oct 18 00:12 config
drwxr-xr-x 3 ngupta ngupta  4096 Oct 18 00:12 bin
drwxr-xr-x 2 ngupta ngupta  4096 Oct 18 00:12 site-docs
drwxr-xr-x 2 ngupta ngupta  4096 Nov 12 02:39 libs
ngupta@node2:~$ mv kafka_2.12-2.3.1 kafka
ngupta@node2:~$ ls -lrt
total 60912
drwxr-xr-x 6 ngupta ngupta     4096 Oct 18 00:12 kafka
-rw-rw-r-- 1 ngupta ngupta 62366158 Nov 12 02:35 kafka_2.12-2.3.1.tgz
ngupta@node2:~$ rm kafka_2.12-2.3.1.tgz
ngupta@node2:~$
```
Node3
```shell script
ngupta@node3:~$ ls -lrt
total 60908
-rw-rw-r-- 1 ngupta ngupta 62366158 Nov 12 02:36 kafka_2.12-2.3.1.tgz
ngupta@node3:~$ tar -xzf kafka_2.12-2.3.1.tgz
ngupta@node3:~$ ls -lrt
total 60912
drwxr-xr-x 6 ngupta ngupta     4096 Oct 18 00:12 kafka_2.12-2.3.1
-rw-rw-r-- 1 ngupta ngupta 62366158 Nov 12 02:36 kafka_2.12-2.3.1.tgz
ngupta@node3:~$ ls -lrt kafka_2.12-2.3.1
total 52
-rw-r--r-- 1 ngupta ngupta   337 Oct 18 00:10 NOTICE
-rw-r--r-- 1 ngupta ngupta 32216 Oct 18 00:10 LICENSE
drwxr-xr-x 2 ngupta ngupta  4096 Oct 18 00:12 config
drwxr-xr-x 3 ngupta ngupta  4096 Oct 18 00:12 bin
drwxr-xr-x 2 ngupta ngupta  4096 Oct 18 00:12 site-docs
drwxr-xr-x 2 ngupta ngupta  4096 Nov 12 02:39 libs
ngupta@node3:~$ mv kafka_2.12-2.3.1 kafka
ngupta@node3:~$ ls -lrt
total 60912
drwxr-xr-x 6 ngupta ngupta     4096 Oct 18 00:12 kafka
-rw-rw-r-- 1 ngupta ngupta 62366158 Nov 12 02:36 kafka_2.12-2.3.1.tgz
ngupta@node3:~$ rm kafka_2.12-2.3.1.tgz
```

* Copy the zookeeper script on all the servers and create the service for the zookeeper on each server.

Node1
```shell script
ngupta@node1:~$ ls -lrt
total 8
drwxr-xr-x 6 ngupta ngupta 4096 Oct 18 00:12 kafka
-rw-rw-r-- 1 ngupta ngupta 1236 Nov 12 02:44 zookeeper.sh
ngupta@node1:~$ vi zookeeper.sh
ngupta@node1:~$  ls /etc/init.d/
acpid     console-setup.sh  dbus         irqbalance         lvm2           lxd             open-vm-tools  rsync           udev                 x11-common
apparmor  cron              ebtables     iscsid             lvm2-lvmetad   mdadm           plymouth       rsyslog         ufw                  zookeeper.sh
apport    cryptdisks        grub-common  keyboard-setup.sh  lvm2-lvmpolld  mdadm-waitidle  plymouth-log   screen-cleanup  unattended-upgrades
atd       cryptdisks-early  hwclock.sh   kmod               lxcfs          open-iscsi      procps         ssh             uuidd
ngupta@node1:~$ sudo chmod +x /etc/init.d/zookeeper.sh
ngupta@node1:~$ sudo chown root:root /etc/init.d/zookeeper.sh
ngupta@node1:~$  sudo update-rc.d zookeeper.sh defaults
ngupta@node1:~$ sudo service zookeeper start
ngupta@node1:~$ nc -vz localhost 2181
Connection to localhost 2181 port [tcp/*] succeeded!
ngupta@node1:~$ echo "ruok" | nc localhost 2181 ; echo
imok
ngupta@node1:~$ sudo service zookeeper stop
ngupta@node1:~$  nc -vz localhost 2181
nc: connect to localhost port 2181 (tcp) failed: Connection refused
ngupta@node1:~$ scp zookeeper.sh ngupta@192.168.109.132:/home/ngupta
ngupta@192.168.109.132's password:
zookeeper.sh                                                                                                                 100% 1236   862.2KB/s   00:00
ngupta@node1:~$ scp zookeeper.sh ngupta@192.168.109.133:/home/ngupta
ngupta@192.168.109.133's password:
zookeeper.sh                                                                                                                 100% 1236   699.5KB/s   00:00
ngupta@node1:~$
```
We have copied the script to our other two servers. In the script we have updated the KAFKA_ROOT_PATH.

Node2
```shell script
ngupta@node2:~$ ls -lrt
total 8
drwxr-xr-x 6 ngupta ngupta 4096 Oct 18 00:12 kafka
-rw-rw-r-- 1 ngupta ngupta 1236 Nov 12 02:48 zookeeper.sh
ngupta@node2:~$ sudo cp zookeeper.sh /etc/init.d/
[sudo] password for ngupta:
ngupta@node2:~$ ls /etc/init.d/
acpid             grub-common        lxd             screen-cleanup
apparmor          hwclock.sh         mdadm           ssh
apport            irqbalance         mdadm-waitidle  udev
atd               iscsid             open-iscsi      ufw
console-setup.sh  keyboard-setup.sh  open-vm-tools   unattended-upgrades
cron              kmod               plymouth        uuidd
cryptdisks        lvm2               plymouth-log    x11-common
cryptdisks-early  lvm2-lvmetad       procps          zookeeper.sh
dbus              lvm2-lvmpolld      rsync
ebtables          lxcfs              rsyslog
ngupta@node2:~$ sudo chmod +x /etc/init.d/zookeeper.sh
ngupta@node2:~$ sudo chown root:root /etc/init.d/zookeeper.sh
ngupta@node2:~$ sudo update-rc.d zookeeper.sh defaults
ngupta@node2:~$ sudo service zookeeper start
ngupta@node2:~$  nc -vz localhost 2181
Connection to localhost 2181 port [tcp/*] succeeded!
ngupta@node2:~$ echo "ruok" | nc localhost 2181 ; echo
imok
ngupta@node2:~$ sudo service zookeeper stop
ngupta@node2:~$ nc -vz localhost 2181
nc: connect to localhost port 2181 (tcp) failed: Connection refused
ngupta@node2:~$
```

Node3
```shell script
ngupta@node3:~$ ls -lrt
total 8
drwxr-xr-x 6 ngupta ngupta 4096 Oct 18 00:12 kafka
-rw-rw-r-- 1 ngupta ngupta 1236 Nov 12 02:48 zookeeper.sh
ngupta@node3:~$ sudo cp zookeeper.sh /etc/init.d/
[sudo] password for ngupta:
ngupta@node3:~$ ls /etc/init.d/
acpid             grub-common        lxd             screen-cleanup
apparmor          hwclock.sh         mdadm           ssh
apport            irqbalance         mdadm-waitidle  udev
atd               iscsid             open-iscsi      ufw
console-setup.sh  keyboard-setup.sh  open-vm-tools   unattended-upgrades
cron              kmod               plymouth        uuidd
cryptdisks        lvm2               plymouth-log    x11-common
cryptdisks-early  lvm2-lvmetad       procps          zookeeper.sh
dbus              lvm2-lvmpolld      rsync
ebtables          lxcfs              rsyslog
ngupta@node3:~$ sudo chmod +x /etc/init.d/zookeeper.sh
ngupta@node3:~$ sudo chown root:root /etc/init.d/zookeeper.sh
ngupta@node3:~$ sudo update-rc.d zookeeper.sh defaults
ngupta@node3:~$ sudo service zookeeper start
ngupta@node3:~$  nc -vz localhost 2181
Connection to localhost 2181 port [tcp/*] succeeded!
ngupta@node3:~$ echo "ruok" | nc localhost 2181 ; echo
imok
ngupta@node3:~$ sudo service zookeeper stop
ngupta@node3:~$ nc -vz localhost 2181
nc: connect to localhost port 2181 (tcp) failed: Connection refused
ngupta@node3:~$
```
We have zookeeper running on each server, But they are still not in cluster. To start them as cluster we need to
provide additional configuration.

* Let's first check if each server is able to communicate with each other or not.

Node1
```shell script
ngupta@node1:~$ sudo service zookeeper start
ngupta@node1:~$ nc -vz 192.168.109.131 2181
Connection to 192.168.109.131 2181 port [tcp/*] succeeded!
ngupta@node1:~$ nc -vz 192.168.109.132 2181
Connection to 192.168.109.132 2181 port [tcp/*] succeeded!
ngupta@node1:~$ nc -vz 192.168.109.133 2181
Connection to 192.168.109.133 2181 port [tcp/*] succeeded!
ngupta@node1:~$ sudo service zookeeper stop
```
Node2
```shell script
ngupta@node2:~$ sudo service zookeeper start
ngupta@node2:~$ nc -vz 192.168.109.131 2181
Connection to 192.168.109.131 2181 port [tcp/*] succeeded!
ngupta@node2:~$ nc -vz 192.168.109.132 2181
Connection to 192.168.109.132 2181 port [tcp/*] succeeded!
ngupta@node2:~$ nc -vz 192.168.109.133 2181
Connection to 192.168.109.133 2181 port [tcp/*] succeeded!
ngupta@node2:~$ sudo service zookeeper stop
```
Node3
```shell script
ngupta@node3:~$ sudo service zookeeper start
ngupta@node3:~$ nc -vz 192.168.109.131 2181
Connection to 192.168.109.131 2181 port [tcp/*] succeeded!
ngupta@node3:~$ nc -vz 192.168.109.132 2181
Connection to 192.168.109.132 2181 port [tcp/*] succeeded!
ngupta@node3:~$ nc -vz 192.168.109.133 2181
Connection to 192.168.109.133 2181 port [tcp/*] succeeded!
ngupta@node3:~$ sudo service zookeeper stop
```

If any server not able to connect to other one first check zookeeper service up on them properly or not. If zookeeper 
service is running and still not able to communicate check your network connection and network topology between your 
machines.

* Create data directory for the zookeeper on each of the server.

Node1
```shell script
ngupta@node1:~$ sudo mkdir -p /data/zookeeper
ngupta@node1:~$ ls -lrt /data/zookeeper/
total 0
ngupta@node1:~$ sudo chown -R ngupta:ngupta /data/
ngupta@node1:~$ echo "1" > /data/zookeeper/myid
ngupta@node1:~$ cat /data/zookeeper/myid
1
ngupta@node1:~$
```
Node2
```shell script
ngupta@node2:~$ sudo mkdir -p /data/zookeeper
ngupta@node2:~$ ls -lrt /data/zookeeper/
total 0
ngupta@node2:~$ sudo chown -R ngupta:ngupta /data/
ngupta@node2:~$
ngupta@node2:~$ echo "2" > /data/zookeeper/myid
ngupta@node2:~$ cat /data/zookeeper/myid
2
ngupta@node2:~$
```
Node3
```shell script
ngupta@node3:~$ sudo mkdir -p /data/zookeeper
ngupta@node3:~$ ls -lrt /data/zookeeper/
total 0
ngupta@node3:~$ sudo chown -R ngupta:ngupta /data/
ngupta@node3:~$
ngupta@node3:~$ echo "3" > /data/zookeeper/myid
ngupta@node3:~$ cat /data/zookeeper/myid
3
ngupta@node3:~$
```

Let's understand above lines. We have created the data directory for the zookeeper and then we have created one file
myid in which we have written number, this myid file is used by zookeeper in cluster to uniquely identify the server.
The id should be unique in cluster so make sure your each node have unique number not contradicting with other cluster id.

* Create configuration for zookeeper cluster. We have created one configuration file which can be used for this course, 
also you can use while setting up. You just need to update the data.dir and server.x where x is my id setup for the 
zookeeper node in above step. 

We have copied this zookeeper.properties to our Node1.
```shell script
ngupta@node1:~$ vi zookeeper.properties
ngupta@node1:~$ scp zookeeper.properties ngupta@192.168.109.132:/home/ngupta
ngupta@192.168.109.132's password:
zookeeper.properties                                                                                                         100%  802   357.4KB/s   00:00
ngupta@node1:~$ scp zookeeper.properties ngupta@192.168.109.133:/home/ngupta
ngupta@192.168.109.133's password:
zookeeper.properties                                                                                                         100%  802   751.7KB/s   00:00
ngupta@node1:~$ rm kafka/config/zookeeper.properties
ngupta@node1:~$ cp zookeeper.properties kafka/config/
ngupta@node1:~$ cat kafka/config/zookeeper.properties
# the location to store the in-memory database snapshots and, unless specified otherwise, the transaction log of updates to the database.
dataDir=/data/zookeeper
# the port at which the clients will connect
clientPort=2181
# disable the per-ip limit on the number of connections since this is a non-production config
maxClientCnxns=0
# the basic time unit in milliseconds used by ZooKeeper. It is used to do heartbeats and the minimum session timeout will be twice the tickTime.
tickTime=2000
# The number of ticks that the initial synchronization phase can take
initLimit=10
# The number of ticks that can pass between
# sending a request and getting an acknowledgement
syncLimit=5
# zoo servers
server.1=192.168.109.131:2888:3888
server.2=192.168.109.132:2888:3888
server.3=192.168.109.133:2888:3888
ngupta@node1:~$
```
As you can see we have updated our configuration for data directory and the server IPs of my cluster. You need update 
this file as per your configuration and network IPs. We also copied these file to Node 2 and Node 3 and have perform the
same operations like below:

Node2
```shell script
ngupta@node2:~$ ls -lrt
total 12
-rw-rw-r-- 1 ngupta ngupta 1236 Nov 12 02:48 zookeeper.sh
drwxr-xr-x 7 ngupta ngupta 4096 Nov 12 02:51 kafka
-rw-rw-r-- 1 ngupta ngupta  802 Nov 12 03:17 zookeeper.properties
ngupta@node2:~$  rm kafka/config/zookeeper.properties
ngupta@node2:~$ cp zookeeper.properties kafka/config/
ngupta@node2:~$  cat kafka/config/zookeeper.properties
# the location to store the in-memory database snapshots and, unless specified otherwise, the transaction log of updates to the database.
dataDir=/data/zookeeper
# the port at which the clients will connect
clientPort=2181
# disable the per-ip limit on the number of connections since this is a non-production config
maxClientCnxns=0
# the basic time unit in milliseconds used by ZooKeeper. It is used to do heartbeats and the minimum session timeout will be twice the tickTime.
tickTime=2000
# The number of ticks that the initial synchronization phase can take
initLimit=10
# The number of ticks that can pass between
# sending a request and getting an acknowledgement
syncLimit=5
# zoo servers
server.1=192.168.109.131:2888:3888
server.2=192.168.109.132:2888:3888
server.3=192.168.109.133:2888:3888
ngupta@node2:~$
```
Node3
```shell script
ngupta@node3:~$ ls -lrt
total 12
-rw-rw-r-- 1 ngupta ngupta 1236 Nov 12 02:48 zookeeper.sh
drwxr-xr-x 7 ngupta ngupta 4096 Nov 12 02:51 kafka
-rw-rw-r-- 1 ngupta ngupta  802 Nov 12 03:17 zookeeper.properties
ngupta@node3:~$  rm kafka/config/zookeeper.properties
ngupta@node3:~$ cp zookeeper.properties kafka/config/
ngupta@node3:~$  cat kafka/config/zookeeper.properties
# the location to store the in-memory database snapshots and, unless specified otherwise, the transaction log of updates to the database.
dataDir=/data/zookeeper
# the port at which the clients will connect
clientPort=2181
# disable the per-ip limit on the number of connections since this is a non-production config
maxClientCnxns=0
# the basic time unit in milliseconds used by ZooKeeper. It is used to do heartbeats and the minimum session timeout will be twice the tickTime.
tickTime=2000
# The number of ticks that the initial synchronization phase can take
initLimit=10
# The number of ticks that can pass between
# sending a request and getting an acknowledgement
syncLimit=5
# zoo servers
server.1=192.168.109.131:2888:3888
server.2=192.168.109.132:2888:3888
server.3=192.168.109.133:2888:3888
ngupta@node3:~$
```

* Let's start testing our cluster initially.
When you start the cluster using command **bin/zookeeper-server-start.sh config/zookeeper.properties** then below will
be output where you find.
If you bring the just one server, it will be wait till other comes otherwise it will keep complaining like below:
```text
[2019-11-14 03:19:04,406] WARN Cannot open channel to 3 at election address /192.168.109.133:3888 (org.apache.zookeeper.server.quorum.QuorumCnxManager)
java.net.ConnectException: Connection refused (Connection refused)
        at java.net.PlainSocketImpl.socketConnect(Native Method)
        at java.net.AbstractPlainSocketImpl.doConnect(AbstractPlainSocketImpl.java:350)
        at java.net.AbstractPlainSocketImpl.connectToAddress(AbstractPlainSocketImpl.java:206)
        at java.net.AbstractPlainSocketImpl.connect(AbstractPlainSocketImpl.java:188)
        at java.net.SocksSocketImpl.connect(SocksSocketImpl.java:392)
        at java.net.Socket.connect(Socket.java:589)
        at org.apache.zookeeper.server.quorum.QuorumCnxManager.connectOne(QuorumCnxManager.java:558)
        at org.apache.zookeeper.server.quorum.QuorumCnxManager.connectAll(QuorumCnxManager.java:610)
        at org.apache.zookeeper.server.quorum.FastLeaderElection.lookForLeader(FastLeaderElection.java:838)
        at org.apache.zookeeper.server.quorum.QuorumPeer.run(QuorumPeer.java:958)
[2019-11-14 03:19:04,408] INFO Resolved hostname: 192.168.109.133 to address: /192.168.109.133 (org.apache.zookeeper.server.quorum.QuorumPeer)
[2019-11-14 03:19:04,408] INFO Notification time out: 1600 (org.apache.zookeeper.server.quorum.FastLeaderElection)
[2019-11-14 03:19:06,012] WARN Cannot open channel to 2 at election address /192.168.109.132:3888 (org.apache.zookeeper.server.quorum.QuorumCnxManager)
java.net.ConnectException: Connection refused (Connection refused)
        at java.net.PlainSocketImpl.socketConnect(Native Method)
        at java.net.AbstractPlainSocketImpl.doConnect(AbstractPlainSocketImpl.java:350)
        at java.net.AbstractPlainSocketImpl.connectToAddress(AbstractPlainSocketImpl.java:206)
        at java.net.AbstractPlainSocketImpl.connect(AbstractPlainSocketImpl.java:188)
        at java.net.SocksSocketImpl.connect(SocksSocketImpl.java:392)
        at java.net.Socket.connect(Socket.java:589)
        at org.apache.zookeeper.server.quorum.QuorumCnxManager.connectOne(QuorumCnxManager.java:558)
        at org.apache.zookeeper.server.quorum.QuorumCnxManager.connectAll(QuorumCnxManager.java:610)
        at org.apache.zookeeper.server.quorum.FastLeaderElection.lookForLeader(FastLeaderElection.java:838)
        at org.apache.zookeeper.server.quorum.QuorumPeer.run(QuorumPeer.java:958)
[2019-11-14 03:19:06,014] INFO Resolved hostname: 192.168.109.132 to address: /192.168.109.132 (org.apache.zookeeper.server.quorum.QuorumPeer)
```

This will stop when you start at least 2 zookeeper servers, and When you will start 3 zookeeper servers below will be 
output on each node.

Node1
```text
[2019-11-14 03:19:10,793] INFO Created server with tickTime 2000 minSessionTimeout 4000 maxSessionTimeout 40000 datadir /data/zookeeper/version-2 snapdir /data/zookeeper/version-2 (org.apache.zookeeper.server.ZooKeeperServer)
[2019-11-14 03:19:10,798] INFO FOLLOWING - LEADER ELECTION TOOK - 7816 (org.apache.zookeeper.server.quorum.Learner)
[2019-11-14 03:19:10,804] INFO Resolved hostname: 192.168.109.132 to address: /192.168.109.132 (org.apache.zookeeper.server.quorum.QuorumPeer)
[2019-11-14 03:19:10,830] INFO Getting a snapshot from leader 0x200000000 (org.apache.zookeeper.server.quorum.Learner)
[2019-11-14 03:19:10,837] INFO Snapshotting: 0x200000000 to /data/zookeeper/version-2/snapshot.200000000 (org.apache.zookeeper.server.persistence.FileTxnSnapLog)
[2019-11-14 03:22:25,095] INFO Received connection request /192.168.109.133:32810 (org.apache.zookeeper.server.quorum.QuorumCnxManager)
[2019-11-14 03:22:25,100] INFO Notification: 1 (message format version), 3 (n.leader), 0x0 (n.zxid), 0x1 (n.round), LOOKING (n.state), 3 (n.sid), 0x2 (n.peerEpoch) FOLLOWING (my state) (org.apache.zookeeper.server.quorum.FastLeaderElection)
[2019-11-14 03:22:25,108] INFO Notification: 1 (message format version), 2 (n.leader), 0x200000000 (n.zxid), 0x1 (n.round), LOOKING (n.state), 3 (n.sid), 0x2 (n.peerEpoch) FOLLOWING (my state) (org.apache.zookeeper.server.quorum.FastLeaderElection)
```
Node2
```text
[2019-11-14 03:19:10,820] INFO Created server with tickTime 2000 minSessionTimeout 4000 maxSessionTimeout 40000 datadir /data/zookeeper/version-2 snapdir /data/zookeeper/version-2 (org.apache.zookeeper.server.ZooKeeperServer)
 [2019-11-14 03:19:10,822] INFO LEADING - LEADER ELECTION TOOK - 250 (org.apache.zookeeper.server.quorum.Leader)
 [2019-11-14 03:19:10,838] INFO Follower sid: 1 : info : org.apache.zookeeper.server.quorum.QuorumPeer$QuorumServer@59208aa6 (org.apache.zookeeper.server.quorum.LearnerHandler)
 [2019-11-14 03:19:10,853] INFO Synchronizing with Follower sid: 1 maxCommittedLog=0x0 minCommittedLog=0x0 peerLastZxid=0x0 (org.apache.zookeeper.server.quorum.LearnerHandler)
 [2019-11-14 03:19:10,853] INFO Sending SNAP (org.apache.zookeeper.server.quorum.LearnerHandler)
 [2019-11-14 03:19:10,854] INFO Sending snapshot last zxid of peer is 0x0  zxid of leader is 0x300000000sent zxid of db as 0x200000000 (org.apache.zookeeper.server.quorum.LearnerHandler)
 [2019-11-14 03:19:10,866] INFO Received NEWLEADER-ACK message from 1 (org.apache.zookeeper.server.quorum.LearnerHandler)
 [2019-11-14 03:19:10,866] INFO Have quorum of supporters, sids: [ 1,2 ]; starting up and setting last processed zxid: 0x300000000 (org.apache.zookeeper.server.quorum.Leader)
 [2019-11-14 03:22:25,127] INFO Received connection request /192.168.109.133:44966 (org.apache.zookeeper.server.quorum.QuorumCnxManager)
 [2019-11-14 03:22:25,132] INFO Notification: 1 (message format version), 3 (n.leader), 0x0 (n.zxid), 0x1 (n.round), LOOKING (n.state), 3 (n.sid), 0x2 (n.peerEpoch) LEADING (my state) (org.apache.zookeeper.server.quorum.FastLeaderElection)
 [2019-11-14 03:22:25,138] INFO Notification: 1 (message format version), 2 (n.leader), 0x200000000 (n.zxid), 0x1 (n.round), LOOKING (n.state), 3 (n.sid), 0x2 (n.peerEpoch) LEADING (my state) (org.apache.zookeeper.server.quorum.FastLeaderElection)
 [2019-11-14 03:22:25,183] INFO Follower sid: 3 : info : org.apache.zookeeper.server.quorum.QuorumPeer$QuorumServer@5608852d (org.apache.zookeeper.server.quorum.LearnerHandler)
 [2019-11-14 03:22:25,186] INFO Synchronizing with Follower sid: 3 maxCommittedLog=0x0 minCommittedLog=0x0 peerLastZxid=0x0 (org.apache.zookeeper.server.quorum.LearnerHandler)
 [2019-11-14 03:22:25,186] INFO Sending SNAP (org.apache.zookeeper.server.quorum.LearnerHandler)
 [2019-11-14 03:22:25,186] INFO Sending snapshot last zxid of peer is 0x0  zxid of leader is 0x300000000sent zxid of db as 0x300000000 (org.apache.zookeeper.server.quorum.LearnerHandler)
 [2019-11-14 03:22:25,199] INFO Received NEWLEADER-ACK message from 3 (org.apache.zookeeper.server.quorum.LearnerHandler)
```
Node3
```text
[2019-11-14 03:22:25,161] INFO Created server with tickTime 2000 minSessionTimeout 4000 maxSessionTimeout 40000 datadir /data/zookeeper/version-2 snapdir /data/zookeeper/version-2 (org.apache.zookeeper.server.ZooKeeperServer)
[2019-11-14 03:22:25,162] INFO FOLLOWING - LEADER ELECTION TOOK - 56 (org.apache.zookeeper.server.quorum.Learner)
[2019-11-14 03:22:25,166] INFO Resolved hostname: 192.168.109.132 to address: /192.168.109.132 (org.apache.zookeeper.server.quorum.QuorumPeer)
[2019-11-14 03:22:25,179] INFO Getting a snapshot from leader 0x300000000 (org.apache.zookeeper.server.quorum.Learner)
[2019-11-14 03:22:25,183] INFO Snapshotting: 0x300000000 to /data/zookeeper/version-2/snapshot.300000000 (org.apache.zookeeper.server.persistence.FileTxnSnapLog)
```
So you can see in logs that the Node1 and Node3 are followers and Node2 is elected as leader. You can find these string
"NEWLEADER-ACK" or "FOLLOWING - LEADER ELECTION TOOK" in your logs to identify the leader and follower in your cluster.

After bringing up the cluster using below commands we tested that they are working fine,no running exception. Let's do the 
four letter command check again and then we will stop and bring them up using service. 
```shell script
ngupta@node1:~$ echo "ruok" | nc 192.168.109.131 2181 ; echo
imok
ngupta@node1:~$ echo "ruok" | nc 192.168.109.132 2181 ; echo
imok
ngupta@node1:~$ echo "ruok" | nc 192.168.109.133 2181 ; echo
imok
```

Our servers are healthy, we can start them as service. After starting the service double check with four letter 
command.

Let's talk about one more other four letter command which is stat, which gives the information about each zookeeper and 
their mode. Below is the command and it's output:
```shell script
ngupta@node1:~$ echo "stat" | nc 192.168.109.131 2181 ; echo
Zookeeper version: 3.4.14-4c25d480e66aadd371de8bd2fd8da255ac140bcf, built on 03/06/2019 16:18 GMT
Clients:
 /192.168.109.131:36884[0](queued=0,recved=1,sent=0)

Latency min/avg/max: 0/0/0
Received: 2
Sent: 1
Connections: 1
Outstanding: 0
Zxid: 0x200000000
Mode: follower
Node count: 4

ngupta@node1:~$ echo "stat" | nc 192.168.109.132 2181 ; echo
Zookeeper version: 3.4.14-4c25d480e66aadd371de8bd2fd8da255ac140bcf, built on 03/06/2019 16:18 GMT
Clients:
 /192.168.109.131:35366[0](queued=0,recved=1,sent=0)

Latency min/avg/max: 0/0/0
Received: 2
Sent: 1
Connections: 1
Outstanding: 0
Zxid: 0x400000000
Mode: leader
Node count: 4
Proposal sizes last/min/max: -1/-1/-1

ngupta@node1:~$ echo "stat" | nc 192.168.109.133 2181 ; echo
Zookeeper version: 3.4.14-4c25d480e66aadd371de8bd2fd8da255ac140bcf, built on 03/06/2019 16:18 GMT
Clients:
 /192.168.109.131:56712[0](queued=0,recved=1,sent=0)

Latency min/avg/max: 0/0/0
Received: 4
Sent: 3
Connections: 1
Outstanding: 0
Zxid: 0x400000000
Mode: follower
Node count: 4
```

This command will show you the latency for my case because I am doing in multiple VMs on same machine it is 0. When you go out 
in production it will be important parameter to see. You can see 131 and 133 are in follower mode and 132 is act as
leader in our quorum.

Let's open the zookeeper shell window and perform the operation which we did in previous section.

Node1
```shell script
ngupta@node1:~/kafka$ bin/zookeeper-shell.sh 192.168.109.131:2181
Connecting to 192.168.109.131:2181
Welcome to ZooKeeper!
JLine support is disabled

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
ls
ls /
[zookeeper]
create /my-node "This is temp node"
Created /my-node
set /my-node "This is changed data"
cZxid = 0x400000008
ctime = Thu Nov 14 03:39:08 UTC 2019
mZxid = 0x400000009
mtime = Thu Nov 14 03:39:51 UTC 2019
pZxid = 0x400000008
cversion = 0
dataVersion = 1
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 20
numChildren = 0
rmr /my-node
```
Node2
```shell script
ngupta@node2:~/kafka$ bin/zookeeper-shell.sh 192.168.109.132:2181
Connecting to 192.168.109.132:2181
Welcome to ZooKeeper!
JLine support is disabled

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
ls
ls /
[zookeeper, my-node]
```
Node3
```shell script
ngupta@node3:~/kafka$ bin/zookeeper-shell.sh 192.168.109.133:2181
Connecting to 192.168.109.133:2181
Welcome to ZooKeeper!
JLine support is disabled

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
get /my-node
This is temp node
cZxid = 0x400000008
ctime = Thu Nov 14 03:39:08 UTC 2019
mZxid = 0x400000008
mtime = Thu Nov 14 03:39:08 UTC 2019
pZxid = 0x400000008
cversion = 0
dataVersion = 0
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 17
numChildren = 0
get /my-node true
This is temp node
cZxid = 0x400000008
ctime = Thu Nov 14 03:39:08 UTC 2019
mZxid = 0x400000008
mtime = Thu Nov 14 03:39:08 UTC 2019
pZxid = 0x400000008
cversion = 0
dataVersion = 0
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 17
numChildren = 0

WATCHER::

WatchedEvent state:SyncConnected type:NodeDataChanged path:/my-node
```

As we can see our data is getting replicated to other servers as well. So our zookeeper is now in cluster and happy.

### Four letter commands of zookeeper
Till now we have seen two commands "ruok" and "stat" command to check status of zookeeper and a little bit their 
information. Let's see more commands, there are several commands which you check [here](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_zkCommands).
Let's get started and see some of the commands and their output:

* **echo "conf"| nc localhost 2181**

This will print the server configuration we are using for our server like data directory, port etc.
```shell script
ngupta@node1:~/kafka$ echo "conf"| nc localhost 2181
clientPort=2181
dataDir=/data/zookeeper/version-2
dataLogDir=/data/zookeeper/version-2
tickTime=2000
maxClientCnxns=0
minSessionTimeout=4000
maxSessionTimeout=40000
serverId=1
initLimit=10
syncLimit=5
electionAlg=3
electionPort=3888
quorumPort=2888
peerType=0
```
* **echo "cons"| nc localhost 2181**

List full connection/session details for all clients connected to this server with some more information like packet sent
received.
```shell script
ngupta@node1:~/kafka$ echo "cons"| nc localhost 2181
 /127.0.0.1:34454[0](queued=0,recved=1,sent=0)
```
 
You can explore more commands provided in the link in this section start.  

### Zookeeper performance
* Zookeeper performance can be affected by the latency, so try to keep the latency as minimum as possible.
* Use fast disk like SSD
* No RAM swap, as we disable while setting up the cluster
* Separate disk for the snapshots and logs
* High Performance network, don't put the cluster spread over the globe, try to minimize the latency by putting them in 
same data center, region.
* Reasonable number of zookeeper as discussed in quorum sizing.
* Isolation of the zookeeper instances from other processes, don't put the co-located zookeeper and kafka we are doing 
for these lessons but for production try to put the zookeeper cluster apart from any of the processes.

## 1.4 Kafka Theory Part
### Kafka Cluster/Quorum sizing
<table>
<tr>
<th>Size 1</th>
<th>Size 3</th>
<th>Size 100</th>
</tr>
<tr>
<td>

* If the broker is restarted, the Kafka cluster is down.
* The maximum replication factor for topics is 1.
* All producer and consumer request go to same unique broker.
* You can only scale vertically (by increasing the instance size and restarting)
* Highly risky and only useful for development environment   
</td>
<td>

* N-1 brokers can be down, where N is your replication factor for default topic.
* Producer and consumer request are spread out between different machines
* Data is spread out between brokers, which means less disk space is used per broker.
</td>
<td>

* your cluster is fully distributed and can handle tremendous volumes even using commodity hardware.
* Zookeeper may be under pressure because of many open connections, so you need to increase the Zookeeper instance 
performance
* Data is spread out between brokers, which means less disk space is used per broker.
* Cluster management is full time job(make sure no broker act weirdly)
* With cluster of size 100 we can have replication factor 4 or greater, but is recommended practice that keep it 3,
if replication factor 4 or more then this would incur network communications within the brokers. So keep it 3.
* Scale horizontally only when a bottleneck reached like network,disk,I/O, CPU, RAM
</td>
</tr>
</table>

### Kafka Configuration
Kafka has more than 140 configuration parameter available. Only a few parameters are needed to get start. 
But for production we can't put Kakfa in one go, this is iterative process which tune our kafka using some 
configuration parameters, which we set over time after observations.
* Kafka divided the parameter on the importance with level high,medium and low on parameter.
* You will not get production ready kafka configuration in one go
* Configuring Kafka is iterative process: behaviour changes over time based on usage and monitoring, so we should update
configuration over looking at observation and performance.

Let's understand some parameter:

* **broker.id(Number) :** Unique ID of broker in cluster.
* **advertised.listeners(String) :** In basic we can have host name and port, later we will explore in depth this.
* **delete.topic.enable(Boolean) :** Topic deletion enabled for the cluster.
* **log.dirs(String) :** Data directory for kafka data.
* **num.partitions(Number) :** Default number of partitions created for topic
* **default.replication.factor(Number) :** Default replication factor for the topic.
* **min.insync.replicas(Number) :** Number of ISR to have in order to minimize data loss.
* **log.segment.bytes(Number) :** The maximum size of a log segment file. When this size is reached a new log segment 
will be created.
* **log.retention.check.interval.ms(Number) :** The interval at which log segments are checked to see if they can be 
deleted according to the retention policies
* **zookeeper.connect(String) :** Zookeeper cluster with root directory in zookeeper.
* **zookeeper.connection.timeout.ms(Number) :** Timeout in ms for connecting to zookeeper
* **auto.create.topics.enable(Boolean) :** Good for the development environment, it will create topic automatically if 
not present. Set false in production.

## 1.5 Kafka Single Instance setup
We should have fastest I/O disk like SSD which we can use for the Kafka. Use this fastest disk as mount in your machine and
provide this path while setting up cluster configuration. For this lesson I am using local disk which is available as our
local system, But recommendation will be use NAS and use mount location for this.

To setup kafka cluster we will do below steps:
* Augment the file handle limits.
* Launch Kafka on one machine
* Setup Kafka as service.

### Augment the file handle limits
Kafka opens many files, so we don't want to kafka failure due to file handler. To augment file limit we will append
below lines in /etc/security/limits.conf with hard limit and soft limit 100000. To perform below we can use vi as the 
parameter is already set, or if does not exist or you have new server you can perform below:

Node1
```shell script
ngupta@node1:~$ echo "* hard nofile 100000
> * soft nofile 100000" | sudo tee --append /etc/security/limits.conf
[sudo] password for ngupta:
* hard nofile 100000
* soft nofile 100000
ngupta@node1:~$ cat /etc/security/limits.conf
.
.
#@student        -       maxlogins       4
 
 # End of file
 * hard nofile 100000
 * soft nofile 100000
 ngupta@node1:~$
```
So we can see hard limit. To apply this limit we need to restart the server, so we will restart the server. Since we need
to perform below step when we will setup the cluster, so I am doing this for other nodes too.

Node2
```shell script
ngupta@node2:~$ echo "* hard nofile 100000
> * soft nofile 100000" | sudo tee --append /etc/security/limits.conf
[sudo] password for ngupta:
* hard nofile 100000
* soft nofile 100000
ngupta@node2:~$ cat /etc/security/limits.conf
.
.
#@student        -       maxlogins       4
 
 # End of file
 * hard nofile 100000
 * soft nofile 100000
 ngupta@node2:~$
```
Node3
````shell script
ngupta@node3:~$ echo "* hard nofile 100000
> * soft nofile 100000" | sudo tee --append /etc/security/limits.conf
[sudo] password for ngupta:
* hard nofile 100000
* soft nofile 100000
ngupta@node3:~$ cat /etc/security/limits.conf
.
.
#@student        -       maxlogins       4
 
 # End of file
 * hard nofile 100000
 * soft nofile 100000
 ngupta@node3:~$
````

### Launch Kafka on one machine
Now to launch kafka let's copy the server.properties from [here](configurations/server.properties) to your 
<KAFKA_PATH>/config folder. You need to update below property with your machine values:
* advertised.listeners=PLAINTEXT://<YOUR_IP>:9092
* log.dirs=<PATH_OF_KAFKA_DATA_DIR_YOU_CREATED>
* zookeeper.connect=<YOUR_ZOOKEEPER_CLUSTER>

For my operations I created the node1.properties which i am putting in kafka config directory. and then we will start 
kafka.
```shell script
ngupta@node1:~$ sudo service zookeeper start
[sudo] password for ngupta:
ngupta@node1:~$ ls
kafka  zookeeper.properties  zookeeper.sh
ngupta@node1:~$ cd kafka/config/
ngupta@node1:~/kafka/config$ ls
connect-console-sink.properties    connect-file-sink.properties    connect-standalone.properties  node1.properties     tools-log4j.properties
connect-console-source.properties  connect-file-source.properties  consumer.properties            producer.properties  trogdor.conf
connect-distributed.properties     connect-log4j.properties        log4j.properties               server.properties    zookeeper.properties
ngupta@node1:~/kafka/config$ rm server.properties
ngupta@node1:~/kafka/config$ mv node1.properties server.properties
ngupta@node1:~/kafka/config$ ls -lrt
total 64
-rw-r--r-- 1 ngupta ngupta 1169 Oct 18 00:10 trogdor.conf
-rw-r--r-- 1 ngupta ngupta 1032 Oct 18 00:10 tools-log4j.properties
-rw-r--r-- 1 ngupta ngupta 1925 Oct 18 00:10 producer.properties
-rw-r--r-- 1 ngupta ngupta 4727 Oct 18 00:10 log4j.properties
-rw-r--r-- 1 ngupta ngupta 1221 Oct 18 00:10 consumer.properties
-rw-r--r-- 1 ngupta ngupta 2262 Oct 18 00:10 connect-standalone.properties
-rw-r--r-- 1 ngupta ngupta 1552 Oct 18 00:10 connect-log4j.properties
-rw-r--r-- 1 ngupta ngupta  881 Oct 18 00:10 connect-file-source.properties
-rw-r--r-- 1 ngupta ngupta  883 Oct 18 00:10 connect-file-sink.properties
-rw-r--r-- 1 ngupta ngupta 5321 Oct 18 00:10 connect-distributed.properties
-rw-r--r-- 1 ngupta ngupta  909 Oct 18 00:10 connect-console-source.properties
-rw-r--r-- 1 ngupta ngupta  906 Oct 18 00:10 connect-console-sink.properties
-rw-rw-r-- 1 ngupta ngupta  802 Nov 12 03:18 zookeeper.properties
-rw-rw-r-- 1 ngupta ngupta 2159 Nov 18 11:23 server.properties
ngupta@node1:~/kafka/config$
```

We have copied configuration and now let's start kafka.
```shell script
ngupta@node1:~/kafka$ bin/kafka-server-start.sh config/server.properties
.
.
.
[2019-11-18 11:26:32,938] INFO Registered broker 1 at path /brokers/ids/1 with addresses: ArrayBuffer(EndPoint(192.168.109.131,9092,ListenerName(PLAINTEXT),PLAINTEXT)), czxid (broker epoch): 21474836507 (kafka.zk.KafkaZkClient)
[2019-11-18 11:26:32,940] WARN No meta.properties file under dir /data/kafka/meta.properties (kafka.server.BrokerMetadataCheckpoint)
[2019-11-18 11:26:33,121] INFO [ExpirationReaper-1-topic]: Starting (kafka.server.DelayedOperationPurgatory$ExpiredOperationReaper)
[2019-11-18 11:26:33,146] INFO [ExpirationReaper-1-Heartbeat]: Starting (kafka.server.DelayedOperationPurgatory$ExpiredOperationReaper)
[2019-11-18 11:26:33,151] INFO [ExpirationReaper-1-Rebalance]: Starting (kafka.server.DelayedOperationPurgatory$ExpiredOperationReaper)
[2019-11-18 11:26:33,206] INFO Successfully created /controller_epoch with initial epoch 0 (kafka.zk.KafkaZkClient)
[2019-11-18 11:26:33,276] INFO [GroupCoordinator 1]: Starting up. (kafka.coordinator.group.GroupCoordinator)
[2019-11-18 11:26:33,294] INFO [GroupCoordinator 1]: Startup complete. (kafka.coordinator.group.GroupCoordinator)
[2019-11-18 11:26:33,341] INFO [GroupMetadataManager brokerId=1] Removed 0 expired offsets in 42 milliseconds. (kafka.coordinator.group.GroupMetadataManager)
[2019-11-18 11:26:33,370] INFO [ProducerId Manager 1]: Acquired new producerId block (brokerId:1,blockStartProducerId:0,blockEndProducerId:999) by writing to Zk with path version 1 (kafka.coordinator.transaction.ProducerIdManager)
[2019-11-18 11:26:33,483] INFO [TransactionCoordinator id=1] Starting up. (kafka.coordinator.transaction.TransactionCoordinator)
[2019-11-18 11:26:33,490] INFO [TransactionCoordinator id=1] Startup complete. (kafka.coordinator.transaction.TransactionCoordinator)
[2019-11-18 11:26:33,511] INFO [Transaction Marker Channel Manager 1]: Starting (kafka.coordinator.transaction.TransactionMarkerChannelManager)
[2019-11-18 11:26:33,790] INFO [/config/changes-event-process-thread]: Starting (kafka.common.ZkNodeChangeNotificationListener$ChangeEventProcessThread)
[2019-11-18 11:26:33,832] INFO [SocketServer brokerId=1] Started data-plane processors for 1 acceptors (kafka.network.SocketServer)
[2019-11-18 11:26:33,895] INFO Kafka version: 2.3.1 (org.apache.kafka.common.utils.AppInfoParser)
[2019-11-18 11:26:33,896] INFO Kafka commitId: 18a913733fb71c01 (org.apache.kafka.common.utils.AppInfoParser)
[2019-11-18 11:26:33,900] INFO Kafka startTimeMs: 1574076393840 (org.apache.kafka.common.utils.AppInfoParser)
[2019-11-18 11:26:33,924] INFO [KafkaServer id=1] started (kafka.server.KafkaServer)
```

As we can is see in above log, kafka broker 1 is started.

### Setup Kafka as service
Now let's install kafka as service. So we will stop the running instance using Ctrl+C and then we will follow below steps:
* Copy file [kafka.sh](scripts/kafka.sh) in etc/init.d/ location.
* update KAFKA_ROOT_PATH property in kafka.sh file with your kafka folder.
* Add executable permission in kafka script
* Change owner of script to root.
* Update the services
* Start kafka
* Test kafka port
* Look into logs
 ```shell script
ngupta@node1:~$ ls
kafka  kafka.sh  zookeeper.properties   zookeeper.sh
ngupta@node1:~$ cp kafka.sh /etc/init.d/kafka.sh
cp: cannot create regular file '/etc/init.d/kafka.sh': Permission denied
ngupta@node1:~$ sudo cp kafka.sh /etc/init.d/kafka.sh
ngupta@node1:~$ sudo vi /etc/init.d/kafka.sh
ngupta@node1:~$ chmod +x /etc/init.d/kafka.sh
chmod: changing permissions of '/etc/init.d/kafka.sh': Operation not permitted
ngupta@node1:~$ sudo chmod +x /etc/init.d/kafka.sh
ngupta@node1:~$ sudo chown root:root /etc/init.d/kafka.sh
ngupta@node1:~$ sudo update-rc.d kafka.sh defaults
ngupta@node1:~$ sudo service kafka start
ngupta@node1:~$ nc -vz localhost 9092
nc: connect to localhost port 9092 (tcp) failed: Connection refused
ngupta@node1:~$ nc -vz localhost 9092
nc: connect to localhost port 9092 (tcp) failed: Connection refused
ngupta@node1:~$ nc -vz localhost 9092
Connection to localhost 9092 port [tcp/*] succeeded!
```

It take few seconds to start and then our kafka broker is started successfully. If you are planning to use only
single broker and hands-on please update min.insync.replicas to 1, otherwise you will be not able to perform produce
and consume operation. If you are going to complete cluster setup follow next section.

## 1.6 Kafka Cluster setup
To setup kafka in cluster, we are going to perform below steps:
* Augment the file handle limits.
* Edit configuration on each machine and make sure the broker ids are different also edit the advertiser listener AND 
Setup kafka as service on each node
* Launch cluster and observe the logs.
* Look all the broker in zookeeper are registered
* Test the cluster

### Augment file handle
We had done this in last section for our rest of two nodes as well and restarted server and zookeeper service.

### Setup kafka service
First we need to replace configuration in configuration directory and update broker id and advertise listener on each 
server. I have did for this lesson setup in file [node2.properties](configurations/node2.properties) 
and [node3.properties](configurations/node3.properties).
We have copied these files on both server respectively.

Node 2
```shell script
ngupta@node2:~/kafka/config$ ls
connect-console-sink.properties    log4j.properties
connect-console-source.properties  node2.properties
connect-distributed.properties     producer.properties
connect-file-sink.properties       server.properties
connect-file-source.properties     tools-log4j.properties
connect-log4j.properties           trogdor.conf
connect-standalone.properties      zookeeper.properties
consumer.properties
ngupta@node2:~/kafka/config$ rm server.properties
ngupta@node2:~/kafka/config$ mv node2.properties server.properties
ngupta@node2:~/kafka/config$ mkdir /data/kafka
ngupta@node2:~/kafka/config$ cd ..
ngupta@node2:~/kafka$ cd ..
ngupta@node2:~$ vi kafka.sh
ngupta@node2:~$ sudo cp kafka.sh /etc/init.d/kafka.sh
[sudo] password for ngupta:
ngupta@node2:~$ sudo vi /etc/init.d/kafka.sh
ngupta@node2:~$ chmod +x /etc/init.d/kafka.sh
chmod: changing permissions of '/etc/init.d/kafka.sh': Operation not permitte                                                                                  d
ngupta@node2:~$ sudo chmod +x /etc/init.d/kafka.sh
ngupta@node2:~$ sudo chown root:root /etc/init.d/kafka.sh
ngupta@node2:~$ sudo update-rc.d kafka.sh defaults
ngupta@node2:~$ sudo service kafka start
ngupta@node2:~$ nc -vz localhost 9092
Connection to localhost 9092 port [tcp/*] succeeded!
```
Node 3
```shell script
ngupta@node3:~$ cd kafka/config/
ngupta@node3:~/kafka/config$ ls
connect-console-sink.properties    log4j.properties
connect-console-source.properties  node3.properties
connect-distributed.properties     producer.properties
connect-file-sink.properties       server.properties
connect-file-source.properties     tools-log4j.properties
connect-log4j.properties           trogdor.conf
connect-standalone.properties      zookeeper.properties
consumer.properties
ngupta@node3:~/kafka/config$ rm server.properties
ngupta@node3:~/kafka/config$ mv node3.properties server.properties
ngupta@node3:~/kafka/config$ mkdir /data/kafka
ngupta@node3:~/kafka/config$ cd ..
ngupta@node3:~/kafka$ cd ..
ngupta@node3:~$ vi kafka.sh
ngupta@node3:~$ sudo cp kafka.sh /etc/init.d/kafka.sh
[sudo] password for ngupta:
ngupta@node3:~$ sudo vi /etc/init.d/kafka.sh
ngupta@node3:~$ sudo chmod +x /etc/init.d/kafka.sh
ngupta@node3:~$ sudo chown root:root /etc/init.d/kafka.sh
ngupta@node3:~$ sudo update-rc.d kafka.sh defaults
ngupta@node3:~$ sudo service kafka start
ngupta@node3:~$ nc -vz localhost 9092
Connection to localhost 9092 port [tcp/*] succeeded!
```

### Observe the log
We can see in server.log inside kafka/log/server.log that serves has been started.

### Zookeeper broker registration verification
```shell script
ngupta@node1:~$ kafka/bin/zookeeper-shell.sh localhost:2181
Connecting to localhost:2181
Welcome to ZooKeeper!
JLine support is disabled

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
ls /
[zookeeper, kafka]
ls /kafka
[cluster, controller_epoch, controller, brokers, admin, isr_change_notification, consumers, log_dir_event_notification, latest_producer_id_block, config]
ls /kafka/brokers
[ids, topics, seqid]
ls /kafka/brokers/ids
[1, 2, 3]
ls /kafka/brokers/ids/1
[]
get ls /kafka/brokers/ids
Command failed: java.lang.IllegalArgumentException: Path must start with / character
get /kafka/brokers/ids
null
cZxid = 0x500000008
ctime = Mon Nov 18 11:26:27 UTC 2019
mZxid = 0x500000008
mtime = Mon Nov 18 11:26:27 UTC 2019
pZxid = 0x5000000bd
cversion = 17
dataVersion = 0
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 0
numChildren = 3
get /kafka/brokers/ids/1
{"listener_security_protocol_map":{"PLAINTEXT":"PLAINTEXT"},"endpoints":["PLAINTEXT://192.168.109.131:9092"],"jmx_port":-1,"host":"192.168.109.131","timestamp":"1574080739330","port":9092,"version":4}
cZxid = 0x5000000bd
ctime = Mon Nov 18 12:38:59 UTC 2019
mZxid = 0x5000000bd
mtime = Mon Nov 18 12:38:59 UTC 2019
pZxid = 0x5000000bd
cversion = 0
dataVersion = 1
aclVersion = 0
ephemeralOwner = 0x3000007c12b0007
dataLength = 200
numChildren = 0
```

As we can see our brokers in kafka cluster node and when we query node data we can see the information about that particular
kafka broker node.

### Test the cluster
Let's test our cluster. For testing the cluster we will follow below steps:
* Create topic with replication factor of 3
```shell script
ngupta@node1:~/kafka$ bin/kafka-topics.sh --zookeeper 192.168.109.131:2181,192.168.109.132:2181,192.168.109.133:2181/kafka --create --topic test_topic --replication-factor 3 --partitions 3
WARNING: Due to limitations in metric names, topics with a period ('.') or underscore ('_') could collide. To avoid issues it is best to use either, but not both.
Created topic test_topic.
ngupta@node1:~/kafka$ bin/kafka-topics.sh --zookeeper 192.168.109.131:2181,192.168.109.132:2181,192.168.109.133:2181/kafka --list
test_topic
```
* Publish data to topic
```shell script
ngupta@node2:~/kafka$ bin/kafka-console-producer.sh --broker-list 192.168.109.131:9092,192.168.109.132:9092,192.168.109.133:9092 --topic test_topic
>This is test data
>for the cluster
>please verify 3 lines should come

```
* Reading data from topic
```shell script
ngupta@node3:~/kafka$ bin/kafka-console-consumer.sh --bootstrap-server 192.168.109.131:9092,192.168.109.132:9092,192.168.109.133:9092 --topic test_topic --from-beginning

This is test data
please verify 3 lines should come
for the cluster
^CProcessed a total of 3 messages
ngupta@node3:~/kafka$ bin/kafka-topics.sh --zookeeper 192.168.109.131:2181,192.168.109.132:2181,192.168.109.133:2181/kafka --describe --topic test_topic
Topic:test_topic        PartitionCount:3        ReplicationFactor:3     Configs:
        Topic: test_topic       Partition: 0    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1
        Topic: test_topic       Partition: 1    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2
        Topic: test_topic       Partition: 2    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3
ngupta@node3:~/kafka$

```
* Observe the kafka filesystem
```shell script
ngupta@node1:/data/kafka$ ls
cleaner-offset-checkpoint  __consumer_offsets-17  __consumer_offsets-26  __consumer_offsets-35  __consumer_offsets-44  __consumer_offsets-9
__consumer_offsets-0       __consumer_offsets-18  __consumer_offsets-27  __consumer_offsets-36  __consumer_offsets-45  log-start-offset-checkpoint
__consumer_offsets-1       __consumer_offsets-19  __consumer_offsets-28  __consumer_offsets-37  __consumer_offsets-46  meta.properties
__consumer_offsets-10      __consumer_offsets-2   __consumer_offsets-29  __consumer_offsets-38  __consumer_offsets-47  recovery-point-offset-checkpoint
__consumer_offsets-11      __consumer_offsets-20  __consumer_offsets-3   __consumer_offsets-39  __consumer_offsets-48  replication-offset-checkpoint
__consumer_offsets-12      __consumer_offsets-21  __consumer_offsets-30  __consumer_offsets-4   __consumer_offsets-49  test_topic-0
__consumer_offsets-13      __consumer_offsets-22  __consumer_offsets-31  __consumer_offsets-40  __consumer_offsets-5   test_topic-1
__consumer_offsets-14      __consumer_offsets-23  __consumer_offsets-32  __consumer_offsets-41  __consumer_offsets-6   test_topic-2
__consumer_offsets-15      __consumer_offsets-24  __consumer_offsets-33  __consumer_offsets-42  __consumer_offsets-7
__consumer_offsets-16      __consumer_offsets-25  __consumer_offsets-34  __consumer_offsets-43  __consumer_offsets-8
```
* Delete the topic
```shell script
ngupta@node2:~/kafka$ bin/kafka-topics.sh --zookeeper 192.168.109.131:2181,192.168.109.132:2181,192.168.109.133:2181/kafka --delete --topic test_topic
Topic test_topic is marked for deletion.
Note: This will have no impact if delete.topic.enable is not set to true.
```
## 1.7 Kafka Performance and Configuration Detail
### Performance
#### Disk: I/O
* Kafka reads are done sequentially, therefore make sure you should a disk type that corresponds well to the requirements
* Format your drives as XFS (easiest, no tuning required)
* If read/write throughput is your bottleneck
    * It is possible to mount multiple disks in parallel for kafka
    * the config is log.dirs=/disk1/kafka-logs,/disk2/kafka-logs,/disk16/kafka-logs
* Kafka performance is constant with regards to the amount of data stored in Kafka
    * Make sure you expire data fast enough (default is one week)
    * Make sure you monitor disk performance

#### Network
* Latency is key in Kafka
    * Ensure your kafka instances are your Zookeeper instances are geographically close.
    * Do not put same cluster broker in different geolocation.
* Network bandwidth is key in Kafka
    * Network will be your bottleneck.
    * Make sure you have enough bandwidth to handle many connections and TCP requests.
    * Make sure your network is high performance
* Monitor network usage too understand when it becomes a bottleneck.

#### RAM
* Kafka has amazing performance thanks to the OS page cache which utilizes your RAM.
* Kafka uses java heap memory and rest of the free memory used by the OS page cache
* We set the java heap and it's usage will increase when we increase number of partition on broker.
* To set the java heap we set KAFKA_HEAP_OPTS environment variable.
* Recommended that provide the java heap max to 4G and monitor your heap usage, when the number of partition will be 
increased,you may need to increase the size of heap.
* The remaining RAM will be used automatically for the Linux OS Page cache.
* Never ever allocate all the memory as JVM heap, to solve performance problem.
* This remaining RAM is used to buffer data to the disk and this is what gives Kafka an amazing performance.
* Any un-used memory will be automatically be leveraged by the Linux operating system and assign memory to the page cache.
* Make sure swapping is disabled for the Kafka entirely as we seen in zookeeper section.

#### CPU
* CPU is usually not a performance bottle neck in Kafka because Kafka doe not parse any messages, but can become one in
some situations
* If you have SSL enabled, Kafka has to encrypt and decrypt every payload, which adds load on the CPU
* Compression can be CPU bound if you force Kafka to do it. Instead, if you send compressed data, make sure your producer
and consumers are the ones doing the compression work(that's the default settings anyway).
* Make sure you monitor Garbage collection over time to ensure the pauses are not too long.
 
#### OS (Operation System)
* Use Linux or Solaris, running production clusters on Windows is not recommended.
* Increase the file descriptor limits (at least 100000 as a starting point)
* Make sure only Kafka is running on your Operating System. Anything else will just slow down your machine.

#### Others
* Make sure you have enough file handles opened on your servers, as Kafka opens 3 file descriptor for each 
topic-partition-segment that lives on the Broker.
* Make sure you use Java 8
* You may want to tune GC Implementation
* Set Kafka quotas in order to prevent unexpected spikes in usage.

### Configurations
#### advertised.listeners
Advertised listeners a key role in our kafka configuration, we need to think before setting up the value of this. Just 
first understand when a client connects to kafka cluster below steps will be performed:
* Client communicate with the server that it want to connect using provided IP
* Then Kafka send a response as that you can connect but use my advertised hostname.
* Kafka provide the advertised.host to client for forward communications.
* Client try to connect kafka server using the IP it get in last step.

Now let's understand what happen when we set advertised.listener to private IP, public IP and localhost.

##### private IP set as advertised listener
When the client is on same network, it will connect to server using public ip and private ip both. If we are trying to
connect using public IP then kafka will return it's private IP and since client is on the same network it can communicate.

When the client is on different network, then call will fail because when client connects using public IP then kafka provides
the private IP set in advertised.listener and then client try to connect to kafka cluster with that IP, so it will try 
connect in the same network and fails to connect.

##### localhost set as advertised listener
When we set the advertised.listener to localhost, then client want to connect to same machine. It will be good for the 
client who are on same machine on which kafka is running. But it is recommended never ever set the advertised.listener
to localhost.

##### public IP as advertised listener
When we set the advertised.listener to public IP the client can connect from same network or outside the network, But 
please cautious about that public IP will be static otherwise your cluster will be screwed after each broker restart.

We can use the DNS as well instead of ip for resolving host.

#### Important configurations
<table>
<tr><th>Parameter</th><th>Parameter description and recommended value</th></tr>
<tr><td>auto.create.topics.enable=true</td><td>set to false in production</td></tr>
<tr><td>background.threads=10</td><td>increase if you have a good CPU</td></tr>
<tr><td>delete.topic.enable=false</td><td>Your choice</td></tr>
<tr><td>log.flush.interval.messages</td><td>Don't ever change. Let your OS do it</td></tr>
<tr><td>log.retention.hours=168</td><td>Set according to your requirements</td></tr>
<tr><td>message.max.bytes=100012</td><td>increase if you need more than 1 MB message</td></tr>
<tr><td>min.insync.replicas=1</td><td>set to 2 if you want to be extra safe</td></tr>
<tr><td>num.io.threads=8</td><td>Increase If your network io is a bottleneck</td></tr>
<tr><td>num.network.threads=3</td><td>Increase If your network io is a bottleneck</td></tr>
<tr><td>num.recovery.threads.per.data.dir=1</td><td>set to number of disks</td></tr>
<tr><td>num.replica.fetchers=1</td><td>increase if your replicas are lagging</td></tr>
<tr><td>offset.retention.minutes=1440</td><td>after 24 hours you lose offsets</td></tr>
<tr><td>unclean.leader.election.enable=true</td><td>false if you don't want data loss</td></tr>
<tr><td>zookeeper.session.timeout.ms=6000</td><td>Increase If you timeout often</td></tr>
<tr><td>broker.rack=null</td><td>set your availability zone in AWS</td></tr>
<tr><td>default.replication.factor=1</td><td>set to 2 or 3 in kafka cluster</td></tr>
<tr><td>num.partition=1</td><td>set from 3 to 8 in your cluster</td></tr>
<tr><td>quota.producer.default=10485760</td><td>Set quota to 10MBs</td></tr>
<tr><td>quota.consumer.default=3</td><td>Set quota to 10MBs</td></tr>
</table>


# Section 2 : Admin Tools setup for Zookeeper and Kafka
For setting up upcoming tools I am using a different server which has IP 192.168.109.130, and hostname as DevAndTools 
machine. Let's get started.
## 2.1 Zoo navigator setup
Zoo navigator provides you UI based Zookeeper node CRUD operations and you can see your data easily. 

You can get zookeeper navigator [here](https://www.elkozmon.com/zoonavigator/), if you want to use docker image of the 
Zoo navigator you can directly go to site and there are straight away instructions. But for locally we need to build the
project and deploy in our HTTP server. Let's see how to do that:
* Checkout projects
* Install necessary tools npm and sbt
* Build the projects

### Checkout projects
```shell script
ngupta@devandtools:~$ mkdir KafkaTools
ngupta@devandtools:~$ cd KafkaTools/
ngupta@devandtools:~/KafkaTools$ mkdir Zookeeper
ngupta@devandtools:~/KafkaTools$ cd Zookeeper/
ngupta@devandtools:~/KafkaTools/Zookeeper$ ls -lrt
total 0
ngupta@devandtools:~/KafkaTools/Zookeeper$ mkdir ZooNav
ngupta@devandtools:~/KafkaTools/Zookeeper$ cd ZooNav/
ngupta@devandtools:~/KafkaTools/Zookeeper/ZooNav$ pwd
/home/ngupta/KafkaTools/Zookeeper/ZooNav
ngupta@devandtools:~/KafkaTools/Zookeeper/ZooNav$ git clone https://github.com/elkozmon/zoonavigator-api.git
Cloning into 'zoonavigator-api'...
remote: Enumerating objects: 151, done.
remote: Counting objects: 100% (151/151), done.
remote: Compressing objects: 100% (88/88), done.
remote: Total 2658 (delta 55), reused 108 (delta 35), pack-reused 2507
Receiving objects: 100% (2658/2658), 391.42 KiB | 692.00 KiB/s, done.
Resolving deltas: 100% (1487/1487), done.
ngupta@devandtools:~/KafkaTools/Zookeeper/ZooNav$ git clone https://github.com/elkozmon/zoonavigator-web.git
Cloning into 'zoonavigator-web'...
remote: Enumerating objects: 74, done.
remote: Counting objects: 100% (74/74), done.
remote: Compressing objects: 100% (50/50), done.
remote: Total 3065 (delta 39), reused 41 (delta 22), pack-reused 2991
Receiving objects: 100% (3065/3065), 1.11 MiB | 1.15 MiB/s, done.
Resolving deltas: 100% (2354/2354), done.
```
### Install necessary tools npm and sbt
```shell script
ngupta@devandtools:~$ sudo apt install nodejs
.
.
ngupta@devandtools:~$ nodejs --version
v8.10.0
ngupta@devandtools:~$ sudo apt install npm
.
.
ngupta@devandtools:~$ npm --version
3.5.2
ngupta@devandtools:~$ echo "deb https://dl.bintray.com/sbt/debian /" | sudo tee -a /etc/apt/sources.list.d/sbt.list
deb https://dl.bintray.com/sbt/debian /
ngupta@devandtools:~$ curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo apt-key add
OK
ngupta@devandtools:~$ sudo apt-get update
Hit:1 http://in.archive.ubuntu.com/ubuntu bionic InRelease
Hit:2 http://in.archive.ubuntu.com/ubuntu bionic-updates InRelease
Hit:3 http://in.archive.ubuntu.com/ubuntu bionic-backports InRelease
Hit:4 http://in.archive.ubuntu.com/ubuntu bionic-security InRelease
Ign:5 https://dl.bintray.com/sbt/debian  InRelease
Get:6 https://dl.bintray.com/sbt/debian  Release [815 B]
Get:7 https://dl.bintray.com/sbt/debian  Release.gpg [821 B]
Get:8 https://dl.bintray.com/sbt/debian  Packages [3,674 B]
Fetched 5,310 B in 3s (2,105 B/s)
Reading package lists... Done
ngupta@devandtools:~$sudo apt-get install sbt
.
.
```
### Build the projects
```shell script
ngupta@devandtools:~/KafkaTools/Zookeeper/ZooNav/zoonavigator-api$ sbt play/run
[info] Loading settings for project zoonavigator-api-build from plugins.sbt ...
[info] Loading project definition from /home/ngupta/KafkaTools/Zookeeper/ZooNav/zoonavigator-api/project
[info] Loading settings for project zoonavigator-api from build.sbt ...
[info] Set current project to zoonavigator-api (in build file:/home/ngupta/KafkaTools/Zookeeper/ZooNav/zoonavigator-api/)

--- (Running the application, auto-reloading is enabled) ---

[info] p.c.s.AkkaHttpServer - Listening for HTTP on /0:0:0:0:0:0:0:0:9000

(Server started, use Enter to stop and go back to the console...)

[info] play.api.Play - Application started (Dev) (no global state)
[debug] curator - GET_DATA event completed with result code 0
[debug] curator - GET_ACL event completed with result code 0
[debug] curator - CHILDREN event completed with result code 0
[debug] application - Closing connection to 192.168.109.131:2181,192.168.109.132:2181,192.168.109.133:2181. Cause: EXPIRED
```
```shell script
ngupta@devandtools:~/KafkaTools/Zookeeper/ZooNav/zoonavigator-web$ npm install -g @angular/cli
▌ ╢░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░╟
loadRequestedDeps         ▌ ╢██████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░╟
loadDep:uuid → resolveWit ▐ ╢██████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░╟
loadDep:uuid → resolveWit ▄ ╢██████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░╟
.
.
ngupta@devandtools:~/KafkaTools/Zookeeper/ZooNav/zoonavigator-web$ npm install
npm WARN deprecated core-js@2.6.10: core-js@<3.0 is no longer maintained and not recommended for usage due to the number of issues. Please, upgrade your dependencies to the actual version of core-js@3.
npm WARN deprecated graceful-fs@2.0.3: please upgrade to graceful-fs 4 for compatibility with current and future versions of Node.js
npm WARN deprecated minimatch@0.2.14: Please update to minimatch 3.0.2 or higher to avoid a RegExp DoS issue
npm WARN deprecated minimatch@0.3.0: Please update to minimatch 3.0.2 or higher to avoid a RegExp DoS issue
ngupta@devandtools:~/KafkaTools/Zookeeper/ZooNav/zoonavigator-web$ npm run dev

> zoonavigator-web@0.6.3-dev.1 dev /home/ngupta/KafkaTools/Zookeeper/ZooNav/zoonavigator-web
> ng serve --host 0.0.0.0 --proxy-config proxy.conf.json

WARNING: This is a simple server for use in testing or debugging Angular applications
locally. It hasn't been reviewed for security issues.

Binding this server to an open connection can result in compromising your application or
computer. Using a different host than the one passed to the "--host" flag might result in
websocket connection issues. You might need to use "--disableHostCheck" if that's the
case.
** Angular Live Development Server is listening on 0.0.0.0:4200, open your browser on http://localhost:4200/ **
 10% building 3/3 modules 0 activeℹ ｢wdm｣: wait until bundle finished: /                                                                                       Date: 2019-11-20T03:16:32.651Z
Hash: ad4d524735f43bc59da5
Time: 37890ms
chunk {main} main.js, main.js.map (main) 565 kB [initial] [rendered]
chunk {polyfills} polyfills.js, polyfills.js.map (polyfills) 332 kB [initial] [rendered]
chunk {runtime} runtime.js, runtime.js.map (runtime) 6.08 kB [entry] [rendered]
chunk {styles} styles.js, styles.js.map (styles) 2.32 MB [initial] [rendered]
chunk {vendor} vendor.js, vendor.js.map (vendor) 9.65 MB [initial] [rendered]
ℹ ｢wdm｣: Compiled successfully.
```
System has started, now we can see it on port UI on 4200. Below are some screenshot of UI.
![Login](screenshot/ZooNavigator/ZooNavigator1.jpg)

![Folder Structure](screenshot/ZooNavigator/ZooNavigtor2.jpg)

provide connection string like 192.168.109.131:2181,192.168.109.132:2181,192.168.109.133:2181.

## 2.2 Kafka Manager

Kafka manager is developed by Yahoo. This will give us information about brokers, topic, ISR and much more. Let's start 
setting up Kafka Manager.

**This Also requires the Scala and Node JS to install, if Scala and Node is not install on the system where you are 
planning to bring up kafka manager, please install these, for reference you can check installation steps for sbt and node 
in last section.**

#### Checking out the project
```shell script
ngupta@devandtools::~/Kafka/KafkaManager$ git clone https://github.com/yahoo/kafka-manager.git
ngupta@devandtools::~/Kafka/KafkaManager$ mv kafka-manager/* .
ngupta@devandtools::~/Kafka/KafkaManager$ rm -r kafka-manager
```

#### Building and running the project
```shell script
ngupta@devandtools:~/Kafka/KafkaManager$ ./sbt clean dist
Downloading sbt launcher for 1.2.8:
  From  http://repo.scala-sbt.org/scalasbt/maven-releases/org/scala-sbt/sbt-launch/1.2.8/sbt-launch.jar
    To  /home/ngupta/.sbt/launchers/1.2.8/sbt-launch.jar
Getting org.scala-sbt sbt 1.2.8  (this may take some time)...
.
.
.
[info] Packaging /home/ngupta/Kafka/KafkaManager/target/scala-2.12/kafka-manager_2.12-2.0.0.2-sans-externalized.jar ...
[info] Done packaging.
[success] All package validations passed
[info] Your package is ready in /home/ngupta/Kafka/KafkaManager/target/universal/kafka-manager-2.0.0.2.zip
[success] Total time: 170 s, completed Dec 1, 2019 8:07:06 AM
ngupta@devandtools:~/Kafka/KafkaManager/target$ mkdir /home/ngupta/Kafka/kafka-manager
ngupta@devandtools:~/Kafka/KafkaManager/target/universal$ pwd
/home/ngupta/Kafka/KafkaManager/target/universal
ngupta@devandtools:~/Kafka/KafkaManager/target/universal$ ls
kafka-manager-2.0.0.2.zip  scripts
ngupta@devandtools:~/Kafka/KafkaManager/target/universal$ cp -r * /home/ngupta/Kafka/kafka-manager/
ngupta@devandtools:~/Kafka/kafka-manager$ pwd
/home/ngupta/Kafka/kafka-manager
ngupta@devandtools:~/Kafka/kafka-manager$ unzip kafka-manager-2.0.0.2.zip
ngupta@devandtools:~/Kafka/kafka-manager$ ls
kafka-manager-2.0.0.2  kafka-manager-2.0.0.2.zip
ngupta@devandtools:~/Kafka/kafka-manager$ cd kafka-manager-2.0.0.2/
ngupta@devandtools:~/Kafka/kafka-manager/kafka-manager-2.0.0.2$ vi conf/application.conf
ngupta@devandtools:~/Kafka/kafka-manager/kafka-manager-2.0.0.2$ bin/kafka-manager
2019-12-01 08:29:32,403 - [WARN] application - application.conf @ file:/home/ngupta/Kafka/kafka-manager/kafka-manager-2.0.0.2/conf/application.conf: 12: play.crypto.secret is deprecated, use play.http.secret.key instead
2019-12-01 08:29:32,997 - [WARN] o.a.c.r.ExponentialBackoffRetry - maxRetries too large (100). Pinning to 29
2019-12-01 08:29:33,208 - [INFO] k.m.a.KafkaManagerActor - Starting curator...
2019-12-01 08:29:33,238 - [INFO] o.a.z.ZooKeeper - Client environment:zookeeper.version=3.4.13-2d71af4dbe22557fda74f9a9b4309b15a7487f03, built on 06/29/2018 00:39 GMT
2019-12-01 08:29:33,239 - [INFO] o.a.z.ZooKeeper - Client environment:host.name=devandtools
2019-12-01 08:29:33,240 - [INFO] o.a.z.ZooKeeper - Client environment:java.version=1.8.0_222
.
.
.
2019-12-01 08:29:33,363 - [INFO] o.a.z.ClientCnxn - Socket connection established to 192.168.109.131/192.168.109.131:2181, initiating session
2019-12-01 08:29:33,387 - [INFO] o.a.z.ClientCnxn - Session establishment complete on server 192.168.109.131/192.168.109.131:2181, sessionid = 0x100001078650003, negotiated timeout = 40000
2019-12-01 08:29:33,548 - [INFO] k.m.a.KafkaManagerActor - Started actor akka://kafka-manager-system/user/kafka-manager
2019-12-01 08:29:33,552 - [INFO] k.m.a.KafkaManagerActor - Starting delete clusters path cache...
2019-12-01 08:29:33,555 - [INFO] k.m.a.DeleteClusterActor - Started actor akka://kafka-manager-system/user/kafka-manager/delete-cluster
```
We have updated the zookeeper host in application conf after unzip. Now you can access the Kafka Manager on server's 9000
port. Below are few screenshot from application :
![Broker Information](screenshot/KafkaManager/Broker%20information.JPG)

![Cluster Information](screenshot/KafkaManager/Cluster%20information.JPG)

![Topic Information](screenshot/KafkaManager/Topic%20Information.JPG)

# Section 3 : Monitoring Tools setup for Zookeeper and Kafka
In the last section we have seen admin tools for the zookeeper and Kafka, Now we are going to see the solution which 
will monitor Zookeeper and Kafka. Zookeeper and Kafka internal matrices is exposed by JMX. There are different vendors
which uses this JMX and provide the matrices to monitor Kafka performance. For this we are going to use prometheus
and Grafana to setup monitoring. There are various monitoring tools in the market like ELK stack, AppDynamics, New Relic
and many more. You can choose according to your organization monitoring solution. Let first setup the Kafka Monitor UI.

## 3.1 Kafka Monitor UI
This Tool is developed by LinkedIn, and this provides us a UI to visualize a continuously running producer/consumer
and measure end-to-end latency. Let's start setting up the Kafka UI.

### Building and running the project
We will checkout the project and build the jar for this. 
```shell script
ngupta@devandtools:~/Kafka$  git clone https://github.com/linkedin/kafka-monitor.git
Cloning into 'kafka-monitor'...
remote: Enumerating objects: 51, done.
remote: Counting objects: 100% (51/51), done.
remote: Compressing objects: 100% (41/41), done.
remote: Total 1362 (delta 11), reused 16 (delta 2), pack-reused 1311
Receiving objects: 100% (1362/1362), 662.17 KiB | 972.00 KiB/s, done.
Resolving deltas: 100% (551/551), done.
ngupta@devandtools:~/Kafka$  cd kafka-monitor
ngupta@devandtools:~/Kafka/kafka-monitor$ ./gradlew jar
Downloading https://services.gradle.org/distributions/gradle-5.2.1-all.zip
...............................................................................................................................................................
.
.
.
Note: Recompile with -Xlint:unchecked for details.

BUILD SUCCESSFUL in 6m 43s
3 actionable tasks: 3 executed
<-------------> 0% WAITING
> IDLE
ngupta@devandtools:~/Kafka/kafka-monitor$ vi config/kafka-monitor.properties
ngupta@devandtools:~/Kafka/kafka-monitor$ ./bin/kafka-monitor-start.sh config/kafka-monitor.properties
[2019-12-02 02:44:03,097] INFO MultiClusterTopicManagementServiceConfig values:
        topic = kafka-monitor-topic
        topic-management.preferred.leader.election.check.interval.ms = 300000
        topic-management.rebalance.interval.ms = 600000
.
.
.
[2019-12-02 02:44:41,232] INFO ==============================================================
kmf:type=kafka-monitor:offline-runnable-count=0.0
kmf.services:name=single-cluster-monitor,type=produce-service:produce-availability-avg=1.0
kmf.services:name=single-cluster-monitor,type=consume-service:consume-availability-avg=1.0
kmf.services:name=single-cluster-monitor,type=produce-service:records-produced-total=414.0
kmf.services:name=single-cluster-monitor,type=consume-service:records-consumed-total=219.0
kmf.services:name=single-cluster-monitor,type=consume-service:records-lost-total=0.0
kmf.services:name=single-cluster-monitor,type=consume-service:records-lost-rate=0.0
kmf.services:name=single-cluster-monitor,type=consume-service:records-duplicated-total=0.0
kmf.services:name=single-cluster-monitor,type=consume-service:records-delay-ms-avg=14.963470319634704
kmf.services:name=single-cluster-monitor,type=produce-service:records-produced-rate=6.918333583997594
kmf.services:name=single-cluster-monitor,type=produce-service:produce-error-rate=0.0
kmf.services:name=single-cluster-monitor,type=consume-service:consume-error-rate=0.0
 (com.linkedin.kmf.services.DefaultMetricsReporterService)

```
We have to edit the zookeeper host and kafka broker host in kafka-monitor.properties, so consumer and producer can work
with them.
 
After setting up this we get UI like below on 8000 port.

![Kafka Monitor](screenshot/KafkaMonitor/Kafka%20Monitor.jpg)

##3.2 Prometheus setup for Zookeeper and Kafka
In this we are going to setup the monitoring for zookeeper and Kafka, So we will do below steps
* Install JMX exporter agent on each Kafka Broker
* Install Prometheus on our DevTools server
* Install JMX exporter agent on each Zookeeper server
* View the data pulled in Prometheus

Let's get started.

### Install JMX exporter agent on Kafka broker
We have to copy few files from [link](https://github.com/prometheus/jmx_exporter), which will give us exporter and \
configuration. Also one configuration file from example_configs of repo. Let's do it.
```shell script
ngupta@node1:~$ mkdir promethus
ngupta@node1:~$ ls
kafka  kafka.sh  promethus  zookeeper.properties  zookeeper.sh
ngupta@node1:~$ cd promethus/
ngupta@node1:~/promethus$ wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.12.0/jmx_prometheus_javaagent-0.12.0.jar
--2019-12-02 03:09:13--  https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.12.0/jmx_prometheus_javaagent-0.12.0.jar
Resolving repo1.maven.org (repo1.maven.org)... 151.101.40.209
Connecting to repo1.maven.org (repo1.maven.org)|151.101.40.209|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 370075 (361K) [application/java-archive]
Saving to: ‘jmx_prometheus_javaagent-0.12.0.jar’

jmx_prometheus_javaagent-0.12.0.jar     100%[==============================================================================>] 361.40K   271KB/s    in 1.3s

2019-12-02 03:09:15 (271 KB/s) - ‘jmx_prometheus_javaagent-0.12.0.jar’ saved [370075/370075]

ngupta@node1:~/promethus$ wget https://raw.githubusercontent.com/prometheus/jmx_exporter/master/example_configs/kafka-2_0_0.yml
--2019-12-02 03:29:37--  https://raw.githubusercontent.com/prometheus/jmx_exporter/master/example_configs/kafka-2_0_0.yml
Resolving raw.githubusercontent.com (raw.githubusercontent.com)... 151.101.0.133, 151.101.64.133, 151.101.128.133, ...
Connecting to raw.githubusercontent.com (raw.githubusercontent.com)|151.101.0.133|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 2785 (2.7K) [text/plain]
Saving to: ‘kafka-2_0_0.yml’

kafka-2_0_0.yml                         100%[==============================================================================>]   2.72K  --.-KB/s    in 0s

2019-12-02 03:29:42 (23.3 MB/s) - ‘kafka-2_0_0.yml’ saved [2785/2785]
ngupta@node1:~/promethus$ ls
jmx_prometheus_javaagent-0.12.0.jar  kafka-2_0_0.yml
ngupta@node1:~/promethus$
```
Now we have to add this java agent to kafka process. So we will change below in our script:
```shell script
export KAFKA_JMX_OPTS=-javaagent:/home/ngupta/promethus/jmx_prometheus_javaagent-0.12.0.jar=8080:/home/ngupta/promethus/kafka-2_0_0.yml
```
In this provide your javaagent and configuration path. Add repeat this step to all of your broker servers. This will give you metrics on 
<server_ip>:8080.

### Install Prometheus on our DevTools server
DevTools server is our different server than the kafka broker and zookeeper. You can have your own server to setup the 
admin tools and the monitoring setup. Let's install the prometheus on the server.
```shell script
ngupta@devandtools:~$ wget https://github.com/prometheus/prometheus/releases/download/v2.14.0/prometheus-2.14.0.linux-amd64.tar.gz
--2019-12-05 02:23:15--  https://github.com/prometheus/prometheus/releases/download/v2.14.0/prometheus-2.14.0.linux-amd64.tar.gz
Resolving github.com (github.com)... 13.234.210.38
Connecting to github.com (github.com)|13.234.210.38|:443... connected.
HTTP request sent, awaiting response... 302 Found
Location: https://github-production-release-asset-2e65be.s3.amazonaws.com/6838921/a4d9ad00-04a7-11ea-9761-3e7fd195c525?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIWNJYAX4CSVEH53A%2F20191205%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20191205T022315Z&X-Amz-Expires=300&X-Amz-Signature=04583ce45dd248f6327250aa3460a3f5e398ee5dd51127073f7c805ff9751f52&X-Amz-SignedHeaders=host&actor_id=0&response-content-disposition=attachment%3B%20filename%3Dprometheus-2.14.0.linux-amd64.tar.gz&response-content-type=application%2Foctet-stream [following]
--2019-12-05 02:23:15--  https://github-production-release-asset-2e65be.s3.amazonaws.com/6838921/a4d9ad00-04a7-11ea-9761-3e7fd195c525?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIWNJYAX4CSVEH53A%2F20191205%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20191205T022315Z&X-Amz-Expires=300&X-Amz-Signature=04583ce45dd248f6327250aa3460a3f5e398ee5dd51127073f7c805ff9751f52&X-Amz-SignedHeaders=host&actor_id=0&response-content-disposition=attachment%3B%20filename%3Dprometheus-2.14.0.linux-amd64.tar.gz&response-content-type=application%2Foctet-stream
Resolving github-production-release-asset-2e65be.s3.amazonaws.com (github-production-release-asset-2e65be.s3.amazonaws.com)... 52.217.46.52
Connecting to github-production-release-asset-2e65be.s3.amazonaws.com (github-production-release-asset-2e65be.s3.amazonaws.com)|52.217.46.52|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 58625125 (56M) [application/octet-stream]
Saving to: ‘prometheus-2.14.0.linux-amd64.tar.gz’

prometheus-2.14.0.linux-amd64.tar.gz    100%[==============================================================================>]  55.91M   922KB/s    in 64s

2019-12-05 02:24:21 (888 KB/s) - ‘prometheus-2.14.0.linux-amd64.tar.gz’ saved [58625125/58625125]

ngupta@devandtools:~$ tar -xzf prometheus-2.14.0.linux-amd64.tar.gz
ngupta@devandtools:~$ ls
Kafka  prometheus-2.14.0.linux-amd64  prometheus-2.14.0.linux-amd64.tar.gz
ngupta@devandtools:~$ mv prometheus-2.14.0.linux-amd64 prometheus
ngupta@devandtools:~$ rm prometheus-2.14.0.linux-amd64.tar.gz
ngupta@devandtools:~$ ls
Kafka  prometheus
ngupta@devandtools:~$ cd prometheus/
ngupta@devandtools:~/prometheus$ vi prometheus.yml
```
Change prometheus.yml for pointing to our Kafka JMX url and scrape interval was 15 sec. which means prometheus will get
the kafka metrics every 15 second and then the scrape config contains the job which need to run and from which url we 
need to fetch metrics.
```yaml
# my global config
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets:
      # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: 'prometheus'

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
    - targets: ['localhost:9090']

  - job_name: 'kafka'

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
            - targets: ['192.168.109.131:8080','192.168.109.132:8080','192.168.109.133:8080']

``` 
Let's start prometheus.
```shell script
ngupta@devandtools:~/prometheus$ ./prometheus \
>
level=info ts=2019-12-05T02:31:57.009Z caller=main.go:296 msg="no time or size retention was set so using the default time retention" duration=15d
level=info ts=2019-12-05T02:31:57.009Z caller=main.go:332 msg="Starting Prometheus" version="(version=2.14.0, branch=HEAD, revision=edeb7a44cbf745f1d8be4ea6f215e79e651bfe19)"
level=info ts=2019-12-05T02:31:57.009Z caller=main.go:333 build_context="(go=go1.13.4, user=root@df2327081015, date=20191111-14:27:12)"
level=info ts=2019-12-05T02:31:57.009Z caller=main.go:334 host_details="(Linux 4.15.0-70-generic #79-Ubuntu SMP Tue Nov 12 10:36:11 UTC 2019 x86_64 devandtools (none))"
level=info ts=2019-12-05T02:31:57.012Z caller=main.go:335 fd_limits="(soft=1024, hard=1048576)"
level=info ts=2019-12-05T02:31:57.012Z caller=main.go:336 vm_limits="(soft=unlimited, hard=unlimited)"
level=info ts=2019-12-05T02:31:57.016Z caller=main.go:657 msg="Starting TSDB ..."
level=info ts=2019-12-05T02:31:57.022Z caller=head.go:535 component=tsdb msg="replaying WAL, this may take awhile"
level=info ts=2019-12-05T02:31:57.023Z caller=head.go:583 component=tsdb msg="WAL segment loaded" segment=0 maxSegment=0
level=info ts=2019-12-05T02:31:57.025Z caller=main.go:672 fs_type=EXT4_SUPER_MAGIC
level=info ts=2019-12-05T02:31:57.025Z caller=main.go:673 msg="TSDB started"
level=info ts=2019-12-05T02:31:57.026Z caller=main.go:743 msg="Loading configuration file" filename=prometheus.yml
level=info ts=2019-12-05T02:31:57.027Z caller=main.go:771 msg="Completed loading of configuration file" filename=prometheus.yml
level=info ts=2019-12-05T02:31:57.017Z caller=web.go:496 component=web msg="Start listening for connections" address=0.0.0.0:9090
level=info ts=2019-12-05T02:31:57.028Z caller=main.go:626 msg="Server is ready to receive web requests."
```
After starting the prometheus we can access the UI on 9090 port of the server. You can query your metrics there. Below is
screenshot from prometheus.

![Promethus](screenshot/Promethus/Promethus.JPG)

#### Configure prometheus as service
To configure the prometheus as service we have put the prometheus.service in folder "/etc/systemd/system/prometheus.service"
```shell script
ngupta@devandtools:~/prometheus$ sudo vi /etc/systemd/system/prometheus.service
ngupta@devandtools:~/prometheus$ sudo systemctl start prometheus
ngupta@devandtools:~/prometheus$ sudo systemctl status prometheus
● prometheus.service - Prometheus Server
   Loaded: loaded (/etc/systemd/system/prometheus.service; disabled; vendor preset: enabled)
   Active: active (running) since Thu 2019-12-05 02:49:07 UTC; 4s ago
     Docs: https://prometheus.io/docs/introduction/overview/
 Main PID: 21017 (prometheus)
    Tasks: 7 (limit: 4632)
   CGroup: /system.slice/prometheus.service
           └─21017 /home/ngupta/prometheus/prometheus --config.file=/home/ngupta/prometheus/prometheus.yml --storage.tsdb.path=/home/ngupta/prometheus/data

Dec 05 02:49:07 devandtools prometheus[21017]: level=info ts=2019-12-05T02:49:07.220Z caller=main.go:657 msg="Starting TSDB ..."
Dec 05 02:49:07 devandtools prometheus[21017]: level=info ts=2019-12-05T02:49:07.227Z caller=head.go:535 component=tsdb msg="replaying WAL, this may take awhil
Dec 05 02:49:07 devandtools prometheus[21017]: level=info ts=2019-12-05T02:49:07.238Z caller=web.go:496 component=web msg="Start listening for connections" add
Dec 05 02:49:07 devandtools prometheus[21017]: level=info ts=2019-12-05T02:49:07.364Z caller=head.go:583 component=tsdb msg="WAL segment loaded" segment=0 maxS
Dec 05 02:49:07 devandtools prometheus[21017]: level=info ts=2019-12-05T02:49:07.364Z caller=head.go:583 component=tsdb msg="WAL segment loaded" segment=1 maxS
Dec 05 02:49:07 devandtools prometheus[21017]: level=info ts=2019-12-05T02:49:07.372Z caller=main.go:672 fs_type=EXT4_SUPER_MAGIC
Dec 05 02:49:07 devandtools prometheus[21017]: level=info ts=2019-12-05T02:49:07.372Z caller=main.go:673 msg="TSDB started"
Dec 05 02:49:07 devandtools prometheus[21017]: level=info ts=2019-12-05T02:49:07.372Z caller=main.go:743 msg="Loading configuration file" filename=/home/ngupta
Dec 05 02:49:07 devandtools prometheus[21017]: level=info ts=2019-12-05T02:49:07.374Z caller=main.go:771 msg="Completed loading of configuration file" filename
Dec 05 02:49:07 devandtools prometheus[21017]: level=info ts=2019-12-05T02:49:07.374Z caller=main.go:626 msg="Server is ready to receive web requests."
```

#### Install JMX exporter agent on each Zookeeper server
Now let's start to add this JMX agent with our zookeeper server. When our zookeeper server are not colocated then we will
download JMX agent and the zookeeper.yaml file on those server and then attach javaagent with the zookeeper process.
Since for this demo we co-located our kafka and zookeeper, we have already downloaded the JMX agent, we just need to
download the zookeeper.yaml file and attach the agent with zookeeper process. Let's get started:
```shell script
ngupta@node1:~$ cd promethus/
ngupta@node1:~/promethus$ ls -lrt
total 368
-rw-rw-r-- 1 ngupta ngupta 370075 Jul  4 14:40 jmx_prometheus_javaagent-0.12.0.jar
-rw-rw-r-- 1 ngupta ngupta   2785 Dec  2 03:29 kafka-2_0_0.yml
ngupta@node1:~/promethus$ wget https://raw.githubusercontent.com/prometheus/jmx_exporter/master/example_configs/zookeeper.yaml
--2019-12-05 03:11:04--  https://raw.githubusercontent.com/prometheus/jmx_exporter/master/example_configs/zookeeper.yaml
Resolving raw.githubusercontent.com (raw.githubusercontent.com)... 151.101.192.133, 151.101.128.133, 151.101.64.133, ...
Connecting to raw.githubusercontent.com (raw.githubusercontent.com)|151.101.192.133|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 997 [text/plain]
Saving to: ‘zookeeper.yaml’

zookeeper.yaml                          100%[==============================================================================>]     997  --.-KB/s    in 0s

2019-12-05 03:11:09 (41.1 MB/s) - ‘zookeeper.yaml’ saved [997/997]

ngupta@node1:~/promethus$ sudo vi /etc/init.d/zookeeper.sh
ngupta@node1:~/promethus$ sudo systemctl daemon-reload
ngupta@node1:~/promethus$ sudo service zookeeper stop
ngupta@node1:~/promethus$ sudo service zookeeper start
ngupta@node1:~/promethus$ sudo service zookeeper status
● zookeeper.service - SYSV: Standard script to start and stop zookeeper
   Loaded: loaded (/etc/init.d/zookeeper.sh; generated)
   Active: active (running) since Thu 2019-12-05 03:44:01 UTC; 3s ago
     Docs: man:systemd-sysv-generator(8)
  Process: 25003 ExecStart=/etc/init.d/zookeeper.sh start (code=exited, status=0/SUCCESS)
    Tasks: 30 (limit: 2290)
   CGroup: /system.slice/zookeeper.service
           └─25319 java -Xmx512M -Xms512M -server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -

Dec 05 03:44:01 node1 systemd[1]: Starting SYSV: Standard script to start and stop zookeeper...
Dec 05 03:44:01 node1 zookeeper.sh[25003]: Starting zookeeper
Dec 05 03:44:01 node1 systemd[1]: Started SYSV: Standard script to start and stop zookeeper.
lines 1-12/12 (END)
ngupta@node1:~/promethus$ 
```
we need to put below line in our service start script.
```text
export KAFKA_JMX_OPTS="-javaagent:/home/ngupta/promethus/jmx_prometheus_javaagent-0.12.0.jar=8081:/home/ngupta/promethus/zookeeper.yaml"
```
You can get latest configuration from the below link:

https://github.com/prometheus/jmx_exporter

We need to repeat above steps for all of our zookeeper servers. After this we need to add one more scrape config in 
prometheus on devtools server. Let's add below scrape config on our prometheus sever.
```text
  - job_name: 'zookeeper'

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
            - targets: ['192.168.109.131:8081','192.168.109.132:8081','192.168.109.133:8081']
```

```shell script
ngupta@devandtools:~/prometheus$ vi prometheus.yml
ngupta@devandtools:~/prometheus$ sudo systemctl restart prometheus
[sudo] password for ngupta:
ngupta@devandtools:~/prometheus$ sudo systemctl status prometheus
● prometheus.service - Prometheus Server
   Loaded: loaded (/etc/systemd/system/prometheus.service; disabled; vendor preset: enabled)
   Active: active (running) since Thu 2019-12-05 03:54:37 UTC; 5s ago
     Docs: https://prometheus.io/docs/introduction/overview/
 Main PID: 21096 (prometheus)
    Tasks: 7 (limit: 4632)
   CGroup: /system.slice/prometheus.service
           └─21096 /home/ngupta/prometheus/prometheus --config.file=/home/ngupta/prometheus/prometheus.yml --storage.tsdb.path=/home/ngupta/prometheus/data

Dec 05 03:54:37 devandtools prometheus[21096]: level=info ts=2019-12-05T03:54:37.541Z caller=head.go:535 component=tsdb msg="replaying WAL, this may take awhil
Dec 05 03:54:37 devandtools prometheus[21096]: level=info ts=2019-12-05T03:54:37.561Z caller=web.go:496 component=web msg="Start listening for connections" add
Dec 05 03:54:37 devandtools prometheus[21096]: level=info ts=2019-12-05T03:54:37.685Z caller=head.go:583 component=tsdb msg="WAL segment loaded" segment=0 maxS
Dec 05 03:54:38 devandtools prometheus[21096]: level=info ts=2019-12-05T03:54:38.387Z caller=head.go:583 component=tsdb msg="WAL segment loaded" segment=1 maxS
Dec 05 03:54:38 devandtools prometheus[21096]: level=info ts=2019-12-05T03:54:38.388Z caller=head.go:583 component=tsdb msg="WAL segment loaded" segment=2 maxS
Dec 05 03:54:38 devandtools prometheus[21096]: level=info ts=2019-12-05T03:54:38.397Z caller=main.go:672 fs_type=EXT4_SUPER_MAGIC
Dec 05 03:54:38 devandtools prometheus[21096]: level=info ts=2019-12-05T03:54:38.398Z caller=main.go:673 msg="TSDB started"
Dec 05 03:54:38 devandtools prometheus[21096]: level=info ts=2019-12-05T03:54:38.398Z caller=main.go:743 msg="Loading configuration file" filename=/home/ngupta
Dec 05 03:54:38 devandtools prometheus[21096]: level=info ts=2019-12-05T03:54:38.399Z caller=main.go:771 msg="Completed loading of configuration file" filename
Dec 05 03:54:38 devandtools prometheus[21096]: level=info ts=2019-12-05T03:54:38.400Z caller=main.go:626 msg="Server is ready to receive web requests."
lines 1-19/19 (END)
ngupta@devandtools:~/prometheus$
```
#### View the data pulled in Prometheus
![Promethus Zookeeper](screenshot/Promethus/Promethus_zookeeper.JPG)

## 3.3 Install Grafana and setup Dashboard
To get the grafana, You need to visit the [Grafana]() page and download the grafana binaries for linux. Then we will 
setup data sources as prometheus and some dashboard, Let's get started.
```shell script
ngupta@devandtools:~$ wget https://dl.grafana.com/oss/release/grafana-6.5.1.linux-amd64.tar.gz
--2019-12-05 12:19:29--  https://dl.grafana.com/oss/release/grafana-6.5.1.linux-amd64.tar.gz
Resolving dl.grafana.com (dl.grafana.com)... 151.101.54.217, 2a04:4e42:a::729
Connecting to dl.grafana.com (dl.grafana.com)|151.101.54.217|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 61013129 (58M) [application/x-tar]
Saving to: ‘grafana-6.5.1.linux-amd64.tar.gz’

grafana-6.5.1.linux-amd64.tar.gz        100%[==============================================================================>]  58.19M   341KB/s    in 2m 57s

2019-12-05 12:22:28 (337 KB/s) - ‘grafana-6.5.1.linux-amd64.tar.gz’ saved [61013129/61013129]
ngupta@devandtools:~$ tar -xzf grafana-6.5.1.linux-amd64.tar.gz
ngupta@devandtools:~$ ls -lrt
total 59596
-rw-rw-r-- 1 ngupta ngupta 61013129 Nov 28 08:10 grafana-6.5.1.linux-amd64.tar.gz
drwxrwxr-x 5 ngupta ngupta     4096 Dec  2 02:13 Kafka
drwxr-xr-x 5 ngupta ngupta     4096 Dec  5 03:53 prometheus
drwxrwxr-x 7 ngupta ngupta     4096 Dec  5 12:23 grafana-6.5.1
ngupta@devandtools:~$ rm *.gz
ngupta@devandtools:~$ mv grafana-6.5.1/ grafana
ngupta@devandtools:~$ ls
grafana  Kafka  prometheus
ngupta@devandtools:~/grafana$ bin/grafana-server
INFO[12-05|12:27:38] Starting Grafana                         logger=server version=6.5.1 commit=1763a0f branch=HEAD compiled=2019-11-28T07:43:49+0000
INFO[12-05|12:27:38] Config loaded from                       logger=settings file=/home/ngupta/grafana/conf/defaults.ini
INFO[12-05|12:27:38] Path Home                                logger=settings path=/home/ngupta/grafana
INFO[12-05|12:27:38] Path Data                                logger=settings path=/home/ngupta/grafana/data
.
.
.
INFO[12-05|12:27:43] HTTP Server Listen                       logger=http.server address=[::]:3000 protocol=http subUrl= socket=
INFO[12-05|12:27:43] Backend rendering via phantomJS          logger=rendering
WARN[12-05|12:27:43] phantomJS is deprecated and will be removed in a future release. You should consider migrating from phantomJS to grafana-image-renderer plugin. logger=rendering

```
Now we can access the grafana on port 3000. Use admin/admin to login in grafana for first login, you can change password
after login or keep as it is. After login you have some screen like below:
![Grafana after login](screenshot/Grafana/Grafana%20after%20login.jpg)

Let's setup the grafana as service for this you need to copy [grafana.service](scripts/grafana.service) file in directory
"/etc/systemd/system/". Change the grafana path in file with your path, it is applicable for all the services and scripts
till we have created. To start the service after creating the service use command "sudo systemctl start grafana".

We need to add datasource first. Let's setup the datasource, below screenshots will show you how to setup datasource.

* To create datasource click on gear icon on left and select datatsource. Then below screen will be shown:
![Datasource Add Step1](screenshot/Grafana/Add%20Datasource%201.jpg)

* Click on the Add Datasource then a page with various type of datasource will be shown, so search for pro and select 
prometheus as datasource.
![Datasource Add Step2](screenshot/Grafana/Add%20Datasource%202.jpg)

* Now provide the promethus server ip and port url and save and test, you should have screen like below:
![Datasource Add Step3](screenshot/Grafana/Add%20Datasource%203.jpg)

Now we will import a basic dashboard for the kafka first and test that we are getting metrics. Let's import dashboard 
from [link](https://grafana.com/grafana/dashboards/721). When you choose any dashboard after googling check for the data 
source type the dashboard use, like for the link dashboard it is prometheus Highlighted in below screenshot. 
![Dashboard datasource](screenshot/Grafana/Dashboard%20datasource.jpg)

Let's import this dashboard in Grafana and see the dashboard.
* To import a dashboard go to four square icon in left and click manage then below screen will appear.
![Import Dashboard Step 1](screenshot/Grafana/Dashboard%20Import%20step%201.jpg)

* Now click on import and provide the url as shown in below screenshot.
![Import Dashboard Step 2](screenshot/Grafana/Dashboard%20Import%20step%203.jpg)

* This will automatically resolve to below screen, you just need to select data source.
![Import Dashboard Step 3](screenshot/Grafana/Dashboard%20Import%20step%203.jpg)

* After importing this the dashboard will be appear like below.
![Import Dashboard Step 4](screenshot/Grafana/Dashboard%20Import%20step%204.jpg)

Using above steps you can import any dashboard. You can also create panels and provide your own formula to get the metrics
on dashboard.

To put this monitoring in production we need to take care of security and start up process according to your organization.
Also it is better if we setup the Prometheus and Grafana in separate machine for Production.
