#!/bin/bash
sleep 300
sudo mkfs.ext4 /dev/xvdb
sudo mkfs.ext4 /dev/xvdc
sudo mkdir -m 000 /mnt1
sudo mkdir -m 000 /mnt2
echo "/dev/xvdb /mnt1 auto noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/xvdc /mnt2 auto noatime 0 0" | sudo tee -a /etc/fstab
mount /mnt1
mount /mnt2
chown -R cassandra:cassandra /mnt1
chown -R cassandra:cassandra /mnt2
cd /mnt1/
mkdir cassandra
cd cassandra
mkdir commitlog
cd ~
cd /mnt2/
mkdir cassandra
cd cassandra
mkdir data
chown -R cassandra:cassandra /mnt1/
chown -R cassandra:cassandra /mnt2/
sed -i 's/192.168.10.10,192.168.11.10,192.168.12.10/10.2.9.218,10.2.9.59,10.2.9.190/g' /etc/cassandra/cassandra.yaml;
sed -i 's/PrfmCluster/NA2Cluster/g' /etc/cassandra/cassandra.yaml;
sed -i 's/us-east-m4/dc1/g' /etc/cassandra/cassandra-rackdc.properties;
sed -i 's/rack1/1a/g' /etc/cassandra/cassandra-rackdc.properties;
sed -i 's/Ec2Snitch/GossipingPropertyFileSnitch/g' /etc/cassandra/cassandra.yaml;
ip=`/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}'`
sed -i 's/192.168.10.10/'"$ip"'/g' /etc/cassandra/cassandra.yaml;
sed -i 's#/var/lib/cassandra/data#/mnt2/cassandra/data#g' /etc/cassandra/cassandra.yaml
sed -i 's#/var/lib/cassandra/commitlog#/mnt1/cassandra/commitlog#g' /etc/cassandra/cassandra.yaml
