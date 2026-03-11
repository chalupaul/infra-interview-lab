output "url" {
  description = "load balancer dns"
  value       = aws_lb.lb.dns_name
}

output "arn" {
  description = "cluster arn"
  value       = aws_ecs_cluster.main.arn
}

output "svc" {
  description = "service name"
  value       = aws_ecs_service.svc.name
}

output "tg" {
  description = "target group arn"
  value       = aws_lb_target_group.tg.arn
}
