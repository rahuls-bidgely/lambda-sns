# Setup instance directory
#!/bin/bash -x
#
TAGPURPOSE=adhoc
> /var/log/cloud-init-output.log
> /var/log/cloud-init.log
#
echo "======USER SCRIPT START==========="

#lsblk  | awk '{print "/dev/"$1}' | sed -n 3p

REGION=$(curl -s 169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//');
INSTANCEID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id );



mkdir -p /opt/bidgely
mkdir -p /var/log/bidgely
mkdir -p /tmp/bidgely/
# TAG's Instance and Its Volumes
REGION=$(curl -s 169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//');

echo "=======USER SCRIPT STARTING========"
echo
echo "Tagging the instance and its volumes"

INSTANCEID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id );

SPOTOROD=`aws ec2 describe-instances --instance-ids $INSTANCEID --region $REGION --filter "Name=instance-lifecycle,Values=spot" --out text | grep $INSTANCEID`
if [ -z "$SPOTOROD" ]; then  TAGNAME=`echo $TAGNAME | sed "s/$TAGNAME/$TAGNAME-od/g"` ;
else TAGNAME=`echo $TAGNAME | sed "s/$TAGNAME/$TAGNAME-spot/g"`
fi

aws ec2 create-tags --resources $INSTANCEID --tags Key=Purpose,Value=$TAGPURPOSE Key=Name,Value=$TAGNAME Key=Environment,Value=$TAGENV Key=Component,Value=$TAGCOMPONENT Key=Owner,Value=$OWNER Key=Utility,Value=$UTILITY --region $REGION
INSTANC_VOLUMES=$(aws ec2 describe-volumes --filter Name=attachment.instance-id,Values=$INSTANCEID --query Volumes[].VolumeId --out text --region $REGION);
for i in `echo $INSTANC_VOLUMES`; do echo $i ; aws ec2 create-tags --resources $i --tags Key=Name,Value=$TAGNAME Key=Component,Value=$TAGCOMPONENT Key=Environment,Value=$TAGENV Key=Owner,Value=$OWNER Key=Utility,Value=$UTILITY  --region $REGION; done

NETWORKINTERFACEID=`aws ec2 describe-instances --instance-ids $INSTANCEID  --region $REGION --output text  | grep NETWORKINTERFACES | awk -F" " '{print $3}'`

for i in `echo $NETWORKINTERFACEID`; do echo $i ; aws ec2 create-tags --resources $i --tags Key=Name,Value=$TAGNAME Key=Component,Value=$TAGCOMPONENT Key=Environment,Value=$TAGENV Key=Owner,Value=$OWNER Key=Utility,Value=$UTILITY  --region $REGION; done

echo
echo "Configuring $REPO/$REPODIR"
#deb http://repo.bidgely.com prodna/
# Create Source list for packages to install from our local repo
echo "deb http://${REPO}/ $REPODIR/" >> /etc/apt/sources.list
echo "Package: *" >> /etc/apt/preferences
echo 'Pin: origin "${REPO}"' >> /etc/apt/preferences
echo "Pin-Priority: 1001" >> /etc/apt/preferences

UBUNTUVERSION=`cat /etc/issue | grep 18`


if [ ! -z "$UBUNTUVERSION" ]; then echo "$UBUNTUVERSION" ; sudo apt-get update --allow-insecure-repositories ; else sudo apt-get update ; fi

apt-get install htop -y

# Move Logs To S3 and Node Termination Checker Setup
aws s3 cp s3://$S3ARTIFACTSBUCKET/s3mover /opt/bidgely/s3mover
aws s3 cp s3://$S3ARTIFACTSBUCKET/s3move_logs /etc/cron.d/
chmod 777 /opt/bidgely/s3mover

# Set env
echo "Configuring env variable's"
sed  -i 's/QUEUE_SUFFIX=.*//g' /etc/environment;
sed -i 's/BIDGELY_ENV=.*//g' /etc/environment;
sed -i 's/JAVA_HOME=.*//g' /etc/environment;
echo BIDGELY_ENV=${BIDGELY_ENV} >> /etc/environment;
echo JAVA_HOME=${JAVA_HOME} >> /etc/environment;
if [ ! -z "$QUEUE_SUFFIX" ]; then
echo QUEUE_SUFFIX=${QUEUE_SUFFIX} >> /etc/environment;
fi
if echo $TAGNAME | grep -Eq pyamidisagg*
then
echo 'OMP_NUM_THREADS=1' >> /etc/environment;
fi
if echo $TAGNAME | grep -Eq pyamidisaggpriority*
then
echo 'PRIORITY_FLAG=true' >> /etc/environment;
fi
if echo $TAGNAME | grep -Eq pdfvalidator*
then
apt-get install libsm6 libxrender1 libfontconfig1 -y
fi

echo "Setting up public pem keys"
# Set the pem keys for login
echo "
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDm9y8GYBZWuaMBwYIISxd1oJSM9wuKNy4sDEjt7yjRcDzCWpenwZhtVM0rnIZyRIy0c1fx4wLeIJ0Q01ijffpvS00dZOj0XLCQ/56e+ODhOyLvQxgOEQGm/2lx5bosiBv7yN0KcwO+Vuc7vpIKBkr8hE6ntH/LkKBr0bBaAhOJX+WmSvIdV6XuXxJrhwSas1T8YZlrW6ykl6z2eR5cdPJgqVEcZitRESK65l/f22gC4eogccJAQnEDtuvJPnqCfgHOJ/eVwvp7wmf0B3E03JiHVQygZZMh/C80FjmSzKJVSA21HWjtGigU1nQwmQCn0ewdpoGhLqLURgd0rwxolnBx auto
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCf9/UbuEp6wPTzJTPuTvcdxIZWM2iUDQgUfjFW07CIH0H1P0o1YLnQsCQqKGxePPuSuBma3239sNQ/6D8w1/EB6nh5S3XP7F+yyAQqs8rZNNYY1EnFnrzQ4qpBy+7uUZEGUu3v5YRPHF99rTNo3lDbjZQ3bTu6WeOxjqQfuZFEL6k9eNIjQjPumlUG6qf1u6jefxOvA6O9Rip+9lkipC8IktrDz0CXBTTk2MW/qFWP9RIGB+XyIk7v2XeUAIT+B/uuO/zaA3uhN9AFPwok/h/d/caaJyfr87zUAwTR2qyoMZOpE6c0NOf6xkhOvCFpGi1NEh4MfyWDrPrihLb8IjN7 bops
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4hLkA190wTcAWd54XEyNznKElDBgn0g3rSdHOCCZBLYnpOXRRTyYnujGEYXktauOFseTbl+l1cc0j75td+d0Bi4K1bX/MmI1b5kJB12MCMIWNfAsXbXF6CVTDdgyZFqc4V1lbk5RvgPggieg2SnhDMX1XZmP6N9VPMB3j02Roxbcs+0MpAcUa13fJ5ZSrh+8nBq3vWDobpk/+F80C4mQbqm6NOhPKxF/vK2+qY6fneAgMo2HrHVwPvWTUQvNfNLQrevvbac7otM8zoePyha70CteqLw/f8EK2NiwSyYqPFst6bjNa4I+7rr75kOy44RuRO1viS9bGfI6kUdH3zG6r bsup
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCTU89Fk8EdFFLq8oj1Gz6jOQYYaxS+/eDxrVMKHO/IJ3QuOPCw45+zUfXPF7ypOkoR8XKCH9aTJVo42Iw0ePGK24/dA3nU2mTCp1hLfTuX1rybN+pfW9ZLpR1GeaLUDqlxIWxG+rFxkeFRRpNFI/hg98sOvw3Zk7fvfd9IFcVycKWa0TQPPTpxj4xSBeYWI+qpmte7nAjzF93X8XMwcdRbR9LZZlfUfn6mZLvr0D6vGmeJOhrS74pgf8ybhM8qABtjOGPMxvjg9lkiiCwJ0zeEeXRdFjZS29zD8AydQUYmCZnb9aVzdsMQtHv62u5SacSm/2wiCJqzA5V0x2WdJQJz prodca
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCSPAMBR9eSqVwsKR//PLm0h48Eco1Rn26OSHy9F2pyHzY++hAMWjc0uPf6zbAIeYsVXi0O2SwU48x+Q0y/mqUyUig8e5/6/i19AEDntEks2JjG46b7hD7+b+/VgF5kj578uAPoFAVsJOqvE5TOd6g0KGYX3ZIh/AM632+J0ti2TjKK7I9qfBYHDQKQvGyLoVlQemnTO0zhdZHyjfo4YYAOdBkfO4MIM5Oy9P8C8cIBjw9MnQP99ovkYtJ7AUp22rIgB1l4zoNeeiWfVawKAl/v7+QA0OKcRWH7dAhFFTz2WEwcWfvwCdINSfZK3yh9mHiYqAXHRAumdsVWJu/5XNMb jenkins" > /home/ubuntu/.ssh/authorized_keys

echo "Configuring package installation setup"
# Package Installation
aws s3 ls s3://$S3ARTIFACTSBUCKET/
aws s3 cp s3://$S3ARTIFACTSBUCKET/prodca-rpmlist .
PACKAGELIST=`cat prodca-rpmlist | grep -w $TAGNAME | awk -F \| '{print $2}' | tr "," " "`

export DEBIAN_FRONTEND=noninteractive
echo "Unstalling the following packages \"$PACKAGELIST\""
sudo dpkg -P "$PACKAGELIST" ; sudo dpkg -P "$PACKAGELIST"
echo "================================================="
echo "Installing the following packages \"$PACKAGELIST\""
for PACKAGE in `echo "$PACKAGELIST"`; do
    apt-get install $PACKAGE -y --force-yes
done
#
# Cloudwatch Setup
if [ "$CLOUDWATCH" == "YES" ]; then
echo "Cloudwatch Setup ...."
aws s3 cp s3://$S3ARTIFACTSBUCKET/cloudwatch-logpush.sh /opt/bidgely/cloudwatch-logpush.sh
chmod 777 /opt/bidgely/cloudwatch-logpush.sh
sh /opt/bidgely/cloudwatch-logpush.sh
fi
#

echo "Stopping the awslogs..."
sudo service awslogs stop

echo
echo "=================USER SCRIPT END===================="
rm -rf userdata.sh
