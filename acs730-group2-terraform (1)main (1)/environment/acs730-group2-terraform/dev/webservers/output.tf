output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "Open this URL in your browser to test the Dev environment"
}

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "SSH to bastion: ssh -i vockey.pem ec2-user@<this_ip>"
}

output "asg_name" {
  value = aws_autoscaling_group.asg.name
}
