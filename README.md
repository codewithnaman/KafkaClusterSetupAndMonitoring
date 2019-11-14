# Kafka Cluster Setup, Monitoring setup and Operations

* [Section 1 : Kafka Cluster Setup](#section-1--kafka-cluster-setup)
    * [1.1 Zookeeper Theory Part](#11-zookeeper-theory-part)
    * [1.2 Zookeeper Single instance setup](#12-zookeeper-single-instance-setup)
    * [1.3 Zookeeper Cluster setup](#13-zookeeper-cluster-setup)

* [Section : Tools setup for Zookeeper and Kafka]()
    * [Zoo navigator setup]()
    * [Netflix Exhibitor setup]()

# Section 1 : Kafka Cluster setup
In this section we are going to discuss below to setup a stable Kafka Cluster
* Zookeeper Cluster
* Kafka Cluster
* Proper replication factor
* Proper configurations
* Administration tools
* HA setting for the cluster

For this course I am using three VMs, each has ubuntu 18.04 and Open JDK 8 install on it. For this course we will 
setup zookeeper and kafka node on each of these three nodes. This is not recommended practice to setup Kafka and
zookeeper co-located. So for this we have static IP setup has done each virtual machine, this is necessary to have
static IP or DNS which can resolve to our HOST. For current setup we have below IP and node name respectively.
* Node 1 - 192.168.109.131
* Node 2 - 192.168.109.132
* Node 3 - 192.168.109.133

If you don't setup your IP static then it will create a problem in cluster every time you restart machine. To setup the 
static ip edit below file in Ubuntu 18.04 and make your file look like below:
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
In above my 192.168.109.132 is static IP for that machine, Please make sure it will be assigned to unique machine in
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
* Zookeeper also maintains the IST (in sync replicas) for partitions, Also in case any broker got disconnect then it will
perform the leader election for partition. The election is as fast the cluster can recover as fast in case of 
the broker failure.
* Zookeeper stores the Kafka cluster id which is randomly generated at 1st startup of cluster.
* Zookeeper also keeps data about ACL(Access control list) in case of security enabled, then it keeps information for 
ACL of Topics, Consumer Groups and Users.

### Zookeeper Cluster/Quorum sizing
* Zookeeper need to have a strict majority of servers up to form the strict majority when votes happen
* There Zookeeper quorums have 1,3,5,7.... (2N+1) servers
* So After this configuration our cluster can survive till N node go down, So in case of 3 it will be active till 2 server
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
As we can see the tickTime, initLimit and syncLimit play important role for synchronization and initialization that's
why a performant network and machine is required for this.

## 1.2 Zookeeper Single instance setup
For now we just start setting up our single instance of zookeeper to do this. For now I have just Linux machine which
has Ubuntu 18.04. To start with setting up zookeeper we are going to perform below steps:
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
This will install the JDK on your machine, to test the JDK is installed or not your machine fire below command:
```shell script
ngupta@node1:~$ java -version
openjdk version "1.8.0_222"
OpenJDK Runtime Environment (build 1.8.0_222-8u222-b10-1ubuntu1~18.04.1-b10)
OpenJDK 64-Bit Server VM (build 25.222-b10, mixed mode)
ngupta@node1:~$
```
So above output is showing that I have installed the JDK 8 version 1.8.0_222. The command will be differ for the different
Linux flavour if you are not using Ubuntu, Google how to install the JDK for your Linux flavor and do it.
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
will set this up to 1. To setup the value for current session we will use the below command:
```shell script
ngupta@node1:~$ sudo sysctl vm.swappiness=1
vm.swappiness = 1
ngupta@node1:~$ sudo sysctl vm.swappiness
vm.swappiness = 1
``` 
In above command we set the value and checked it, but it is for the current session, if our machine get restart then it 
will set to it's default value again. To setup this for machine we need to add the entry vm.swappiness = 1 to 
/etc/sysctl.conf. To do this you can use vi editor or to append in last you can use below command:
```shell script
ngupta@node1:~$ echo 'vm.swappiness=1' | sudo tee --append /etc/sysctl.conf
ngupta@node1:~$ cat /etc/sysctl.conf |grep 'swappiness'
vm.swappiness=1
```
As you can see we have disabled the RAM swap. Now let's move to next step.

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
As of now we are leaving this settings as it is now and start our zookeeper. Again these settings are not best suited for
the production environment in later section I will explain what are setting you need to take care while setting the Zookeeper
in production. Let's move to next step

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
So your zookeeper started but it is in hand mode of the zookeeper, you can't give any further command from same window.
Also when the window will be closed then zookeeper will go down, so Now we will start zookeeper in the background mode
using below command
```shell script
ngupta@node1:~/kafka/kafka_2.12-2.3.0$ bin/zookeeper-server-start.sh -daemon config/zookeeper.properties
ngupta@node1:~/kafka/kafka_2.12-2.3.0$
```

So zookeeper wil be run in the background. Let's test it by using some command on the zookeeper:
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
If you are getting the output on ls / as [zookeeper] then the zookeeper is good. We have one more method to test the
zookeeper which comes from [Four letter words zookeeper command](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_zkCommands)
to test zookeeper.
```shell script
ngupta@node1:~/kafka/kafka_2.12-2.3.0$ echo "ruok" | nc localhost 2181 ; echo
imok
```
so In this command we are sending the ruok("Are you OK?") command to zookeeper and in response zookeeper returning response
imok("I am OK").

Now let's setup the zookeeper as service. 

### Setup Zookeeper as a service on the machine
To register the zookeeper as service we need some script which can start,stop,restart our zookeeper server. I have kept
one script with file name [zookeeper.sh](scripts/zookeeper.sh) in scripts folder to perform this. We will copy this script
to our servers in the directory. You just need to update the KAFKA_ROOT_PATH in file with your path to kafka and then 
copy this file to /etc/init.d. Since this is script we need to give the executable permission on this using chmod
so we will do it. I have copied this file and edited with my kafka path in home directory, now we will copy to init.d
directory.
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
so as you can see we have tested our service by starting,stopping and using four letter word command  followed by service
status. and It is working. To check the logs just go to kafka directory and perform the less command on the the logs/zookeeper.out.

Now our zookeeper has been setup, let's get some hands-on on the zookeeper cli. This is not required for Kafka Cluster
but it is good to have.

### Hands-on over Zookeeper CLI
Let's understand and some of the commands we can use in Zookeeper with CLI, As written in above section this is not required
but good to have. We will look below operations using the Zookeeper CLI. 
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
As you can see in above script we entered in CLI then we had done ls to list all the nodes. Initially we did ls only
and we got no results as we were not querying the root. Then we created the node we need to provide the / character
at start otherwise we get the error as you can see in above output. So when we had proper syntax like 
"create /my-node "This is my-node node data" a node is created with data in it which we had provided. And when we
query using "ls /" we can see our newly created node. Now let's create a sub node.
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
To get your data from Zookeeper you need to fire the command get and path to node.
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
Let's watch the nodes, watching means whenever the data is updated on the node we will get an notification when we are
watching on the data. To set the watch we need to pass one more argument with get which is true to watch as done below:

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
To delete data recursively we need to use below command:
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

So we have java node in our each server.

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
are our new node so we had setup for them.

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
At Node 1 we have downloaded a copy of Kafka and copied on to the server path /home/ngupta. Let's check server 2 and 
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

So we have zookeeper running on each server, But they are still not in cluster. To start them as cluster we need to
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

If your any server not able to connect to other one first check zookeeper service up on them properly If zookeeper 
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
also you can use while setting up. You just need to update the data.dir and according to your cluster update server.x.

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
this file as your configuration and network IPs. We also copied these file to Node 2 and Node 3 and have perform the
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

So This will stop when you start at least 2 zookeeper servers, When you will start 3 zookeeper servers below will be 
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

After bringing up the cluster using the command we tested that they are working fine,no running exception. Let's do the 
four letter command check again and then we will stop and bring them up using service. 
```shell script
ngupta@node1:~$ echo "ruok" | nc 192.168.109.131 2181 ; echo
imok
ngupta@node1:~$ echo "ruok" | nc 192.168.109.132 2181 ; echo
imok
ngupta@node1:~$ echo "ruok" | nc 192.168.109.133 2181 ; echo
imok
```

So our servers are healthy, we can start them as service. After starting the service double check with four letter 
command.

Let's talk about one more other four letter command which is stat, which gives the information about each zookeeper and 
their mode. Below is the command and it's output.
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

So it will show you the latency for my case because I am doing in multiple VMs on same machine it is 0. When you go out 
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

So our data is getting replicated to other servers as well. So our zookeeper is now in cluster and happy.

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
recieved.
```shell script
ngupta@node1:~/kafka$ echo "cons"| nc localhost 2181
 /127.0.0.1:34454[0](queued=0,recved=1,sent=0)
```
 
You can the more commands provided in the link in this section start.  

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

## 1.4 Kafka Cluster setup
