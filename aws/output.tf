
output "alb_dns_name" {
  value       = aws_lb.front_end.dns_name
  description = "Доменное имя ALB"
}
