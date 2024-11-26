terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

resource "digitalocean_droplet" "terraform-infrastructure" {
  image  = "ubuntu-20-04-x64"
  name   = "terraform-infrastructure"
  region = "sgp1"
  size   = "s-1vcpu-1gb"
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]

  user_data = <<-EOF
    #!/bin/bash
    # Update and install necessary packages
    apt-get update
    apt-get install -y nginx net-tools fontconfig openjdk-17-jre-headless

    # Install Docker
    apt-get install -y docker.io

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/2.5.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Jenkins configuration
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

    # Install Jenkins
    apt-get update
    apt-get install -y jenkins

    # Configure Docker permissions
    systemctl restart docker.service
    usermod -aG docker $USER
    usermod -aG docker jenkins
    newgrp docker
    chmod 666 /var/run/docker.sock

    # NGINX Reverse Proxy for Jenkins
    cat <<EOT > /etc/nginx/sites-available/default
    server {
        listen 80;
        server_name viethoang-terraform-infrastructure.io.vn;

        location / {
            proxy_pass http://localhost:8080;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
    EOT

    # Restart NGINX to apply the new configuration
    systemctl restart nginx

    # Enable and restart services
    systemctl enable docker.service jenkins.service nginx.service
    systemctl restart docker.service jenkins.service nginx.service
  EOF
}

resource "digitalocean_ssh_key" "default" {
  name       = "terraform-infrastructure"
  public_key = var.ssh_public_key
}

provider "digitalocean" {
  token = var.do_token
}
