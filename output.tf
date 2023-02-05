output "pacpet1_ansibleserver" {
  value       = aws_instance.pacpet1-ansible-server.public_ip
  description = "ansible server ip"
}

output "pacpet1_dockerserver" {
  value       = aws_instance.pacpet1_dockerserver.public_ip
  description = "docker server ip"
}

 output "db-endpoint" {
  value = aws_db_instance.pacpet1-rds.endpoint
} 

output "pacpet1_jenkinsserver" {
  value       = aws_instance.pacpet1_Jenkins_Host.public_ip
  description = "jenkins server ip"
}

output "pacpet1_sonarqubeserver" {
  value       = aws_instance.Sonarqube_Server.public_ip
  description = "sonarqube server ip"
}

output "ALB" {
  value       = aws_lb.pacpet1-lb.dns_name
  description = "Load balancer"
}

output "nameserver" {
  value       = aws_route53_zone.hosted_zone.name_servers
  description = "nameserver"
}