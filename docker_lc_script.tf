locals {
  docker_lc_user_data = <<-EOF
  #!/bin/bash
  sudo systemctl enable docker
  sudo setenforce 0
  sudo systemctl start docker
  sudo docker start pet-adoption-container
  EOF
}