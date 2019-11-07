# Kafka Cluster Setup, Monitoring setup and Operations

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

```

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
 