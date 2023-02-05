locals {
  ansible_user_data = <<-EOF
#!/bin/bash
sudo yum update -y

echo "***********Install python for ansible and docker enginee***********"
sudo yum install python3.8 -y
sudo alternatives --set python /usr/bin/python3.8
sudo yum -y install python3-pip

#Install ansible
sudo yum install ansible -y

#Install docker
sudo pip3 install docker-py
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce -y

#Enable and start docker engine and assign user
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

#changing ssh configs
echo "PubkeyAcceptedKeyTypes=+ssh-rsa" >> /etc/ssh/sshd_config.d/10-insecure-rsa-keysig.conf
sudo service sshd restart
sudo bash -c ' echo "StrictHostKeyChecking No" >> /etc/ssh/ssh_config'

echo "***********private key in new file***********"
cat <<EOT>> /home/ec2-user/.ssh/anskey_rsa
${tls_private_key.pacpet1_key.private_key_pem}
EOT

#Install and configure user
pip3 install ansible --user
sudo chown ec2-user:ec2-user /etc/ansible
sudo chmod -R 700 .ssh/
sudo chmod 600 .ssh/authorized_keys
sudo chown -R ec2-user:ec2-user .ssh/
sudo chown ec2-user:ec2-user hosts

#configure localhost and docker connection
cat <<EOT>> /etc/ansible/hosts
localhost ansible_connection=local
[docker_host]
${aws_instance.pacpet1_dockerserver.public_ip}  ansible_ssh_private_key_file=/home/ec2-user/.ssh/anskey_rsa
EOT

#Install New relic
sudo curl -o /etc/yum.repos.d/newrelic-infra.repo https://download.newrelic.com/infrastructure_agent/linux/yum/el/7/x86_64/newrelic-infra.repo
sudo yum -q makecache -y --disablerepo='*' --enablerepo='newrelic-infra'
sudo yum install newrelic-infra -y
echo "license_key: eu01xxedb357e285032e439afe5df743eb20NRAL" | sudo tee -a /etc/newrelic-infra.yml

#create docker file
sudo mkdir /opt/docker
sudo chown -R ec2-user:ec2-user /opt/docker
sudo chmod -R 700 /opt/docker
touch /opt/docker/Dockerfile
cat <<EOT>> /opt/docker/Dockerfile
# pull tomcat image from docker hub
FROM tomcat
FROM openjdk:8-jre-slim
#copy war file on the container
COPY spring-petclinic-2.4.2.war app/
WORKDIR app/
RUN pwd
RUN ls -al
ENTRYPOINT [ "java", "-jar", "spring-petclinic-2.4.2.war", "--server.port=8085"]
EOT

#create docker-image file
touch /opt/docker/docker-image.yml
cat <<EOT>> /opt/docker/docker-image.yml
---
 - hosts: localhost
  #root access to user
   become: true

   tasks:
   - name: login to dockerhub
     command: docker login -u cloudhight -p CloudHight_Admin123@

   - name: Create docker image from Pet Adoption war file
     command: docker build -t pet-adoption-image .
     args:
       chdir: /opt/docker

   - name: Add tag to image
     command: docker tag pet-adoption-image cloudhight/pet-adoption-image

   - name: Push image to docker hub
     command: docker push cloudhight/pet-adoption-image

   - name: Remove docker image from Ansible node
     command: docker rmi pet-adoption-image cloudhight/pet-adoption-image
     ignore_errors: yes
EOT

#create docker-container file
touch /opt/docker/docker-container.yml
cat <<EOT>> /opt/docker/docker-container.yml
---
 - hosts: docker_host
   become: true

   tasks:
   - name: login to dockerhub
     command: docker login -u cloudhight -p CloudHight_Admin123@

   - name: Stop any container running
     command: docker stop pet-adoption-container
     ignore_errors: yes

   - name: Remove stopped container
     command: docker rm pet-adoption-container
     ignore_errors: yes

   - name: Remove docker image
     command: docker rmi cloudhight/pet-adoption-image
     ignore_errors: yes

   - name: Pull docker image from dockerhub
     command: docker pull cloudhight/pet-adoption-image
     ignore_errors: yes

   - name: Create container from pet adoption image
     command: docker run -it -d --name pet-adoption-container -p 8080:8085 cloudhight/pet-adoption-image
     ignore_errors: yes
EOT

#create newrelic file
cat << EOT > /opt/docker/newrelic.yml
---
 - hosts: docker
   become: true

   tasks:
   - name: install newrelic agent
     command: docker run \
                     -d \
                     --name newrelic-infra \
                     --network=host \
                     --cap-add=SYS_PTRACE \
                     --privileged \
                     --pid=host \
                     -v "/:/host:ro" \
                     -v "/var/run/docker.sock:/var/run/docker.sock" \
                     -e NRIA_LICENSE_KEY=eu01xx7c0963548bf7c1e0573aa71a97340aNRAL \
                     newrelic/infrastructure:latest
EOT

echo "****************Change Hostname(IP) to something readable**************"
sudo hostnamectl set-hostname Ansible
sudo reboot
EOF
}